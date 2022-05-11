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
pub const scene = @import("scene.zig");
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

