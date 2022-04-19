//! A simple backend agnostic UI library for zig. Provides tools to quickly layout
//! user interfaces in code and bring them to life on screen.
//! - Bring your own renderer and event loop.

const std = @import("std");
const ArrayList = std.ArrayList;
const w4 = @import("wasm4");

pub const default = @import("default.zig");

pub const Event = enum {
    PointerMotion,
    PointerPress,
    PointerRelease,
    PointerClick,
    PointerEnter,
    PointerLeave,
};

pub const InputData = struct {
    // event: Event,
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

pub const Vec = @Vector(2, i32);
pub fn vec_double(vec: Vec) @Vector(4, i32) {
    return .{ vec[0], vec[1], vec[0], vec[1] };
}

/// Represents a rectangle as .{ left, top, right, bottom }
pub const Rect = @Vector(4, i32);
pub fn top(rect: Rect) i32 {
    return rect[1];
}
pub fn left(rect: Rect) i32 {
    return rect[0];
}
pub fn top_left(rect: Rect) Vec {
    return .{ rect[0], rect[1] };
}
pub fn right(rect: Rect) i32 {
    return rect[2];
}
pub fn bottom(rect: Rect) i32 {
    return rect[3];
}
pub fn bottom_right(rect: Rect) Vec {
    return .{ rect[2], rect[3] };
}
pub fn rect_size(rect: Rect) Vec {
    return .{ rect[2] - rect[0], rect[3] - rect[1] };
}
pub fn rect_contains(rect: Rect, vec: Vec) bool {
    return @reduce(.And, top_left(rect) < vec) and @reduce(.And, bottom_right(rect) > vec);
}
pub fn rect_shift(rect: Rect, vec: Vec) Rect {
    return rect + vec_double(vec);
}

/// Available layout algorithms
pub const Layout = union(enum) {
    /// Default layout of root - expands children to fill entire space
    Fill,
    /// Default layout. Children are positioned relative to the parent with no
    /// attempt made to prevent overlapping.
    Relative,
    /// Specify an anchor (between 0 and 1) and a margin (in screen space) for
    /// childrens bounding box
    Anchor: struct { anchor: Rect, margin: Rect },
    // Divide horizontal space equally
    // HDiv,
    // Divide vertical space equally
    // VDiv,
    // Stack elements horizontally
    // HList,
    // Stack elements vertically
    VList: struct { top: i32 = 0 },
    // Takes a slice of ints specifying the relative size of each column
    // Grid: []const f32,
};

/// Provide your basic types
pub fn UIContext(comptime T: type) type {
    return struct {
        modified: bool,
        /// A monotonically increasing integer assigning new handles
        handle_count: usize,
        root_layout: Layout = .Relative,
        /// Array of all ui elements
        nodes: ArrayList(Node),
        listeners: ArrayList(Listener),
        alloc: std.mem.Allocator,

        // User defined functions
        updateFn: UpdateFn,
        paintFn: PaintFn,
        sizeFn: SizeFn,

        pub const UpdateFn = fn (Node) Node;
        pub const PaintFn = fn (Node) void;
        pub const SizeFn = fn (T) Vec;

        pub const Listener = struct {
            const Fn = fn (Node, Event) void;
            handle: usize,
            event: Event,
            callback: Fn,
        };

        pub const Node = struct {
            /// Determines whether the current node and it's children are visible
            hidden: bool = false,
            /// Indicates whether the rect has a background and
            has_background: bool = false,
            /// If the node captures pointer input
            capture_pointer: bool = false,
            /// Whether the pointer is over the node
            pointer_over: bool = false,
            /// If the pointer is pressed over the node
            pointer_pressed: bool = false,
            /// Pointer FSM
            pointer_state: enum { Open, Hover, Pressed, Clicked } = .Open,
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

            fn print_debug(this: @This()) void {
                const typename: [*:0]const u8 = @tagName(this.layout);
                const dataname: [*:0]const u8 = if (this.data) |data| @tagName(data) else "null";
                w4.tracef("type %s, data %s, children %d", typename, dataname, this.children);
            }
        };

        pub fn init(alloc: std.mem.Allocator, sizeFn: SizeFn, updateFn: UpdateFn, paintFn: PaintFn) @This() {
            return @This(){
                .alloc = alloc,
                .modified = false,
                .handle_count = 0,
                .nodes = ArrayList(Node).init(alloc),
                .listeners = ArrayList(Listener).init(alloc),
                .sizeFn = sizeFn,
                .updateFn = updateFn,
                .paintFn = paintFn,
            };
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

        pub fn dispatch(this: *@This(), handle: usize, event: Event) void {
            this.dispatch_raw(this.get_index_by_handle(handle), event);
        }

        fn dispatch_raw(this: *@This(), index: usize, event: Event) void {
            const node = this.nodes.items[index];
            for (this.listeners.items) |listener| {
                if (listener.handle == node.handle and event == listener.event) {
                    listener.callback(node, event);
                }
            }
            var parent_iter = this.get_parent_iter(index);
            while (parent_iter.next()) |parent_index| {
                const parent = this.nodes.items[parent_index];
                for (this.listeners.items) |listener| {
                    if (listener.handle == parent.handle and event == listener.event) {
                        listener.callback(parent, event);
                    }
                }
            }
        }

        /// Call this method every time input is recieved
        pub fn update(this: *@This(), inputs: InputData) void {
            {
                // Iterate backwards until we find an element that contains the mouse, then dispatch
                // the event. Dispatching will bubble the event to the topmost element.
                var mouse_captured = false;
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
                    if (rect_contains(node.bounds, inputs.pointer.pos)) {
                        this.nodes.items[i].pointer_over = true;
                        this.nodes.items[i].pointer_pressed = inputs.pointer.left;
                        if (node.capture_pointer and !mouse_captured) {
                            mouse_captured = true;
                            var mouse_enter = false;
                            var mouse_pressed = false;
                            var mouse_released = false;
                            // Node now contains the old state
                            if (!node.pointer_over) {
                                this.dispatch_raw(i, .PointerEnter);
                                mouse_enter = true;
                            }
                            if (node.pointer_pressed and !inputs.pointer.left) {
                                this.dispatch_raw(i, .PointerRelease);
                                mouse_released = true;
                            }
                            if (!node.pointer_pressed and inputs.pointer.left) {
                                this.dispatch_raw(i, .PointerPress);
                                mouse_pressed = true;
                            }
                            const nptr = &this.nodes.items[i].pointer_state;
                            switch (node.pointer_state) {
                                .Open => {
                                    if (mouse_enter) nptr.* = .Hover;
                                    if (mouse_pressed) nptr.* = .Pressed;
                                },
                                .Hover => {
                                    if (mouse_pressed) nptr.* = .Pressed;
                                },
                                .Pressed => {
                                    if (mouse_released) nptr.* = .Clicked;
                                },
                                .Clicked => {
                                    this.dispatch_raw(i, .PointerClick);
                                    nptr.* = .Open;
                                },
                            }
                        }
                    } else {
                        this.nodes.items[i].pointer_over = false;
                        this.nodes.items[i].pointer_pressed = false;
                        if (node.pointer_over) {
                            this.nodes.items[i].pointer_state = .Open;
                            this.dispatch_raw(i, .PointerLeave);
                        }
                    }
                }
            }

            for (this.nodes.items) |node, i| {
                this.nodes.items[i] = this.updateFn(node);
            }
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
        pub fn layout(this: *@This(), screen: Rect) !void {
            // Nothing to layout
            defer this.modified = false;
            if (this.nodes.items.len == 0) return;

            // Queue determines next item to run layout on
            var queue = std.PriorityQueue(NodeDepth, void, order_node_depth).init(this.alloc, {});
            defer queue.deinit();

            // Run the root layout function
            {
                var childIter = this.get_root_iter();
                // Layout top level
                var child_count: usize = 0;
                while (childIter.next()) |childi| : (child_count += 1) {
                    _ = this.run_layout(this.root_layout, screen, childi, child_count);
                    try queue.add(NodeDepth{ .node = childi, .depth = 0 });
                }
            }

            while (queue.removeOrNull()) |node_depth| {
                const i = node_depth.node;
                const depth = node_depth.depth;
                const node = this.nodes.items[i];
                if (node.layout == .VList) {
                    this.nodes.items[i].layout.VList.top = 0;
                }
                var childIter = this.get_child_iter(i);
                var child_count: usize = 0;
                while (childIter.next()) |childi| : (child_count += 1) {
                    this.nodes.items[i].layout = this.run_layout(this.nodes.items[i].layout, node.bounds, childi, child_count);
                    try queue.add(NodeDepth{ .node = childi, .depth = depth + 1 });
                }
            }
        }

        /// Runs the layout function and returns the new state of the layout component, if applicable
        fn run_layout(this: *@This(), which_layout: Layout, bounds: Rect, child_index: usize, _: usize) Layout {
            const child = this.nodes.items[child_index];
            switch (which_layout) {
                .Fill => {
                    this.nodes.items[child_index].bounds = bounds;
                    return .Fill;
                },
                .Relative => {
                    const pos = top_left(bounds);
                    // Layout top level
                    this.nodes.items[child_index].bounds = Rect{ pos[0], pos[1], child.min_size[0], child.min_size[1] };
                    return .Relative;
                },
                .Anchor => |anchor_data| {
                    const MAX = vec_double(.{ 100, 100 });
                    const size_doubled = vec_double((bottom_right(bounds) - top_left(bounds)));
                    const anchor = rect_shift(
                        @divTrunc((MAX - (MAX - anchor_data.anchor)) * size_doubled, MAX),
                        top_left(bounds),
                    );
                    const margin = anchor + anchor_data.margin;
                    this.nodes.items[child_index].bounds = margin;
                    return .{ .Anchor = anchor_data };
                },
                .VList => |vlist_data| {
                    const _left = bounds[0];
                    const _top = bounds[1] + vlist_data.top;
                    this.nodes.items[child_index].bounds = Rect{ _left, _top, _left + child.min_size[0], _top + child.min_size[1] };
                    return .{ .VList = .{ .top = _top + child.min_size[1] } };
                },
            }
        }

        const ChildIter = struct {
            nodes: []Node,
            index: usize,
            end: usize,
            pub fn next(this: *@This()) ?usize {
                if (this.index > this.end or this.index > this.nodes.len) return null;
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
            while (childIter.next()) : (children += 1) {}
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
            //
            return null;
        }

        /// Move an item to the front of it's parent. Will invalidate the given
        /// id and any ids under that parent that are in front of it.
        pub fn bring_to_front(this: *@This(), id: usize) void {
            std.debug.assert(id < this.nodes.len);
            if (id == this.nodes.len - 1) {
                // Do nothing, the node is already at the front
                return;
            }
            // Copy the array so we can shift things around
            const nodes = this.nodes.clone();
            defer nodes.deinit();
            const node = nodes.items[id];

            // Grab slice containing the node and its children
            const node_and_children = nodes.items[id .. id + node.children];

            const parent_id = this.get_parent(id);
            const parent = nodes.items[parent_id];
            const rest = nodes.items[id + node.children .. parent_id + parent.children];

            // Insert elements in new order
            this.nodes.replaceRange(id, rest.len, rest);
            this.nodes.replaceRange(id + rest.len, node_and_children.len, node_and_children);
        }
    };
}
