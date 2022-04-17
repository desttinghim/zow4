const std = @import("std");
const w4 = @import("wasm4");
const geom = @import("geometry.zig");
const draw = @import("draw.zig");
const text = @import("text.zig");
const Input = @import("input.zig");
const v = geom.Vec;

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

/// Fill entire available space
fn size_fill(_: *Element, bounds: geom.AABB) geom.AABB {
    return bounds;
}

/// Size is preset
fn size_static(el: *Element, _: geom.AABB) geom.AABB {
    return el.size;
}

/// No layout
fn layout_relative(el: *Element, _: usize) geom.AABB {
    return el.size;
}

/// Divide vertical space equally
fn layout_div_vertical(el: *Element, childID: usize) geom.AABB {
    const vsize = @divTrunc(el.size.size[v.y], @intCast(i32, el.children));
    return geom.AABB.initv(
        el.size.pos + geom.Vec2{ 0, @intCast(i32, childID) * vsize },
        geom.Vec2{ el.size.size[v.x], vsize },
    );
}

/// Divide horizontal space equally
fn layout_div_horizontal(el: *Element, childID: usize) geom.AABB {
    const hsize = @divTrunc(el.size.size[v.x], @intCast(i32, el.children));
    return geom.AABB.initv(
        el.size.pos + geom.Vec2{ @intCast(i32, childID) * hsize, 0 },
        geom.Vec2{ hsize, el.size.size[v.y] },
    );
}

/// Center component
fn layout_center(el: *Element, childID: usize) geom.AABB {
    const centerv = el.size.pos + @divTrunc(el.size.size, geom.Vec2{ 2, 2 });
    var centeraabb = geom.AABB.initv(centerv, geom.Vec2{ 0, 0 });
    if (el.getChild(childID)) |child| {
        centeraabb.pos -= @divTrunc(child.size.size, geom.Vec2{ 2, 2 });
        centeraabb.size = child.size.size;
    }
    return centeraabb;
}

pub const Element = struct {
    hidden: bool = false,
    hover: bool = false,
    self: *anyopaque,
    /// Space that the element takes up
    size: geom.AABB,
    children: usize = 0,
    ctx: *Stage,
    prev: ?*@This() = null,
    next: ?*@This() = null,
    parent: ?*@This() = null,
    child: ?*@This() = null,
    // Function Pointers
    sizeFn: SizeFn,
    layoutFn: LayoutFn,
    renderFn: ?RenderFn,

    /// Passed self, bounding box, and returns a size
    const SizeFn = fn (*Element, geom.AABB) geom.AABB;
    /// Passed self number of children, and child number, returns bounds to be passed to size
    const LayoutFn = fn (*Element, usize) geom.AABB;
    /// Event
    const EventCB = fn (*Element, EventData) void;
    /// Draws element to the screen
    const RenderFn = fn (Element) void;

    pub fn init(ctx: *Stage, self: *anyopaque, sizeFn: SizeFn, layoutFn: LayoutFn, renderFn: ?RenderFn) @This() {
        return @This(){
            .ctx = ctx,
            .self = self,
            .size = geom.AABB.init(0, 0, 160, 160),
            .sizeFn = sizeFn,
            .layoutFn = layoutFn,
            .renderFn = renderFn,
        };
    }

    pub fn listen(this: *@This(), event: Event, callback: ListenFn) void {
        this.ctx.listen(this, event, callback);
    }

    pub fn unlisten(this: *@This(), event: Event, callback: ListenFn) void {
        this.ctx.unlisten(this, event, callback);
    }

    fn update(this: *@This()) void {
        if (this.size.contains(Input.mousepos())) {
            if (!this.hover) {
                this.hover = true;
                this.ctx.dispatch(this, .MouseEnter);
            }
        } else {
            this.ctx.dispatch(this, .MouseLeave);
            this.hover = false;
        }
        if (this.child) |child| child.update();
        if (this.next) |next| next.update();
    }

    fn bubble(this: *@This(), ev: EventData) void {
        var child_opt = this.child;
        var i: usize = 0;
        while (child_opt) |child| : (child_opt = child.next) {
            if (child.hidden) {
                i += 1;
                continue;
            }
            switch (ev) {
                .MouseMoved,
                .MousePressed,
                .MouseReleased,
                .MouseClicked,
                => |pos| {
                    if (child.size.contains(pos)) child.bubble(ev);
                },
                else => child.bubble(ev),
            }
            i += 1;
        }
        this.ctx.dispatch(this, ev);
    }

    pub fn remove(this: *@This()) void {
        // TODO
        if (this.child) |child| child.remove();
        if (this.prev) |prev| prev.next = this.next;
        if (this.parent) |parent| parent.children -= 1;
        this.ctx.destroy(this.self);
    }

    pub fn compute_size(this: *@This(), bounds: geom.AABB) void {
        this.size = this.sizeFn(this, bounds);
    }

    pub fn layout(this: *@This()) void {
        var child_opt = this.child;
        var i: usize = 0;
        while (child_opt) |child| : (i += 1) {
            const bounds = this.layoutFn(this, i);
            child.compute_size(bounds);
            child.layout();
            child_opt = child.next;
        }
    }

    const Self = @This();
    pub const ChildIter = struct {
        child_opt: ?*Self,
        pub fn next(this: @This()) ?*Self {
            if (this.child_opt) |child| {
                this.child_opt = this.child_opt.next;
                return child;
            }
            return null;
        }
    };

    pub fn childIter(this: *@This()) ChildIter {
        return .{ .child_opt = this.child };
    }

    pub fn getChild(this: *@This(), num: usize) ?*@This() {
        var i: usize = 0;
        var child_opt = this.child;
        while (child_opt) |child| : (i += 1) {
            if (i == num) return child;
        }
        return null;
    }

    pub fn appendChild(this: *@This(), el: *@This()) void {
        el.parent = this;
        this.children += 1;

        var child_opt = this.child;
        while (child_opt) |child| {
            if (child.next) |next| {
                child_opt = next;
            } else {
                child.next = el;
                break; // prevent else block
            }
        } else {
            this.child = el;
        }
    }

    pub fn render(this: @This()) void {
        if (!this.hidden) {
            if (this.renderFn) |rfn| rfn(this);
            if (this.child) |child| child.render();
        }
        if (this.next) |next| next.render();
    }
};

