pub const AstEmitter = @import("AstEmitter.zig");

pub fn emit(allocator: Allocator, source: [:0]const u8, out_writer: *std.Io.Writer, pretty: bool) !void {
    var ast = try Ast.parse(allocator, source, .zig);
    defer ast.deinit(allocator);

    var str: Stringify = .{
        .options = .{ .whitespace = if (pretty) .indent_4 else .minified },
        .writer = out_writer,
    };

    var emitter: AstEmitter = .{
        .ast = &ast,
        .str = &str,
    };
    try str.beginObject();
    try str.objectField("decls");
    try emitter.emit();
    try str.endObject();
    try out_writer.flush();
}

const std = @import("std");
const ArrayList = std.ArrayList;
const Ast = std.zig.Ast;
const Stringify = std.json.Stringify;
const mimalloc = @import("mimalloc");
const Allocator = std.mem.Allocator;
