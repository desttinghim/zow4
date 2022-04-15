const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");
const geom = zow4.geometry;
const color = zow4.draw.color;

const Input = zow4.input;
const ui = zow4.ui;
const Sprite = zow4.ui.Sprite;
const Panel = zow4.ui.Panel;
const Stage = zow4.ui.Stage;

const bubbles_bmp = zow4.draw.load_bitmap(@embedFile("bubbles.bmp")) catch |e| @compileLog("Hey", e);

var fba: std.heap.FixedBufferAllocator = undefined;
var alloc: std.mem.Allocator = undefined;
var bubbles: *Sprite = undefined;
var stage: *Stage = undefined;
var float: *ui.Float = undefined;

var grabbed: ?*ui.Element = null;
var grab_point: ?geom.Vec2 = null;

fn float_drag(ptr: *anyopaque, event: ui.Event) void {
    const this = @ptrCast(*ui.Float, @alignCast(@alignOf(ui.Float), ptr));
    switch (event) {
        .MouseReleased => |_| {
            grabbed = null;
            grab_point = null;
        },
        .MousePressed => |pos| {
            const diff = pos - this.element.size.pos;
            grab_point = diff;
            grabbed = &this.element;
        },
        .MouseClicked => |_| {
            float_hide();
            return;
        },
        else => {},
    }
}

fn float_show() void {
    float.element.hidden = false;
}

fn float_hide() void {
    float.element.hidden = true;
}

fn float_toggle() void {
    float.element.hidden = !float.element.hidden;
}

export fn start() void {
    fba = zow4.heap.init();
    alloc = fba.allocator();

    stage = Stage.new(alloc) catch @panic("creating stage");

    float = ui.Float.new(alloc, geom.AABB.init(32, 32, 120, 120)) catch @panic("creating anchorEl");
    float.element.listen(float_drag);
    stage.element.appendChild(&float.element);

    var menubar = ui.Float.new(alloc, geom.AABB.init(0, 0, 160, 16)) catch @panic("creating menubar");
    stage.element.appendChild(&menubar.element);

    var hlist = ui.HList.new(alloc) catch @panic("hlist");
    menubar.element.appendChild(&hlist.element);

    var btn1 = ui.Button.new(alloc, ui.DefaultStyle, "Show", float_show) catch @panic("creating button");
    hlist.element.appendChild(&btn1.element);
    var btn2 = ui.Button.new(alloc, ui.DefaultStyle, "Hide", float_hide) catch @panic("creating button");
    hlist.element.appendChild(&btn2.element);
    var btn3 = ui.Button.new(alloc, ui.DefaultStyle, "Toggle", float_toggle) catch @panic("creating button");
    hlist.element.appendChild(&btn3.element);

    var panel = Panel.new(alloc, color.select(.Light, .Dark)) catch @panic("creating element");
    float.element.appendChild(&panel.element);

    var vlist = ui.VList.new(alloc) catch @panic("creating vlist");
    panel.element.appendChild(&vlist.element);

    vlist.element.appendChild(ui.center(alloc, &(ui.Label.new(alloc, color.fill(.Dark), "Click To Hide") catch @panic("creating label")).element) catch @panic("centering"));

    var center = ui.Center.new(alloc) catch @panic("creating center element");
    vlist.element.appendChild(&center.element);
    const blit = zow4.draw.Blit.init(0x0004, &bubbles_bmp, .{ .bpp = .b1 });
    bubbles = Sprite.new(alloc, blit) catch @panic("sprite");
    center.element.appendChild(&bubbles.element);

    vlist.element.appendChild(ui.center(alloc, &(ui.Label.new(alloc, color.fill(.Dark), "Drag To Move") catch @panic("creating label")).element) catch @panic("centering"));

    stage.layout();
}

export fn update() void {
    stage.update();
    stage.layout();
    stage.render();

    if (grabbed) |el| {
        if (grab_point) |point| {
            el.size.pos = Input.mousepos() - point;
        }
    }

    Input.update();
}