pub const StyleSheet = struct {
    const ButtonStyle = struct { label: u16, panel: u16 };
    background: u16,
    button: struct {
        default: ButtonStyle,
        hover: ButtonStyle,
        click: ButtonStyle,
    },
};

pub const DefaultStyle = StyleSheet{
    .background = draw.color.select(.Light, .Dark),
    .button = .{
        .default = .{
            .panel = draw.color.fill(.Light),
            .label = draw.color.fill(.Dark),
        },
        .hover = .{
            .panel = draw.color.select(.Light, .Dark),
            .label = draw.color.fill(.Dark),
        },
        .click = .{
            .panel = draw.color.fill(.Dark),
            .label = draw.color.fill(.Light),
        },
    },
};

pub const Listener = struct {
    el: *Element,
    event: Event,
    callback: fn (*Element, EventData) void,
};

pub const ListenFn = fn (*Element, EventData) void;

pub const Stage = struct {
    alloc: std.mem.Allocator,
    style: StyleSheet = DefaultStyle,
    event_listeners: EventList,
    root: *Element,

    const EventList = std.ArrayList(Listener);

    pub fn init(alloc: std.mem.Allocator) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .event_listeners = EventList.init(alloc),
            .root = undefined,
        };
        this.root = try this.float(geom.AABB.init(0, 0, 160, 160));
        return this;
    }

    pub fn deinit(this: *@This()) !*@This() {
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
            this.event_listeners.swapRemove(i);
        }
    }

    pub fn dispatch(this: *@This(), el: *Element, event: EventData) void {
        for (this.event_listeners.items) |listener| {
            if (listener.el != el or listener.event != event) continue;
            listener.callback(el, event);
        }
    }

    pub fn update(this: *@This()) void {
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
        this.root.render();
    }

    pub fn layout(this: *@This()) void {
        this.root.layout();
    }

    pub fn hdiv(this: *@This()) !*Element {
        var el = try this.alloc.create(Element);
        el.* = Element.init(this, el, size_fill, layout_div_horizontal, null);
        return el;
    }

    pub fn vdiv(this: *@This()) !*Element {
        var el = try this.alloc.create(Element);
        el.* = Element.init(this, el, size_fill, layout_div_vertical, null);
        return el;
    }

    pub fn center(this: *@This()) !*Element {
        var el = try this.alloc.create(Element);
        el.* = Element.init(this, el, size_fill, layout_center, null);
        return el;
    }

    pub fn float(this: *@This(), rect: geom.AABB) !*Element {
        var el = try this.alloc.create(Element);
        el.* = Element.init(this, el, size_static, layout_relative, null);
        el.size = rect;
        return el;
    }

    pub fn panel(this: *@This(), style: u16) !*Element {
        const el = try this.alloc.create(Panel);
        el.* = Panel{
            .element = Element.init(this, el, size_fill, layout_relative, Panel.renderFn),
            .style = style,
        };
        return &el.element;
    }

    pub fn label(this: *@This(), style: u16, txt: []const u8) !*Element {
        const el = try this.alloc.create(Label);
        el.* = Label{
            .element = Element.init(this, el, Label.sizeFn, layout_relative, Label.renderFn),
            .style = style,
            .string = txt,
        };
        return &el.element;
    }

    pub fn sprite(this: *@This(), blit: Blit) !*Element {
        const el = try this.alloc.create(Sprite);
        el.* = Sprite{
            .element = Element.init(this, el, Sprite.sizeFn, layout_relative, Sprite.renderFn),
            .blit = blit,
        };
        el.element.size.size = el.blit.get_size();
        return &el.element;
    }

    pub fn button(this: *@This(), string: []const u8) !*Element {
        const new_btn = try this.alloc.create(Button);
        const new_panel = try this.panel(this.style.button.default.panel);
        const centerel = try this.center();
        const new_label = try this.label(this.style.button.default.label, string);
        centerel.appendChild(new_label);
        new_panel.appendChild(centerel);
        new_btn.* = Button{
            .element = Element.init(this, new_btn, size_fill, layout_relative, null),
            .label = @ptrCast(*Label, @alignCast(@alignOf(Label), new_label.self)),
            .panel = @ptrCast(*Panel, @alignCast(@alignOf(Panel), new_panel.self)),
        };
        new_btn.element.appendChild(new_panel);
        this.listen(&new_btn.element, .MouseClicked, Button.eventFn);
        this.listen(&new_btn.element, .MousePressed, Button.eventFn);
        this.listen(&new_btn.element, .MouseReleased, Button.eventFn);
        this.listen(&new_btn.element, .MouseEnter, Button.eventFn);
        this.listen(&new_btn.element, .MouseLeave, Button.eventFn);
        return &new_btn.element;
    }
};

