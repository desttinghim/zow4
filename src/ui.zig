const std = @import("std");
const w4 = @import("wasm4");
const geom = @import("geometry.zig");
const draw = @import("draw.zig");
const text = @import("text.zig");
const Input = @import("input.zig");
const v = geom.Vec;

const Blit = draw.Blit;
const BlitFlags = draw.BlitFlags;

pub const Event = union(enum) {
    MousePressed: geom.Vec2,
    MouseReleased: geom.Vec2,
    MouseMoved: geom.Vec2,
    MouseClicked: geom.Vec2,
    MouseEnter,
    MouseLeave,
};

pub fn center(alloc: std.mem.Allocator, el: *Element) !*Element {
    var centerEl = try Center.new(alloc);
    centerEl.element.appendChild(el);
    return &centerEl.element;
}

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

// pub const Node = struct {};

// pub const Leaf = struct {
//     hidden: bool = false,
//     hover: bool = false,
//     self: *anyopaque,
//     size: geom.AABB,
//     next: ?*@This() = null,

//     sizeFn: SizeFn,
//     deleteFn: DeleteFn,
//     eventFn: ?EventCB,
//     renderFn: ?RenderFn,
// };

pub const Element = struct {
    hidden: bool = false,
    hover: bool = false,
    self: *anyopaque,
    /// Space that the element takes up
    size: geom.AABB,
    children: usize = 0,
    prev: ?*@This() = null,
    next: ?*@This() = null,
    parent: ?*@This() = null,
    child: ?*@This() = null,
    // Function Pointers
    sizeFn: SizeFn,
    eventFn: ?EventCB = null,
    layoutFn: LayoutFn,
    renderFn: ?RenderFn,
    deleteFn: DeleteFn,

    /// Passed self, bounding box, and returns a size
    const SizeFn = fn (*Element, geom.AABB) geom.AABB;
    /// Passed self number of children, and child number, returns bounds to be passed to size
    const LayoutFn = fn (*Element, usize) geom.AABB;
    /// Event
    const EventCB = fn (*Element, Event) void;
    /// Draws element to the screen
    const RenderFn = fn (Element) void;
    /// Frees element from memory
    const DeleteFn = fn (*Element) void;

    pub fn init(self: *anyopaque, sizeFn: SizeFn, layoutFn: LayoutFn, renderFn: ?RenderFn, deleteFn: DeleteFn) @This() {
        return @This(){
            .self = self,
            // .bounds = geom.AABB.init(0, 0, 160, 160),
            .size = geom.AABB.init(0, 0, 160, 160),
            .sizeFn = sizeFn,
            .layoutFn = layoutFn,
            .renderFn = renderFn,
            .deleteFn = deleteFn,
        };
    }

    pub fn listen(this: *@This(), cb: EventCB) void {
        this.eventFn = cb;
    }

    fn update(this: *@This()) void {
        if (this.size.contains(Input.mousepos())) {
            if (!this.hover) {
                this.hover = true;
                this.event(.MouseEnter);
            }
        } else {
            this.event(.MouseLeave);
            this.hover = false;
        }
        if (this.child) |child| child.update();
        if (this.next) |next| next.update();
    }

    fn event(this: *@This(), ev: Event) void {
        if (this.eventFn) |cb| {
            cb(this, ev);
        }
    }

    fn bubble(this: *@This(), ev: Event) void {
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
        this.event(ev);
    }

    pub fn remove(this: *@This()) void {
        if (this.child) |child| child.remove();
        if (this.prev) |prev| prev.next = this.next;
        if (this.parent) |parent| parent.children -= 1;
        this.deleteFn();
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

pub const Stage = struct {
    alloc: std.mem.Allocator,
    element: Element,

    pub fn update(this: *@This()) void {
        this.element.update();

        const mousepos = Input.mousepos();
        if (Input.mousep(.left)) {
            this.element.bubble(.{ .MousePressed = mousepos });
        }
        if (Input.mouser(.left)) {
            this.element.bubble(.{ .MouseReleased = mousepos });
        }
        if (geom.Vec.isZero(Input.mousediff())) {
            this.element.bubble(.{ .MouseMoved = mousepos });
        }
        if (Input.clickstate == .clicked) {
            this.element.bubble(.{ .MouseClicked = mousepos });
        }
    }

    pub fn render(this: @This()) void {
        this.element.render();
    }

    pub fn layout(this: *@This()) void {
        this.element.compute_size(geom.AABB.init(0, 0, 160, 160));
        this.element.layout();
    }

    pub fn new(alloc: std.mem.Allocator) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = Element.init(this, size_static, layoutFn, null, deleteFn),
        };
        return this;
    }

    /// Draws all children with no offset or constraints
    fn layoutFn(_: *Element, _: usize) geom.AABB {
        return geom.AABB.init(0, 0, 160, 160);
    }

    fn deleteFn(el: *Element) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        this.alloc.destroy(this);
    }
};

