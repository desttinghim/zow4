//!  ________  ________  ___       __   ___   ___
//! |\_____  \|\   __  \|\  \     |\  \|\  \ |\  \
//!  \|___/  /\ \  \|\  \ \  \    \ \  \ \  \\_\  \
//!      /  / /\ \  \\\  \ \  \  __\ \  \ \______  \
//!     /  /_/__\ \  \\\  \ \  \|\__\_\  \|_____|\  \
//!    |\________\ \_______\ \____________\     \ \__\
//!     \|_______|\|_______|\|____________|      \|__|
//!
//! ZOW4: Zig On WASM4

pub const geometry = @import("geometry.zig");
pub const input = @import("input.zig");
pub const draw = @import("draw.zig");
pub const text = @import("text.zig");
pub const mem = @import("mem.zig");
pub const ui = struct {
    pub usingnamespace @import("ui.zig");
    pub const default = @import("ui/default.zig");
};

const std = @import("std");
const w4 = @import("wasm4");

pub fn panic(message: []const u8) noreturn {
    w4.tracef("TERMINATING %s", message.ptr);
    @panic(message);
}

pub fn update(ui_ctx: *ui.default.Context) !void {
    ui_ctx.update(.{
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
    try ui_ctx.layout(.{ 0, 0, 160, 160 });
    ui_ctx.paint();
    input.update();
}
