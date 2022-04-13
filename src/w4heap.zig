const std = @import("std");
const w4 = @import("wasm4");

pub const heap: [58975]u8 = undefined;
pub var fixed_buffer_allocator = std.heap.FixedBufferAllocator.init(heap);

test "heap usage" {
    var alloc = fixed_buffer_allocator.allocator();
}
