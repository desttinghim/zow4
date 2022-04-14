const std = @import("std");
const w4 = @import("wasm4");
const geom = @import("geometry.zig");
const draw = @import("draw.zig");
const v = geom.Vec;

const Blit = draw.Blit;
const BlitFlags = draw.BlitFlags;

pub const Element = struct {
    T: union(enum) {
        none,
        panel,
        sprite: struct {
            data: *Blit,
            src: ?geom.Vec2,
            flags: BlitFlags,
        },
    },
    pos: geom.Vec2,
    size: geom.Vec2,
    style: u16,
    next: ?*Element = null,
    child: ?*Element = null,

    pub fn stage() @This() {
        return @This(){
            .T = .none,
            .pos = geom.Vec2{ 0, 0 },
            .size = geom.Vec2{ 160, 160 },
            .style = draw.color.select(.Transparent, .Transparent),
        };
    }

    pub fn panel(style: u16, rect: geom.AABB) @This() {
        return @This(){
            .T = .panel,
            .pos = rect.pos,
            .size = rect.size,
            .style = style,
        };
    }

    pub fn sprite(style: u16, rect: geom.AABB, blit: *Blit, src: ?geom.Vec2) @This() {
        return @This(){
            .pos = rect.pos,
            .size = rect.size,
            .style = style,
            .T = .{
                .sprite = .{
                    .data = blit,
                    .src = src,
                    .flags = .{ .bpp = .b1 },
                },
            },
        };
    }

    pub fn appendChild(this: *@This(), el: *@This()) void {
        this.child = el;
    }

    pub fn append(this: *@This(), el: *@This()) void {
        this.next = el;
    }

    pub fn render(this: @This(), offset: ?geom.Vec2) void {
        const pos = (offset orelse geom.Vec2{ 0, 0 }) + this.pos;
        w4.DRAW_COLORS.* = this.style;
        switch (this.T) {
            .none => {},
            .panel => w4.rect(pos[v.x], pos[v.y], @intCast(u32, this.size[v.x]), @intCast(u32, this.size[v.y])),
            .sprite => |sprite| {
                const blit = sprite.data;
                blit.blit(pos, sprite.flags);
            },
        }
        if (this.child) |child| child.render(pos);
        if (this.next) |next| next.render(offset);
    }
};

// pub const DisplayList = struct {
//     count: usize = 0,
//     elements: std.AutoHashMap(usize, Element),
//     // alloc: std.mem.Allocator,

//     pub fn init(alloc: std.mem.Allocator) @This() {
//         var this = @This(){
//             .count = 0,
//             .elements = std.AutoHashMap(usize, Element).init(alloc),
//             // .alloc= alloc,
//         };
//         return this;
//     }

//     pub fn deinit(this: @This()) void {
//         this.elements.deinit();
//     }

//     pub fn panel(this: *@This(), style: u16, rect: geom.AABB) !ElementHandle {
//         const new_panel = Element.panel(style, rect);
//         try this.add(new_panel);
//     }

//     pub fn sprite(this: *@This(), style: u16, rect: geom.AABB, blit: *Blit, src: ?geom.Vec2) !ElementHandle {
//         const new_sprite = Element.sprite(style, rect, blit, src);
//         try this.add(new_sprite);
//     }

//     pub fn add(this: *@This(), el: Element) !usize {
//         const id = this.count;
//         try this.elements.put(id, el);
//         this.count += 1;
//         return id;
//     }

//     pub fn addChild(this: *@This(), el: ElementHandle, new: Element) ElementHandle {}

//     // pub fn addChild(this: *@This(), id: usize, el: Element) usize {
//     //     this.elements.append(el);
//     // }

//     pub fn render(this: *@This()) void {
//         for (this.elements.items) |el| {
//             w4.DRAW_COLORS.* = el.style;
//             switch (el.T) {
//                 .none => {},
//                 .panel => w4.rect(el.pos[v.x], el.pos[v.y], @intCast(u32, el.size[v.x]), @intCast(u32, el.size[v.y])),
//                 .sprite => |sprite| {
//                     const blit = sprite.data;
//                     blit.blit(el.pos, sprite.flags);
//                 },
//             }
//         }
//     }
// };
