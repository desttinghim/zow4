const std = @import("std");
const w4 = @import("wasm4");
const draw = @import("../draw.zig");
const text = @import("../text.zig");
const ui = @import("context.zig");
const UIContext = @import("context.zig").UIContext;

pub const DefaultUIContext = UIContext(DefaultUI);
const Node = DefaultUIContext.Node;

const Button = struct {
    label: []const u8,
    state: union(enum) { Open, Hover, Pressed, Clicked: u8 },
};

/// A simple default UI
pub const DefaultUI = union(enum) {
    /// Draws text to the screen. Pass a pointer to the text to be rendered.
    Label: []const u8,
    /// Draws an image to the screen. Assumes there is another array containing image info
    Image: *draw.Blit,
    /// Button
    Btn: Button,

    pub fn init(alloc: std.mem.Allocator) DefaultUIContext {
        return DefaultUIContext.init(alloc, size, update, paint);
    }

    pub fn size(this: @This()) ui.Vec {
        switch (this) {
            .Label => |label| {
                const label_size = text.text_size(label);
                return .{
                    @intToFloat(f32, label_size[0]),
                    @intToFloat(f32, label_size[1]),
                };
            },
            .Image => |blit| {
                const blit_size = blit.get_size();
                return .{
                    @intToFloat(f32, blit_size[0]),
                    @intToFloat(f32, blit_size[1]),
                };
            },
            .Btn => |btn| {
                const label_size = text.text_size(btn.label);
                const padding = 4; // 2 pixels on each side
                return .{
                    @intToFloat(f32, label_size[0] + padding),
                    @intToFloat(f32, label_size[1] + padding),
                };
            },
        }
    }

    pub fn update(node: Node) Node {
        switch (node.data) {
            .Label => {},
            .Image => {},
            .Btn => {},
        }
        return node;
    }

    pub fn paint(node: Node) void {
        switch (node.data) {
            .Label => |label| {
                w4.DRAW_COLORS.* = 0x04;
                const x = @floatToInt(i32, node.bounds[0]);
                const y = @floatToInt(i32, node.bounds[1]);
                w4.textUtf8(label.ptr, label.len, x, y);
            },
            .Image => {},
            .Btn => {},
        }
    }
};
