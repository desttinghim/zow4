//! Scene
const std = @import("std");

const test1 = struct {
    const scene2 = Scene(test2);
    var manager: *SceneManager = undefined;
    pub fn start(scene_manager: *SceneManager) void {
        manager = scene_manager;
        std.log.info("Test 1 Start", .{});
    }
    pub fn update() void {
        manager.push(scene2);
        std.log.info("Test 1 Update", .{});
    }
    pub fn end() void {
        std.log.info("Test 1 End", .{});
    }
};

const test2 = struct {
    var manager: *SceneManager = undefined;
    pub fn start(scene_manager: *SceneManager) void {
        manager = scene_manager;
        std.log.info("Test 2 Start", .{});
    }
    pub fn update() void {
        std.log.info("Test 2 Update", .{});
        manager.pop();
    }
    pub fn end() void {
        std.log.info("Test 2 End", .{});
    }
};

test "usage" {
    const scene1 = Scene(test1);
    var scene_manager = SceneManager.init(scene1);
    scene_manager.run();
    scene_manager.run();
    scene_manager.run();
    scene_manager.pop();
}

const SceneManager = @This();

pub fn Scene(comptime T: anytype) ScenePtrs {
    if (@hasField(T, "start")) {
        @compileLog("Scene requires start function", T);
    }
    if (@hasField(T, "update")) {
        @compileLog("Scene requires update function", T);
    }
    if (@hasField(T, "end")) {
        @compileLog("Scene requires end function", T);
    }
    return .{
        .start = @field(T, "start"),
        .update = @field(T, "update"),
        .end = @field(T, "end"),
    };
}

pub const ScenePtrs = struct {
    start: fn (*SceneManager) void,
    update: fn () void,
    end: fn () void,
};

scenes: [5]ScenePtrs = undefined,
current_scene: usize = 0,

pub fn init(initial_scene: ScenePtrs) @This() {
    var this = @This(){};
    this.scenes[0] = initial_scene;
    this.scenes[0].start(&this);
    return this;
}

pub fn run(this: @This()) void {
    this.scenes[this.current_scene].update();
}

pub fn push(this: *@This(), scene: ScenePtrs) void {
    if (this.current_scene < this.scenes.len - 1) {
        this.current_scene += 1;
        this.scenes[this.current_scene] = scene;
        this.scenes[this.current_scene].start(this);
    } else {
        @panic("Scenes out of bounds");
        // return error.OutOfBounds;
    }
}

pub fn replace(this: *@This(), scene: Scene) void {
    this.scenes[this.current_scene].end();
    this.scenes[this.current_scene] = scene;
    this.scenes[this.current_scene].start();
}

pub fn pop(this: *@This()) void {
    if (this.current_scene > 0) {
        this.scenes[this.current_scene].end();
        this.current_scene -= 1;
    } else {
        // This should quit the game in native runtimes
        @panic("Popped last scene, quitting...");
    }
}
