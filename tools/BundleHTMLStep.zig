//! A small script for bundling carts into a single html file
const std = @import("std");

const KB = 1024;
const MB = 1024 * KB;

const BundleStep = @This();

step: std.build.Step,
builder: *std.build.Builder,
cart_path: std.build.FileSource,
wasm4_path: std.build.FileSource,
output_name: []const u8,
title: []const u8,
description: []const u8,
icon_url: ?[]const u8,

pub fn create(b: *std.build.Builder, opt: struct {
    cart_path: std.build.FileSource,
    exec_path: std.build.FileSource,
    output_name: []const u8 = "index.html",
    title: []const u8 = "WASM-4",
    description: []const u8 = "A WASM-4 Game",
    icon_url: ?[]const u8 = null,
}) *@This() {
    var result = b.allocator.create(BundleStep) catch @panic("memory");
    result.* = BundleStep{
        .step = std.build.Step.init(.custom, "bundle a wasm4 cart with the native wasm4 runtime", b.allocator, make),
        .builder = b,
        .cart_path = opt.cart_path,
        .exec_path = opt.exec_path,
        .output_name = opt.output_name,
        .title = opt.title,
        .description = opt.description,
        .icon_url = opt.icon_url,
    };
    // result.builder.installBinFile(opt.output_name, opt.output_name);
    return result;
}

const template =
    \\<!doctype html>
    \\<html lang="en">
    \\  <head>
    \\    <meta charset="utf-8" />
    \\    <meta
    \\      name="viewport"
    \\      content="width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=1, user-scalable=no"
    \\    />
    \\    {[metadata]s}
    \\    {[description]s}
    \\    {[iconUrl]s}
    \\    <title>{[title]s}</title>
    \\    <style type="text/css" id="wasm4-css">{[css]s}</style>
    \\  </head>
    \\  <body>
    \\    <div class="container">
    \\      <div id="content">
    \\        <div class="infobox">
    \\          <h2 id="title"></h2>
    \\          <h4 id="author"></h4>
    \\          <span class="play-button"></span>
    \\        </div>
    \\        <div id="screenshot"></div>
    \\      </div>
    \\    </div>
    \\    <div id="gamepad">
    \\      <div id="gamepad-dpad"></div>
    \\      <div id="gamepad-action1"></div>
    \\      <div id="gamepad-action2"></div>
    \\    </div>
    \\    <script
    \\      id="wasm4-cart-json"
    \\      type="application/json"
    \\    >{[cartJSON]s}</script>
    \\    <script id="wasm4-js">{[js]s}</script>
    \\  </body>
    \\</html>
;

const TemplateVars = struct {
    metadata: []const u8,
    description: []const u8,
    iconUrl: []const u8,
    title: []const u8,
    css: []const u8,
    cartJSON: []const u8,
    js: []const u8,
};

fn make(step: *std.build.Step) !void {
    const this = @fieldParentPtr(BundleStep, "step", step);

    const cart_path = this.cart_path.getPath(this.builder);
    const output = this.builder.getInstallPath(.bin, "index.html");

    // TODO: Make a zig package of wasm4
    const wasm4_repo = this.wasm4.getPath(this.builder);
    const wasm4_dir = try std.fs.openDirAbsolute(wasm4_repo);
    _ = wasm4_dir;

    // NOTE: Vite and node are needed to build wasm4
    const css_path = "wasm4/runtimes/web/dist/wasm4.css";
    const js_path = "wasm4/runtimes/web/dist/wasm4.js";

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const cwd = std.fs.cwd();

    const cart = cart: {
        const cart_file = try cwd.openFile(cart_path, .{});
        defer cart_file.close();
        break :cart try cart_file.readToEndAlloc(allocator, 1 * MB);
    };
    defer allocator.free(cart);

    const cart_z85 = try Z85.encode(cart);
    defer this.builder.allocator.free(cart_z85);
    const cartJSON = std.json.stringifyAlloc(this.builder.allocator, .{.WASM4_CART = cart_z85, .WASM4_CART_SIZE = cart.len}, .{});
    defer this.builder.allocator.free(cartJSON);

    const css = css: {
        const css_file = try cwd.openFile(css_path, .{});
        defer css_file.close();
        break :css try css_file.readToEndAlloc(allocator, 1 * MB);
    };
    defer allocator.free(css);

    const js = js: {
        const js_file = try cwd.openFile(js_path, .{});
        defer js_file.close();
        break :js try js_file.readToEndAlloc(allocator, 1 * MB);
    };
    defer allocator.free(js);

    // TODO: Get css and js files from WASM4 repo
    const metadata = try std.fmt.allocPrint(this.builder.allocator, "<meta name=\"{s}\" content=\"{s}\">", .{ "generator", "WASM-4 2.4" });

    const vars = TemplateVars{
        .metadata = metadata,
        .description = this.description,
        // TODO: Add support for icon url
        .iconUrl = this.icon_url orelse "",
        .title = this.title,
        .css = css,
        .cartJSON = cartJSON,
        .js = js,
    };

    const renderedHTML = try std.fmt.allocPrint(this.builder.allocator, template, vars);
    defer this.builder.allocator.free(renderedHTML);

    cwd.makePath(this.builder.getInstallPath(.bin, "")) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };
    try cwd.writeFile(output, renderedHTML);
}

