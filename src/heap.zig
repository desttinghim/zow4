const std = @import("std");
const w4 = @import("wasm4");

pub var heap: *[44223]u8 = w4.PROGRAM_MEMORY[14752..];
// pub var heapdata: [40000]u8 = undefined;
// pub var heap: *[40000]u8 = &heapdata;

pub fn init() std.heap.FixedBufferAllocator {
    return std.heap.FixedBufferAllocator.init(heap);
}

test "heap usage" {
    var fba = init();
    var alloc = fba.allocator();
    var buf = try alloc.alloc(u8, 100);
    var i: u8 = 0;
    while (i < buf.len) : (i += 1) {
        const num = i % (127 - ' ');
        const char = num + ' ';
        buf[i] = char;
    }
    std.log.warn("{s}", .{buf});

    var thing = try alloc.create(i32);
    thing.* = 1337;
    try std.testing.expectEqual(@as(i32, 1337), thing.*);
}
