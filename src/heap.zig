const std = @import("std");
const w4 = @import("wasm4");

pub var heap: *[44223]u8 = w4.PROGRAM_MEMORY[14752..];
// pub var heapdata: [40000]u8 = undefined;
// pub var heap: *[40000]u8 = &heapdata;

pub fn init() std.heap.FixedBufferAllocator {
    return std.heap.FixedBufferAllocator.init(heap);
}

pub fn report_memory_usage(fba: std.heap.FixedBufferAllocator) void {
    const mem_used = permyriad(fba.end_index, fba.buffer.len) / 10;
    w4.tracef("%d/%d bytes used - %d%%", fba.end_index, fba.buffer.len, mem_used);
}

fn get_memory_usage(comptime T: type, count: usize) usize {
    const size: usize = @sizeOf(T);
    const MEM = heap.len;
    return @truncate(usize, @divTrunc(permyriad(count * size,MEM), 100));
}

fn percentage(amount: usize, total: usize) usize {
   return @divTrunc(amount * 100, total);
}

fn perthousands(amount: usize, total: usize) usize {
    return @divTrunc(amount * 1000, total);
}

fn permyriad(amount: usize, total: usize) u64 {
    return @divTrunc(@intCast(u64, amount) * 10_000, @intCast(u64, total));
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
