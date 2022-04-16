const std = @import("std");

pub const Vec2f = std.meta.Vector(2, f32);
pub const Vec2 = std.meta.Vector(2, i32);

pub const Vec = struct {
    pub const x = 0;
    pub const y = 1;

    pub fn equals(v1: Vec2, v2: Vec2) bool {
        return @reduce(.And, v1 == v2);
    }

    pub fn isZero(vec: Vec2) bool {
        return equals(vec, Vec2{ 0, 0 });
    }
};

const v = Vec;

pub const Dir = struct {
    pub const up = Vec2{ 0, -1 };
    pub const down = Vec2{ 0, 1 };
    pub const left = Vec2{ -1, 0 };
    pub const right = Vec2{ 1, 0 };
};

pub const DirF = struct {
    pub const up = Vec2f{ 0, -1 };
    pub const down = Vec2f{ 0, 1 };
    pub const left = Vec2f{ -1, 0 };
    pub const right = Vec2f{ 1, 0 };
};

pub fn lengthSquared(a: Vec2) i32 {
    return @reduce(.Add, a * a);
}

pub fn length(a: Vec2) i32 {
    return @floatToInt(i32, @intToFloat(f32, lengthSquared(a)));
}

pub fn dist(a: Vec2, b: Vec2) i32 {
    return length(a - b);
}

pub fn distancef(a: Vec2f, b: Vec2f) f32 {
    var subbed = @fabs(a - b);
    return lengthf(subbed);
}

pub fn lengthf(vec: Vec2f) f32 {
    var squared = vec * vec;
    return @sqrt(@reduce(.Add, squared));
}

pub fn normalizef(vec: Vec2f) Vec2f {
    return vec / @splat(2, lengthf(vec));
}

pub fn vec2ToVec2f(vec2: Vec2) Vec2f {
    return Vec2f{ @intToFloat(f32, vec2[0]), @intToFloat(f32, vec2[1]) };
}

pub fn vec2fToVec2(vec2f: Vec2f) Vec2 {
    return Vec2{ @floatToInt(i32, @floor(vec2f[0])), @floatToInt(i32, @floor(vec2f[1])) };
}

pub const Rect = struct {
    top: i32,
    left: i32,
    right: i32,
    bottom: i32,

    pub fn init_sizev(posi: Vec2, sizei: Vec2) @This() {
        return @This(){
            .left = posi[v.x],
            .right = posi[v.x] + sizei[v.x],
            .top = posi[v.y],
            .bottom = posi[v.y] + sizei[v.y],
        };
    }

    pub fn empty() @This() {
        return @This(){
            .top = 0,
            .left = 0,
            .right = 0,
            .bottom = 0,
        };
    }

    pub fn pos(this: @This()) Vec2 {
        return Vec2{ this.left, this.top };
    }

    pub fn size(this: @This()) Vec2 {
        return Vec2{ this.right - this.left, this.bottom - this.top };
    }
};

pub const AABB = struct {
    pos: Vec2,
    size: Vec2,

    pub fn top(this: @This()) i32 {
        return this.pos[v.y];
    }
    pub fn left(this: @This()) i32 {
        return this.pos[v.x];
    }
    pub fn top_left(this: @This()) Vec2 {
        return this.pos;
    }
    pub fn right(this: @This()) i32 {
        return this.pos[v.x] + this.size[v.x];
    }
    pub fn bottom(this: @This()) i32 {
        return this.pos[v.y] + this.size[v.y];
    }
    pub fn bottom_right(this: @This()) Vec2 {
        return this.pos + this.size;
    }
    // pub fn rect(this: @This()) Rect {
    //     return .{
    //         .
    //     }
    // }

    pub fn init(x: i32, y: i32, w: i32, h: i32) @This() {
        return @This(){
            .pos = Vec2{ x, y },
            .size = Vec2{ w, h },
        };
    }

    pub fn initv(topleft: Vec2, size: Vec2) @This() {
        return @This(){
            .pos = topleft,
            .size = size,
        };
    }

    pub fn addv(this: @This(), vec2: Vec2) @This() {
        return @This(){ .pos = this.pos + vec2, .size = this.size };
    }

    pub fn contains(this: @This(), vec: Vec2) bool {
        const tl = this.top_left();
        const br = this.bottom_right();
        return tl[v.x] < vec[v.x] and br[v.x] > vec[v.x] and
            tl[v.y] < vec[v.y] and br[v.y] > vec[v.y];
    }

    pub fn overlaps(a: @This(), b: @This()) bool {
        return a.pos[0] < b.pos[0] + b.size[0] and
            a.pos[0] + a.size[0] > b.pos[0] and
            a.pos[1] < b.pos[1] + b.size[1] and
            a.pos[1] + a.size[1] > b.pos[1];
    }
};

pub const AABBf = struct {
    pos: Vec2f,
    size: Vec2f,

    pub fn init(x: f32, y: f32, w: f32, h: f32) @This() {
        return @This(){
            .pos = Vec2{ x, y },
            .size = Vec2{ w, h },
        };
    }

    pub fn addv(this: @This(), vec2f: Vec2f) @This() {
        return @This(){ .pos = this.pos + vec2f, .size = this.size };
    }

    pub fn overlaps(a: @This(), b: @This()) bool {
        return a.pos[0] < b.pos[0] + b.size[0] and
            a.pos[0] + a.size[0] > b.pos[0] and
            a.pos[1] < b.pos[1] + b.size[1] and
            a.pos[1] + a.size[1] > b.pos[1];
    }
};
