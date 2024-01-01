const std = @import("std");
const Regex = @import("lib/zig-regex/src/regex.zig").Regex;

const stdout = std.io.getStdOut();
var buffered_writer = std.io.bufferedWriter(stdout.writer());
const writer = buffered_writer.writer();

fn println(comptime format: []const u8, args: anytype) !void {
    try writer.print(format ++ "\n", args);
}

fn printlnf(comptime format: []const u8, args: anytype) !void {
    try writer.print(format ++ "\n", args);
    try buffered_writer.flush();
}

const ProgramError = error{
    InvalidArgument,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        try printlnf("Usage: {s} <pattern> <file>", .{args[0]});
        return ProgramError.InvalidArgument;
    }

    const path = try std.fs.realpathAlloc(allocator, args[args.len - 1]);
    defer allocator.free(path);

    const file = try std.fs.openFileAbsolute(path, .{});
    var buffered_file_reader = std.io.bufferedReader(file.reader());
    const file_reader = buffered_file_reader.reader();

    const file_string = try file_reader.readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(file_string);

    var lines = std.mem.splitSequence(u8, file_string, "\n");

    var re = try Regex.compile(allocator, args[args.len - 2]);
    defer re.deinit();

    var line_number: u32 = 1;

    while (lines.next()) |line| {
        if (try re.partialMatch(line)) {
            try printlnf("{d}: {s}", .{ line_number, line });
        }

        line_number += 1;
    }

    try buffered_writer.flush();
}
