const std = @import("std");
const geom = @import("geometry.zig");

pub const Document = struct {
    text: []const u8,
    cols: i32,
    lines: i32,

    pub fn fromText(string: []const u8) @This() {
        @setEvalBranchQuota(10_000);
        var tokiter = std.mem.split(u8, string, "\n");
        var i: usize = 0;
        var maxline: usize = 0;
        while (tokiter.next()) |tok| {
            i += 1;
            if (tok.len > maxline) maxline = tok.len;
            // if (tok.len > 19) {
            //     @compileLog("Line is too long: ");
            //     @compileLog(i);
            // }
        }
        return @This(){
            .text = string,
            .cols = @intCast(i32, maxline),
            .lines = @intCast(i32, i),
        };
    }
};

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

const CharDrawType = enum {
    Character,
    Space,
    Newline,
};

fn get_char_draw_type(char: u8) CharDrawType {
    switch (char) {
        'A'...'Z',
        'a'...'z',
        ':'...'@',
        '!'...'.',
        '['...'`',
        '{'...'~',
        => return .Character,
        ' ' => return .Space,
        '\n' => return .Newline,
        else => return .Space,
    }
}
