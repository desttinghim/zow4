const std = @import("std");
const w4 = @import("wasm4");
const geom = @import("geometry.zig");
const draw = @import("draw.zig");
const v = geom.Vec;

const Blit = draw.Blit;
const BlitFlags = draw.BlitFlags;

const ElementIface = struct {
    self: *anyopaque,
    renderImpl: fn (*anyopaque, geom.Vec2) geom.Vec2,
    deleteImpl: fn (*anyopaque) void,
    prev: ?*@This() = null,
    next: ?*@This() = null,
    parent: ?*@This() = null,
    child: ?*@This() = null,

    pub fn remove(this: *@This()) void {
        if (this.child) |child| child.remove();
        if (this.prev) |prev| prev.next = this.next;
        this.deleteImpl();
    }

    pub fn appendChild(this: *@This(), el: *@This()) void {
        el.parent = this;
        if (this.child) |child| {
            child.append(el);
        } else {
            this.child = el;
        }
    }

    pub fn append(this: *@This(), el: *@This()) void {
        if (this.next) |next| {
            next.append(el);
        } else {
            this.next = el;
            el.prev = this;
        }
    }

    pub fn render(this: @This(), offset: geom.Vec2) void {
        const pos = this.renderImpl(this.self, offset);
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

    pub fn new(alloc: std.mem.Allocator) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = .{ .self = this, .deleteImpl = deleteImpl, .renderImpl = renderImpl },
        };
        return this;
    }

    pub fn deleteImpl(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        this.alloc.destroy(this);
    }

    pub fn renderImpl(_: *anyopaque, _: geom.Vec2) geom.Vec2 {
        return geom.Vec2{ 0, 0 };
    }
};

pub const Panel = struct {
    alloc: std.mem.Allocator,
    element: ElementIface,
    style: u16,
    rect: geom.AABB,

    pub fn new(alloc: std.mem.Allocator, style: u16, rect: geom.AABB) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = .{ .self = this, .renderImpl = renderImpl, .deleteImpl = deleteImpl },
            .style = style,
            .rect = rect,
        };
        return this;
    }

    pub fn deleteImpl(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        this.alloc.destroy(this);
    }

    fn renderImpl(ptr: *anyopaque, offset: geom.Vec2) geom.Vec2 {
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

    pub fn new(alloc: std.mem.Allocator, style: u16, bmp: *const Blit, pos: geom.Vec2, rect: ?geom.AABB) !*@This() {
        const this = try alloc.create(@This());
        this.* = @This(){
            .alloc = alloc,
            .element = .{ .self = this, .renderImpl = renderImpl, .deleteImpl = deleteImpl },
            .bmp = bmp,
            .pos = pos,
            .rect = if (rect) |r| .{ .aabb = r } else .full,
            .flags = .{ .bpp = .b1 },
            .style = style,
        };
        return this;
    }

    pub fn deleteImpl(ptr: *anyopaque) void {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        this.alloc.destroy(this);
    }

    fn renderImpl(ptr: *anyopaque, offset: geom.Vec2) geom.Vec2 {
        const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), ptr));
        w4.DRAW_COLORS.* = this.style;
        switch (this.rect) {
            .full => this.bmp.blit(this.pos + offset, this.flags),
            .aabb => |aabb| this.bmp.blitSub(this.pos + offset, aabb, this.flags),
        }
        return this.pos + offset;
    }
};

// pub const Node = struct {
//     T: union(enum) {
//         none,
//         panel,
//         sprite: struct {
//             data: *Blit,
//             src: ?geom.Vec2,
//             flags: BlitFlags,
//         },
//     },
//     pos: geom.Vec2,
//     size: geom.Vec2,
//     style: u16,
//     next: ?*Element = null,
//     child: ?*Element = null,

//     pub fn stage() @This() {
//         return @This(){
//             .T = .none,
//             .pos = geom.Vec2{ 0, 0 },
//             .size = geom.Vec2{ 160, 160 },
//             .style = draw.color.select(.Transparent, .Transparent),
//         };
//     }

//     pub fn panel(style: u16, rect: geom.AABB) @This() {
//         return @This(){
//             .T = .panel,
//             .pos = rect.pos,
//             .size = rect.size,
//             .style = style,
//         };
//     }

//     pub fn sprite(style: u16, rect: geom.AABB, blit: *Blit, src: ?geom.Vec2) @This() {
//         return @This(){
//             .pos = rect.pos,
//             .size = rect.size,
//             .style = style,
//             .T = .{
//                 .sprite = .{
//                     .data = blit,
//                     .src = src,
//                     .flags = .{ .bpp = .b1 },
//                 },
//             },
//         };
//     }

//     pub fn appendChild(this: *@This(), el: *@This()) void {
//         this.child = el;
//     }

//     pub fn append(this: *@This(), el: *@This()) void {
//         this.next = el;
//     }

//     pub fn render(this: @This(), offset: ?geom.Vec2) void {
//         const pos = (offset orelse geom.Vec2{ 0, 0 }) + this.pos;
//         w4.DRAW_COLORS.* = this.style;
//         switch (this.T) {
//             .none => {},
//             .panel => w4.rect(pos[v.x], pos[v.y], @intCast(u32, this.size[v.x]), @intCast(u32, this.size[v.y])),
//             .sprite => |sprite| {
//                 const blit = sprite.data;
//                 blit.blit(pos, sprite.flags);
//             },
//         }
//         if (this.child) |child| child.render(pos);
//         if (this.next) |next| next.render(offset);
//     }
// };
