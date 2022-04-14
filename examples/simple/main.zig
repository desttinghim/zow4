const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");
const geom = zow4.geometry;
const color = zow4.draw.color;

const ui = zow4.ui;
const Sprite = zow4.ui.Sprite;
const Panel = zow4.ui.Panel;
const Stage = zow4.ui.Stage;

const bubbles_bmp = zow4.draw.load_bitmap(@embedFile("bubbles.bmp")) catch |e| @compileLog("Hey", e);

var fba: std.heap.FixedBufferAllocator = undefined;
var alloc: std.mem.Allocator = undefined;
var bubbles: *Sprite = undefined;
var stage: *Stage = undefined;

export fn start() void {
    fba = zow4.heap.init();
    alloc = fba.allocator();

    stage = Stage.new(alloc) catch @panic("creating stage");

    var float = ui.Float.new(alloc, geom.AABB.init(10, 10, 80, 80)) catch @panic("creating anchorEl");
    stage.element.appendChild(&float.element);

    var panel = Panel.new(alloc, color.select(.Light, .Dark)) catch @panic("creating element");
    float.element.appendChild(&panel.element);

    // var vlist = ui.VList.new(alloc) catch @panic("vlist");
    // panel.element.appendChild(&vlist.element);

    // var c1 = Panel.new(alloc, color.select(.Light, .Transparent)) catch @panic("c1");
    // var c2 = Panel.new(alloc, color.select(.Midtone1, .Transparent)) catch @panic("c2");
    // var c3 = Panel.new(alloc, color.select(.Midtone2, .Transparent)) catch @panic("c3");
    // var c4 = Panel.new(alloc, color.select(.Dark, .Transparent)) catch @panic("c4");
    // vlist.element.appendChild(&c1.element);
    // vlist.element.appendChild(&c2.element);
    // vlist.element.appendChild(&c3.element);
    // vlist.element.appendChild(&c4.element);

    var center = ui.Center.new(alloc) catch @panic("creating center element");
    panel.element.appendChild(&center.element);

    const blit = zow4.draw.Blit.init(0x0004, &bubbles_bmp, .{ .bpp = .b1 });

    bubbles = Sprite.new(alloc, blit) catch @panic("sprite");
    center.element.appendChild(&bubbles.element);

    stage.layout();
}

export fn update() void {
    stage.render();

    w4.DRAW_COLORS.* = 2;

    const free = fba.buffer.len - fba.end_index;
    const msg = std.fmt.allocPrintZ(alloc, "{} bytes free\nof {} bytes", .{ free, fba.buffer.len }) catch @panic("msg");
    defer alloc.free(msg);
    w4.text(msg.ptr, 10, 18);

    const gamepad = w4.GAMEPAD1.*;
    if (gamepad & w4.BUTTON_1 != 0) {
        w4.DRAW_COLORS.* = 4;
    }

    w4.text("Press X to blink", 16, 90);
}
