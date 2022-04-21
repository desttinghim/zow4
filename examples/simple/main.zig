const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");

const input = zow4.input;
const ui = zow4.ui;
const g = zow4.geometry;

const Context = ui.default.Context;
const EventData = ui.EventData;
const Node = Context.Node;

const bubbles_bmp = zow4.draw.load_bitmap(@embedFile("bubbles.bmp")) catch |e| @compileLog("Could not load bitmap", e);
var bubbles: zow4.draw.Blit = zow4.draw.Blit{ .style = 0x0004, .bmp = &bubbles_bmp };

var float: usize = undefined;

const Grab = struct { moved: bool, handle: usize, diff: g.Vec2 };
var grabbed: ?Grab = null;
var grab_point: ?g.Vec2 = null;

var zow_os: ZowOS = undefined;

export fn start() void {
    zow_os = ZowOS.start() catch |e| {
        switch (e) {
            error.OutOfMemory => {
                w4.trace("[START] Out of Memory!");
            },
        }
        zow4.panic("Encountered an error");
    };
}


export fn update() void {
    zow_os.update() catch |e| {
        zow4.heap.report_memory_usage(zow_os.fba);
        switch (e) {
            error.OutOfMemory => {
                w4.trace("[UPDATE] Out of Memory!");
            },
        }
        zow_os.fba.reset();
    };
}

const KB = 1024;
var heap: [44 * KB]u8 = undefined;
pub const ZowOS = struct {
    fba: std.heap.FixedBufferAllocator,
    alloc: std.mem.Allocator,
    window_manager: WindowManager,
    pub fn start() !@This() {
        var fba = std.heap.FixedBufferAllocator.init(&heap);
        var alloc = fba.allocator();

        var window_manager = try WindowManager.init(alloc);

        return @This(){
            .fba = fba,
            .alloc = alloc,
            .window_manager = window_manager,
        };
    }

    pub fn update(this: *@This()) !void {
        try this.window_manager.update();
    }
};

fn log(text: []const u8) void {
    w4.traceUtf8(text.ptr, text.len);
}

pub const WindowManager = struct {
    ctx: Context,
    handle: usize,
    menubar: usize,
    // fn show_start(_: Node, _: EventData) ?Node {}
    fn init(alloc: std.mem.Allocator) !@This() {
        var ctx = ui.default.init(alloc);

        var wm = try ctx.insert(null, Node.fill());

        var menubar = try ctx.insert(null, Node.anchor(.{ 0, 0, 100, 0 }, .{ 0, 0, 0, 16 }));

        var menu_div = try ctx.insert(menubar, Node.hlist().hasBackground(true));

        var btn1 = try ctx.insert(menu_div, Node.relative().dataValue(.{ .Button = "\x81" }).capturePointer(true));
        try ctx.listen(btn1, .PointerClick, float_show);

        // var btn2 = try ctx.insert(hdiv, Node.relative().dataValue(.{ .Button = "Hide" }).capturePointer(true));
        // try ctx.listen(btn2, .PointerClick, float_hide);

        // var btn3 = try ctx.insert(hdiv, Node.relative().dataValue(.{ .Button = "Toggle" }).capturePointer(true));
        // try ctx.listen(btn3, .PointerClick, float_toggle);

        float = try ctx.insert(wm, Node.anchor(.{ 0, 0, 0, 0 }, .{ 32, 32, 152, 152 }).minSize(.{ 120, 120 }));
        try ctx.listen(float, .PointerPress, float_pressed);
        try ctx.listen(float, .PointerRelease, float_release);
        try ctx.listen(float, .PointerClick, float_hide);

        var vdiv = try ctx.insert(float, Node.vdiv().hasBackground(true).capturePointer(true));
        {
            var center = try ctx.insert(vdiv, Node.center());
            _ = try ctx.insert(center, Node.relative().dataValue(.{ .Label = "Click to Hide" }));
        }

        const elsize = std.fmt.comptimePrint("{}", .{@sizeOf(Node)});
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

        var float2 = try ctx.insert(wm, Node.anchor(.{ 0, 0, 0, 0 }, .{ 20, 20, 140, 140 }).minSize(.{ 120, 120 }));
        try ctx.listen(float2, .PointerPress, float_pressed);
        try ctx.listen(float2, .PointerRelease, float_release);
        // try ctx.listen(float2, .PointerClick, float_hide);

        var vlist = try ctx.insert(float2, Node.vlist().hasBackground(true).capturePointer(true));
        _ = try ctx.insert(vlist, Node.relative().dataValue(.{ .Label = "Click to Hide" }));
        _ = try ctx.insert(vlist, Node.relative().dataValue(.{ .Label = elsize }));
        _ = try ctx.insert(vlist, Node.relative().dataValue(.{ .Image = &bubbles }));
        _ = try ctx.insert(vlist, Node.relative().dataValue(.{ .Label = "Drag to Move" }));

        ctx.layout(.{ 0, 0, 160, 160 });

        var this = @This(){
            .ctx = ctx,
            .handle = wm,
            .menubar = menubar,
        };

        return this;
    }

    fn update(this: *@This()) !void {
        w4.DRAW_COLORS.* = 0x04;
        zow4.draw.cubic_bezier(.{ 0, 0 }, .{ 160, 0 }, .{ 0, 160 }, .{ 160, 160 });
        zow4.draw.quadratic_bezier(.{ 0, 0 }, .{ 320, 80 }, .{ 0, 160 });
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

        if (grabbed) |grab| {
            if (this.ctx.get_node(grab.handle)) |node| {
                var new_node = node;
                const pos = input.mousepos() - grab.diff;
                const size = node.min_size;
                new_node.pointer_state = .Hover;
                new_node.layout.Anchor.margin = g.Rect{ pos[0], pos[1], pos[0] + size[0], pos[1] + size[1] };
                _ = this.ctx.set_node(new_node);
            }
        }
        // const modified = this.ctx.modified != null;
        this.ctx.layout(.{ 0, 0, 160, 160 });
        // if (modified and this.ctx.modified == null) {
        //     w4.trace("");
        //     this.ctx.print_debug(log);
        // }
        this.ctx.paint();
        input.update();
    }
};

