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
var float: *ui.Element = undefined;

var grabbed: ?*ui.Element = null;
var grab_point: ?geom.Vec2 = null;

fn float_drag(el: *ui.Element, event: ui.Event) void {
    switch (event) {
        .MouseReleased => |_| {
            grabbed = null;
            grab_point = null;
        },
        .MousePressed => |pos| {
            const diff = pos - el.size.pos;
            grab_point = diff;
            grabbed = el;
        },
        .MouseClicked => |_| {
            float_hide();
            return;
        },
        else => {},
    }
}

fn float_show() void {
    float.hidden = false;
}

fn float_hide() void {
    float.hidden = true;
}

fn float_toggle() void {
    float.hidden = !float.hidden;
}

export fn start() void {
    fba = zow4.heap.init();
    alloc = fba.allocator();

    stage = Stage.new(alloc) catch @panic("creating stage");

    float = stage.float(geom.AABB.init(32, 32, 120, 120)) catch @panic("creating anchorEl");
    float.listen(float_drag);
    stage.element.appendChild(float);

    var menubar = stage.float(geom.AABB.init(0, 0, 160, 16)) catch @panic("creating menubar");
    stage.element.appendChild(menubar);

    var hlist = stage.hdiv() catch @panic("hlist");
    menubar.appendChild(hlist);

    var btn1 = ui.Button.new(alloc, ui.DefaultStyle, "Show", float_show) catch @panic("creating button");
    hlist.appendChild(&btn1.element);
    var btn2 = ui.Button.new(alloc, ui.DefaultStyle, "Hide", float_hide) catch @panic("creating button");
    hlist.appendChild(&btn2.element);
    var btn3 = ui.Button.new(alloc, ui.DefaultStyle, "Toggle", float_toggle) catch @panic("creating button");
    hlist.appendChild(&btn3.element);

    var panel = Panel.new(alloc, color.select(.Light, .Dark)) catch @panic("creating element");
    float.appendChild(&panel.element);

    var vlist = stage.vdiv() catch @panic("creating vlist");
    panel.element.appendChild(vlist);

    {
        var center = stage.center() catch @panic("center");
        var label = ui.Label.new(alloc, color.fill(.Dark), "Click To Hide") catch @panic("creating label");
        center.appendChild(&label.element);
        vlist.appendChild(center);
    }

    {
        const elsize = std.fmt.allocPrint(alloc, "{}", .{ @sizeOf(ui.Element) }) catch @panic("alloc");
        var center = stage.center() catch @panic("center");
        var label = ui.Label.new(alloc, color.fill(.Dark), elsize) catch @panic("creating label");
        center.appendChild(&label.element);
        vlist.appendChild(center);
    }

    {
        var center = stage.center() catch @panic("center");
        vlist.appendChild(center);
        bubbles = Sprite.new(alloc, .{.style = 0x0004, .bmp = &bubbles_bmp }) catch @panic("sprite");
        center.appendChild(&bubbles.element);
    }
    {
        var center = stage.center() catch @panic("center");
        var label = ui.Label.new(alloc, color.fill(.Dark), "Drag To Move") catch @panic("creating label");
        center.appendChild(&label.element);
        vlist.appendChild(center);
    }

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
