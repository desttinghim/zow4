const std = @import("std");
const w4 = @import("wasm4");

pub var heap: *[58975]u8 = w4.PROGRAM_MEMORY;
pub var fixed_buffer_allocator: ?std.heap.FixedBufferAllocator = null;

pub fn allocator() std.mem.Allocator {
    // Get the allocator
    return (fixed_buffer_allocator orelse fba: {
        fixed_buffer_allocator = std.heap.FixedBufferAllocator.init(heap);
        break :fba fixed_buffer_allocator.?;
    }).allocator();
}

test "heap usage" {
    var alloc = allocator();
    var buf = try alloc.alloc(u8, 100);
    var i: u8 = 0;
    while (i < buf.len) : (i += 1) {
        const num = i % (127 - ' ');
        const char = num + ' ';
        buf[i] = char;
    }
    std.log.warn("{s}", .{buf});

    var alloc2 = allocator();
    var thing = try alloc2.create(i32);
    thing.* = 1337;
    try std.testing.expectEqual(@as(i32, 1337), thing.*);
}