pub const Window = struct {
    window: usize,
    canvas: usize,
    // Close event handler
    fn close(node: Node, event: EventData) Node {
        std.debug.assert(event == .PointerClick);
        zow_os.window_manager.ctx.remove(node.handle) catch zow4.panic("removing element");
        return null;
    }
    pub fn init(box: g.AABB) @This() {
        const anchor_topleft = g.Rect{ 0, 0, 0, 0 };
        var win = try zow_os.window_manager.ctx.insert(zow_os.window_manager.handle, Node.anchor(anchor_topleft, g.aabb.as_rect(box)).minSize(g.aabb.size(box)));
        var vlist = try zow_os.window_manager.ctx.insert(win, Node.vlist());
        var menubar = try zow_os.window_manager.ctx.insert(win, Node.anchor(.{ 0, 0, 100, 0 }, .{ 0, 0, 0, 10 }).minSize(.{ 32, 10 }).hasBackground(true));
        _ = try zow_os.window_manager.ctx.insert(menubar, Node.relative.dataValue(.{ .Button = "X" }).capturePointer(true).eventFilter(.Pass));
        var canvas = try zow_os.window_manager.ctx.insert(vlist, Node.fill().capturePointer(true).eventFilter(.Prevent));

        try zow_os.window_manager.ctx.listen(win, .PointerPress, float_pressed);
        try zow_os.window_manager.ctx.listen(win, .PointerRelease, float_release);
        try zow_os.window_manager.ctx.listen(win, .PointerClick, close);

        return .{ .window = win, .canvas = canvas };
    }
    fn insert(this: @This(), node: Node) !usize {
        // Add an element to the window
        try zow_os.window_manager.ctx.insert(this.canvas, node);
    }
};

////////////////////
// Event Handlers //
////////////////////

fn float_release(_: Node, _: zow4.ui.EventData) ?Node {
    grabbed = null;
    grab_point = null;
    return null;
}

fn float_pressed(node: Node, event: zow4.ui.EventData) ?Node {
    const pos = event.pointer.pos;
    if (node.layout == .Anchor) {
        const diff = pos - g.rect.top_left(node.layout.Anchor.margin);
        grabbed = .{
            .moved = false,
            .handle = node.handle,
            .diff = diff,
        };
        zow_os.window_manager.ctx.bring_to_front(node.handle);
    }
    return null;
}

fn float_hide(_: Node, _: zow4.ui.EventData) ?Node {
    zow_os.window_manager.ctx.remove(float);
    // _ = zow_os.window_manager.ctx.hide_node(float);
    return null;
}

fn float_show(_: Node, _: zow4.ui.EventData) ?Node {
    _ = zow_os.window_manager.ctx.show_node(float);
    return null;
}

fn float_toggle(_: Node, _: zow4.ui.EventData) ?Node {
    _ = zow_os.window_manager.ctx.toggle_hidden(float);
    return null;
}
