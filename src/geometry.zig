const std = @import("std");

/// Represents a rectangle as .{ left, top, right, bottom }
pub const Rect = @Vector(4, i32);
/// Represents a 2D floating point Vector as .{ x, y }
pub const Vec2f = std.meta.Vector(2, f32);
/// Represents a 2D signed Vector as .{ x, y }
pub const Vec2 = std.meta.Vector(2, i32);

pub const vec = struct {
    pub const x = 0;
    pub const y = 1;

    /////////////////////////////////////////
    // i32 integer backed vector functions //
    /////////////////////////////////////////

    /// Returns true x = x and y = y
    pub fn equals(v1: Vec2, v2: Vec2) bool {
        return @reduce(.And, v1 == v2);
    }

    /// Returns true if the vector is zero
    pub fn isZero(v: Vec2) bool {
        return equals(v, Vec2{ 0, 0 });
    }

    /// Copies the vectors x and y to make a rect
    pub fn double(v: Vec2) Rect {
        return Rect{ v[0], v[1], v[0], v[1] };
    }

    /// Returns the length of the vector, squared
    pub fn length_sqr(a: Vec2) i32 {
        return @reduce(.Add, a * a);
    }

    /// Returns the distance squared
    pub fn dist_sqr(a: Vec2, b: Vec2) i32 {
        return length_sqr(a - b);
    }

    /// Returns the length of the vector.
    /// NOTE: Conversion between floats and ints on WASM appears
    /// to be broken, so this may not return the correct results.
    pub fn length(a: Vec2) i32 {
        return @floatToInt(i32, @sqrt(@intToFloat(f32, length_sqr(a))));
    }

    /// Returns the distance between two vectors (assuming they are points).
    /// NOTE: Conversion between floats and ints on WASM appears
    /// to be broken, so this may not return the correct results.
    pub fn dist(a: Vec2, b: Vec2) i32 {
        return length(a - b);
    }

    ///////////////////////////////////////
    // f32 float backed vector functions //
    ///////////////////////////////////////

    /// Rturns the distance between two vectors
    pub fn distf(a: Vec2f, b: Vec2f) f32 {
        var subbed = @fabs(a - b);
        return lengthf(subbed);
    }

    /// Returns the length between two vectors
    pub fn lengthf(vector: Vec2f) f32 {
        var squared = vector * vector;
        return @sqrt(@reduce(.Add, squared));
    }

    /// Returns the normalized vector
    pub fn normalizef(vector: Vec2f) Vec2f {
        return vector / @splat(2, lengthf(vector));
    }

    /// Converts an i32 backed vector to a f32 backed one.
    /// NOTE: Conversion between floats and ints on WASM appears
    /// to be broken, so this may not return the correct results.
    pub fn itof(vec2: Vec2) Vec2f {
        return Vec2f{ @intToFloat(f32, vec2[0]), @intToFloat(f32, vec2[1]) };
    }

    /// Converts a f32 backed vector to an i32 backed one.
    /// NOTE: Conversion between floats and ints on WASM appears
    /// to be broken, so this may not return the correct results.
    pub fn ftoi(vec2f: Vec2f) Vec2 {
        return Vec2{ @floatToInt(i32, @floor(vec2f[0])), @floatToInt(i32, @floor(vec2f[1])) };
    }
};

pub const rect = struct {
    pub fn top(rectangle: Rect) i32 {
        return rectangle[1];
    }

    pub fn left(rectangle: Rect) i32 {
        return rectangle[0];
    }

    pub fn top_left(rectangle: Rect) Vec2 {
        return .{ rectangle[0], rectangle[1] };
    }

    pub fn right(rectangle: Rect) i32 {
        return rectangle[2];
    }

    pub fn bottom(rectangle: Rect) i32 {
        return rectangle[3];
    }

    pub fn bottom_right(rectangle: Rect) Vec2 {
        return .{ rectangle[2], rectangle[3] };
    }

    pub fn size(rectangle: Rect) Vec2 {
        return .{ rectangle[2] - rectangle[0], rectangle[3] - rectangle[1] };
    }

    pub fn contains(rectangle: Rect, vector: Vec2) bool {
        return @reduce(.And, top_left(rectangle) < vector) and @reduce(.And, bottom_right(rectangle) > vector);
    }

    pub fn shift(rectangle: Rect, vector: Vec2) Rect {
        return rectangle + vec.double(vector);
    }
};

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

pub const AABB = struct {
    pos: Vec2,
    size: Vec2,

    pub fn top(this: @This()) i32 {
        return this.pos[vec.y];
    }
    pub fn left(this: @This()) i32 {
        return this.pos[vec.x];
    }
    pub fn top_left(this: @This()) Vec2 {
        return this.pos;
    }
    pub fn right(this: @This()) i32 {
        return this.pos[vec.x] + this.size[vec.x];
    }
    pub fn bottom(this: @This()) i32 {
        return this.pos[vec.y] + this.size[vec.y];
    }
    pub fn bottom_right(this: @This()) Vec2 {
        return this.pos + this.size;
    }

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

    pub fn contains(this: @This(), vector: Vec2) bool {
        const tl = this.top_left();
        const br = this.bottom_right();
        return tl[vec.x] < vector[vec.x] and br[vec.x] > vector[vec.x] and
            tl[vec.y] < vector[vec.y] and br[vec.y] > vector[vec.y];
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
