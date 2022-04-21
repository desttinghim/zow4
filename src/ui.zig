//! A simple backend agnostic UI library for zig. Provides tools to quickly layout
//! user interfaces in code and bring them to life on screen. Depends only on the
//! zig std library.

const std = @import("std");

const g = @import("geometry.zig");
const Vec = g.Vec2;
const Rect = g.Rect;

const Allocator = std.mem.Allocator;

/// Mimics the array list api, but operates on a fixed slice that is passed in
fn SliceList(comptime T: type) type {
    return struct {
        items: []T,
        capacity: []T,

        pub fn init(buffer: []u8) @This() {
            const start = std.mem.alignPointer(buffer.ptr, @alignOf(T)).?; //orelse return error.OutOfMemory;
            const ptr = @ptrCast([*]T, @alignCast(@alignOf(T), start));
            const items = ptr[0..1];
            return @This(){
                .items = items,
                .capacity = ptr[0..@divTrunc(buffer.len, @alignOf(T))],
            };
        }

        /// Insert `item` at index `n`. Moves `list[n .. list.len]`
        /// to higher indices to make room.
        /// This operation is O(N).
        pub fn insert(this: *@This(), n: usize, item: T) Allocator.Error!void {
            if (this.items.len >= this.capacity.len) return error.OutOfMemory;
            this.items.len += 1;

            std.mem.copyBackwards(T, this.items[n + 1 .. this.items.len], this.items[n .. this.items.len - 1]);
            this.items[n] = item;
        }

        /// Extend the list by 1 element.
        pub fn append(this: *@This(), item: T) Allocator.Error!void {
            if (this.items.len >= this.capacity.len) return error.OutOfMemory;
            this.items.len += 1;
            this.items[this.items.len - 1] = item;
        }

        /// Removes the element at the specified index and returns it.
        /// The empty slot is filled from the end of the list.
        /// Invalidates pointers to last element.
        /// This operation is O(1).
        pub fn swapRemove(this: *@This(), i: usize) T {
            if (this.items.len - 1 == i) return this.pop();

            const old_item = this.items[i];
            this.items[i] = this.pop();
            return old_item;
        }

        /// Remove and return the last element from the list.
        /// Asserts the list has at least one item.
        /// Invalidates pointers to last element.
        pub fn pop(this: *@This()) T {
            const val = this.items[this.items.len - 1];
            this.items.len -= 1;
            return val;
        }

        /// Reduce length to `new_len`.
        /// Invalidates pointers to elements `items[new_len..]`.
        /// Keeps capacity the same.
        pub fn shrinkRetainingCapacity(this: *@This(), new_len: usize) void {
            std.debug.assert(new_len <= this.items.len);
            this.items.len = new_len;
        }
    };
}

const List = std.ArrayList;

pub const Event = enum {
    PointerMove,
    PointerPress,
    PointerRelease,
    PointerClick,
    PointerEnter,
    PointerLeave,
};

pub const EventData = struct {
    _type: Event,
    pointer: PointerData,
};

pub const InputData = struct {
    pointer: PointerData,
    keys: KeyData,
};

pub const PointerData = struct {
    left: bool,
    right: bool,
    middle: bool,
    pos: Vec,
};

pub const KeyData = struct {
    up: bool,
    down: bool,
    left: bool,
    right: bool,
    accept: bool,
    reject: bool,
};

/// Available layout algorithms
pub const Layout = union(enum) {
    /// Default layout of root - expands children to fill entire space
    Fill,
    /// Default layout. Children are positioned relative to the parent with no
    /// attempt made to prevent overlapping.
    Relative,
    /// Keep elements centered
    Center,
    /// Specify an anchor (between 0 and 1) and a margin (in screen space) for
    /// childrens bounding box
    Anchor: struct { anchor: Rect, margin: Rect },
    // Divide horizontal space equally
    HDiv,
    // Divide vertical space equally
    VDiv,
    // Stack elements horizontally
    HList: struct { left: i32 = 0 },
    // Stack elements vertically
    VList: struct { top: i32 = 0 },
    // Takes a slice of ints specifying the relative size of each column
    // Grid: []const f32,
};

