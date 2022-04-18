const std = @import("std");
const w4 = @import("wasm4");
const geom = @import("geometry.zig");
const draw = @import("draw.zig");
const text = @import("text.zig");
const Input = @import("input.zig");
const elmnt = @import("ui/element.zig");
const v = geom.Vec;

pub const layout = @import("ui/layout.zig");
pub const style = @import("ui/style.zig");
pub const Element = elmnt.Element;

const Blit = draw.Blit;
const BlitFlags = draw.BlitFlags;

const SizeFn  = elmnt.SizeFn;
const LayoutFn  = elmnt.LayoutFn;
const RenderFn  = elmnt.RenderFn;

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
    callback: ListenFn,
};

pub const ListenFn = fn (*Element, EventData) bool;

pub const Stage = struct {
    alloc: std.mem.Allocator,
    style: style.StyleSheet = style.DefaultStyle,
    event_listeners: EventList,
    root: *Element,
    // element_list: ElementList,
    focus: ?*Element = null,
    last_focus: ?*Element = null,

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
        this.root.remove();
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

    pub fn dispatch(this: *@This(), el: *Element, event: EventData) bool {
        for (this.event_listeners.items) |listener| {
            if (listener.el != el or listener.event != event) continue;
            const stop = listener.callback(el, event);
            if (stop) return true;
        }
        return false;
    }

    pub fn update(this: *@This()) void {
        this.root.layout();
        this.root.update();

        const mousepos = Input.mousepos();
        if (this.root.find_top(mousepos)) |focus| {
            this.last_focus = this.focus;
            this.focus = focus;
            if (Input.mousep(.left)) {
                focus.bubble_up(.{ .MousePressed = mousepos });
            }
            if (Input.mouser(.left)) {
                focus.bubble_up(.{ .MouseReleased = mousepos });
            }
            if (!geom.Vec.isZero(Input.mousediff())) {
                focus.bubble_up(.{ .MouseMoved = mousepos });
            }
            if (this.focus != this.last_focus) {
                focus.bubble_up(.MouseEnter);
                if (this.last_focus) |last_focus| {
                    last_focus.bubble_up(.MouseLeave);
                    // this.last_focus = null;
                }
            }
        }
    }

    pub fn render(this: @This()) void {
        this.root.render(.background);
    }

    pub fn element(this: *@This(), self: ?*anyopaque, sizeFn: SizeFn, layoutFn: LayoutFn, renderFn: ?RenderFn) !*Element {
        var el = try this.alloc.create(Element);
        const ptr: *anyopaque = self orelse el;
        el.* = Element.init(this, ptr, sizeFn, layoutFn, renderFn);
        return el;
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

    pub fn vlist(this: *@This()) !*Element {
        var el = try this.alloc.create(Element);
        el.* = Element.init(this, el, layout.size_fill, layout.layout_vlist, null);
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
        new_btn.renderFn = Panel.renderBtn;
        new_btn.style = .{ .rule = style.style_interactive };

        const centerel = try this.center();
        centerel.capture_mouse = false;

        const new_label = try this.label(string);
        new_label.style = .{ .rule = style.style_inverse };
        new_label.capture_mouse = false;

        new_btn.appendChild(centerel);
        centerel.appendChild(new_label);

        return new_btn;
    }
};

pub const Panel = struct {
    fn renderFn(el: *const Element, ctx: style.PaintStyle) style.PaintStyle {
        const rect = el.size;
        var draw_style = switch (el.style) {
            .static => |staticstyle| staticstyle,
            .rule => |stylerule| stylerule(el, ctx),
        };
        w4.DRAW_COLORS.* = draw_style.to_style();
        w4.rect(rect.pos[v.x], rect.pos[v.y], @intCast(u32, rect.size[v.x]), @intCast(u32, rect.size[v.y]));
        return draw_style;
    }

    fn renderBtn(el: *const Element, _: style.PaintStyle) style.PaintStyle {
        const rect = el.size;
        var draw_style: style.PaintStyle = .frame;

        var sizex = @intCast(u32, rect.size[v.x]);
        var sizey = @intCast(u32, rect.size[v.y]);

        switch (el.mouse_state) {
            .Open, .Hover => {
                w4.DRAW_COLORS.* = draw_style.to_style();
                w4.rect(rect.left() + 1, rect.top() + 1, sizex - 2, sizey - 2);
                w4.DRAW_COLORS.* = style.PaintStyle.foreground.to_style();
                // Render "Shadow"
                w4.hline(rect.left() + 2, rect.bottom() - 1, sizex - 2);
                w4.vline(rect.right() - 1, rect.top() + 2, sizey - 2);
                // Render "Side"
                w4.hline(rect.left() + 1, rect.bottom() - 2, sizex - 2);
                w4.vline(rect.right() - 2, rect.top() + 1, sizey - 2);
                if (el.mouse_state == .Hover) {
                    draw_style = .frame;
                    w4.DRAW_COLORS.* = draw_style.to_style();
                    w4.rect(rect.left() + 1, rect.top() + 1, sizex - 2, sizey - 2);
                }
            },
            .Pressed => {
                draw_style = .foreground;
                w4.DRAW_COLORS.* = draw_style.to_style();
                w4.rect(rect.left() + 2, rect.top() + 2, sizex - 2, sizey - 2);
            },
            .Clicked => {
                draw_style = .foreground;
                w4.DRAW_COLORS.* = draw_style.to_style();
                w4.rect(rect.left() + 2, rect.top() + 2, sizex - 2, sizey - 2);
            },
        }

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

    fn renderFn(el: *const Element, _: style.PaintStyle) style.PaintStyle {
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

    fn renderFn(el: *const Element, ctx: style.PaintStyle) style.PaintStyle {
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
