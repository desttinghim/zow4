const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");
const geom = zow4.geometry;
const color = zow4.draw.color;

const ui = zow4.ui;
const Sprite = zow4.ui.Sprite;
const Panel = zow4.ui.Panel;
const Stage = zow4.ui.Stage;

const bubbles_bmp = zow4.draw.bmpToBlit(@embedFile("bubbles.bmp")) catch |e| @compileLog("Hey", e);

var fba: std.heap.FixedBufferAllocator = undefined;
var alloc: std.mem.Allocator = undefined;
var bubbles: *Sprite = undefined;
var stage: *Stage = undefined;

export fn start() void {
    fba = zow4.heap.init();
    alloc = fba.allocator();
    // bubbles = Sprite.init(&bubbles_bmp, geom.Vec2{ 60, 60 });

    stage = Stage.new(alloc) catch @panic("creating stage");

    var panel = Panel.new(alloc, color.select(.Light, .Dark), ui.Anchors.init(10, 10, 10, 10)) catch @panic("creating element");
    panel.rect.pos = geom.Vec2{ 60, 60 };
    stage.element.appendChild(&panel.element);

    var center = ui.Center.new(alloc) catch @panic("creating center element");
    panel.element.appendChild(&center.element);

    bubbles = Sprite.new(alloc, 0x0004, &bubbles_bmp, null) catch @panic("sprite");
    center.element.appendChild(&bubbles.element);

    stage.layout();
}

export fn update() void {
    w4.DRAW_COLORS.* = 2;

    w4.text("Hello from ZOW4!", 10, 18);

    const gamepad = w4.GAMEPAD1.*;
    if (gamepad & w4.BUTTON_1 != 0) {
        w4.DRAW_COLORS.* = 4;
    }

    // bubbles.blit();
    w4.text("Press X to blink", 16, 90);

    w4.DRAW_COLORS.* = 1;
    w4.rect(0, 0, 16, 16);
    w4.DRAW_COLORS.* = 2;
    w4.rect(0, 16, 16, 16);
    w4.DRAW_COLORS.* = 3;
    w4.rect(0, 32, 16, 16);
    w4.DRAW_COLORS.* = 4;
    w4.rect(0, 48, 16, 16);

    stage.render();
}
