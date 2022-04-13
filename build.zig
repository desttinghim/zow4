const std = @import("std");

pub const pkgs = struct {
    const wasm4 = std.build.Pkg{
        .name = "wasm4",
        .path = std.build.FileSource.relative("src/wasm4.zig"),
        .dependencies = null,
    };

    const input = std.build.Pkg{
        .name = "wasm4",
        .path = std.build.FileSource.relative("src/input.zig"),
        .dependencies = &[_]std.build.Pkg{wasm4},
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

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&w4input_tests.step);
}
