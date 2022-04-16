const std = @import("std");
const w4 = @import("wasm4");
const geom = @import("geometry.zig");
const v = geom.Vec;
const Text = @import("text.zig");

pub fn pixel(x: i32, y: i32) void {
    if (x < 0 or x >= 160 or y < 0 or y >= 160) return;
    // The byte index into the framebuffer that contains (x, y)
    const idx = (@intCast(usize, y) * 160 + @intCast(usize, x)) >> 2;
    // Calculate the bits within the byte that corresponds to our position
    const shift = @intCast(u3, (x & 0b11) * 2);
    const mask = @as(u8, 0b11) << shift;
    // Use the first DRAW_COLOR as the pixel color
    const palette_color = @intCast(u8, w4.DRAW_COLORS.* & 0b1111);
    if (palette_color == 0) { // Transparent
        return;
    }
    const col= (palette_color - 1) & 0b11;
    // Write to the framebuffer
    w4.FRAMEBUFFER[idx] = (col << shift) | (w4.FRAMEBUFFER[idx] & ~mask);
}

pub fn text(string: []const u8, pos: geom.Vec2) void {
    w4.textUtf8(string.ptr, string.len, pos[0], pos[1]);
}

/// Draws a string in a miniature form, with 1 pixel equal to 1 character.
pub fn text_mini(string: []const u8, pos: geom.Vec2, lines: ?usize) void {
    var x = pos[0];
    var y = pos[1];
    var line: usize = 0;
    for (string) |char| {
        switch (Text.get_char_draw_type(char)) {
            .Space => {
                x += 1;
            },
            .Character => {
                pixel(x, y);
                x += 1;
            },
            .Newline => {
                line += 1;
                if (lines) |l| {
                    if (line == l) return;
                }
                x = pos[0];
                y += 1;
            },
        }
    }
}


pub const Color = enum(u16) {
    Transparent = 0,
    Light = 1,
    Midtone1 = 2,
    Midtone2 = 3,
    Dark = 4,
};

pub const color = struct {
    pub fn fill(col: Color) u16 {
        return @enumToInt(col);
    }

    pub fn stroke(col: Color) u16 {
        return @enumToInt(col) << 4;
    }

    pub fn select(col1: Color, col2: Color) u16 {
        return @enumToInt(col1) |
            (@enumToInt(col2)) << 4;
    }

    pub fn select4(col1: Color, col2: Color, col3: Color, col4: Color) u16 {
        return @enumToInt(col1) |
            (@enumToInt(col2) << 4) |
            (@enumToInt(col3) << 8) |
            (@enumToInt(col4) << 12);
    }
};

// Object to render bitmap
pub const Blit = struct {
    bmp: *const Bitmap,
    rect: union(enum) { full, aabb: geom.AABB } = .full,
    flags: BlitFlags = .{.bpp = .b1},
    style: u16,

    pub fn init(style: u16, bitmap: *const Bitmap, flags: BlitFlags) @This() {
        return @This(){
            .bmp = bitmap,
            .rect = .full,
            .flags = flags,
            .style = style,
        };
    }

    pub fn init_sub(style: u16, bitmap: *const Bitmap, flags: BlitFlags, region: geom.AABB) @This() {
        return @This(){
            .bmp = bitmap,
            .rect = .{ .aabb = region },
            .flags = flags,
            .style = style,
        };
    }

    pub fn get_size(this: @This()) geom.Vec2 {
        return switch (this.rect) {
            .full => geom.Vec2{ this.bmp.width, this.bmp.height },
            .aabb => |aabb| geom.Vec2{ aabb.size[v.x], aabb.size[v.y] },
        };
    }

    pub fn blit(this: @This(), pos: geom.Vec2) void {
        w4.DRAW_COLORS.* = this.style;
        switch (this.rect) {
            .full => this.bmp.blit(pos, this.flags),
            .aabb => |aabb| this.bmp.blit_sub(pos, aabb, this.flags),
        }
    }
};

pub const Bitmap = struct {
    data: [*]const u8,
    width: i32,
    height: i32,

    pub fn blit(this: @This(), pos: geom.Vec2, flags: BlitFlags) void {
        w4.blit(this.data, pos[v.x], pos[v.y], this.width, this.height, @bitCast(u32, flags));
    }

    pub fn blit_sub(this: @This(), pos: geom.Vec2, rect: geom.AABB, flags: BlitFlags) void {
        w4.blitSub(
            this.data,
            pos[v.x],
            pos[v.y],
            rect.size[v.x],
            rect.size[v.y],
            @intCast(u32, rect.pos[v.x]),
            @intCast(u32, rect.pos[v.y]),
            this.width,
            @bitCast(u32, flags),
        );
    }
};