// Copyright Notice for z85 encode/decode, adapted from
// https://github.com/zeromq/rfc/blob/master/src/spec_32.c
// See also: https://rfc.zeromq.org/spec/32/
//  --------------------------------------------------------------------------
//  Reference implementation for rfc.zeromq.org/spec:32/Z85
//
//  This implementation provides a Z85 codec as an easy-to-reuse C class
//  designed to be easy to port into other languages.

//  --------------------------------------------------------------------------
//  Copyright (c) 2010-2013 iMatix Corporation and Contributors
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//  --------------------------------------------------------------------------
const Z85 = struct {
    const encoder: *const [85:0]u8 =
        "0123456789" ++
        "abcdefghij" ++
        "klmnopqrst" ++
        "uvwxyzABCD" ++
        "EFGHIJKLMN" ++
        "OPQRSTUVWX" ++
        "YZ.-:+=^!/" ++
        "*?&<>()[]{" ++
        "}@%$#";

    const decoder: [96]u8 = [_]u8{
        0x00, 0x44, 0x00, 0x54, 0x53, 0x52, 0x48, 0x00,
        0x4B, 0x4C, 0x46, 0x41, 0x00, 0x3F, 0x3E, 0x45,
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x40, 0x00, 0x49, 0x42, 0x4A, 0x47,
        0x51, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A,
        0x2B, 0x2C, 0x2D, 0x2E, 0x2F, 0x30, 0x31, 0x32,
        0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A,
        0x3B, 0x3C, 0x3D, 0x4D, 0x00, 0x4E, 0x43, 0x00,
        0x00, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
        0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20,
        0x21, 0x22, 0x23, 0x4F, 0x00, 0x50, 0x00, 0x00,
    };

    /// Takes a slice of bytes, and returns a z85 encoded string. User owns the returned slice.
    fn encode(alloc: std.mem.Allocator, data: []const u8) ![]const u8 {
        if (data.len % 4 != 0) return error.LenNotDivisibleBy4;
        const encoded_size = data.len * 5 / 4;
        const encoded = try alloc.alloc(u8, encoded_size);
        var char_idx: usize = 0;
        var byte_idx: usize = 0;
        var value: usize = 0;

        while (byte_idx < data.len) {
            value = value * 256 + data[byte_idx];
            byte_idx += 1;
            if (byte_idx % 4 == 0) {
                var divisor: usize = 85 * 85 * 85 * 85;
                while (divisor != 0) : (divisor /= 85) {
                    encoded[char_idx] = encoder[value / divisor % 85];
                    char_idx += 1;
                }
                value = 0;
            }
        }

        std.debug.assert(char_idx == encoded_size);
        return encoded;
    }

    /// Takes a z85 encoded string, and returns a slice of bytes. User owns the returned slice.
    fn decode(alloc: std.mem.Allocator, data: []const u8) ![]const u8 {
        if (data.len % 5 != 0) return error.LenNotDivisibleBy5;
        const decoded_size = data.len * 4 / 5;
        const decoded = try alloc.alloc(u8, decoded_size);

        var byte_idx: usize = 0;
        var char_idx: usize = 0;
        var value: usize = 0;
        while (char_idx < data.len) {
            value = value * 85 + decoder[@intCast(u8, data[char_idx] - 32)];
            char_idx += 1;
            if (char_idx % 5 == 0) {
                var divisor: usize = 256 * 256 * 256;
                while (divisor != 0) : (divisor /= 256) {
                    decoded[byte_idx] = @intCast(u8, value / divisor % 256);
                    byte_idx += 1;
                }
                value = 0;
            }
        }
        std.debug.assert(byte_idx == decoded_size);
        return decoded;
    }
};

test "Encode Z85" {
    const decoded = [8]u8{ 0x86, 0x4F, 0xD2, 0x6F, 0xB5, 0x59, 0xF7, 0x5B };
    const encoded = "HelloWorld";

    const try_encode = try Z85.encode(std.testing.allocator, &decoded);
    defer std.testing.allocator.free(try_encode);
    try std.testing.expectEqualSlices(u8, encoded, try_encode);
}

test "Decode Z85" {
    const decoded = [8]u8{ 0x86, 0x4F, 0xD2, 0x6F, 0xB5, 0x59, 0xF7, 0x5B };
    const encoded = "HelloWorld";

    const try_decode = try Z85.decode(std.testing.allocator, encoded);
    defer std.testing.allocator.free(try_decode);
    try std.testing.expectEqualSlices(u8, &decoded, try_decode);
}
