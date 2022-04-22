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
    zow_os = ZowOS.init() catch |e| {
        zow4.mem.report_memory_usage(zow_os.fba);
        switch (e) {
            error.OutOfMemory => {
                w4.trace("[INIT] Out of Memory!");
            },
        }
        zow4.panic("Encountered an error");
    };
    w4.trace("Booted");
    zow_os.start() catch |e| {
        zow4.mem.report_memory_usage(zow_os.fba);
        switch (e) {
            error.OutOfMemory => {
                w4.trace("[START] Out of Memory!");
            },
        }
        // zow4.panic("Encountered an error");
    };
}

export fn update() void {
    zow_os.update() catch |e| {
        zow4.mem.report_memory_usage(zow_os.fba);
        switch (e) {
            error.OutOfMemory => {
                w4.trace("[UPDATE] Out of Memory!");
            },
        }
        // zow_os.fba.reset();
    };
}

const KB = 1024;
var heap: [40 * KB]u8 = undefined;
pub const ZowOS = struct {
    fba: std.heap.FixedBufferAllocator,
    alloc: std.mem.Allocator,
    window_manager: WindowManager,
    pub fn init() !@This() {
        var fba = std.heap.FixedBufferAllocator.init(&heap);
        var alloc = fba.allocator();

        var window_manager = try WindowManager.init(alloc);

        return @This(){
            .fba = fba,
            .alloc = alloc,
            .window_manager = window_manager,
        };
    }

    pub fn start(this: *@This()) !void {
        var welcome = try Window.init(&this.window_manager, .{ 20, 20, 80, 80 });
        _ = try this.window_manager.ctx.insert(welcome.canvas, Node.relative().dataValue(.{ .Label = "Welcome!" }));
        _ = try this.window_manager.ctx.insert(welcome.canvas, Node.relative().dataValue(.{ .Image = &bubbles }));
    }

    pub fn load(this: *@This()) void {
        this._load() catch zow4.panic("lol");
    }

    pub fn _load(this: *@This()) !void {
        var welcome = try Window.init(&this.window_manager, .{ 20, 20, 80, 80 });
        _ = try this.window_manager.ctx.insert(welcome.canvas, Node.relative().dataValue(.{ .Label = "Welcome!" }));
        _ = try this.window_manager.ctx.insert(welcome.canvas, Node.relative().dataValue(.{ .Image = &bubbles }));
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
    fn on_start(_: Node, _: EventData) ?Node {
        zow_os.load();
        return null;
    }
    fn init(alloc: std.mem.Allocator) !@This() {
        var ctx = try ui.default.init(alloc);

        var wm = try ctx.insert(null, Node.fill());

        var menubar = try ctx.insert(null, Node.anchor(.{ 0, 0, 100, 0 }, .{ 0, 0, 0, 16 }));

        var this = @This(){
            .ctx = ctx,
            .handle = wm,
            .menubar = menubar,
        };

        var menu_div = try this.ctx.insert(menubar, Node.hlist().hasBackground(true));

        var btn1 = try this.ctx.insert(menu_div, Node.relative().dataValue(.{ .Button = "\x81" }).capturePointer(true));
        try this.ctx.listen(btn1, .PointerClick, on_start);

        // var btn2 = try ctx.insert(hdiv, Node.relative().dataValue(.{ .Button = "Hide" }).capturePointer(true));
        // try ctx.listen(btn2, .PointerClick, float_hide);

        // var btn3 = try ctx.insert(hdiv, Node.relative().dataValue(.{ .Button = "Toggle" }).capturePointer(true));
        // try ctx.listen(btn3, .PointerClick, float_toggle);

        // float = try ctx.insert(wm, Node.anchor(.{ 0, 0, 0, 0 }, .{ 32, 32, 152, 152 }).minSize(.{ 120, 120 }));
        // try ctx.listen(float, .PointerPress, float_pressed);
        // try ctx.listen(float, .PointerRelease, float_release);
        // try ctx.listen(float, .PointerClick, float_hide);

        // var vdiv = try ctx.insert(float, Node.vdiv().hasBackground(true).capturePointer(true));
        // {
        //     var center = try ctx.insert(vdiv, Node.center());
        //     _ = try ctx.insert(center, Node.relative().dataValue(.{ .Label = "Click to Hide" }));
        // }

        // const elsize = std.fmt.comptimePrint("{}", .{@sizeOf(Node)});
        // {
        //     var center = try ctx.insert(vdiv, Node.center());
        //     _ = try ctx.insert(center, Node.relative().dataValue(.{ .Label = elsize }));
        // }

        // {
        //     var center = try ctx.insert(vdiv, Node.center());
        //     bubbles = zow4.draw.Blit{ .style = 0x0004, .bmp = &bubbles_bmp };
        //     _ = try ctx.insert(center, Node.relative().dataValue(.{ .Image = &bubbles }));
        // }

        // {
        //     var center = try ctx.insert(vdiv, Node.center());
        //     _ = try ctx.insert(center, Node.relative().dataValue(.{ .Label = "Drag to Move" }));
        // }

        // var float2 = try ctx.insert(wm, Node.anchor(.{ 0, 0, 0, 0 }, .{ 20, 20, 140, 140 }).minSize(.{ 120, 120 }));
        // try ctx.listen(float2, .PointerPress, float_pressed);
        // try ctx.listen(float2, .PointerRelease, float_release);
        // // try ctx.listen(float2, .PointerClick, float_hide);

        // var padding = try ctx.insert(float2, Node.anchor(.{ 0, 0, 100, 100 }, .{ 2, 2, -2, -2 }));
        // var vlist = try ctx.insert(padding, Node.vlist().hasBackground(true).capturePointer(true));
        // _ = try ctx.insert(vlist, Node.relative().dataValue(.{ .Label = "Click to Hide" }));
        // _ = try ctx.insert(vlist, Node.relative().dataValue(.{ .Label = elsize }));
        // _ = try ctx.insert(vlist, Node.relative().dataValue(.{ .Image = &bubbles }));
        // _ = try ctx.insert(vlist, Node.relative().dataValue(.{ .Label = "Drag to Move" }));

        this.ctx.layout(.{ 0, 0, 160, 160 });

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
        // this.ctx.layout(.{ 0, 0, 160, 160 });
        // if (modified and this.ctx.modified == null) {
        //     w4.trace("");
        //     this.ctx.print_debug(log);
        // }
        this.ctx.layout(.{ 0, 0, 160, 160 });
        this.ctx.paint();

        input.update();
    }
};

pub const Window = struct {
    window: usize,
    canvas: usize,
    // Close event handler
    fn close(node: Node, event: EventData) ?Node {
        std.debug.assert(event._type == .PointerClick);
        zow_os.window_manager.ctx.remove(node.handle);
        return null;
    }
    pub fn init(wm: *WindowManager, box: g.AABB) !@This() {
        var win = try wm.ctx.insert(wm.handle, Node.anchor(.{ 0, 0, 0, 0 }, g.aabb.as_rect(box)).minSize(g.aabb.size(box)));
        const barsize = 14;
        var dragbar = try wm.ctx.insert(win, Node.anchor(.{ 0, 0, 100, 0 }, .{ 0, 0, 0, barsize }).minSize(.{ 32, barsize }).hasBackground(true).capturePointer(true).eventFilter(.{ .PassExcept = .PointerClick }));
        var menubar = try wm.ctx.insert(dragbar, Node.hlist().minSize(.{ 32, barsize }).hasBackground(true));
        _ = try wm.ctx.insert(menubar, Node.relative().dataValue(.{ .Button = "X" }).capturePointer(true).eventFilter(.Pass));
        var space = try wm.ctx.insert(win, Node.anchor(.{ 0, 0, 100, 100 }, .{ 0, barsize, 0, 0 }));
        var canvas = try wm.ctx.insert(space, Node.vlist().capturePointer(true).eventFilter(.Prevent));

        try wm.ctx.listen(win, .PointerPress, float_pressed);
        try wm.ctx.listen(win, .PointerRelease, float_release);
        try wm.ctx.listen(win, .PointerClick, close);
        return @This(){ .window = win, .canvas = canvas };
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
