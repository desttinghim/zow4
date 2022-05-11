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


const mem = std.mem;
const assert = std.debug.assert;

fn sliceContainsPtr(container: []u8, ptr: [*]u8) bool {
    return @ptrToInt(ptr) >= @ptrToInt(container.ptr) and
        @ptrToInt(ptr) < (@ptrToInt(container.ptr) + container.len);
}

fn sliceContainsSlice(container: []u8, slice: []u8) bool {
    return @ptrToInt(slice.ptr) >= @ptrToInt(container.ptr) and
        (@ptrToInt(slice.ptr) + slice.len) <= (@ptrToInt(container.ptr) + container.len);
}

/// A modifed fixed buffer allocator that allows freeing memory as a stack.
pub const StackAllocator = struct {
    end_index: usize,
    buffer: []u8,

    pub fn init(buffer: []u8) StackAllocator {
        return StackAllocator{
            .buffer = buffer,
            .end_index = 0,
        };
    }

    /// *WARNING* using this at the same time as the interface returned by `threadSafeAllocator` is not thread safe
    pub fn allocator(self: *StackAllocator) Allocator {
        return Allocator.init(self, alloc, resize, free);
    }

    /// Provides a lock free thread safe `Allocator` interface to the underlying `StackAllocator`
    /// *WARNING* using this at the same time as the interface returned by `getAllocator` is not thread safe
    // pub fn threadSafeAllocator(self: *StackAllocator) Allocator {
    //     return Allocator.init(
    //         self,
    //         threadSafeAlloc,
    //         Allocator.NoResize(StackAllocator).noResize,
    //         Allocator.NoOpFree(StackAllocator).noOpFree,
    //     );
    // }

    pub fn ownsPtr(self: *StackAllocator, ptr: [*]u8) bool {
        return sliceContainsPtr(self.buffer, ptr);
    }

    pub fn ownsSlice(self: *StackAllocator, slice: []u8) bool {
        return sliceContainsSlice(self.buffer, slice);
    }

    /// NOTE: this will not work in all cases, if the last allocation had an adjusted_index
    ///       then we won't be able to determine what the last allocation was.  This is because
    ///       the alignForward operation done in alloc is not reversible.
    pub fn isLastAllocation(self: *StackAllocator, buf: []u8) bool {
        return buf.ptr + buf.len == self.buffer.ptr + self.end_index;
    }

    /// Header placed directly before allocations
    const Header = struct {
        padding: u8,
    };

    fn alloc(self: *StackAllocator, n: usize, ptr_align: u29, len_align: u29, ra: usize) Allocator.Error![]u8 {
        _ = len_align;
        _ = ra;
        if (ptr_align > 128) return error.OutOfMemory;
        const adjust_off = mem.alignPointerOffset(self.buffer.ptr + self.end_index + @sizeOf(Header), ptr_align) orelse
            return error.OutOfMemory;
        const adjusted_index = self.end_index + adjust_off + @sizeOf(Header);
        const new_end_index = adjusted_index + n;
        if (new_end_index > self.buffer.len) {
            return error.OutOfMemory;
        }
        const header_index = adjusted_index - @sizeOf(Header);
        const header = .{.padding = @truncate(u8, header_index - self.end_index)};
        const header_buf = self.buffer[header_index..adjusted_index];
        @ptrCast(*align(@alignOf(Header)) Header, header_buf).* = header;
        const result = self.buffer[adjusted_index..new_end_index];
        self.end_index = new_end_index;

        return result;
    }

    fn resize(
        self: *StackAllocator,
        buf: []u8,
        buf_align: u29,
        new_size: usize,
        len_align: u29,
        return_address: usize,
    ) ?usize {
        _ = buf_align;
        _ = return_address;
        assert(self.ownsSlice(buf)); // sanity check

        if (!self.isLastAllocation(buf)) {
            if (new_size > buf.len) return null;
            return mem.alignAllocLen(buf.len, new_size, len_align);
        }

        if (new_size <= buf.len) {
            const sub = buf.len - new_size;
            self.end_index -= sub;
            return mem.alignAllocLen(buf.len - sub, new_size, len_align);
        }

        const add = new_size - buf.len;
        if (add + self.end_index > self.buffer.len) return null;

        self.end_index += add;
        return new_size;
    }

    fn free(
        self: *StackAllocator,
        buf: []u8,
        buf_align: u29,
        return_address: usize,
    ) void {
        _ = buf_align;
        _ = return_address;
        assert(self.ownsSlice(buf)); // sanity check

        if (sliceContainsSlice(self.buffer[self.end_index..], buf)) {
            // Allow double frees
            return;
        }

        const start = @ptrToInt(self.buffer.ptr);
        const cur_addr = @ptrToInt(buf.ptr);

        const header = @intToPtr(*align(@alignOf(Header)) Header, cur_addr - @sizeOf(Header)).*;
        const prev_offset = cur_addr - header.padding - start;

        self.end_index = prev_offset;
    }

    // fn threadSafeAlloc(self: *StackAllocator, n: usize, ptr_align: u29, len_align: u29, ra: usize) ![]u8 {
    //     _ = len_align;
    //     _ = ra;
    //     var end_index = @atomicLoad(usize, &self.end_index, .SeqCst);
    //     while (true) {
    //         const adjust_off = mem.alignPointerOffset(self.buffer.ptr + end_index, ptr_align) orelse
    //             return error.OutOfMemory;
    //         const adjusted_index = end_index + adjust_off;
    //         const new_end_index = adjusted_index + n;
    //         if (new_end_index > self.buffer.len) {
    //             return error.OutOfMemory;
    //         }
    //         end_index = @cmpxchgWeak(usize, &self.end_index, end_index, new_end_index, .SeqCst, .SeqCst) orelse return self.buffer[adjusted_index..new_end_index];
    //     }
    // }

    pub fn reset(self: *StackAllocator) void {
        self.end_index = 0;
    }
};
