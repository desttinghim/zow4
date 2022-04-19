const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");
const input = zow4.input;

var app: App = undefined;

// WASM4 exports
export fn start() void {
    app = App.init() catch |e| {
        switch (e) {
            error.OutOfMemory => w4.trace("Out of Memory"),
        }
        @panic("Couldn't initialize");
    };
}

export fn update() void {
    app.update() catch |e| {
        switch (e) {
            error.OutOfMemory => w4.trace("Out of Memory"),
        }
        @panic("Couldn't initialize");
    };
}

const App = struct {
    const UI = zow4.ui.context.default;

    ui: UI.DefaultUIContext,
    fba: std.heap.FixedBufferAllocator,
    alloc: std.mem.Allocator,

    fn say_hi(node: UI.Node, event: zow4.ui.context.Event) void {
        _ = node;
        _ = event;
        w4.trace("hi");
    }
    fn say_bye(node: UI.Node, event: zow4.ui.context.Event) void {
        _ = node;
        _ = event;
        w4.trace("bye");
    }
    fn say_click(node: UI.Node, event: zow4.ui.context.Event) void {
        _ = node;
        _ = event;
        w4.trace("click!");
    }

    fn init() !@This() {
        // Initialize dynamic memory
        var fba = zow4.heap.init();
        var alloc = fba.allocator();

        var this = @This(){
            .ui = UI.DefaultUI.init(alloc),
            .fba = fba,
            .alloc = alloc,
        };

        this.ui.root_layout = .Fill;

        const relative = try this.ui.insert(null, .{ .layout = .Relative });

        const anchor = try this.ui.insert(null, .{ .layout = .{
            .Anchor = .{
                .anchor = .{ 0, 0, 100, 100 },
                .margin = .{ 32, 32, -32, -32 },
            },
        } });

        const vlist = try this.ui.insert(relative, .{ .layout = .{ .VList = .{} } });

        const btn = try this.ui.insert(vlist, .{
            .capture_pointer = true,
            .data = .{
                .Button = "uicontext",
            },
        });
        try this.ui.listen(btn, .PointerPress, say_hi);
        try this.ui.listen(btn, .PointerRelease, say_bye);
        try this.ui.listen(btn, .PointerClick, say_click);

        _ = try this.ui.insert(anchor, .{
            .capture_pointer = true,
            .has_background = true,
            .data = .{
                .Label = "uicontext",
            },
        });

        try this.ui.layout(.{ 0, 0, 160, 160 });

        return this;
    }

    fn update(this: *@This()) !void {
        _ = this;
        const mouse_pos = input.mousepos();
        // w4.tracef("%d, %d", mouse_pos[0], mouse_pos[1]);
        this.ui.update(.{
            .pointer = .{
                .left = input.mouse(.left),
                .right = input.mouse(.right),
                .middle = input.mouse(.middle),
                .pos = mouse_pos,
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
        // var buf: [100]u8 = undefined;
        // var msg = std.fmt.bufPrint(&buf, "{}, {}", .{ mouse_pos[0], mouse_pos[1] }) catch "huh";
        // w4.textUtf8(msg.ptr, msg.len, 0, 80);
        this.ui.paint();
        input.update();
    }
};
