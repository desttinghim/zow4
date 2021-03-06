const std = @import("std");

pub fn Manager(comptime Context: type, comptime Scenes: []const type) type {
    comptime var scene_enum: std.builtin.Type.Enum = std.builtin.Type.Enum{
        .layout = .Auto,
        .tag_type = usize,
        .fields = &.{},
        .decls = &.{},
        .is_exhaustive = false,
    };
    inline for (Scenes) |t, i| {
        scene_enum.fields = scene_enum.fields ++ [_]std.builtin.Type.EnumField{.{.name = @typeName(t), .value = i}};
    }
    const SceneEnum = @Type(.{.Enum = scene_enum});
    return struct {
        alloc: std.mem.Allocator,
        ctx: *Context,
        scenes: std.ArrayList(ScenePtr),

        pub const Scene = SceneEnum;
        const ScenePtr = struct {which: usize, ptr: *anyopaque};

        pub fn init( alloc: std.mem.Allocator,ctx: *Context, opt: struct {scene_capacity: usize = 5}) !@This() {
            return @This() {
                .alloc = alloc,
                .ctx = ctx,
                .scenes = try std.ArrayList(ScenePtr).initCapacity(alloc, opt.scene_capacity),
            };
        }

        pub fn deinit(this: *@This()) void {
            this.scenes.deinit();
        }

        pub fn push(this: *@This(), comptime which: SceneEnum) anyerror!*Scenes[@enumToInt(which)] {
            const i = @enumToInt(which);
            const scene = try this.alloc.create(Scenes[i]);
            scene.* = try @field(Scenes[i], "init")(this.ctx);
            try this.scenes.append(.{.which = i, .ptr = scene});
            return scene;
        }

        pub fn pop(this: *@This()) void {
            const scene = this.scenes.popOrNull() orelse return;
            inline for (Scenes) |S, i| {
                if (i == scene.which) {
                    const ptr = @ptrCast(*S, @alignCast(@alignOf(S), scene.ptr));
                    @field(S,"deinit")(ptr);
                    this.alloc.destroy(ptr);
                }
                break;
            }
        }

        pub fn replace(this: *@This(), comptime which: SceneEnum) anyerror!void  {
            this.pop();
            _ = try this.push(which);
        }

        pub fn tick(this: *@This()) anyerror!void {
            // if (this.scenes.items.len == 0) return;
            const scene = this.scenes.items[this.scenes.items.len - 1];
            inline for (Scenes) |S, i| {
                if (i == scene.which) {
                    const ptr = @ptrCast(*S, @alignCast(@alignOf(S), scene.ptr));
                    try @field(S,"update")(ptr);
                    break;
                }
            } else {
                return error.NoSuchScene;
            }
        }
    };
}


test "Scene Manager" {
    const Ctx = struct { count: usize };
    const Example = struct {
        ctx: *Ctx,
        fn init(ctx: *Ctx)  @This() {
            return @This(){
                .ctx = ctx,
            };
        }
        fn deinit(_: *@This()) void {}
        fn update(this: *@This())  void {
            this.ctx.count += 1;
        }
    };
    const SceneManager = Manager(Ctx, &[_]type{Example});
    var ctx = Ctx{.count = 0};

    var sm = SceneManager.init(&ctx, std.testing.allocator, .{});
    defer sm.deinit();

    const example_ptr = try sm.push(.Example);
    example_ptr.update();
    try std.testing.expectEqual(@as(usize, 1), ctx.count);

    sm.tick();
    try std.testing.expectEqual(@as(usize, 2), ctx.count);

    sm.pop();
}
