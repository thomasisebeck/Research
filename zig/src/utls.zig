const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;

pub fn printArray(arr: []const i32) !void {
    print("[ ", .{});

    for (arr) |el| {
        print("{} ", .{el});
    }

    print("]\n", .{});
}

pub fn readFromFile(comptime size: usize, comptime T: type, io: std.Io, path: []const u8) ![size]T {
    //var stdout_writer = std.Io.File.stdout().writer(io, &.{});
    //const stdout = &stdout_writer.interface;
    var file_buf: [size * 4]u8 = undefined;
    const file = try std.Io.Dir.cwd().readFile(io, path, &file_buf);

    // init the array to all 0, len 5
    var input_array = [_]i32{0} ** size;
    var counter: usize = 0;

    var iter = std.mem.splitScalar(u8, file, ',');
    while (iter.next()) |part| {
        if (counter >= size)
            break;

        // pass the buffer as base 10
        input_array[counter] = try std.fmt.parseInt(i32, part, 10);

        counter += 1;
    }

    assert(counter == size);

    return input_array;
}
