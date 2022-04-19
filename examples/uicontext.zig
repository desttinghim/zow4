const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");

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

    fn init() !@This() {
        // Initialize dynamic memory
        var fba = zow4.heap.init();
        var alloc = fba.allocator();

        var this = @This(){
            .ui = UI.DefaultUI.init(alloc),
            .fba = fba,
            .alloc = alloc,
        };

        _ = try this.ui.insert(null, .{ .layout = .{
            .Anchor = .{
                .anchor = .{ 0.5, 0.5, 0.5, 0.5 },
                .margin = .{ -16, -4, 16, 4 },
            },
        } });

        _ = try this.ui.insert(null, .{ .data = .{
            .Button = .{
                .label = "uicontext",
            }
        } });

        _ = try this.ui.insert(0, .{ .data = .{
            .Label = "uicontext",
        } });

        try this.ui.layout(.{ 0, 0, 160, 160 });

        return this;
    }

    fn update(this: *@This()) !void {
        _ = this;
        this.ui.paint();
    }
};
