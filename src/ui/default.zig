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
    state: enum { Open, Hover, Pressed, Clicked } = .Open,
    clicked: u8 = 0,

    pub fn update(node: Node, data: Button) Node {
        var new_button = data;
        new_button.clicked -|= 1;
        switch (data.state) {
            .Open => {
                if (node.pointer_over) {
                    new_button.state = .Hover;
                } else {
                    new_button.state = .Open;
                }
            },
            .Hover => {
                if (node.pointer_pressed) {
                    new_button.state = .Pressed;
                } else if (node.pointer_over) {
                    new_button.state = .Hover;
                } else {
                    new_button.state = .Open;
                }
            },
            .Pressed => {
                if (!node.pointer_over) {
                    new_button.state = .Open;
                } else if (!node.pointer_pressed) {
                    new_button.state = .Clicked;
                } else {
                    new_button.state = .Pressed;
                }
            },
            .Clicked => {
                if (!node.pointer_over) {
                    new_button.state = .Open;
                } else {
                    new_button.state = .Hover;
                }
            },
        }
        if (data.state == .Clicked) {
            new_button.clicked = 15;
        }
        var new_node = node;
        new_node.data = .{ .Button = new_button };
        return new_node;
    }
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
            .Button => |btn| {
                const label_size = text.text_size(btn.label);
                const padding = 4; // 2 pixels on each side
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
                .Button => |btn| return Button.update(node, btn),
            }
        }
        return node;
    }

    pub fn paint(node: Node) void {
        if (node.data) |data| {
            switch (data) {
                .Label => |label| {
                    w4.DRAW_COLORS.* = 0x04;
                    w4.textUtf8(label.ptr, label.len, node.bounds[0], node.bounds[1]);
                },
                .Image => |blit| {
                    blit.blit(.{ node.bounds[0], node.bounds[1] });
                },
                .Button => |btn| {
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
                    if (btn.clicked > 0) {
                        w4.DRAW_COLORS.* = 0x44;
                        w4.rect(left + 2, top + 2, sizex - 2, sizey - 2);
                    } else {
                        switch (btn.state) {
                            .Open, .Hover => {
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
                            .Clicked => {},
                        }
                    }
                    w4.DRAW_COLORS.* = 0x04;
                    w4.textUtf8(btn.label.ptr, btn.label.len, left + 2, top + 2);
                },
            }
        }
    }
};
