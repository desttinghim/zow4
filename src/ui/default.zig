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
    state: union(enum) { Open, Hover, Pressed, Clicked: u8 } = .Open,
};

/// A simple default UI
pub const DefaultUI = union(enum) {
    /// Draws text to the screen. Pass a pointer to the text to be rendered.
    Label: []const u8,
    /// Draws an image to the screen. Assumes there is another array containing image info
    Image: *draw.Blit,
    /// Button
    Button: Button,

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
            .Button => |btn| {
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
        if (node.data) |data| {
            switch (data) {
                .Label => {},
                .Image => {},
                .Button => {},
            }
        }
        return node;
    }

    pub fn paint(node: Node) void {
        if (node.data) |data| {
            switch (data) {
                .Label => |label| {
                    w4.DRAW_COLORS.* = 0x04;
                    const x = @floatToInt(i32, node.bounds[0]);
                    const y = @floatToInt(i32, node.bounds[1]);
                    w4.textUtf8(label.ptr, label.len, x, y);
                },
                .Image => |blit| {
                    const x = @floatToInt(i32, node.bounds[0]);
                    const y = @floatToInt(i32, node.bounds[1]);
                    blit.blit(.{ x, y });
                },
                .Button => |btn| {
                    var left = @floatToInt(i32, ui.left(node.bounds));
                    var right = @floatToInt(i32, ui.right(node.bounds));
                    var top = @floatToInt(i32, ui.top(node.bounds));
                    var bottom = @floatToInt(i32, ui.bottom(node.bounds));

                    var sizex = @floatToInt(u32, ui.rect_size(node.bounds)[0]);
                    var sizey = @floatToInt(u32, ui.rect_size(node.bounds)[1]);

                    switch (btn.state) {
                        .Open, .Hover => {
                            w4.DRAW_COLORS.* = 0x01;
                            w4.rect(left + 1, top + 1, sizex - 2, sizey - 2);
                            w4.DRAW_COLORS.* = 0x04;
                            // Render "Shadow"
                            w4.hline(left + 2, bottom - 1, sizex - 2);
                            w4.vline(right - 1, top + 2, sizey - 2);
                            // Render "Side"
                            w4.hline(left + 1, bottom - 2, sizex - 2);
                            w4.vline(right - 2, top + 1, sizey - 2);
                            if (btn.state == .Hover) {
                                w4.DRAW_COLORS.* = 0x41;
                                w4.rect(left + 1, top + 1, sizex - 2, sizey - 2);
                            }
                        },
                        .Pressed => {
                            w4.DRAW_COLORS.* = 0x44;
                            w4.rect(left + 2, top + 2, sizex - 2, sizey - 2);
                        },
                        .Clicked => {
                            w4.DRAW_COLORS.* = 0x44;
                            w4.rect(left + 2, top + 2, sizex - 2, sizey - 2);
                        },
                    }
                    w4.DRAW_COLORS.* = 0x04;
                    w4.textUtf8(btn.label.ptr, btn.label.len, left + 2, top + 2);
                },
            }
        }
    }
};
