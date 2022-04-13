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
        .name = "w4input",
        .path = FileSource.relative("src/input.zig"),
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

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const w4input = b.addStaticLibrary("w4input", "src/input.zig");
    w4input.setBuildMode(mode);
    w4input.addPackage(pkgs.wasm4);
    w4input.install();

    const w4input_tests = b.addTest("src/input.zig");
    w4input_tests.setBuildMode(mode);
    w4input_tests.addPackage(pkgs.wasm4);

    const scene_tests = b.addTest("src/scene.zig");
    scene_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&w4input_tests.step);
    test_step.dependOn(&scene_tests.step);
}
