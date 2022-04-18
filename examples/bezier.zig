const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");
const draw = zow4.draw;
const geom = zow4.geometry;
const input = zow4.input;
const ui = zow4.ui;

const Stage = zow4.ui.Stage;
//////////////////////
// Global Variables //
//////////////////////

var fba: std.heap.FixedBufferAllocator = undefined;
var allocator: std.mem.Allocator = undefined;
var stage: *Stage = undefined;
var canvas: *ui.Element = undefined;

var grabbed: ?*ui.Element = null;
var grab_point: ?geom.Vec2 = null;
var edit_data: EditData = .{ .points = .Zero, .link = null };
var paths: PathRenderer = undefined;

////////////////////
// Initialization //
////////////////////

export fn start() void {
    real_start() catch @panic("failed to start");
}

fn real_start() !void {
    fba = zow4.heap.init();
    allocator = fba.allocator();

    stage = try Stage.init(allocator);

    canvas = try stage.float(geom.AABB.init(0, 0, 160, 160));
    canvas.listen(.MouseClicked, canvas_clicked);
    stage.root.appendChild(canvas);

    paths = PathRenderer.init(allocator);
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
        else => {},
    }

    // w4.trace("rendering");
    for (paths.get_slice()) |segment| {
        w4.DRAW_COLORS.* = 0x04;
        segment.render();
    }

    stage.update();
    // w4.trace("updated");
    stage.render();
    // w4.trace("rendered");

    // if (grabbed) |el| {
    //     if (grab_point) |point| {
    //         el.size.pos = input.mousepos() - point;
    //     }
    // }

    input.update();
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
    link: ?*SegmentHandle,
};

const PathRenderer = struct {
    segments: std.ArrayList(PathSegment),

    fn init(alloc: std.mem.Allocator) @This() {
        return @This(){
            .segments = std.ArrayList(PathSegment).init(alloc),
        };
    }

    fn get_slice(this: *@This()) []PathSegment {
        return this.segments.items;
    }

    fn get(this: *@This(), segment: usize) PathSegment {
        return this.segments.items[segment];
    }

    fn set(this: *@This(), id: usize, segment: PathSegment) void {
        w4.tracef("setting %d", id);
        this.segments.items[id] = segment;
        const segptr = &this.segments.items[id];
        if (segment.next) |next| {
            w4.trace("updating next");
            this.segments.items[next].points[0] = segptr.points[3];
        }
        if (segment.prev) |prev| {
            w4.trace("updating prev");
            this.segments.items[prev].points[3] = segptr.points[0];
        }
    }

    fn set_point(this: *@This(), id: usize, which: usize, vec: geom.Vec2) void {
        this.segments.items[id].points[which] = vec;
        if (this.segments.next) |next| {
            w4.trace("updating next");
            this.segments.items[next].points[0] = this.segments.items[id].points[3];
        }
    }

    fn deinit(this: *@This()) void {
        this.segments.deinit();
    }

    fn append(this: *@This(), segment: PathSegment) !usize {
        try this.segments.append(segment);
        w4.tracef("appended %d", this.segments.items.len - 1);
        return this.segments.items.len - 1;
    }
};

const PathSegment = struct {
    points: [4]geom.Vec2f,
    /// Previous point in path
    prev: ?usize = null,
    /// Next point in path
    next: ?usize = null,

    pub fn init(p1: geom.Vec2f, p2: geom.Vec2f, p3: geom.Vec2f, p4: geom.Vec2f) @This() {
        return .{ .points = .{ p1, p2, p3, p4 } };
    }

    /// Draw this part of the line segment
    pub fn render(this: @This()) void {
        draw.cubic_bezier(this.points[0], this.points[1], this.points[2], this.points[3]);
    }
};

const QuadraticBezier = struct {
    p1: geom.Vec2f,
    p2: geom.Vec2f,
    p3: geom.Vec2f,

    pub fn init(p1: geom.Vec2f, p2: geom.Vec2f, p3: geom.Vec2f) @This() {
        return .{ .p1 = p1, .p2 = p2, .p3 = p3 };
    }

    pub fn render(this: @This()) void {
        draw.cubic_bezier(this.p1, this.p2, this.p3, this.p3);
    }
};

/////////////////////////////////////
// Bezier Control Point UI Element //
/////////////////////////////////////

fn control_render(el: *const ui.Element, _: ui.style.PaintStyle) ui.style.PaintStyle {
    var draw_style = ui.style.PaintStyle.background;

    if (el.mouse_state == .Hover) {
        draw_style = .frame;
        w4.DRAW_COLORS.* = 0x30;
        w4.oval(el.size.left(), el.size.top(), el.size.size[0], el.size.size[1]);
    } else if (el.mouse_state == .Pressed) {
        draw_style = .foreground;
        w4.DRAW_COLORS.* = 0x33;
        w4.oval(el.size.left(), el.size.top(), el.size.size[0], el.size.size[1]);
    } else {
        draw_style = .frame;
        w4.DRAW_COLORS.* = 0x33;
        w4.oval(el.size.left() + 1, el.size.top() + 1, el.size.size[0] - 2, el.size.size[1] - 2);
    }
    return draw_style;
}

