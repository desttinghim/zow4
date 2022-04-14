const std = @import("std");
const w4 = @import("wasm4");
const geom = @import("geometry.zig");
const v = geom.Vec;

pub const Blit = struct {
    data: [*]const u8,
    width: i32,
    height: i32,

    pub fn blit(this: @This(), pos: geom.Vec2, flags: u32) void {
        w4.blit(this.data, pos[v.x], pos[v.y], this.width, this.height, flags);
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

pub fn bmpToBlit(comptime monoBmp: []const u8) BlittyError!Blit {
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

    return Blit{
        .data = &blitData,
        .width = @intCast(i32, imgWidth),
        .height = @intCast(i32, imgHeight),
    };
}
