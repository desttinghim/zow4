const std = @import("std");

const Pkg = std.build.Pkg;
const FileSource = std.build.FileSource;

pub const pkgs = struct {
    pub const wasm4 = Pkg{
        .name = "wasm4",
        .path = FileSource.relative("src/wasm4.zig"),
        .dependencies = null,
    };

    pub const input = Pkg{
        .name = "input",
        .path = FileSource.relative("src/input.zig"),
        .dependencies = &[_]Pkg{wasm4},
    };

    pub const heap = Pkg{
        .name = "heap",
        .path = FileSource.relative("src/heap.zig"),
        .dependencies = &[_]Pkg{wasm4},
    };

    pub const scene = Pkg{
        .name = "scene",
        .path = FileSource.relative("src/scene.zig"),
    };

    pub const zow4 = Pkg{
        .name = "zow4",
        .path = FileSource.relative("src/zow4.zig"),
        .dependencies = &[_]Pkg{wasm4},
    };
};

pub fn addWasm4RunStep(b: *std.build.Builder, name: []const u8, cart: *std.build.LibExeObjStep) !void {
    const w4native = b.addSystemCommand(&.{ "w4", "run-native" });
    w4native.addArtifactArg(cart);

    const run = b.step(name, "Launches w4 run-native command on cart.");
    run.dependOn(&w4native.step);
}

pub fn addWasm4Cart(b: *std.build.Builder, name: []const u8, path: []const u8) !*std.build.LibExeObjStep {
    const mode = b.standardReleaseOptions();
    const lib = b.addSharedLibrary(name, path, .unversioned);

    lib.addPackage(pkgs.wasm4);

    lib.setBuildMode(mode);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.import_memory = true;
    lib.initial_memory = 65536;
    lib.max_memory = 65536;
    lib.stack_size = 14752;

    // Export WASM-4 symbols
    lib.export_symbol_names = &[_][]const u8{ "start", "update" };

    lib.install();

    return lib;
}


pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const input = b.addStaticLibrary("input", "src/input.zig");
    input.setBuildMode(mode);
    input.addPackage(pkgs.wasm4);
    input.install();

    const heap = b.addStaticLibrary("heap", "src/heap.zig");
    heap.setBuildMode(mode);
    heap.addPackage(pkgs.wasm4);
    heap.install();

    try tests(b, mode);

    const example = try addWasm4Cart(b, "cart", "examples/simple/main.zig");
    example.addPackage(pkgs.zow4);
    try addWasm4RunStep(b, "run-example", example);

    const counter = try addWasm4Cart(b, "counter", "examples/counter.zig");
    counter.addPackage(pkgs.zow4);
    try addWasm4RunStep(b, "run-counter", counter);
}

fn tests(b: *std.build.Builder, mode: std.builtin.Mode) !void {
    const input_tests = b.addTest("src/input.zig");
    input_tests.setBuildMode(mode);
    input_tests.addPackage(pkgs.wasm4);

    const heap_tests = b.addTest("src/heap.zig");
    heap_tests.setBuildMode(mode);
    heap_tests.addPackage(pkgs.wasm4);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&input_tests.step);
    test_step.dependOn(&heap_tests.step);
}
