const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");
const geom = zow4.geometry;

const bubbles_bmp = zow4.draw.bmpToBlit(@embedFile("bubbles.bmp")) catch |e| @compileLog("Hey", e);

var fba: std.heap.FixedBufferAllocator = undefined;
var alloc: std.mem.Allocator = undefined;
var bubbles: zow4.draw.Sprite = undefined;

export fn start() void {
    fba = zow4.heap.init();
    alloc = fba.allocator();
    bubbles = zow4.draw.Sprite.init(&bubbles_bmp, geom.Vec2{ 60, 60 });
}

export fn update() void {
    w4.DRAW_COLORS.* = 2;

    w4.text("Hello from ZOW4!", 10, 18);

    const gamepad = w4.GAMEPAD1.*;
    if (gamepad & w4.BUTTON_1 != 0) {
        w4.DRAW_COLORS.* = 4;
    }

    bubbles.blit();
    w4.text("Press X to blink", 16, 90);
}
