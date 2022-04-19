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
};

pub const EventData = struct {
    event: Event,
    pos: Vec,
    button: PointerButton,
};

pub const PointerButton = struct {
    left: bool,
    right: bool,
    middle: bool,
};

pub const Vec = @Vector(2, f32);
pub fn vec_double(vec: Vec) @Vector(4, f32) {
    return .{ vec[0], vec[1], vec[0], vec[1] };
}
// struct {
//     x: f32,
//     y: f32,

//     pub fn mul(lhs: @This(), rhs: )
// };

/// Represents a rectangle as .{ left, top, right, bottom }
pub const Rect = @Vector(4, f32);
pub fn top(rect: Rect) f32 {
    return rect[1];
}
pub fn left(rect: Rect) f32 {
    return rect[0];
}
pub fn top_left(rect: Rect) Vec {
    return .{ rect[0], rect[1] };
}
pub fn right(rect: Rect) f32 {
    return rect[2];
}
pub fn bottom(rect: Rect) f32 {
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
// struct {
//     top: f32,
//     left: f32,
//     right: f32,
//     bottom: f32,

//     pub fn top_left(this: @This()) Vec {
//         return Vec{.x = this.left, .y = this.top};
//     }

//     pub fn width(this: @This()) f32 {
//         return this.right - this.left;
//     }
//     pub fn height(this: @This()) f32 {
//         return this.bottom - this.top;
//     }
// };

/// Available layout algorithms
pub const Layout = union(enum) {
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
    // VList,
    // Takes a slice of floats specifying the relative size of each column
    // Grid: []const f32,
};

/// Provide your basic types
pub fn UIContext(comptime T: type) type {
    return struct {
        modified: bool,
        /// A monotonically increasing integer assigning new handles
        handle_count: usize,
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
            handle: usize,
            event: Event,
            callback: fn (Node, Event) void,
        };

        pub const Node = struct {
            hidden: bool = false,
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
            data: T,
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
            if (parent_opt) |parent| {
                w4.trace("insert with parent");
                try this.nodes.insert(parent + 1, node);
                this.nodes.items[parent + 1].handle = handle;
                this.nodes.items[parent].children += 1;
            } else {
                w4.trace("insert no parent");
                try this.nodes.append(node);
                this.nodes.items[this.nodes.items.len - 1].handle = handle;
            }
            w4.tracef("%d nodes", this.nodes.items.len);
            return handle;
        }

        /// Call this method every time input is recieved
        pub fn update(this: *@This(), event: Event) void {
            var i: usize = 0;
            while (i < this.nodes.items.len) : (i += 1) {
                const node = this.nodes.items[i];
                if (node.hidden) {
                    i += node.children;
                    continue;
                }
                if (!rect_contains(node.bounds, event.pos))
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
            w4.trace("queue");
            var queue = std.PriorityQueue(NodeDepth, void, order_node_depth).init(this.alloc, {});
            defer queue.deinit();

            {
                var childIter = this.get_root_iter();
                w4.trace("childIter");
                // Layout top level
                while (childIter.next()) |child| {
                    this.nodes.items[child].bounds = screen;
                }
                w4.trace("top level rect");
            }

            {
                try queue.add(NodeDepth{ .node = 0, .depth = 0 });
            }

            while (queue.removeOrNull()) |node_depth| {
                const i = node_depth.node;
                const depth = node_depth.depth;
                const node = this.nodes.items[i];
                if (i + node.children + 1 < this.nodes.items.len) {
                    try queue.add(.{ .node = i + node.children + 1, .depth = depth });
                }
                var childIter = this.get_child_iter(i);
                switch (node.layout) {
                    .Relative => {
                        while (childIter.next()) |child| {
                            this.nodes.items[child].bounds = node.bounds;
                        }
                    },
                    .Anchor => |anchor_data| {
                        const anchor = rect_shift(
                            vec_double((bottom_right(node.bounds) - top_left(node.bounds))) * anchor_data.anchor,
                            top_left(node.bounds),
                        );
                        const margin = anchor + anchor_data.margin;
                        while (childIter.next()) |child| {
                            this.nodes.items[child].bounds = margin;
                        }
                    },
                }
            }
        }

        const ChildIter = struct {
            nodes: []Node,
            index: usize,
            end: usize,
            pub fn next(this: *@This()) ?usize {
                if (this.index > this.end) return null;
                const index = this.index;
                const node = this.nodes[this.index];
                this.index += node.children + 1;
                return index;
            }
        };
        pub fn get_child_iter(this: @This(), index: usize) ChildIter {
            const node = this.nodes.items[index];
            return ChildIter{
                .nodes = this.nodes.items,
                .index = index + 1,
                .end = index + node.children,
            };
        }

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
            const nodetree = this.nodes.items[index..node.children];
            var children: usize = 0;
            var i: usize = 0;
            while (i < nodetree.len) : (i += 1) {
                const child = nodetree[i];
                i += child.children;
                children += 1;
            }
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

        /// Get the parent of given element. Returns null if the parent is the root
        pub fn get_parent(this: @This(), id: usize) ?usize {
            if (id == 0) return null;
            if (id > this.get_count()) return null; // The id is outside of bounds
            var i: usize = id - 1;
            while (i > 0) : (i -= 1) {
                const node = this.nodes.items[i];
                // If the node's children includes the searched for id, it is a
                // parent, and our loop will end as soon as we find the first
                // one
                if (i + node.children >= id) return i;
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

// fn layout_grid(columns: []const f32, nodetree: []Node) void {
//     const grid = nodetree[0];
//     var total: f32 = 0;
//     for (columns) |col| {
//         total += col;
//     }
//     // Start with the first child
//     var index: usize = 1;
//     var which: usize = 0;
//     var bounds: ui.Rect = grid.bounds;
//     const width = bounds.width();
//     var left = bounds.left;
//     var row_height: f32 = 0;

//     // Iterate over children
//     while (index < nodetree.len) {
//         const child = nodetree[index];
//         // Skip over children's children, we only care about direct descendants
//         defer index += child.children + 1;
//         defer which += 1;

//         const col = which % columns.len;
//         // const row = @divFloor(which, total);

//         if (col == 0) {
//             // New row, recalculate bounds
//             left = bounds.left;
//             bounds.top += row_height;
//             row_height = 0;
//             var row_index = 0;
//             while (row_index < columns.len) : (row_index += 1) {
//                 // TODO: Iterate over row and calculate row height
//             }
//         }
//         const col_size = (columns[col] / total) * width;
//         var child_bounds = ui.Rect{
//             .top = bounds.top,
//             .left = left,
//             .right = left + col_size,
//             .bottom = row_height,
//         };
//         left = child_bounds.right;
//         child.bounds = child_bounds;
//     }
// }
