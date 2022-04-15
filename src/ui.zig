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

fn button_callback(ptr: *anyopaque, event: Event) void {
    const this = @ptrCast(*Panel, @alignCast(@alignOf(Panel), ptr));
    switch (event) {
        .MousePressed => |_| {
            this.style = draw.color.select(.Dark, .Dark);
        },
        .MouseEnter,
        .MouseReleased,
        => {
            this.style = draw.color.select(.Midtone1, .Dark);
        },
        .MouseLeave => {
            this.style = draw.color.select(.Light, .Dark);
        },
        else => {},
    }
}

pub fn button(alloc: std.mem.Allocator, string: []const u8) !*Element {
    var btn = try Panel.new(alloc, draw.color.select(.Light, .Dark));
    btn.element.listen(button_callback);

    var center = try Center.new(alloc);
    btn.element.appendChild(&center.element);

    var btn_label = try Label.new(alloc, draw.color.fill(.Dark), string);
    center.element.appendChild(&btn_label.element);

    return &btn.element;
}

pub const Element = struct {
    self: *anyopaque,
    hidden: bool = false,
    hover: bool = false,
    /// Space that the element is allowed to take up
    bounds: geom.AABB,
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
    renderFn: RenderFn,
    deleteFn: DeleteFn,

    /// Passed self, bounding box, and returns a size
    const SizeFn = fn (*anyopaque) geom.AABB;
    /// Passed self number of children, and child number, returns bounds to be passed to size
    const LayoutFn = fn (*anyopaque, usize) geom.AABB;
    /// Event
    const EventCB = fn (*anyopaque, Event) void;
    /// Draws element to the screen
    const RenderFn = fn (*anyopaque) void;
    /// Frees element from memory
    const DeleteFn = fn (*anyopaque) void;

    pub fn init(self: *anyopaque, sizeFn: SizeFn, layoutFn: LayoutFn, renderFn: RenderFn, deleteFn: DeleteFn) @This() {
        return @This(){
            .self = self,
            .bounds = geom.AABB.init(0, 0, 160, 160),
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
            cb(this.self, ev);
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

    pub fn compute_size(this: *@This()) void {
        this.size = this.sizeFn(this.self);
    }

    pub fn layout(this: *@This()) void {
        var child_opt = this.child;
        var i: usize = 0;
        while (child_opt) |child| : (i += 1) {
            child.bounds = this.layoutFn(this.self, i);
            child.compute_size();
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
        if (this.child) |child| {
            child.append(el);
        } else {
            this.child = el;
            el.parent = this;
            this.children += 1;
        }
    }

    pub fn append(this: *@This(), el: *@This()) void {
        if (this.next) |next| {
            next.append(el);
        } else {
            this.next = el;
            el.prev = this;
            el.parent = this.parent;
            el.parent.?.children += 1;
        }
    }

    pub fn render(this: @This()) void {
        if (!this.hidden) {
            this.renderFn(this.self);
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
        this.element.compute_size();
        this.element.layout();
    }

    pub fn new(alloc: std.mem.Allocator) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = Element.init(this, sizeFn, layoutFn, renderFn, deleteFn),
        };
        return this;
    }

    /// Draws all children with no offset or constraints
    fn layoutFn(_: *anyopaque, _: usize) geom.AABB {
        return geom.AABB.init(0, 0, 160, 160);
    }

    fn sizeFn(_: *anyopaque) geom.AABB {
        return geom.AABB.init(0, 0, 160, 160);
    }

    fn deleteFn(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        this.alloc.destroy(this);
    }

    fn renderFn(_: *anyopaque) void {}
};

pub const VList = struct {
    alloc: std.mem.Allocator,
    element: Element,

    pub fn new(alloc: std.mem.Allocator) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = Element.init(this, sizeFn, layoutFn, renderFn, deleteFn),
        };
        return this;
    }

    fn layoutFn(ptr: *anyopaque, childID: usize) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        const vsize = @divTrunc(this.element.bounds.size[v.y], @intCast(i32, this.element.children));
        return geom.AABB.initv(
            this.element.bounds.pos + geom.Vec2{ 0, @intCast(i32, childID) * vsize },
            geom.Vec2{ this.element.bounds.size[v.x], vsize },
        );
    }

    fn sizeFn(ptr: *anyopaque) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        return this.element.bounds;
    }

    fn deleteFn(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        this.alloc.destroy(this);
    }

    fn renderFn(_: *anyopaque) void {}
};

