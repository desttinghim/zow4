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

pub fn percentage(amount: usize, total: usize) usize {
   return @divTrunc(amount * 100, total);
}

pub fn perthousands(amount: usize, total: usize) usize {
    return @divTrunc(amount * 1000, total);
}

pub fn permyriad(amount: usize, total: usize) u64 {
    return @divTrunc(@intCast(u64, amount) * 10_000, @intCast(u64, total));
}

const Allocator = std.mem.Allocator;
/// Mimics the array list api, but operates on a fixed slice that is passed in
fn SliceList(comptime T: type) type {
    return struct {
        items: []T,
        capacity: []T,

        pub fn init(buffer: []u8) @This() {
            const start = std.mem.alignPointer(buffer.ptr, @alignOf(T)).?; //orelse return error.OutOfMemory;
            const ptr = @ptrCast([*]T, @alignCast(@alignOf(T), start));
            const items = ptr[0..1];
            return @This(){
                .items = items,
                .capacity = ptr[0..@divTrunc(buffer.len, @alignOf(T))],
            };
        }

        /// Insert `item` at index `n`. Moves `list[n .. list.len]`
        /// to higher indices to make room.
        /// This operation is O(N).
        pub fn insert(this: *@This(), n: usize, item: T) Allocator.Error!void {
            if (this.items.len >= this.capacity.len) return error.OutOfMemory;
            this.items.len += 1;

            std.mem.copyBackwards(T, this.items[n + 1 .. this.items.len], this.items[n .. this.items.len - 1]);
            this.items[n] = item;
        }

        /// Extend the list by 1 element.
        pub fn append(this: *@This(), item: T) Allocator.Error!void {
            if (this.items.len >= this.capacity.len) return error.OutOfMemory;
            this.items.len += 1;
            this.items[this.items.len - 1] = item;
        }

        /// Removes the element at the specified index and returns it.
        /// The empty slot is filled from the end of the list.
        /// Invalidates pointers to last element.
        /// This operation is O(1).
        pub fn swapRemove(this: *@This(), i: usize) T {
            if (this.items.len - 1 == i) return this.pop();

            const old_item = this.items[i];
            this.items[i] = this.pop();
            return old_item;
        }

        /// Remove and return the last element from the list.
        /// Asserts the list has at least one item.
        /// Invalidates pointers to last element.
        pub fn pop(this: *@This()) T {
            const val = this.items[this.items.len - 1];
            this.items.len -= 1;
            return val;
        }

        /// Reduce length to `new_len`.
        /// Invalidates pointers to elements `items[new_len..]`.
        /// Keeps capacity the same.
        pub fn shrinkRetainingCapacity(this: *@This(), new_len: usize) void {
            std.debug.assert(new_len <= this.items.len);
            this.items.len = new_len;
        }
    };
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
