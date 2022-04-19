const std = @import("std");
const w4 = @import("wasm4");
const draw = @import("../draw.zig");
const text = @import("../text.zig");
const ui = @import("context.zig");
const UIContext = @import("context.zig").UIContext;

pub const DefaultUIContext = UIContext(DefaultUI);
pub const Node = DefaultUIContext.Node;

/// A simple default UI
pub const DefaultUI = union(enum) {
    /// Draws text to the screen. Pass a pointer to the text to be rendered.
    Label: []const u8,
    /// Draws an image to the screen. Assumes there is another array containing image info
    Image: *draw.Blit,
    /// Button
    Button: []const u8,

    pub fn init(alloc: std.mem.Allocator) DefaultUIContext {
        return DefaultUIContext.init(alloc, size, update, paint);
    }

    pub fn size(this: @This()) ui.Vec {
        switch (this) {
            .Label => |label| {
                const label_size = text.text_size(label);
                return .{
                    label_size[0],
                    label_size[1],
                };
            },
            .Image => |blit| {
                const blit_size = blit.get_size();
                return .{
                    blit_size[0], blit_size[1],
                };
            },
            .Button => |btn_label| {
                const label_size = text.text_size(btn_label);
                const padding = 6; // 3 pixels left, 2 pixels right
                return .{
                    label_size[0] + padding, label_size[1] + padding,
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
        if (node.has_background) {
            var left = ui.left(node.bounds);
            var top = ui.top(node.bounds);

            const rect_size = ui.rect_size(node.bounds);
            // Make sure we are at least the minimum size to prevent crashing
            var sizex = @intCast(u32, rect_size[0]);
            var sizey = @intCast(u32, rect_size[1]);

            // Clear background
            w4.DRAW_COLORS.* = 0x41;
            w4.rect(left, top, sizex, sizey);
        }
        if (node.data) |data| {
            switch (data) {
                .Label => |label| {
                    w4.DRAW_COLORS.* = 0x04;
                    w4.textUtf8(label.ptr, label.len, node.bounds[0], node.bounds[1]);
                },
                .Image => |blit| {
                    blit.blit(.{ node.bounds[0], node.bounds[1] });
                },
                .Button => |btn_label| {
                    var left = ui.left(node.bounds);
                    var right = ui.right(node.bounds);
                    var top = ui.top(node.bounds);
                    var bottom = ui.bottom(node.bounds);

                    const rect_size = ui.rect_size(node.bounds);
                    // Make sure we are at least the minimum size to prevent crashing
                    var sizex = @intCast(u32, if (rect_size[0] < node.min_size[0])
                        node.min_size[0]
                    else
                        rect_size[0]);
                    var sizey = @intCast(u32, if (rect_size[1] < node.min_size[1])
                        node.min_size[1]
                    else
                        rect_size[1]);

                    // Clear background
                    w4.DRAW_COLORS.* = 0x01;
                    w4.rect(left + 1, top + 1, sizex - 2, sizey - 2);
                    var dark = false;
                    switch (node.pointer_state) {
                        .Open, .Hover => {
                            w4.DRAW_COLORS.* = 0x04;
                            // Render "Shadow"
                            w4.hline(left + 2, bottom - 1, sizex - 2);
                            w4.vline(right - 1, top + 2, sizey - 2);
                            // Render "Side"
                            w4.hline(left + 1, bottom - 2, sizex - 2);
                            w4.vline(right - 2, top + 1, sizey - 2);
                            if (node.pointer_state == .Hover) {
                                w4.DRAW_COLORS.* = 0x41;
                                w4.rect(left + 1, top + 1, sizex - 2, sizey - 2);
                            }
                        },
                        .Pressed => {
                            w4.DRAW_COLORS.* = 0x44;
                            w4.rect(left + 2, top + 2, sizex - 2, sizey - 2);
                            dark = true;
                        },
                        .Clicked => {
                            w4.DRAW_COLORS.* = 0x44;
                            w4.rect(left + 2, top + 2, sizex - 2, sizey - 2);
                            dark = true;
                        },
                    }
                    w4.DRAW_COLORS.* = if (dark) 0x01 else 0x04;
                    const offset: i32 = if (dark) 4 else 3;
                    w4.textUtf8(btn_label.ptr, btn_label.len, left + offset, top + offset);
                },
            }
        }
    }
};