pub const Panel = struct {
    element: Element,
    style: u16,

    fn renderFn(el: Element) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        const rect = this.element.size;
        w4.DRAW_COLORS.* = this.style;
        w4.rect(rect.pos[v.x], rect.pos[v.y], @intCast(u32, rect.size[v.x]), @intCast(u32, rect.size[v.y]));
    }
};

pub const Sprite = struct {
    element: Element,
    blit: Blit,

    fn sizeFn(el: *Element, bounds: geom.AABB) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        return geom.AABB.initv(bounds.pos, this.blit.get_size());
    }

    fn renderFn(el: Element) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        this.blit.blit(this.element.size.pos);
    }
};

pub const Label = struct {
    element: Element,
    style: u16,
    string: []const u8,

    fn sizeFn(el: *Element, bounds: geom.AABB) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        return geom.AABB.initv(bounds.pos, text.text_size(this.string));
    }

    fn renderFn(el: Element) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        w4.DRAW_COLORS.* = this.style;
        draw.text(this.string, this.element.size.pos);
    }
};

pub const Button = struct {
    element: Element,
    label: *Label,
    panel: *Panel,

    fn eventFn(el: *Element, event: EventData) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        switch (event) {
            .MousePressed => |_| {
                this.label.style = this.element.ctx.style.button.click.label;
                this.panel.style = this.element.ctx.style.button.click.panel;
            },
            .MouseEnter,
            .MouseReleased,
            => {
                this.label.style = this.element.ctx.style.button.hover.label;
                this.panel.style = this.element.ctx.style.button.hover.panel;
            },
            .MouseLeave => {
                this.label.style = this.element.ctx.style.button.default.label;
                this.panel.style = this.element.ctx.style.button.default.panel;
            },
            else => {},
        }
    }
};