pub const VList = struct {
    alloc: std.mem.Allocator,
    element: Element,

    pub fn new(alloc: std.mem.Allocator) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = Element.init(this, size_fill, layoutFn, null, deleteFn),
        };
        return this;
    }

    fn layoutFn(el: *Element, childID: usize) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        const vsize = @divTrunc(this.element.size.size[v.y], @intCast(i32, this.element.children));
        return geom.AABB.initv(
            this.element.size.pos + geom.Vec2{ 0, @intCast(i32, childID) * vsize },
            geom.Vec2{ this.element.size.size[v.x], vsize },
        );
    }

    fn deleteFn(el: *Element) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        this.alloc.destroy(this);
    }
};

pub const HList = struct {
    alloc: std.mem.Allocator,
    element: Element,

    pub fn new(alloc: std.mem.Allocator) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = Element.init(this, size_fill, layoutFn, null, deleteFn),
        };
        return this;
    }

    fn layoutFn(el: *Element, childID: usize) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        const hsize = @divTrunc(this.element.size.size[v.x], @intCast(i32, this.element.children));
        return geom.AABB.initv(
            this.element.size.pos + geom.Vec2{ @intCast(i32, childID) * hsize, 0 },
            geom.Vec2{ hsize, this.element.size.size[v.y] },
        );
    }

    fn deleteFn(el: *Element) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        this.alloc.destroy(this);
    }
};

pub const Float = struct {
    alloc: std.mem.Allocator,
    element: Element,

    pub fn new(alloc: std.mem.Allocator, rect: geom.AABB) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = Element.init(this, size_static, layout_relative, null, deleteFn),
        };
        this.element.size = rect;
        return this;
    }

    fn deleteFn(el: *Element) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        this.alloc.destroy(this);
    }
};

pub const Anchor = struct {
    top_left: geom.Vec2,
    bottom_right: geom.Vec2,

    pub fn init(left: i32, top: i32, right: i32, bottom: i32) @This() {
        return @This(){
            .top_left = geom.Vec2{ left, top },
            .bottom_right = geom.Vec2{ right, bottom },
        };
    }
};

pub const AnchorElement = struct {
    alloc: std.mem.Allocator,
    element: Element,
    anchor: Anchor,

    pub fn new(alloc: std.mem.Allocator, anchor: Anchor) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = Element.init(this, sizeFn, layout_relative, null, deleteFn),
            .anchor = anchor,
        };
        return this;
    }

    fn sizeFn(el: *Element) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        var pos = this.element.bounds.top_left() + this.anchor.top_left;
        var size = this.element.bounds.bottom_right() + (this.anchor.bottom_right) - pos;
        return geom.AABB{ .pos = pos, .size = size };
    }

    fn deleteFn(el: *Element) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        this.alloc.destroy(this);
    }
};

pub const Center = struct {
    alloc: std.mem.Allocator,
    element: Element,

    pub fn new(alloc: std.mem.Allocator) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = Element.init(this, size_fill, layoutFn, null, deleteFn),
        };
        return this;
    }

    fn layoutFn(el: *Element, childID: usize) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        const centerv = this.element.size.pos + @divTrunc(this.element.size.size, geom.Vec2{ 2, 2 });
        var centeraabb = geom.AABB.initv(centerv, geom.Vec2{ 0, 0 });
        if (this.element.getChild(childID)) |child| {
            centeraabb.pos -= @divTrunc(child.size.size, geom.Vec2{ 2, 2 });
            centeraabb.size = child.size.size;
        }
        return centeraabb;
    }

    fn deleteFn(el: *Element) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        this.alloc.destroy(this);
    }
};

