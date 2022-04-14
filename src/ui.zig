const std = @import("std");
const w4 = @import("wasm4");
const geom = @import("geometry.zig");
const draw = @import("draw.zig");
const v = geom.Vec;

const Blit = draw.Blit;
const BlitFlags = draw.BlitFlags;

const ElementIface = struct {
    self: *anyopaque,
    bounds: geom.AABB,
    size: geom.AABB,
    children: usize = 0,
    prev: ?*@This() = null,
    next: ?*@This() = null,
    parent: ?*@This() = null,
    child: ?*@This() = null,
    // Function Pointers
    sizeFn: SizeFn,
    layoutFn: LayoutFn,
    renderFn: RenderFn,
    deleteFn: DeleteFn,

    /// Passed self, bounding box, and returns a size
    const SizeFn = fn (*anyopaque, geom.AABB) geom.AABB;
    /// Passed self number of children, and child number, returns bounds to be passed to size
    const LayoutFn = fn (*anyopaque, usize) geom.AABB;
    /// Draws element to the screen
    const RenderFn = fn (*anyopaque, geom.Vec2) geom.Vec2;
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

    pub fn remove(this: *@This()) void {
        if (this.child) |child| child.remove();
        if (this.prev) |prev| prev.next = this.next;
        if (this.parent) |parent| parent.children -= 1;
        this.deleteFn();
    }

    pub fn layout(this: *@This()) void {
        var child_opt = this.child;
        var i: usize = 0;
        while (child_opt) |child| : (i += 1) {
            child.layout();
            const bounds = this.layoutFn(this.self, i);
            child.size = child.sizeFn(child.self, bounds);
            child_opt = child.next;
        }
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

    pub fn render(this: @This(), offset: geom.Vec2) void {
        const pos = this.renderFn(this.self, offset);
        if (this.child) |child| child.render(pos);
        if (this.next) |next| next.render(offset);
    }
};

pub const Stage = struct {
    alloc: std.mem.Allocator,
    element: ElementIface,

    pub fn render(this: @This()) void {
        this.element.render(geom.Vec2{ 0, 0 });
    }

    pub fn layout(this: *@This()) void {
        this.element.layout();
    }

    pub fn new(alloc: std.mem.Allocator) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = ElementIface.init(this, sizeFn, layoutFn, renderFn, deleteFn),
        };
        return this;
    }

    /// Draws all children with no offset or constraints
    fn layoutFn(_: *anyopaque, _: usize) geom.AABB {
        return geom.AABB.init(0, 0, 160, 160);
    }

    fn sizeFn(_: *anyopaque, _: geom.AABB) geom.AABB {
        return geom.AABB.init(0, 0, 160, 160);
    }

    fn deleteFn(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        this.alloc.destroy(this);
    }

    fn renderFn(_: *anyopaque, _: geom.Vec2) geom.Vec2 {
        return geom.Vec2{ 0, 0 };
    }
};

pub const Anchors = struct {
    top_left: geom.Vec2,
    bottom_right: geom.Vec2,

    pub fn init(left: i32, top: i32, right: i32, bottom: i32) @This() {
        return @This(){
            .top_left = geom.Vec2{ left, top },
            .bottom_right = geom.Vec2{ right, bottom },
        };
    }
};

pub const Center = struct {
    alloc: std.mem.Allocator,
    element: ElementIface,

    pub fn new(alloc: std.mem.Allocator) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = ElementIface.init(this, sizeFn, layoutFn, renderFn, deleteFn),
        };
        return this;
    }

    fn layoutFn(ptr: *anyopaque, _: usize) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        return this.element.bounds;
    }

    fn sizeFn(_: *anyopaque, bounds: geom.AABB) geom.AABB {
        return bounds;
    }

    fn deleteFn(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        this.alloc.destroy(this);
    }

    fn renderFn(ptr: *anyopaque, _: geom.Vec2) geom.Vec2 {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        var center = @divTrunc(this.element.size.size, geom.Vec2{ 2, 2 });
        if (this.element.getChild(0)) |child| {
            center -= @divTrunc(child.size.size, geom.Vec2{ 2, 2 });
        }
        return center;
    }
};

pub const Panel = struct {
    alloc: std.mem.Allocator,
    element: ElementIface,
    style: u16,
    anchors: Anchors,
    rect: geom.AABB,

    pub fn new(alloc: std.mem.Allocator, style: u16, anchors: Anchors) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = ElementIface.init(this, sizeFn, layoutFn, renderFn, deleteFn),
            .style = style,
            .anchors = anchors,
            .rect = geom.AABB.init(0, 0, 160, 160),
        };
        return this;
    }

    /// Items positioned relative to self
    fn layoutFn(ptr: *anyopaque, _: usize) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        return this.rect;
    }

    fn sizeFn(ptr: *anyopaque, bounds: geom.AABB) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        var aabb = geom.AABB.init(0, 0, 160, 160);
        aabb.pos = bounds.top_left() + this.anchors.top_left;
        aabb.size = bounds.bottom_right() - this.anchors.bottom_right - this.anchors.top_left;
        this.rect = aabb;
        return bounds;
    }

    fn deleteFn(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        this.alloc.destroy(this);
    }

    fn renderFn(ptr: *anyopaque, offset: geom.Vec2) geom.Vec2 {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        const pos = this.rect.pos + offset;
        w4.DRAW_COLORS.* = this.style;
        w4.rect(pos[v.x], pos[v.y], @intCast(u32, this.rect.size[v.x]), @intCast(u32, this.rect.size[v.y]));
        return pos;
    }
};

pub const Sprite = struct {
    alloc: std.mem.Allocator,
    element: ElementIface,
    bmp: *const Blit,
    pos: geom.Vec2,
    rect: union(enum) { full, aabb: geom.AABB },
    flags: BlitFlags,
    style: u16,

    pub fn new(alloc: std.mem.Allocator, style: u16, bmp: *const Blit, src: ?geom.AABB) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = ElementIface.init(this, sizeFn, layoutFn, renderFn, deleteFn),
            .bmp = bmp,
            .pos = geom.Vec2{ 0, 0 },
            .rect = if (src) |r| .{ .aabb = r } else .full,
            .flags = .{ .bpp = .b1 },
            .style = style,
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

    fn layoutFn(ptr: *anyopaque, child: usize) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        _ = child;
        return this.element.bounds;
    }

    fn sizeFn(ptr: *anyopaque, bounds: geom.AABB) geom.AABB {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        return switch (this.rect) {
            .full => geom.AABB.init(bounds.pos[v.x], bounds.pos[v.y], this.bmp.width, this.bmp.height),
            .aabb => |aabb| geom.AABB.init(bounds.pos[v.x], bounds.pos[v.y], aabb.size[v.x], aabb.size[v.y]),
        };
    }

    fn renderFn(ptr: *anyopaque, offset: geom.Vec2) geom.Vec2 {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        w4.DRAW_COLORS.* = this.style;
        switch (this.rect) {
            .full => this.bmp.blit(this.pos + offset, this.flags),
            .aabb => |aabb| this.bmp.blitSub(this.pos + offset, aabb, this.flags),
        }
        return this.pos + offset;
    }
};