/// Provide your basic types
pub fn Context(comptime T: type) type {
    return struct {
        modified: bool,
        inputs_last: InputData = .{
            .pointer = .{ .pos = Vec{ 0, 0 }, .left = false, .right = false, .middle = false },
            .keys = .{
                .up = false,
                .left = false,
                .right = false,
                .down = false,
                .accept = false,
                .reject = false,
            },
        },
        pointer_start_press: Vec = Vec{ 0, 0 },
        /// A monotonically increasing integer assigning new handles
        handle_count: usize,
        root_layout: Layout = .Fill,
        /// Array of all ui elements
        nodes: List(Node),
        /// Array of listeners
        listeners: List(Listener),
        /// Array of reorder operations to perform
        reorder_op: ?Reorder,

        // User defined functions
        updateFn: UpdateFn,
        paintFn: PaintFn,
        sizeFn: SizeFn,

        // Reorder operations that can take significant processing time, so
        // wait until we are doing layout to begin
        const Reorder = union(enum) {
            // Insert: usize,
            Remove: usize,
            BringToFront: usize,
        };

        pub const UpdateFn = fn (Node) Node;
        pub const PaintFn = fn (Node) void;
        pub const SizeFn = fn (T) Vec;

        pub const Listener = struct {
            const Fn = fn (Node, EventData) ?Node;
            handle: usize,
            event: Event,
            callback: Fn,
        };

        pub const Node = struct {
            /// Determines whether the current node and it's children are visible
            hidden: bool = false,
            /// Indicates whether the rect has a background and
            has_background: bool = false,
            /// If the node recieves pointer events
            capture_pointer: bool = false,
            /// If the node prevents other nodes from recieving events
            event_filter: EventFilter = .Prevent,
            /// Whether the pointer is over the node
            pointer_over: bool = false,
            /// If the pointer is pressed over the node
            pointer_pressed: bool = false,
            /// Pointer FSM
            pointer_state: enum { Open, Hover, Press, Drag, Click } = .Open,
            /// How many descendants this node has
            children: usize = 0,
            /// A unique handle
            handle: usize = 0,
            /// Minimum size of the element
            min_size: Vec = Vec{ 0, 0 },
            /// Screen space rectangle
            bounds: Rect = Rect{ 0, 0, 0, 0 },
            /// What layout function to use on children
            layout: Layout = .Relative,
            /// User specified type
            data: ?T = null,

            const EventFilter = union(enum) { Prevent, Pass, PassExcept: Event };

            pub fn anchor(_anchor: Rect, margin: Rect) @This() {
                return @This(){
                    .layout = .{
                        .Anchor = .{
                            .anchor = _anchor,
                            .margin = margin,
                        },
                    },
                };
            }

            pub fn fill() @This() {
                return @This(){
                    .layout = .Fill,
                };
            }

            pub fn relative() @This() {
                return @This(){
                    .layout = .Relative,
                };
            }

            pub fn center() @This() {
                return @This(){
                    .layout = .Center,
                };
            }

            pub fn vlist() @This() {
                return @This(){
                    .layout = .{ .VList = .{} },
                };
            }

            pub fn hlist() @This() {
                return @This(){
                    .layout = .{ .HList = .{} },
                };
            }

            pub fn vdiv() @This() {
                return @This(){
                    .layout = .{ .VDiv = .{} },
                };
            }

            pub fn hdiv() @This() {
                return @This(){
                    .layout = .{ .HDiv = .{} },
                };
            }

            pub fn capturePointer(this: @This(), value: bool) @This() {
                var node = this;
                node.capture_pointer = value;
                return node;
            }

            pub fn eventFilter(this: @This(), value: EventFilter) @This() {
                var node = this;
                node.event_filter = value;
                return node;
            }

            pub fn hasBackground(this: @This(), value: bool) @This() {
                var node = this;
                node.has_background = value;
                return node;
            }

            pub fn dataValue(this: @This(), value: T) @This() {
                var node = this;
                node.data = value;
                return node;
            }

            pub fn minSize(this: @This(), value: Vec) @This() {
                var node = this;
                node.min_size = value;
                return node;
            }
        };

        pub fn init(alloc: Allocator, sizeFn: SizeFn, updateFn: UpdateFn, paintFn: PaintFn) !@This() {
            var listenerlist = try List(Listener).initCapacity(alloc, 20);
            var nodelist = try List(Node).initCapacity(alloc, 20);
            return @This(){
                .modified = true,
                .handle_count = 100,
                .nodes = nodelist,
                .listeners = listenerlist,
                .reorder_op = null,
                .sizeFn = sizeFn,
                .updateFn = updateFn,
                .paintFn = paintFn,
            };
        }

        pub fn print_list(this: @This(), alloc: Allocator, print: fn ([]const u8) void) !void {
            const header = try std.fmt.allocPrint(
                alloc,
                "{s:^16}|{s:^16}|{s:^8}|{s:^8}",
                .{ "layout", "datatype", "children", "hidden" },
            );
            defer this.alloc.free(header);
            print(header);
            for (this.nodes.items) |node| {
                const typename: [*:0]const u8 = @tagName(node.layout);
                const dataname: [*:0]const u8 = if (node.data) |data| @tagName(data) else "null";
                const log = try std.fmt.allocPrint(
                    this.alloc,
                    "{s:<16}|{s:^16}|{:^8}|{:^8}",
                    .{ typename, dataname, node.children, node.hidden },
                );
                defer this.alloc.free(log);
                print(log);
            }
        }

        pub fn print_debug(this: @This(), print: fn ([]const u8) void) void {
            var child_iter = this.get_root_iter();
            while (child_iter.next()) |childi| {
                this.print_recursive(print, childi, 0);
            }
        }

        pub fn print_recursive(this: @This(), print: fn ([]const u8) void, index: usize, depth: usize) void {
            const node = this.nodes.items[index];
            const typename: [*:0]const u8 = @tagName(node.layout);
            const dataname: [*:0]const u8 = if (node.data) |data| @tagName(data) else "null";
            const depth_as_bits = @as(u8, 1) << @intCast(u3, depth);
            const log = std.fmt.allocPrint(
                this.alloc,
                "{b:>8}\t{:>16}|{s:<16}|{s:^16}|{:^8}|{:^8}",
                .{ depth_as_bits, node.handle, typename, dataname, node.children, node.hidden },
            ) catch @panic("yeah");
            defer this.alloc.free(log);
            print(log);
            var child_iter = this.get_child_iter(index);
            while (child_iter.next()) |childi| {
                this.print_recursive(print, childi, depth + 1);
            }
        }

        /// Create a new node under given parent. Pass null to create a top level element.
        pub fn insert(this: *@This(), parent_opt: ?usize, node: Node) !usize {
            this.modified = true;
            const handle = this.handle_count;
            this.handle_count += 1;
            var index: usize = undefined;
            var no_parent = parent_opt == null;
            if (parent_opt) |parent_handle| {
                const parent_o = this.get_index_by_handle(parent_handle);
                if (parent_o) |parent| {
                    const p = this.nodes.items[parent];
                    index = parent + p.children + 1;
                    try this.nodes.insert(index, node);
                    this.nodes.items[index].handle = handle;

                    this.nodes.items[parent].children += 1;
                    var parent_iter = this.get_parent_iter(parent);
                    while (parent_iter.next()) |ancestor| {
                        this.nodes.items[ancestor].children += 1;
                    }
                } else {
                    no_parent = true;
                }
            }
            if (no_parent) {
                try this.nodes.append(node);
                index = this.nodes.items.len - 1;
                this.nodes.items[index].handle = handle;
            }
            if (node.data) |data| {
                this.nodes.items[index].min_size = this.sizeFn(data);
            }
            return handle;
        }

        pub fn listen(this: *@This(), handle: usize, event: Event, listenFn: Listener.Fn) !void {
            try this.listeners.append(.{
                .handle = handle,
                .event = event,
                .callback = listenFn,
            });
        }

        pub fn listen_maybe(this: *@This(), handle: usize, event: Event, listenFn: Listener.Fn) void {
            this.listeners.append(.{
                .handle = handle,
                .event = event,
                .callback = listenFn,
            }) catch {
                // Don't do anything about the error
            };
        }

        pub fn unlisten(this: *@This(), handle: usize, event: Event, listenFn: Listener.Fn) void {
            var i: usize = 0;
            while (i < this.listeners.items.len) : (i += 1) {
                const listener = this.listeners.items[i];
                if (listener.handle == handle and listener.event == event and listener.callback == listenFn) {
                    _ = this.listeners.swapRemove(i);
                    break;
                }
            }
        }

        pub fn dispatch(this: *@This(), handle: usize, event: EventData) void {
            this.dispatch_raw(this.get_index_by_handle(handle), event);
        }

        fn dispatch_raw(this: *@This(), index: usize, event: EventData) void {
            // TODO: Account for user reordering requests.
            const node = this.nodes.items[index];
            for (this.listeners.items) |listener| {
                if (listener.handle == node.handle and event._type == listener.event) {
                    if (listener.callback(node, event)) |new_node| {
                        this.nodes.items[index] = new_node;
                        this.modified = true;
                    }
                }
            }
            switch (node.event_filter) {
                .Pass => {},
                .PassExcept => |except| if (except == event._type) return,
                .Prevent => return,
            }
            var parent_iter = this.get_parent_iter(index);
            while (parent_iter.next()) |parent_index| {
                const parent = this.nodes.items[parent_index];
                // TODO: filter here as well
                for (this.listeners.items) |listener| {
                    if (listener.handle == parent.handle and event._type == listener.event) {
                        if (listener.callback(parent, event)) |new_node| {
                            this.nodes.items[parent_index] = new_node;
                            this.modified = true;
                        }
                    }
                }
            }
        }

        /// Call this method every time input is recieved
        pub fn update(this: *@This(), inputs: InputData) void {
            {
                // Collect info about state
                const pointer_diff = inputs.pointer.pos - this.inputs_last.pointer.pos;
                const pointer_move = @reduce(.Or, pointer_diff != Vec{ 0, 0 });
                const pointer_press = !this.inputs_last.pointer.left and inputs.pointer.left;
                const pointer_release = this.inputs_last.pointer.left and !inputs.pointer.left;
                if (pointer_press) {
                    this.pointer_start_press = inputs.pointer.pos;
                }
                const drag_threshold = 10 * 10;
                const pointer_drag = inputs.pointer.left and pointer_move and g.vec.dist_sqr(this.pointer_start_press, inputs.pointer.pos) > drag_threshold;

                // Iterate backwards until we find an element that contains the pointer, then dispatch
                // the event. Dispatching will bubble the event to the topmost element.
                var pointer_captured = false;
                var i = this.nodes.items.len - 1;
                var run = true;
                while (run) : (i -|= 1) {
                    const node = this.nodes.items[i];
                    defer if (i == 0) {
                        // TODO: store root listeners
                        // this.dispatch_root(.PointerRelease);
                        run = false;
                    };
                    if (node.hidden) {
                        continue;
                    }
                    if (g.rect.contains(node.bounds, inputs.pointer.pos) and node.capture_pointer and !pointer_captured) {
                        this.nodes.items[i].pointer_over = true;
                        this.nodes.items[i].pointer_pressed = inputs.pointer.left;
                        if (node.event_filter == .Prevent) {
                            pointer_captured = true;
                        }
                        var pointer_enter = false;
                        // Node now contains the old state
                        var event_data = EventData{ ._type = .PointerEnter, .pointer = inputs.pointer };
                        if (!node.pointer_over) {
                            event_data._type = .PointerEnter;
                            this.dispatch_raw(i, event_data);
                            pointer_enter = true;
                        }
                        if (pointer_move) {
                            event_data._type = .PointerMove;
                            this.dispatch_raw(i, event_data);
                        }
                        if (pointer_release) {
                            event_data._type = .PointerRelease;
                            this.dispatch_raw(i, event_data);
                        }
                        if (pointer_press) {
                            event_data._type = .PointerPress;
                            this.dispatch_raw(i, event_data);
                        }
                        const nptr = &this.nodes.items[i].pointer_state;
                        switch (node.pointer_state) {
                            .Open => {
                                if (pointer_enter) nptr.* = .Hover;
                                if (pointer_press) nptr.* = .Press;
                            },
                            .Hover => {
                                if (pointer_press) nptr.* = .Press;
                            },
                            .Press => {
                                if (pointer_release) nptr.* = .Click;
                                if (pointer_drag) nptr.* = .Drag;
                            },
                            .Drag => {
                                if (pointer_release) nptr.* = .Hover;
                            },
                            .Click => {
                                event_data._type = .PointerClick;
                                this.dispatch_raw(i, event_data);
                                nptr.* = .Open;
                            },
                        }
                    } else {
                        this.nodes.items[i].pointer_over = false;
                        this.nodes.items[i].pointer_pressed = false;
                        if (node.pointer_over) {
                            this.nodes.items[i].pointer_state = .Open;
                            this.dispatch_raw(i, .{ ._type = .PointerLeave, .pointer = inputs.pointer });
                        }
                    }
                }
            }

            for (this.nodes.items) |node, i| {
                this.nodes.items[i] = this.updateFn(node);
            }
            this.inputs_last = inputs;
        }

        pub fn paint(this: *@This()) void {
            var i: usize = 0;
            while (i < this.nodes.items.len) : (i += 1) {
                const node = this.nodes.items[i];
                if (node.hidden) {
                    i += node.children;
                    continue;
                }
                this.paintFn(node);
            }
        }

        const NodeDepth = struct { node: usize, depth: usize };

        fn order_node_depth(context: void, a: NodeDepth, b: NodeDepth) std.math.Order {
            _ = context;
            return std.math.order(a.depth, b.depth);
        }

        /// Layout
        pub fn layout(this: *@This(), screen: Rect) void {
            // Nothing to layout
            if (this.nodes.items.len == 0) return;
            // If nothing has been modified, we don't need to proceed
            if (!this.modified) return;
            // Perform reorder operation if one was queued
            if (this.reorder_op != null) {
                this.reorder();
            }

            if (this.root_layout == .VList) {
                this.root_layout.VList.top = 0;
            }
            if (this.root_layout == .HList) {
                this.root_layout.HList.left = 0;
            }

            // Layout top level
            var childIter = this.get_root_iter();
            const child_count = this.get_root_child_count();
            var child_num: usize = 0;
            while (childIter.next()) |childi| : (child_num += 1) {
                this.root_layout = this.run_layout(this.root_layout, screen, childi, child_num, child_count);
                // Run layout for child nodes
                this.layout_children(childi);
            }
        }

        pub fn layout_children(this: *@This(), index: usize) void {
            const node = this.nodes.items[index];
            if (node.layout == .VList) {
                this.nodes.items[index].layout.VList.top = 0;
            }
            if (node.layout == .HList) {
                this.nodes.items[index].layout.HList.left = 0;
            }
            var childIter = this.get_child_iter(index);
            const child_count = this.get_child_count(index);
            var child_num: usize = 0;
            while (childIter.next()) |childi| : (child_num += 1) {
                this.nodes.items[index].layout = this.run_layout(this.nodes.items[index].layout, node.bounds, childi, child_num, child_count);
                // Run layout for child nodes
                this.layout_children(childi);
            }
        }

        /// Runs the layout function and returns the new state of the layout component, if applicable
        fn run_layout(this: *@This(), which_layout: Layout, bounds: Rect, child_index: usize, child_num: usize, child_count: usize) Layout {
            const child = this.nodes.items[child_index];
            switch (which_layout) {
                .Fill => {
                    this.nodes.items[child_index].bounds = bounds;
                    return .Fill;
                },
                .Relative => {
                    const pos = g.rect.top_left(bounds);
                    // Layout top level
                    this.nodes.items[child_index].bounds = Rect{ pos[0], pos[1], pos[0] + child.min_size[0], pos[1] + child.min_size[1] };
                    return .Relative;
                },
                .Center => {
                    const min_half = @divTrunc(child.min_size, Vec{ 2, 2 });
                    const center = @divTrunc(g.rect.size(bounds), Vec{ 2, 2 });
                    const pos = g.rect.top_left(bounds) + center - min_half;
                    // Layout top level
                    this.nodes.items[child_index].bounds = Rect{ pos[0], pos[1], pos[0] + child.min_size[0], pos[1] + child.min_size[1] };
                    return .Center;
                },
                .Anchor => |anchor_data| {
                    const MAX = g.vec.double(.{ 100, 100 });
                    const size_doubled = g.vec.double((g.rect.bottom_right(bounds) - g.rect.top_left(bounds)));
                    const anchor = g.rect.shift(
                        @divTrunc((MAX - (MAX - anchor_data.anchor)) * size_doubled, MAX),
                        g.rect.top_left(bounds),
                    );
                    const margin = anchor + anchor_data.margin;
                    this.nodes.items[child_index].bounds = margin;
                    return .{ .Anchor = anchor_data };
                },
                .VList => |vlist_data| {
                    const _left = bounds[0];
                    const _top = bounds[1] + vlist_data.top;
                    this.nodes.items[child_index].bounds = Rect{ _left, _top, bounds[2], _top + child.min_size[1] };
                    return .{ .VList = .{ .top = vlist_data.top + child.min_size[1] } };
                },
                .HList => |hlist_data| {
                    const _left = bounds[0] + hlist_data.left;
                    const _top = bounds[1];
                    this.nodes.items[child_index].bounds = Rect{ _left, _top, _left + child.min_size[0], bounds[3] };
                    return .{ .HList = .{ .left = hlist_data.left + child.min_size[0] } };
                },
                .VDiv => {
                    const vsize = @divTrunc(g.rect.size(bounds)[1], @intCast(i32, child_count));
                    const num = @intCast(i32, child_num);
                    this.nodes.items[child_index].bounds = Rect{ bounds[0], bounds[1] + vsize * num, bounds[2], bounds[1] + vsize * (num + 1) };
                    return .VDiv;
                },
                .HDiv => {
                    const hsize = @divTrunc(g.rect.size(bounds)[0], @intCast(i32, child_count));
                    const num = @intCast(i32, child_num);
                    this.nodes.items[child_index].bounds = Rect{ bounds[0] + hsize * num, bounds[1], bounds[0] + hsize * (num + 1), bounds[3] };
                    return .HDiv;
                },
            }
        }

        const ChildIter = struct {
            nodes: []Node,
            index: usize,
            end: usize,
            pub fn next(this: *@This()) ?usize {
                if (this.index > this.end or this.index >= this.nodes.len) return null;
                const index = this.index;
                const node = this.nodes[this.index];
                this.index += node.children + 1;
                return index;
            }
        };

        /// Returns an iterator over the direct childtren of given node
        pub fn get_child_iter(this: @This(), index: usize) ChildIter {
            const node = this.nodes.items[index];
            return ChildIter{
                .nodes = this.nodes.items,
                .index = index + 1,
                .end = index + node.children,
            };
        }

        /// Returns an iterator over the root's direct children
        pub fn get_root_iter(this: @This()) ChildIter {
            return ChildIter{
                .nodes = this.nodes.items,
                .index = 0,
                .end = this.nodes.items.len - 1,
            };
        }

        /// Returns a count of the direct children of the node
        pub fn get_child_count(this: @This(), index: usize) usize {
            const node = this.nodes.items[index];
            if (node.children <= 1) return node.children;
            var children: usize = 0;
            var childIter = this.get_child_iter(index);
            while (childIter.next()) |_| : (children += 1) {}
            return children;
        }

        pub fn get_root_child_count(this: @This()) usize {
            if (this.get_count() <= 1) return this.get_count();
            var children: usize = 0;
            var childIter = this.get_root_iter();
            while (childIter.next()) |_| : (children += 1) {}
            return children;
        }

        pub fn get_count(this: @This()) usize {
            return this.nodes.items.len;
        }

        pub fn get_index_by_handle(this: @This(), handle: usize) ?usize {
            for (this.nodes.items) |node, i| {
                if (node.handle == handle) return i;
            }
            return null;
        }

        pub fn get_node(this: @This(), handle: usize) ?Node {
            if (this.get_index_by_handle(handle)) |node| {
                return this.nodes.items[node];
            }
            return null;
        }

        pub fn set_slice_hidden(slice: []Node, hidden: bool) void {
            for (slice) |*node| {
                node.*.hidden = hidden;
            }
        }

        pub fn hide_node(this: *@This(), handle: usize) bool {
            if (this.get_index_by_handle(handle)) |i| {
                var rootnode = this.nodes.items[i];
                var slice = this.nodes.items[i .. i + rootnode.children];
                set_slice_hidden(slice, true);
                return true;
            }
            return false;
        }

        pub fn show_node(this: *@This(), handle: usize) bool {
            if (this.get_index_by_handle(handle)) |i| {
                var rootnode = this.nodes.items[i];
                var slice = this.nodes.items[i .. i + rootnode.children];
                set_slice_hidden(slice, false);
                return true;
            }
            return false;
        }

        pub fn toggle_hidden(this: *@This(), handle: usize) bool {
            if (this.get_index_by_handle(handle)) |i| {
                const rootnode = this.nodes.items[i];
                const hidden = !rootnode.hidden;
                var slice = this.nodes.items[i .. i + rootnode.children];
                set_slice_hidden(slice, hidden);
                return true;
            }
            return false;
        }

        /// Returns true if the node existed
        pub fn set_node(this: *@This(), node: Node) bool {
            if (this.get_index_by_handle(node.handle)) |i| {
                this.nodes.items[i] = node;
                this.modified = true;
                return true;
            }
            return false;
        }

        const ParentIter = struct {
            nodes: []Node,
            index: usize,
            child_component: usize,
            pub fn next(this: *@This()) ?usize {
                const index = this.index;
                while (true) : (this.index -|= 1) {
                    const node = this.nodes[this.index];
                    if (index != this.index and this.index + node.children >= this.child_component) {
                        // Never return with the same index as we started with
                        return this.index;
                    }
                    if (this.index == 0) return null;
                }
                return null;
            }
        };

        pub fn get_parent_iter(this: @This(), index: usize) ParentIter {
            return ParentIter{
                .nodes = this.nodes.items,
                .index = index,
                .child_component = index,
            };
        }

        /// Get the parent of given element. Returns null if the parent is the root
        pub fn get_parent(this: @This(), id: usize) ?usize {
            if (id == 0) return null;
            if (id > this.get_count()) return null; // The id is outside of bounds
            var i: usize = id - 1;
            while (true) : (i -= 1) {
                const node = this.nodes.items[i];
                // If the node's children includes the searched for id, it is a
                // parent, and our loop will end as soon as we find the first
                // one
                if (i + node.children >= id) return i;
                if (i == 0) break;
            }
            return null;
        }

        ///////////////////////////
        // Reordering Operations //
        ///////////////////////////

        /// Prepare to move a nodetree to the front of it's parent
        pub fn bring_to_front(this: *@This(), handle: usize) void {
            this.modified = true;
            if (this.reorder_op != null) {
                this.reorder();
            }
            this.reorder_op = .{ .BringToFront = handle };
        }

        /// Queue a nodetree for removal
        pub fn remove(this: *@This(), handle: usize) void {
            this.modified = true;
            if (this.reorder_op != null) {
                this.reorder();
            }
            this.reorder_op = .{ .Remove = handle };
        }

        /// Empty reorder list
        fn reorder(this: *@This()) void {
            if (this.reorder_op) |op| {
                this.run_reorder(op);
            }
            this.reorder_op = null;
        }

        fn run_reorder(this: *@This(), reorder_op: Reorder) void {
            switch (reorder_op) {
                .Remove => |handle| {
                    // Get the node
                    const index = this.get_index_by_handle(handle) orelse return;
                    const node = this.nodes.items[index];
                    const count = node.children + 1;

                    // Get slice of children and rest
                    const rest_slice = this.nodes.items[index + node.children + 1 ..];

                    // Move all elements back by the length of node.children
                    std.mem.copy(Node, this.nodes.items[index .. index + rest_slice.len], rest_slice);

                    // Remove children count from parents
                    var parent_iter = this.get_parent_iter(index);
                    while (parent_iter.next()) |parent| {
                        std.debug.assert(this.nodes.items[parent].children > node.children);
                        this.nodes.items[parent].children -= count;
                    }

                    // Remove unneeded slots
                    this.nodes.shrinkRetainingCapacity(index + rest_slice.len);
                },
                .BringToFront => |handle| {
                    const index = this.get_index_by_handle(handle) orelse return;
                    // Do nothing, the node is already at the front
                    if (index == this.nodes.items.len - 1) return;

                    const node = this.nodes.items[index];
                    const slice = slice: {
                        if (this.get_parent(index)) |parent_index| {
                            const parent = this.nodes.items[parent_index];
                            break :slice this.nodes.items[index .. parent_index + parent.children + 1];
                        } else {
                            break :slice this.nodes.items[index..];
                        }
                    };

                    std.mem.rotate(Node, slice, node.children + 1);
                },
            }
        }
    };
}
