const std = @import("std");
const w4 = @import("wasm4");
const geom = @import("geometry.zig");
const draw = @import("draw.zig");
const text = @import("text.zig");
const Input = @import("input.zig");
const v = geom.Vec;

pub const layout = @import("ui/layout.zig");
pub const Element = @import("ui/element.zig").Element;
pub const style = @import("ui/style.zig");

const Blit = draw.Blit;
const BlitFlags = draw.BlitFlags;

pub const Event = enum {
    MousePressed,
    MouseReleased,
    MouseMoved,
    MouseClicked,
    MouseEnter,
    MouseLeave,
};

pub const EventData = union(Event) {
    MousePressed: geom.Vec2,
    MouseReleased: geom.Vec2,
    MouseMoved: geom.Vec2,
    MouseClicked: geom.Vec2,
    MouseEnter,
    MouseLeave,
};
pub const Listener = struct {
    el: *Element,
    event: Event,
    callback: fn (*Element, EventData) void,
};

pub const ListenFn = fn (*Element, EventData) void;

pub const Stage = struct {
    alloc: std.mem.Allocator,
    style: style.StyleSheet = style.DefaultStyle,
    event_listeners: EventList,
    root: *Element,
    // element_list: ElementList,

    const EventList = std.ArrayList(Listener);
    // const ElementList = std.ArrayList(Element);

    pub fn init(alloc: std.mem.Allocator) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .event_listeners = EventList.init(alloc),
            .root = undefined,
            // .element_list = ElementList.init(alloc),
        };
        this.root = try this.float(geom.AABB.init(0, 0, 160, 160));
        return this;
    }

    pub fn deinit(this: *@This()) !*@This() {
        this.event_listeners.deinit();
        this.alloc.destroy(this);
    }

    pub fn listen(this: *@This(), el: *Element, event: Event, callback: ListenFn) void {
        this.event_listeners.append(.{
            .el = el,
            .event = event,
            .callback = callback,
        }) catch w4.trace("couldn't add listener");
    }

    pub fn unlisten(this: *@This(), el: *Element, event: Event, callback: ListenFn) void {
        var i: usize = this.event_listeners.items.len;
        while (i > 0) : (i -= 1) {
            const listener = this.event_listeners.items[i];
            if (listener.el != el or listener.event != event or listener.callback != callback) continue;
            _ = this.event_listeners.swapRemove(i);
        }
    }

    pub fn unlisten_all(this: *@This(), el: *Element) void {
        var i: usize = this.event_listeners.items.len;
        while (i > 0) : (i -= 1) {
            const listener = this.event_listeners.items[i];
            if (listener.el != el) continue;
            _ = this.event_listeners.swapRemove(i);
        }
    }

    pub fn dispatch(this: *@This(), el: *Element, event: EventData) void {
        for (this.event_listeners.items) |listener| {
            if (listener.el != el or listener.event != event) continue;
            listener.callback(el, event);
        }
    }

    pub fn update(this: *@This()) void {
        this.root.layout();
        this.root.update();

        const mousepos = Input.mousepos();
        if (Input.mousep(.left)) {
            this.root.bubble(.{ .MousePressed = mousepos });
        }
        if (Input.mouser(.left)) {
            this.root.bubble(.{ .MouseReleased = mousepos });
        }
        if (geom.Vec.isZero(Input.mousediff())) {
            this.root.bubble(.{ .MouseMoved = mousepos });
        }
        if (Input.clickstate == .clicked) {
            this.root.bubble(.{ .MouseClicked = mousepos });
        }
    }

    pub fn render(this: @This()) void {
        this.root.render(.background);
    }

    pub fn hdiv(this: *@This()) !*Element {
        var el = try this.alloc.create(Element);
        el.* = Element.init(this, el, layout.size_fill, layout.layout_div_horizontal, null);
        return el;
    }

    pub fn vdiv(this: *@This()) !*Element {
        var el = try this.alloc.create(Element);
        el.* = Element.init(this, el, layout.size_fill, layout.layout_div_vertical, null);
        return el;
    }

    pub fn center(this: *@This()) !*Element {
        var el = try this.alloc.create(Element);
        el.* = Element.init(this, el, layout.size_fill, layout.layout_center, null);
        return el;
    }

    pub fn float(this: *@This(), rect: geom.AABB) !*Element {
        var el = try this.alloc.create(Element);
        el.* = Element.init(this, el, layout.size_static, layout.layout_relative, null);
        el.size = rect;
        return el;
    }

    pub fn panel(this: *@This()) !*Element {
        const el = try this.alloc.create(Element);
        el.* = Element.init(this, el, layout.size_fill, layout.layout_relative, Panel.renderFn);
        el.style = .{ .static = .frame };
        return el;
    }

    pub fn label(this: *@This(), txt: []const u8) !*Element {
        const el = try this.alloc.create(Label);
        el.* = Label{
            .element = Element.init(this, el, Label.sizeFn, layout.layout_relative, Label.renderFn),
            .string = txt,
        };
        el.element.style = .{ .static = .foreground };
        return &el.element;
    }

    pub fn sprite(this: *@This(), blit: Blit) !*Element {
        const el = try this.alloc.create(Sprite);
        el.* = Sprite{
            .element = Element.init(this, el, Sprite.sizeFn, layout.layout_relative, Sprite.renderFn),
            .blit = blit,
        };
        el.element.size.size = el.blit.get_size();
        el.element.style = .{ .static = .foreground };
        return &el.element;
    }

    pub fn button(this: *@This(), string: []const u8) !*Element {
        const new_btn = try this.alloc.create(Element);
        new_btn.* = Element.init(this, new_btn, layout.size_fill, layout.layout_relative, null);

        const new_panel = try this.panel();
        new_panel.style = .{ .rule = style.style_interactive };
        new_btn.appendChild(new_panel);

        const centerel = try this.center();
        new_panel.appendChild(centerel);

        const new_label = try this.label(string);
        new_label.style = .{ .rule = style.style_inverse };
        centerel.appendChild(new_label);

        return new_btn;
    }
};

