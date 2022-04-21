const std = @import("std");

const Pkg = std.build.Pkg;
const FileSource = std.build.FileSource;

pub const pkgs = struct {
    pub const wasm4 = Pkg{
        .name = "wasm4",
        .path = FileSource.relative("src/wasm4.zig"),
        .dependencies = null,
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

pub fn addWasmOpt(b: *std.build.Builder, name: []const u8, cart: *std.build.LibExeObjStep) !*std.build.Step {
    const prefix = b.getInstallPath(.lib, "");
    const opt = b.addSystemCommand(&[_][]const u8{
        "wasm-opt",
        "-Oz",
        "--strip-debug",
        "--strip-producers",
        "--zero-filled-memory",
    });

    opt.addArtifactArg(cart);
    const cartname = try std.fmt.allocPrint(b.allocator, "{s}{s}", .{ name, ".wasm" });
    defer b.allocator.free(cartname);
    const optout = try std.fs.path.join(b.allocator, &.{ prefix, cartname });
    defer b.allocator.free(optout);
    opt.addArgs(&.{ "--output", optout });

    const stepname = try std.fmt.allocPrint(b.allocator, "{s}-opt", .{name});
    defer b.allocator.free(stepname);
    const msg = try std.fmt.allocPrint(b.allocator, "Run wasm-opt on {s}, producing {s}", .{cart.name, cartname});
    defer b.allocator.free(msg);
    const opt_step = b.step(stepname, msg);
    opt_step.dependOn(&cart.step);
    opt_step.dependOn(&opt.step);
    return opt_step;
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

pub fn build(b: *std.build.Builder) !void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const input = b.addStaticLibrary("input", "src/input.zig");
    input.setBuildMode(mode);
    input.addPackage(pkgs.wasm4);
    input.install();

    try tests(b, mode);

    const zowOS = try addWasm4Cart(b, "zowOS", "examples/zow-os/main.zig");
    zowOS.addPackage(pkgs.zow4);
    try addWasm4RunStep(b, "run-zowOS", zowOS);
    const zowOS_opt = try addWasmOpt(b, "zowOS", zowOS);

    const counter = try addWasm4Cart(b, "counter", "examples/counter.zig");
    counter.addPackage(pkgs.zow4);
    try addWasm4RunStep(b, "run-counter", counter);
    const counter_opt = try addWasmOpt(b, "counter", counter);

    const bezier = try addWasm4Cart(b, "bezier", "examples/bezier.zig");
    bezier.addPackage(pkgs.zow4);
    try addWasm4RunStep(b, "run-bezier", bezier);
    const bezier_opt = try addWasmOpt(b, "bezier", bezier);

    const optimize_step = b.step("opt", "Builds example carts and optimizes them with wasm-opt (must be installed)");
    optimize_step.dependOn(zowOS_opt);
    optimize_step.dependOn(counter_opt);
    optimize_step.dependOn(bezier_opt);
    if (mode == .ReleaseSmall) {
        b.getInstallStep().dependOn(optimize_step);
        try optimize_step.make();
    }
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
