const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");

const geom = zow4.geometry;
const color = zow4.draw.color;
const input = zow4.input;
const ui = zow4.ui;
const Context = zow4.ui.default.Context;
const Node = Context.Node;

const bubbles_bmp = zow4.draw.load_bitmap(@embedFile("bubbles.bmp")) catch |e| @compileLog("Could not load bitmap", e);

var fba: std.heap.FixedBufferAllocator = undefined;
var alloc: std.mem.Allocator = undefined;

var bubbles: zow4.draw.Blit = undefined;
var stage: usize = undefined;
var wm_handle: usize = undefined;
var float: usize = undefined;

const Grab = struct { handle: usize, diff: geom.Vec2 };
var grabbed: ?Grab = null;
var grab_point: ?geom.Vec2 = null;

////////////////////
// Event Handlers //
////////////////////

fn float_release(_: ui.default.Node, _: zow4.ui.EventData) ?ui.default.Node {
    grabbed = null;
    grab_point = null;
    return null;
}

fn float_pressed(node: ui.default.Node, event: zow4.ui.EventData) ?ui.default.Node {
    const pos = event.pointer.pos;
    const diff = pos - ui.top_left(node.bounds);
    grabbed = .{
        .handle = node.handle,
        .diff = diff,
    };
    app.ctx.bring_to_front(node.handle);
    return null;
}

// fn float_drag(node: ui.default.Node, _: zow4.ui.EventData) ?ui.default.Node {
//     if (grabbed) |grab| {
//         var new_node = node;
//         if (grab.handle == node.handle) {
//             // Reset the pointer state
//             new_node.pointer_state = .Open;
//             return new_node;
//         }
//     }
//     return null;
// }

// fn float_delete(el: *ui.Element, _: ui.EventData) bool {
//     el.remove();
//     return false;
// }

fn float_hide(_: ui.default.Node, _: zow4.ui.EventData) ?ui.default.Node {
    w4.trace("show");
    _ = app.ctx.hide_node(float);
    return null;
}

fn float_show(_: ui.default.Node, _: zow4.ui.EventData) ?ui.default.Node {
    w4.trace("hide");
    _ = app.ctx.show_node(float);
    return null;
}

fn float_toggle(_: ui.default.Node, _: zow4.ui.EventData) ?ui.default.Node {
    w4.trace("toggle");
    _ = app.ctx.toggle_hidden(float);
    return null;
}

var app: App = undefined;

export fn start() void {
    app = App.start() catch |e| {
        switch (e) {
            error.OutOfMemory => {
                w4.trace("Out of Memory!");
            },
        }
        @panic("Encountered an error");
    };
}

export fn update() void {
    app.update() catch |e| {
        switch (e) {
            error.OutOfMemory => {
                w4.trace("Out of Memory!");
            },
        }
        @panic("Encountered an error");
    };
}

fn log (text: []const u8) void {
    w4.traceUtf8(text.ptr, text.len);
}

