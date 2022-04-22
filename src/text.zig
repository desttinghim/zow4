const std = @import("std");
const geom = @import("geometry.zig");

/// Returns a vector with the width and height of the text in pixels.
pub fn text_size(string: []const u8) geom.Vec2 {
    var tokiter = std.mem.split(u8, string, "\n");
    var i: usize = 0;
    var maxline: usize = 0;
    while (tokiter.next()) |tok| {
        i += 1;
        if (tok.len > maxline) maxline = tok.len;
    }
    return geom.Vec2{
        @intCast(i32, maxline * 8),
        @intCast(i32, i * 8),
    };
}
