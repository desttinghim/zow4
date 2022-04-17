const std = @import("std");
const zow4 = @import("zow4");

const Input = zow4.input;
const ui = zow4.ui;

var fba: std.heap.FixedBufferAllocator = undefined;
var alloc: std.mem.Allocator = undefined;
var stage: *ui.Stage = undefined;
var counter: isize = 0;
var counter_label: *ui.Label = undefined;
var counter_text: []u8 = undefined;

fn increment(_: *ui.Element, _: ui.EventData) void {
    counter +|= 1;
    alloc.free(counter_text);
    counter_text = std.fmt.allocPrint(alloc, "{}", .{counter}) catch @panic("formatting string");
    counter_label.string = counter_text;
}

fn decrement(_: *ui.Element, _: ui.EventData) void {
    counter -|= 1;
    alloc.free(counter_text);
    counter_text = std.fmt.allocPrint(alloc, "{}", .{counter}) catch @panic("formatting string");
    counter_label.string = counter_text;
}

export fn start() void {
    fba = zow4.heap.init();
    alloc = fba.allocator();

    stage = ui.Stage.init(alloc) catch @panic("creating stage");

    var vdiv = stage.vdiv() catch @panic("vdiv");
    stage.root.appendChild(vdiv);

    {
        var spacer = stage.panel() catch @panic("spacer");
        spacer.style = .{ .static = .background };
        vdiv.appendChild(spacer);
    }

    var hdiv = stage.hdiv() catch @panic("hdiv");
    vdiv.appendChild(hdiv);

    {
        var spacer = stage.panel() catch @panic("spacer");
        spacer.style = .{ .static = .background };
        vdiv.appendChild(spacer);
    }

    {
        var btn1 = stage.button("-") catch @panic("creating button");
        btn1.listen(.MouseClicked, decrement);
        btn1.layoutFn = ui.layout.layout_padded;
        hdiv.appendChild(btn1);
    }

    {
        var center = stage.center() catch @panic("centering");
        hdiv.appendChild(center);
        counter_text = std.fmt.allocPrint(alloc, "{}", .{counter}) catch @panic("formatting string");
        var label = stage.label(counter_text) catch @panic("creating label");
        counter_label = @ptrCast(*ui.Label, @alignCast(@alignOf(ui.Label), label));
        center.appendChild(label);
    }

    {
        var btn2 = stage.button("+") catch @panic("creating button");
        btn2.listen(.MouseClicked, increment);
        btn2.layoutFn = ui.layout.layout_padded;
        hdiv.appendChild(btn2);
    }
}

export fn update() void {
    stage.update();
    stage.render();

    Input.update();
}
