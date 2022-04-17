const Element = @import("../ui.zig").Element;
const draw = @import("../draw.zig");

pub const DefaultStyle = StyleSheet{
    .background = draw.color.fill(.Light),
    .foreground = draw.color.fill(.Dark),
    .frame = draw.color.select(.Light, .Dark),
};

pub const StyleSheet = struct {
    background: u16,
    foreground: u16,
    frame: u16,
};

pub const PaintStyle = enum {
    background,
    foreground,
    frame,

    pub fn to_style(this: @This()) u16 {
        return switch (this) {
            .foreground => DefaultStyle.foreground,
            .background => DefaultStyle.background,
            .frame => DefaultStyle.frame,
        };
    }
};

pub fn style_interactive(el: Element, _: PaintStyle) PaintStyle {
    if (el.mouse_state == .Clicked) return .foreground;
    if (el.mouse_state == .Hover) return .frame;
    return .background;
}

pub fn style_inverse(_: Element, parent_style: PaintStyle) PaintStyle {
    return switch (parent_style) {
        .background => .foreground,
        .foreground => .background,
        .frame => .foreground,
    };
}