pub const App = struct {
    ctx: Context = undefined,
    fn start() !@This() {
        fba = zow4.heap.init();
        alloc = fba.allocator();

        var ctx = ui.default.init(alloc);

        wm_handle = try ctx.insert(null, Node.fill());

        var menubar = try ctx.insert(null, Node.anchor(.{ 0, 0, 100, 0 }, .{ 0, 0, 0, 16 }));

        var hdiv = try ctx.insert(menubar, Node.hdiv().hasBackground(true));

        var btn1 = try ctx.insert(hdiv, Node.relative().dataValue(.{ .Button = "Show" }).capturePointer(true));
        try ctx.listen(btn1, .PointerClick, float_show);

        var btn2 = try ctx.insert(hdiv, Node.relative().dataValue(.{ .Button = "Hide" }).capturePointer(true));
        try ctx.listen(btn2, .PointerClick, float_hide);

        var btn3 = try ctx.insert(hdiv, Node.relative().dataValue(.{ .Button = "Toggle" }).capturePointer(true));
        try ctx.listen(btn3, .PointerClick, float_toggle);

        float = try ctx.insert(wm_handle, Node.anchor(.{ 0, 0, 0, 0 }, .{ 32, 32, 152, 152 }));
        try ctx.listen(float, .PointerPress, float_pressed);
        try ctx.listen(float, .PointerRelease, float_release);
        // try ctx.listen(float, .PointerClick, float_hide);
        // try ctx.listen(float, .PointerMove, float_drag);

        var vdiv = try ctx.insert(float, Node.vdiv().hasBackground(true).capturePointer(true));
        {
            var center = try ctx.insert(vdiv, Node.center());
            _ = try ctx.insert(center, Node.relative().dataValue(.{ .Label = "Click to Hide" }));
        }

        const elsize = try std.fmt.allocPrint(alloc, "{}", .{@sizeOf(Node)});
        {
            var center = try ctx.insert(vdiv, Node.center());
            _ = try ctx.insert(center, Node.relative().dataValue(.{ .Label = elsize }));
        }

        {
            var center = try ctx.insert(vdiv, Node.center());
            bubbles = zow4.draw.Blit{ .style = 0x0004, .bmp = &bubbles_bmp };
            _ = try ctx.insert(center, Node.relative().dataValue(.{ .Image = &bubbles }));
        }

        {
            var center = try ctx.insert(vdiv, Node.center());
            _ = try ctx.insert(center, Node.relative().dataValue(.{ .Label = "Drag to Move" }));
        }

        var float2 = try ctx.insert(wm_handle, Node.anchor(.{ 0, 0, 0, 0 }, .{ 20, 20, 140, 140 }));
        try ctx.listen(float2, .PointerPress, float_pressed);
        try ctx.listen(float2, .PointerRelease, float_release);
        // try ctx.listen(float2, .PointerClick, float_hide);
        // try ctx.listen(float2, .PointerMove, float_drag);

        var vlist = try ctx.insert(float2, Node.vlist().hasBackground(true).capturePointer(true));
        _ = try ctx.insert(vlist, Node.relative().dataValue(.{ .Label = "Click to Hide" }));
        _ = try ctx.insert(vlist, Node.relative().dataValue(.{ .Label = elsize }));
        _ = try ctx.insert(vlist, Node.relative().dataValue(.{ .Image = &bubbles }));
        _ = try ctx.insert(vlist, Node.relative().dataValue(.{ .Label = "Drag to Move" }));

        try ctx.layout(.{ 0, 0, 160, 160 });
        ctx.print_debug(log);
        return @This(){.ctx =  ctx};
    }

    fn update(this: *@This()) !void {
        w4.DRAW_COLORS.* = 0x04;
        zow4.draw.cubic_bezier(.{ 0, 0 }, .{ 160, 0 }, .{ 0, 160 }, .{ 160, 160 });
        zow4.draw.quadratic_bezier(.{ 0, 0 }, .{ 320, 80 }, .{ 0, 160 });

        if (grabbed) |grab| {
            if (this.ctx.get_node(grab.handle)) |*node| {
                const pos = input.mousepos() - grab.diff;
                const size = ui.rect_size(node.bounds);
                node.bounds = geom.Rect{ pos[0], pos[1], pos[0] + size[0], pos[1] + size[1] };
                _ = this.ctx.set_node(node.*);
            }
        }
        this.ctx.update(.{
            .pointer = .{
                .left = input.mouse(.left),
                .right = input.mouse(.right),
                .middle = input.mouse(.middle),
                .pos = input.mousepos(),
            },
            .keys = .{
                .up = input.btn(.one, .up),
                .down = input.btn(.one, .down),
                .left = input.btn(.one, .left),
                .right = input.btn(.one, .right),
                .accept = input.btn(.one, .x),
                .reject = input.btn(.one, .z),
            },
        });
        const modified = this.ctx.modified != null;
        try this.ctx.layout(.{ 0, 0, 160, 160 });
        if (modified and this.ctx.modified == null) {
            w4.trace("");
            this.ctx.print_debug(log);
        }
        this.ctx.paint();
        input.update();
    }
};
