const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");
const geom = zow4.geometry;

const Element = zow4.ui.Element;

const bubbles_bmp = zow4.draw.bmpToBlit(@embedFile("bubbles.bmp")) catch |e| @compileLog("Hey", e);

var fba: std.heap.FixedBufferAllocator = undefined;
var alloc: std.mem.Allocator = undefined;
var bubbles: zow4.draw.Sprite = undefined;
var stage: zow4.ui.Element = undefined;

export fn start() void {
    fba = zow4.heap.init();
    alloc = fba.allocator();
    bubbles = zow4.draw.Sprite.init(&bubbles_bmp, geom.Vec2{ 60, 60 });

    stage = Element.stage();
    var panel = alloc.create(Element) catch @panic("creating element");
    panel.* = Element.panel(zow4.draw.color.select(.Light, .Dark), geom.AABB.init(20, 20, 16, 16));
    stage.appendChild(panel);
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

    w4.DRAW_COLORS.* = 1;
    w4.rect(0, 0, 16, 16);
    w4.DRAW_COLORS.* = 2;
    w4.rect(0, 16, 16, 16);
    w4.DRAW_COLORS.* = 3;
    w4.rect(0, 32, 16, 16);
    w4.DRAW_COLORS.* = 4;
    w4.rect(0, 48, 16, 16);

    stage.render(null);
}
