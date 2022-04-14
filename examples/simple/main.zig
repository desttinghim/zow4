const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");
const geom = zow4.geometry;

const smiley = [8]u8{
    0b11000011,
    0b10000001,
    0b00100100,
    0b00100100,
    0b00000000,
    0b00100100,
    0b10011001,
    0b11000011,
};

const bubbles = zow4.draw.bmpToBlit(@embedFile("bubbles.bmp")) catch |e| @compileLog("Hey", e);

var fba: std.heap.FixedBufferAllocator = undefined;
var alloc: std.mem.Allocator = undefined;
var startframeaddr: usize = undefined;
var updateframeaddr: usize = undefined;

export fn start() void {
    fba = zow4.heap.init();
    alloc = fba.allocator();
    startframeaddr = @frameAddress();
}

export fn update() void {
    updateframeaddr = @frameAddress();
    update_with_errors() catch @panic("uh oh");
}

fn update_with_errors() !void {
    w4.DRAW_COLORS.* = 2;

    const faddr = @frameAddress();
    const message = try std.fmt.allocPrint(alloc, "{x} {x} {x}", .{ startframeaddr, updateframeaddr, faddr });
    defer alloc.free(message);
    const message2 = try std.fmt.allocPrint(alloc, "{} {}", .{ w4.MOUSE_X.*, w4.MOUSE_Y.* });
    defer alloc.free(message2);
    w4.textUtf8(message.ptr, message.len, 10, 10);
    w4.textUtf8(message2.ptr, message2.len, 10, 18);

    const gamepad = w4.GAMEPAD1.*;
    if (gamepad & w4.BUTTON_1 != 0) {
        w4.DRAW_COLORS.* = 4;
    }

    bubbles.blit(geom.Vec2{ 20, 30 }, w4.BLIT_1BPP);
    w4.text("Press X to blink", 16, 90);
}