pub const Panel = struct {
    alloc: std.mem.Allocator,
    element: Element,
    style: u16,

    pub fn new(alloc: std.mem.Allocator, style: u16) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = Element.init(this, size_fill, layout_relative, renderFn, deleteFn),
            .style = style,
        };
        return this;
    }

    fn deleteFn(el: *Element) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        this.alloc.destroy(this);
    }

    fn renderFn(el: Element) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        const rect = this.element.size;
        w4.DRAW_COLORS.* = this.style;
        w4.rect(rect.pos[v.x], rect.pos[v.y], @intCast(u32, rect.size[v.x]), @intCast(u32, rect.size[v.y]));
    }
};

pub const Sprite = struct {
    alloc: std.mem.Allocator,
    element: Element,
    blit: Blit,

    pub fn new(alloc: std.mem.Allocator, blit: Blit) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = Element.init(this, sizeFn, layout_relative, renderFn, deleteFn),
            .blit = blit,
        };
        this.element.size.size = this.blit.get_size();
        return this;
    }

    /// WARNING: Not safe if this is part of a displaylist
    pub fn deinit(this: *@This()) void {
        this.alloc.destroy(this);
    }

    fn deleteFn(el: *Element) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        this.deinit();
    }

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
    alloc: std.mem.Allocator,
    element: Element,
    style: u16,
    string: []const u8,

    pub fn new(alloc: std.mem.Allocator, style: u16, txt: []const u8) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = Element.init(this, sizeFn, layout_relative, renderFn, deleteFn),
            .style = style,
            .string = txt,
        };
        return this;
    }

    /// WARNING: Not safe if this is part of a displaylist
    pub fn deinit(this: *@This()) void {
        this.alloc.destroy(this);
    }

    fn deleteFn(el: *Element) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        this.deinit();
    }

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

pub const ButtonStyle = struct {
    label: u16,
    panel: u16,
};

pub const StyleSheet = struct {
    default: ButtonStyle,
    hover: ButtonStyle,
    click: ButtonStyle,
};

pub const DefaultStyle = StyleSheet{
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
};

pub const Button = struct {
    alloc: std.mem.Allocator,
    element: Element,
    label: *Label,
    panel: *Panel,
    stylesheet: StyleSheet,
    onclick: ?fn () void,

    pub fn new(alloc: std.mem.Allocator, style: StyleSheet, string: []const u8, onclick: ?fn () void) !*@This() {
        const this = try alloc.create(@This());
        const panel = try Panel.new(alloc, style.default.panel);
        const centerel = try Center.new(alloc);
        const label = try Label.new(alloc, style.default.label, string);
        centerel.element.appendChild(&label.element);
        panel.element.appendChild(&centerel.element);
        this.* = @This(){
            .alloc = alloc,
            .element = Element.init(this, size_fill, layout_relative, null, deleteFn),
            .label = label,
            .panel = panel,
            .stylesheet = style,
            .onclick = onclick,
        };
        this.element.appendChild(&panel.element);
        this.element.listen(eventFn);
        return this;
    }

    fn eventFn(el: *Element, event: Event) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        switch (event) {
            .MousePressed => |_| {
                this.label.style = this.stylesheet.click.label;
                this.panel.style = this.stylesheet.click.panel;
                if (this.onclick) |onclick| onclick();
            },
            .MouseEnter,
            .MouseReleased,
            => {
                this.label.style = this.stylesheet.hover.label;
                this.panel.style = this.stylesheet.hover.panel;
            },
            .MouseLeave => {
                this.label.style = this.stylesheet.default.label;
                this.panel.style = this.stylesheet.default.panel;
            },
            else => {},
        }
    }

    /// WARNING: Not safe if this is part of a displaylist
    pub fn deinit(this: *@This()) void {
        this.alloc.destroy(this);
    }

    fn deleteFn(el: *Element) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), el.self));
        this.deinit();
    }
};
