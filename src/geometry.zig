const std = @import("std");

pub const Vec2f = std.meta.Vector(2, f32);
pub const Vec2 = std.meta.Vector(2, i32);

pub const Vec = struct {
    pub const x = 0;
    pub const y = 1;
};

// pub const Vec = struct {
//     pub const x = 0;
//     pub const y = 1;
// };

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

pub const AABB = struct {
    pos: Vec2f,
    size: Vec2f,

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
