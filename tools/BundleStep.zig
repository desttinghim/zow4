//! A small script for bundling carts on to the native WASM4 executable
const std = @import("std");

const KB = 1024;
const MB = 1024 * KB;

const BundleStep = @This();

step: std.build.Step,
builder: *std.build.Builder,
cart_path: std.build.FileSource,
exec_path: std.build.FileSource,
output_name: []const u8,
title: []const u8,

pub fn create(b: *std.build.Builder, opt: struct {
    cart_path: std.build.FileSource,
    exec_path: std.build.FileSource,
    output_name: []const u8,
    title: []const u8,
}) *@This() {
    var result = b.allocator.create(BundleStep) catch @panic("memory");
    result.* = BundleStep{
        .step = std.build.Step.init(.custom, "bundle a wasm4 cart with the native wasm4 runtime", b.allocator, make),
        .builder = b,
        .cart_path = opt.cart_path,
        .exec_path = opt.exec_path,
        .output_name = opt.output_name,
        .title = opt.title,
    };
    // result.builder.installBinFile(opt.output_name, opt.output_name);
    return result;
}

const FileFooter = extern struct {
    /// Should be the 4 byte ASCII string "CART" (1414676803)
    magic: [4]u8,

    /// Window title
    title: [128]u8,

    /// Length of the cart.wasm bytes used to offset backwards from the footer
    cartLength: u32,
};

fn make(step: *std.build.Step) !void {
    const this = @fieldParentPtr(BundleStep, "step", step);

    const exe_src = this.exec_path.getPath(this.builder);
    const cart_src = this.cart_path.getPath(this.builder);
    // const output = this.output_name;
    const output = this.builder.getInstallPath(.bin, this.output_name);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const cwd = std.fs.cwd();

    const cart_file = try cwd.openFile(cart_src, .{});
    defer cart_file.close();
    const cart = try cart_file.readToEndAlloc(allocator, 1 * MB);
    defer allocator.free(cart);

    const exe_file = try cwd.openFile(exe_src, .{});
    defer exe_file.close();
    const exe = try exe_file.readToEndAlloc(allocator, 10 * MB);
    defer allocator.free(exe);

    var data = std.ArrayList(u8).init(allocator);
    defer data.deinit();
    const writer = data.writer();

    try writer.writeAll(exe);
    try writer.writeAll(cart);

    var footer = FileFooter{
        .magic = .{ 'C', 'A', 'R', 'T' },
        .title = undefined,
        .cartLength = @truncate(u32, cart.len),
    };

    _ = try std.fmt.bufPrintZ(&footer.title, "{s}", .{this.title});

    try writer.writeStruct(footer);

    std.log.warn("{s}", .{output});
    cwd.makePath(this.builder.getInstallPath(.bin, "")) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };
    try cwd.writeFile(output, data.items);
}
