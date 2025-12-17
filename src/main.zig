pub fn main() !void {
    const allocator = mimalloc.basic_allocator;
    const params = comptime clap.parseParamsComptime(
        \\--input <str>   zig source file, default stdin
        \\--output <str>  output file path, default stdout
        \\--pretty        pretty print the output
    );

    var stderr_buffer: [1024]u8 = undefined;
    var stderr = std.fs.File.stderr().writer(&stderr_buffer);

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        // Report useful error and exit.
        diag.report(&stderr.interface, err) catch {};
        return err;
    };
    defer res.deinit();

    var in_file = file: {
        if (res.args.input) |input| {
            break :file try std.fs.cwd().openFile(input, .{});
        } else {
            break :file std.fs.File.stdin();
        }
    };
    defer in_file.close();

    const in_content = content: {
        var in_buffer: [4 * 1024]u8 = undefined;
        var in_reader = in_file.reader(&in_buffer);
        var buffer: std.ArrayList(u8) = .empty;
        defer buffer.deinit(allocator);
        try in_reader.interface.appendRemaining(allocator, &buffer, .unlimited);
        break :content try buffer.toOwnedSliceSentinel(allocator, 0);
    };
    defer allocator.free(in_content);

    var out_file = file: {
        if (res.args.output) |output| {
            break :file try std.fs.cwd().createFile(output, .{});
        } else {
            break :file std.fs.File.stdout();
        }
    };
    defer out_file.close();

    var out_buffer: [4 * 1024]u8 = undefined;
    var out_writer = out_file.writer(&out_buffer);

    const pretty = res.args.pretty == 1;

    try astdump.emit(allocator, in_content, &out_writer.interface, pretty);
}

const std = @import("std");
const clap = @import("clap");
const mimalloc = @import("mimalloc");
const astdump = @import("zigastdump");
