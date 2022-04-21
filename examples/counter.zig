const std = @import("std");
const zow4 = @import("zow4");

const input = zow4.input;
const ui = zow4.ui;
const Context = ui.default.Context;
const Node = Context.Node;

var fba: std.heap.FixedBufferAllocator = undefined;
var alloc: std.mem.Allocator = undefined;
var ctx: Context = undefined;

var counter: isize = 0;
var counter_handle: usize = undefined;
var counter_text: []u8 = undefined;

fn update_label() void {
    if (ctx.get_node(counter_handle)) |node| {
        var new_node = node;
        alloc.free(counter_text);
        counter_text = std.fmt.allocPrint(alloc, "{}", .{counter}) catch @panic("formatting string");
        new_node.data.?.Label = counter_text;
        _ = ctx.set_node(new_node);
    }
}

fn increment(_: ui.default.Node, _: zow4.ui.EventData) ?ui.default.Node {
    counter +|= 1;
    update_label();
    return null;
}

fn decrement(_: ui.default.Node, _: zow4.ui.EventData) ?ui.default.Node {
    counter -|= 1;
    update_label();
    return null;
}

export fn start() void {
    init() catch @panic("eh");
}

fn init() !void {
    fba = zow4.mem.init();
    alloc = fba.allocator();

    ctx = ui.default.init(alloc);

    var vdiv = try ctx.insert(null, Node.vdiv());

    // Spacer
    _ = try ctx.insert(vdiv, .{});

    {
        const hdiv = try ctx.insert(vdiv, Node.hdiv());

        const center_dec = try ctx.insert(hdiv, Node.center());
        const btn_decrement = try ctx.insert(center_dec, Node.relative().dataValue(.{ .Button = "-" }).capturePointer(true));
        try ctx.listen(btn_decrement, .PointerClick, decrement);

        counter = 0;
        counter_text = try std.fmt.allocPrint(alloc, "{}", .{counter});
        const center_lbl = try ctx.insert(hdiv, Node.center());
        counter_handle = try ctx.insert(center_lbl, Node.relative().dataValue(.{ .Label = counter_text }));

        const center_inc = try ctx.insert(hdiv, Node.center());
        const btn_increment = try ctx.insert(center_inc, Node.relative().dataValue(.{ .Button = "+" }).capturePointer(true));
        try ctx.listen(btn_increment, .PointerClick, increment);
    }

    // Spcer
    _ = try ctx.insert(vdiv, .{});

    ctx.layout(.{ 0, 0, 160, 160 });
}

export fn update() void {
    _update() catch @panic("update");
}

fn _update() !void {
    ctx.update(.{
        .pointer = .{
            .left = input.mouse(.left),
            .right = input.mouse(.right),
            .middle = input.mouse(.middle),
            .pos = input.mousepos(),
        },
        .keys = .{
            .up = input.btn(.one, .up),
            .down = input.btn(.one, .down),
            .left = input.btn(.one, .left),
            .right = input.btn(.one, .right),
            .accept = input.btn(.one, .x),
            .reject = input.btn(.one, .z),
        },
    });
    ctx.layout(.{ 0, 0, 160, 160 });
    ctx.paint();
    input.update();
}
