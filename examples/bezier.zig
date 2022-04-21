const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");

const draw = zow4.draw;
const geom = zow4.geometry;
const input = zow4.input;
const ui = zow4.ui;

const Context = zow4.ui.default.Context;
const Node = Context.Node;

//////////////////////
// Global Variables //
//////////////////////

var fba: std.heap.FixedBufferAllocator = undefined;
var allocator: std.mem.Allocator = undefined;
var ctx: Context = undefined;
var canvas: usize = undefined;

var edit_data: EditData = .{
    .points = .Zero, //.link = null,
};

////////////////////
// Initialization //
////////////////////

export fn start() void {
    real_start() catch @panic("failed to start");
}

var ui_buffer: [32 * 1024]u8 = undefined;
fn real_start() !void {
    fba = zow4.mem.init();
    allocator = fba.allocator();

    ctx = try zow4.ui.default.init(allocator);

    canvas = try ctx.insert(null, Node.anchor(.{ 0, 0, 100, 100 }, .{ 0, 0, 0, 0 }).capturePointer(true));
    try ctx.listen(canvas, .PointerClick, canvas_clicked);
}

////////////
// Update //
////////////

export fn update() void {
    const points = edit_data.points;
    switch (points) {
        .One => |pt| {
            w4.DRAW_COLORS.* = 0x40;
            const x = @floatToInt(i32, pt[0]);
            const y = @floatToInt(i32, pt[1]);
            w4.oval(x - 2, y - 2, 4, 4);
        },
        .Two => |pts| {
            w4.DRAW_COLORS.* = 0x04;
            const x = @floatToInt(i32, pts[0][0]);
            const y = @floatToInt(i32, pts[0][1]);
            const x2 = @floatToInt(i32, pts[1][0]);
            const y2 = @floatToInt(i32, pts[1][1]);
            w4.line(x, y, x2, y2);
        },
        .Three => |pts| {
            w4.DRAW_COLORS.* = 0x04;
            draw.quadratic_bezier(pts[0], pts[1], pts[2]);
        },
        .Four => |pts| {
            w4.DRAW_COLORS.* = 0x04;
            draw.cubic_bezier(pts[0], pts[1], pts[2], pts[3]);
        },
        else => {},
    }

    zow4.ui.default.update(&ctx);
}

/////////////////////
// Data Structures //
/////////////////////

const EditState = union(enum) {
    Zero,
    One: geom.Vec2f,
    Two: [2]geom.Vec2f,
    Three: [3]geom.Vec2f,
    Four: [4]geom.Vec2f,
    fn add_point(this: @This(), point: geom.Vec2f) @This() {
        return switch (this) {
            .Zero => .{ .One = point },
            .One => |pt| .{ .Two = .{ pt, point } },
            .Two => |pts| .{ .Three = .{ pts[0], pts[1], point } },
            .Three => |pts| .{ .Four = .{ pts[0], pts[1], pts[2], point } },
            .Four => this,
        };
    }
};

const EditData = struct {
    points: EditState,
};

fn canvas_clicked(_: Node, ev: ui.EventData) ?Node {
    // w4.trace("click");
    if (edit_data.points == .Four) {
        edit_data.points = .Zero;
        // add_curve() catch w4.trace("add curve failed");
    }
    const mouse_pos = geom.vec.itof(ev.pointer.pos);
    edit_data.points = edit_data.points.add_point(mouse_pos);
    return null;
}