pub const HList = struct {
    alloc: std.mem.Allocator,
    element: Element,

    pub fn new(alloc: std.mem.Allocator) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = Element.init(this, sizeFn, layoutFn, renderFn, deleteFn),
        };
        return this;
    }

    fn layoutFn(ptr: *anyopaque, childID: usize) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        const hsize = @divTrunc(this.element.bounds.size[v.x], @intCast(i32, this.element.children));
        return geom.AABB.initv(
            this.element.bounds.pos + geom.Vec2{ @intCast(i32, childID) * hsize, 0 },
            geom.Vec2{ hsize, this.element.bounds.size[v.y] },
        );
    }

    fn sizeFn(ptr: *anyopaque) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        return this.element.bounds;
    }

    fn deleteFn(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        this.alloc.destroy(this);
    }

    fn renderFn(_: *anyopaque) void {}
};

pub const Float = struct {
    alloc: std.mem.Allocator,
    element: Element,

    pub fn new(alloc: std.mem.Allocator, rect: geom.AABB) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = Element.init(this, sizeFn, layoutFn, renderFn, deleteFn),
        };
        this.element.size = rect;
        return this;
    }

    fn layoutFn(ptr: *anyopaque, _: usize) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        return this.element.size;
    }

    fn sizeFn(ptr: *anyopaque) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        return this.element.size;
    }

    fn deleteFn(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        this.alloc.destroy(this);
    }

    fn renderFn(_: *anyopaque) void {}
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
            .element = Element.init(this, sizeFn, layoutFn, renderFn, deleteFn),
            .anchor = anchor,
        };
        return this;
    }

    fn layoutFn(ptr: *anyopaque, _: usize) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        return this.element.size;
    }

    fn sizeFn(ptr: *anyopaque) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        var pos = this.element.bounds.top_left() + this.anchor.top_left;
        var size = this.element.bounds.bottom_right() + (this.anchor.bottom_right) - pos;
        return geom.AABB{ .pos = pos, .size = size };
    }

    fn deleteFn(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        this.alloc.destroy(this);
    }

    fn renderFn(_: *anyopaque) void {}
};

pub const Center = struct {
    alloc: std.mem.Allocator,
    element: Element,

    pub fn new(alloc: std.mem.Allocator) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = Element.init(this, sizeFn, layoutFn, renderFn, deleteFn),
        };
        return this;
    }

    fn layoutFn(ptr: *anyopaque, childID: usize) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        const center = this.element.bounds.pos + @divTrunc(this.element.bounds.size, geom.Vec2{ 2, 2 });
        var centeraabb = geom.AABB.initv(center, geom.Vec2{ 0, 0 });
        if (this.element.getChild(childID)) |child| {
            centeraabb.pos -= @divTrunc(child.size.size, geom.Vec2{ 2, 2 });
            centeraabb.size = child.size.size;
        }
        return centeraabb;
    }

    fn sizeFn(ptr: *anyopaque) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        return this.element.bounds;
    }

    fn deleteFn(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        this.alloc.destroy(this);
    }

    fn renderFn(_: *anyopaque) void {}
};

pub const Panel = struct {
    alloc: std.mem.Allocator,
    element: Element,
    style: u16,

    pub fn new(alloc: std.mem.Allocator, style: u16) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = Element.init(this, sizeFn, layoutFn, renderFn, deleteFn),
            .style = style,
        };
        return this;
    }

    /// Items positioned relative to self
    fn layoutFn(ptr: *anyopaque, _: usize) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        return this.element.size;
    }

    fn sizeFn(ptr: *anyopaque) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        return this.element.bounds;
    }

    fn deleteFn(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        this.alloc.destroy(this);
    }

    fn renderFn(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
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
            .element = Element.init(this, sizeFn, layoutFn, renderFn, deleteFn),
            .blit = blit,
        };
        this.element.size.size = this.blit.get_size();
        return this;
    }

    /// WARNING: Not safe if this is part of a displaylist
    pub fn deinit(this: *@This()) void {
        this.alloc.destroy(this);
    }

    fn deleteFn(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        this.deinit();
    }

    fn layoutFn(ptr: *anyopaque, child: usize) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        _ = child;
        return this.element.size;
    }

    fn sizeFn(ptr: *anyopaque) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        const bounds = this.element.bounds;
        return geom.AABB.initv(bounds.pos, this.blit.get_size());
    }

    fn renderFn(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
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
            .element = Element.init(this, sizeFn, layoutFn, renderFn, deleteFn),
            .style = style,
            .string = txt,
        };
        return this;
    }

    /// WARNING: Not safe if this is part of a displaylist
    pub fn deinit(this: *@This()) void {
        this.alloc.destroy(this);
    }

    fn deleteFn(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        this.deinit();
    }

    fn layoutFn(ptr: *anyopaque, _: usize) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        return this.element.size;
    }

    fn sizeFn(ptr: *anyopaque) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        return geom.AABB.initv(this.element.bounds.pos, text.text_size(this.string));
    }

    fn renderFn(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        w4.DRAW_COLORS.* = this.style;
        draw.text(this.string, this.element.size.pos);
    }
};