pub const Panel = struct {
    fn renderFn(el: Element, ctx: style.PaintStyle) style.PaintStyle {
        const rect = el.size;
        var draw_style = switch (el.style) {
            .static => |staticstyle| staticstyle,
            .rule => |stylerule| stylerule(el, ctx),
        };
        w4.DRAW_COLORS.* = draw_style.to_style();
        // w4.DRAW_COLORS.* = this.style;
        w4.rect(rect.pos[v.x], rect.pos[v.y], @intCast(u32, rect.size[v.x]), @intCast(u32, rect.size[v.y]));
        return draw_style;
    }
};

pub const Sprite = struct {
    element: Element,
    blit: Blit,

    fn sizeFn(el: *Element, bounds: geom.AABB) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        return geom.AABB.initv(bounds.pos, this.blit.get_size());
    }

    fn renderFn(el: Element, _: style.PaintStyle) style.PaintStyle {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        this.blit.blit(this.element.size.pos);
        return .foreground;
    }
};

pub const Label = struct {
    element: Element,
    string: []const u8,

    fn sizeFn(el: *Element, bounds: geom.AABB) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        return geom.AABB.initv(bounds.pos, text.text_size(this.string));
    }

    fn renderFn(el: Element, ctx: style.PaintStyle) style.PaintStyle {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        var draw_style = switch (el.style) {
            .static => |staticstyle| staticstyle,
            .rule => |stylerule| stylerule(el, ctx),
        };
        w4.DRAW_COLORS.* = draw_style.to_style();
        // w4.DRAW_COLORS.* = this.style;
        draw.text(this.string, this.element.size.pos);
        return draw_style;
    }
};
