const std = @import("std");
const zow4 = @import("zow4");
const w4 = @import("wasm4");

const input = zow4.input;
const SceneManager = zow4.scene.Manager(Context, &.{Scene1, Scene2});

const Context = struct {
    fba: std.heap.FixedBufferAllocator = undefined,
    alloc: std.mem.Allocator = undefined,
    scenes: SceneManager,
};

const KB = 1024;
var heap: [4 * KB]u8 = undefined;
var stack_heap: [4 * KB]u8 = undefined;
var stack_allocator = zow4.mem.StackAllocator.init(&stack_heap);
var ctx: Context = undefined;

export fn start() void {
    _start() catch |e| zow4.panic(@errorName(e));
}

fn _start() !void {
    var fba = std.heap.FixedBufferAllocator.init(&heap);
    var alloc = fba.allocator();
    ctx = .{
        .fba = fba,
        .alloc = alloc,
        .scenes = try SceneManager.init(stack_allocator.allocator(), &ctx, .{}),
    };
    _ = try ctx.scenes.push(.Scene1);
}

export fn update() void {
    _update() catch |e| zow4.panic(@errorName(e));
}

fn _update() !void {
    try ctx.scenes.tick();
    input.update();
}

const Scene1 = struct {
    ctx: *Context,
    counter: isize,
    pub fn init(_ctx: *Context) !@This() {
        return @This(){ .ctx = _ctx, .counter = 0 };
    }
    pub fn deinit(_: *@This()) void {}
    pub fn update(this: *@This()) !void {
        w4.text("Scene 1", 80 - 3 * 8, 64);
        var buf: [32]u8 = undefined;
        const text = try std.fmt.bufPrintZ(&buf, "< {} >", .{this.counter});
        w4.text(text.ptr, 80 - @divTrunc(@intCast(i32, text.len * 8), 2), 80);
        w4.text("z to push", 80 - 3 * 8, 96);
        if (input.btnp(.one, .left)) {
            this.counter -= 1;
        }
        if (input.btnp(.one, .right)) {
            this.counter += 1;
        }
        if (input.btnp(.one, .z)) {
            _ = try this.ctx.scenes.push(.Scene2);
        }
    }
};

const Scene2 = struct {
    ctx: *Context,
    pub fn init(_ctx: *Context) !@This() {
        return @This(){ .ctx = _ctx };
    }
    pub fn deinit(_: *@This()) void {}
    pub fn update(this: *@This()) !void {
        w4.text("Scene 2", 80 - 3 * 8, 64);
        if (input.btnp(.one, .x)) {
            this.ctx.scenes.pop();
        }
        w4.text("x to pop", 80 - 3 * 8, 96);
    }
};