const SegmentHandle = struct {
    id: usize,
    which: usize,

    fn cast(self: *anyopaque) *@This() {
        return @ptrCast(*@This(), @alignCast(@sizeOf(@This()), self));
    }

    fn get(this: *@This()) geom.Vec2f {
        // w4.tracef("this is %d, %d", this.id, this.which);
        const path = paths.get(this.id);
        return path.points[this.which];
    }

    fn set(this: *@This(), new: geom.Vec2f) void {
        paths.set_point(this.id, this.which, new);
    }

    // fn can_link(this: @This()) bool {
    //     const path = paths.get(this.id);
    //     return (path.prev == null and this.which == 0) or (path.next == null and this.which == 3);
    // }

    // fn link_next(this: @This(), id: usize) void {
    //     w4.tracef("%d items total, linking %d next to %d", paths.segments.items.len, this.id, id);
    //     // std.debug.assert(this.which == 3);

    //     w4.trace("getting path");
    //     var path = paths.get(this.id);
    //     path.next = id;
    //     paths.set(this.id, path);
    // }

    // fn link_prev(this: @This(), id: usize) void {
    //     w4.tracef("%d items total, linking %d prev to %d", paths.segments.items.len, this.id, id);
    //     // std.debug.assert(this.which == 0);

    //     w4.trace("getting path");
    //     var path = paths.get(this.id);
    //     path.prev = id;
    //     paths.set(this.id, path);
    // }
};

fn control_init(parent: *ui.Element, path: usize, which: usize) !void {
    var handle: *SegmentHandle = try allocator.create(SegmentHandle);
    // w4.tracef("path %d, which %d", path, which);
    handle.* = .{ .id = path, .which = which };
    var control = try stage.element(handle, ui.layout.size_static, ui.layout.layout_relative, control_render);
    // w4.tracef("path %d, which %d", handle.id, handle.which);
    const pos = geom.vec2fToVec2(handle.get());
    control.size.pos = pos - geom.Vec2{ 2, 2 };
    control.size.size = geom.Vec2{ 5, 5 };
    control.listen(.MousePressed, float_pressed);
    control.listen(.MouseReleased, float_release);
    control.listen(.MouseMoved, float_drag);
    control.listen(.MouseClicked, control_click);
    parent.appendChild(control);
}

fn add_curve() !void {
    // w4.trace("adding curve");
    // w4.tracef("fba %d %d", fba.end_index, fba.buffer.len);
    var segment = try paths.append(.{
        .points = .{
            edit_data.points.Four[0],
            edit_data.points.Four[1],
            edit_data.points.Four[2],
            edit_data.points.Four[3],
        },
    });
    edit_data.points = .Zero;
    // if (edit_data.link) |link| {
    //     if (link.which == 0) {
    //         link.link_prev(segment);
    //     } else {
    //         link.link_next(segment);
    //     }
    // }
    edit_data.link = null;
    // const parent = try stage.element(null, ui.layout.size_fill, ui.layout.layout_relative, null);
    try control_init(canvas, segment, 0);
    try control_init(canvas, segment, 1);
    try control_init(canvas, segment, 2);
    try control_init(canvas, segment, 3);
}

/////////////////////
// Event Listeners //
/////////////////////
fn control_click(el: *ui.Element, _: ui.EventData) bool {
    // w4.trace("control");
    grabbed = null;
    grab_point = null;
    // w4.trace("getting handle");
    const handle: *SegmentHandle = SegmentHandle.cast(el.self);
    // if (!handle.can_link()) return true;
    var point = handle.get();
    if (edit_data.points == .Zero) {
        edit_data.points = edit_data.points.add_point(point);
        edit_data.link = handle;
    } else if (edit_data.points == .Four) {
        add_curve() catch w4.trace("add curve failed control click");
    }
    return true;
}

fn canvas_clicked(_: *ui.Element, ev: ui.EventData) bool {
    // w4.trace("click");
    const mouse_pos = geom.vec2ToVec2f(ev.MouseClicked);
    edit_data.points = edit_data.points.add_point(mouse_pos);
    if (edit_data.points == .Four) {
        add_curve() catch w4.trace("add curve failed");
    }
    return false;
}

fn float_release(_: *ui.Element, _: ui.EventData) bool {
    grabbed = null;
    grab_point = null;
    return false;
}

fn float_pressed(el: *ui.Element, event: ui.EventData) bool {
    const pos = event.MousePressed;
    const diff = pos - el.size.pos;
    grab_point = diff;
    grabbed = el;
    el.move_to_front();
    return false;
}

fn float_drag(el: *ui.Element, _: ui.EventData) bool {
    if (grabbed) |grab| {
        if (grab == el) {
            // Reset the mouse_state
            grab.mouse_state = .Hover;
        }
    }
    return false;
}