pub const BlitFlags = packed struct {
    bpp: enum(u1) {
        b1,
        b2,
    } = .b1,
    flip_x: bool = false,
    flip_y: bool = false,
    rotate: bool = false,
    _: u28 = 0,
    comptime {
        if (@sizeOf(@This()) != @sizeOf(u32)) unreachable;
    }
};

pub const BlittyError = error{
    NotABitmap,
    InvalidInfoHeaderSize,
    NotAMonoChromaticBitmap,
    InvalidImage,
    UnsupportedWidth,
    UnsupportedHeight,
};

pub fn load_bitmap(comptime monoBmp: []const u8) BlittyError!Bitmap {
    if (!std.mem.eql(u8, "BM", monoBmp[0x0..0x2])) {
        return BlittyError.NotABitmap;
    }

    const dataOffset = std.mem.readIntLittle(u32, monoBmp[0xa..0xe]);

    const infoHeaderSize = std.mem.readIntLittle(u32, monoBmp[0xe..0x12]);
    if (infoHeaderSize != 40) {
        @compileLog("Info Header Size: ");
        @compileLog(infoHeaderSize);
        return BlittyError.InvalidInfoHeaderSize;
    }

    const imgWidth = std.mem.readIntLittle(u32, monoBmp[0x12..0x16]);
    const imgHeight = std.mem.readIntLittle(u32, monoBmp[0x16..0x1a]);

    if (imgWidth % 2 != 0) {
        @compileLog("Unsupported image width: ");
        @compileLog(imgWidth);
        return BlittyError.UnsupportedWidth;
    }

    if (imgHeight % 2 != 0) {
        @compileLog("Unsupported image height: ");
        @compileLog(imgHeight);
        return BlittyError.UnsupportedHeight;
    }

    const bpp = std.mem.readIntLittle(u16, monoBmp[0x1c..0x1e]);
    if (bpp != 1) {
        return BlittyError.NotAMonoChromaticBitmap;
    }

    const imageSize = std.mem.readIntLittle(u32, monoBmp[0x22..0x26]);
    const pixelData = monoBmp[dataOffset .. dataOffset + imageSize];

    const imgWidthBytes = iwb: {
        var row_bytes: u32 = 0;
        row_bytes += imgWidth / 8;
        row_bytes += if (imgWidth % 8 != 0) @as(u32, 1) else @as(u32, 0);
        row_bytes += if (row_bytes % 4 == 0) @as(u32, 0) else (4 - row_bytes % 4);
        break :iwb row_bytes;
    };

    const blitSize = if ((imgWidth * imgHeight) % 8 != 0)
        imgWidth * imgHeight + (8 - ((imgWidth * imgHeight) % 8))
    else
        imgWidth * imgHeight;
    const blitArraySize = blitSize / 8;
    var blitData: [blitArraySize]u8 = [_]u8{0} ** (blitArraySize);

    var blitIndex: u32 = 0;
    var dataIndex: u32 = 0;
    var totalBits: u32 = 0;
    var y: u32 = 0;
    @setEvalBranchQuota(4000);
    while (y < imgHeight) : (y += 1) {
        const row_data = pixelData[dataIndex .. dataIndex + imgWidthBytes].*;
        blitIndex += row_data.len;
        dataIndex += imgWidthBytes;
        var btSrcCnt: u32 = 0;
        row_loop: for (row_data) |byte| {
            var bit: u8 = 7;
            while (bit >= 0) : (bit -= 1) {
                const vi: bool = (byte & (1 << bit)) != 0;
                if (vi) {
                    blitData[blitData.len - blitIndex] |= 1 << (7 - (totalBits % 8));
                }

                totalBits += 1;
                if (totalBits % 8 == 0) {
                    blitIndex -= 1;
                }

                if (btSrcCnt == imgWidth - 1) {
                    blitIndex += row_data.len;
                    break :row_loop;
                }
                btSrcCnt += 1;
                if (bit == 0) break;
            }
        }
    }

    // for (blitData) |byte| {
    //     @compileLog(std.fmt.comptimePrint("{b:08}", .{byte}));
    // }

    return Bitmap{
        .data = &blitData,
        .width = @intCast(i32, imgWidth),
        .height = @intCast(i32, imgHeight),
    };
}
