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
var bubbles: *ui.Element = undefined;
var stage: *Stage = undefined;
var float: *ui.Element = undefined;

var grabbed: ?*ui.Element = null;
var grab_point: ?geom.Vec2 = null;

fn float_release(_: *ui.Element, _: ui.EventData) bool {
    grabbed = null;
    grab_point = null;
    return false;
}

fn float_pressed(el: *ui.Element, event: ui.EventData) bool {
    const pos = event.MousePressed;
    const diff = pos - el.size.pos;
    grab_point = diff;
    grabbed = el;
    el.move_to_front();
    return false;
}

fn float_drag(el: *ui.Element, _: ui.EventData) bool {
    if (grabbed) |grab| {
        if (grab == el) {
            // Reset the mouse_state
            grab.mouse_state = .Hover;
        }
    }
    return false;
}

fn float_delete(el: *ui.Element, _: ui.EventData) bool {
    el.remove();
    return false;
}

fn float_show(_: *ui.Element, _: ui.EventData) bool {
    float.hidden = false;
    return false;
}

fn float_hide(_: *ui.Element, _: ui.EventData) bool {
    float.hidden = true;
    return false;
}

fn float_toggle(_: *ui.Element, _: ui.EventData) bool {
    float.hidden = !float.hidden;
    return false;
}

export fn start() void {
    fba = zow4.heap.init();
    alloc = fba.allocator();

    stage = Stage.init(alloc) catch @panic("creating stage");

    float = stage.float(geom.AABB.init(32, 32, 120, 120)) catch @panic("creating anchorEl");
    float.listen(.MousePressed, float_pressed);
    float.listen(.MouseReleased, float_release);
    float.listen(.MouseClicked, float_hide);
    float.listen(.MouseMoved, float_drag);
    stage.root.appendChild(float);

    var menubar = stage.float(geom.AABB.init(0, 0, 160, 16)) catch @panic("creating menubar");
    stage.root.appendChild(menubar);

    var hlist = stage.hdiv() catch @panic("hlist");
    menubar.appendChild(hlist);

    var btn1 = stage.button("Show") catch @panic("creating button");
    btn1.listen(.MouseClicked, float_show);
    hlist.appendChild(btn1);

    var btn2 = stage.button("Hide") catch @panic("creating button");
    btn2.listen(.MouseClicked, float_hide);
    hlist.appendChild(btn2);

    var btn3 = stage.button("Toggle") catch @panic("creating button");
    btn3.listen(.MouseClicked, float_toggle);
    hlist.appendChild(btn3);

    var panel = stage.panel() catch @panic("creating element");
    float.appendChild(panel);

    var vdiv = stage.vdiv() catch @panic("creating vdiv");
    panel.appendChild(vdiv);

    {
        var center = stage.center() catch @panic("center");
        var label = stage.label("Click To Hide") catch @panic("creating label");
        center.appendChild(label);
        vdiv.appendChild(center);
    }

    {
        const elsize = std.fmt.allocPrint(alloc, "{}", .{@sizeOf(ui.Element)}) catch @panic("alloc");
        var center = stage.center() catch @panic("center");
        var label = stage.label(elsize) catch @panic("creating label");
        center.appendChild(label);
        vdiv.appendChild(center);
    }

    {
        var center = stage.center() catch @panic("center");
        vdiv.appendChild(center);
        bubbles = stage.sprite(.{ .style = 0x0004, .bmp = &bubbles_bmp }) catch @panic("sprite");
        center.appendChild(bubbles);
    }
    {
        var center = stage.center() catch @panic("center");
        var label = stage.label("Drag To Move") catch @panic("creating label");
        center.appendChild(label);
        vdiv.appendChild(center);
    }

    var float2 = stage.float(geom.AABB.init(20, 120, 120, 120)) catch @panic("creating anchorEl");
    float2.listen(.MousePressed, float_pressed);
    float2.listen(.MouseReleased, float_release);
    float2.listen(.MouseMoved, float_drag);
    stage.root.appendChild(float2);

    var panel2 = stage.panel() catch @panic("creating element");
    float2.appendChild(panel2);

    var vlist = stage.vlist() catch @panic("creating vlist");
    panel2.appendChild(vlist);

    {
        var label = stage.label("Click To Hide") catch @panic("creating label");
        vlist.appendChild(label);
    }

    {
        const elsize = std.fmt.allocPrint(alloc, "{}", .{@sizeOf(ui.Element)}) catch @panic("alloc");
        var label = stage.label(elsize) catch @panic("creating label");
        vlist.appendChild(label);
    }

    {
        var bubbles2 = stage.sprite(.{ .style = 0x0004, .bmp = &bubbles_bmp }) catch @panic("sprite");
        vlist.appendChild(bubbles2);
    }
    {
        var label = stage.label("Drag To Move") catch @panic("creating label");
        vlist.appendChild(label);
    }
    w4.trace("here init?");
}

export fn update() void {
    zow4.draw.cubic_bezier(.{0,0}, .{160,0}, .{0, 160}, .{160, 160});
    zow4.draw.quadratic_bezier(.{0,0}, .{320,80}, .{0, 160});

    stage.update();
    stage.render();

    if (grabbed) |el| {
        if (grab_point) |point| {
            el.size.pos = Input.mousepos() - point;
        }
    }

    Input.update();
}
