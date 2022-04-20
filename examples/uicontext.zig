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
        @panic("Couldn't update");
    };
}

fn drag_handler(node: ui.default.Node, event: zow4.ui.context.EventData) ?ui.default.Node {
    if (node.handle != app.wm_handle) return null;
    const margin = node.layout.Anchor.margin;
    switch (event._type) {
        .PointerPress => {
            if (app.grab != null) return null;
            app.grab = .{ .handle = node.handle, .vec = event.pointer.pos - ui.top_left(margin) };
        },
        else => {},
    }
    return null;
}

fn toggle_window(_: ui.default.Node, _: ui.EventData) ?ui.default.Node {
    _ = app.ui.toggle_hidden(app.wm_handle);
    return null;
}

const ui = zow4.ui.context;
const App = struct {
    ui: ui.default.DefaultUIContext,
    fba: std.heap.FixedBufferAllocator,
    alloc: std.mem.Allocator,

    wm_handle: usize,
    grab: ?struct { handle: usize, vec: ui.Vec } = null,

    fn init() !@This() {
        // Initialize dynamic memory
        var fba = zow4.heap.init();
        var alloc = fba.allocator();

        var this = @This(){
            .ui = ui.default.DefaultUI.init(alloc),
            .fba = fba,
            .alloc = alloc,
            .wm_handle = undefined,
        };

        this.ui.root_layout = .Fill;

        const relative = try this.ui.insert(null, .{
            .layout = .Relative,
        });

        this.wm_handle = try this.ui.insert(null, .{
            .capture_pointer = false,
            .event_filter = .Pass,
            .layout = .{
                .Anchor = .{
                    .anchor = .{ 0, 0, 0, 0 },
                    .margin = .{ 0, 0, 80, 80 },
                },
            },
        });
        try this.ui.listen(this.wm_handle, .PointerPress, drag_handler);
        const window = try this.ui.insert(this.wm_handle, .{
            .capture_pointer = true,
            .layout = .{ .Anchor = .{
                .anchor = .{ 0, 0, 100, 100 },
                .margin = .{ 2, 2, 2, 2 },
            } },
            .has_background = true,
        });

        const vlist = try this.ui.insert(relative, .{ .layout = .{ .VList = .{} } });

        const button = try this.ui.insert(vlist, .{
            .capture_pointer = true,
            .data = .{
                .Button = "uicontext",
            },
        });
        try this.ui.listen(button, .PointerClick, toggle_window);

        _ = try this.ui.insert(window, .{
            .data = .{
                .Label = "uicontext",
            },
        });

        this.ui.layout(.{ 0, 0, 160, 160 });

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
        if (this.grab) |grab| {
            if (this.ui.get_node(grab.handle)) |oldnode| {
                var node = oldnode;
                const margin = &node.layout.Anchor.margin;
                const topleft = mouse_pos - grab.vec;
                const bottomright = topleft + ui.rect_size(margin.*);
                margin.* = ui.Rect{ topleft[0], topleft[1], bottomright[0], bottomright[1] };
                if (!this.ui.set_node(node)) {
                    w4.trace("couldn't set node");
                }
                if (!input.mouse(.left)) {
                    this.grab = null;
                }
            }
        }
        this.ui.layout(.{ 0, 0, 160, 160 });
        this.ui.paint();
        input.update();
    }
};
