const std = @import("std");
pub const IMAGE_SIZE = 500;
const print = std.debug.print;
const assert = std.debug.assert;

pub const Colour = struct { r: f32, g: f32, b: f32 };

pub const Mode = enum { HIGH, MED, LOW };

pub const PipelineConfig = struct { colour_mode: Mode, blur_mode: Mode, apply_blur: bool, sharpen_mode: Mode, quantise_mode: Mode, apply_quantisation: bool, saturation_mode: Mode, apply_saturation: bool };

pub const Neighbours = struct {
    topLeft: Colour,
    middleLeft: Colour,
    bottomLeft: Colour,
    bottomMiddle: Colour,
    bottomRight: Colour,
    middleRight: Colour,
    topRight: Colour,
    topMiddle: Colour,
};

pub fn printImage(mat: [IMAGE_SIZE][IMAGE_SIZE]Colour) !void {
    print("[\n", .{});

    for (mat) |row| {
        print("  [ ", .{});
        for (row) |pixel| {
            // Formatting the floats to 2 decimal places so the columns line up neatly
            print("({d:.2},{d:.2},{d:.2}) ", .{ pixel.r, pixel.g, pixel.b });
        }
        print("]\n", .{});
    }

    print("]\n", .{});
}

pub fn generateRandomArray(comptime array_size: usize, io: anytype, path: []const u8) !void {
    var file = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
    defer file.close(io);

    // 2. Wrap the file in a buffered writer to drastically reduce system call overhead
    var file_writer = file.writer(io, &.{});

    // 3. Obtain a high-quality seed from the OS cryptographically secure random source
    var prng = std.Random.DefaultPrng.init(12345);

    for (0..array_size) |_| {
        // Generates an integer between 1 and 3 inclusive
        const num = prng.random().intRangeAtMost(u8, 1, 3);

        try file_writer.interface.print("{}\n", .{num});
    }
}

pub fn writeImageToFile(io: anytype, path: []const u8) !void {
    var file = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
    defer file.close(io);

    var file_writer = file.writer(io, &.{});

    var prng = std.Random.DefaultPrng.init(12345);

    // 2. Safely populate the matrix with example pixel data
    for (0..IMAGE_SIZE) |_| {
        for (0..IMAGE_SIZE) |_| {
            // Generate distinct procedural values between 0.0 and 1.0 based on layout
            const rf = prng.random().float(f32);
            const gf = prng.random().float(f32);
            const bf = prng.random().float(f32);

            std.debug.print("{d:.6} {d:.6} {d:.6}\n", .{ rf, gf, bf });
            try file_writer.interface.print("{d:.6} {d:.6} {d:.6}\n", .{ rf, gf, bf });
        }
    }
}

pub fn readArrayFromFile(comptime array_size: usize, io: std.Io, path: []const u8) ![array_size]i64 {
    //var stdout_writer = std.Io.File.stdout().writer(io, &.{});
    //const stdout = &stdout_writer.interface;
    var file_buf: [array_size * 32]u8 = undefined;
    const file = try std.Io.Dir.cwd().readFile(io, path, &file_buf);

    // init the array to all 0, len 5
    var input_array = [_]i64{0} ** array_size;
    var counter: u32 = 0;

    var iter = std.mem.tokenizeScalar(u8, file, '\n');
    while (iter.next()) |line| {
        if (counter >= array_size) break;

        const clean_line = std.mem.trim(u8, line, "\r");

        // pass the buffer as base 10
        input_array[counter] = try std.fmt.parseInt(i64, clean_line, 10);

        counter += 1;
    }

    assert(counter == array_size);

    return input_array;
}

pub fn readImageFromFile(io: anytype, path: []const u8, mat: *[IMAGE_SIZE][IMAGE_SIZE]Colour) !i32 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);

    var file_buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &file_buffer);
    var row: u32 = 0;
    var col: u32 = 0;
    var channel: u32 = 0;

    while (try reader.interface.takeDelimiter('\n')) |line| {
        var iterator = std.mem.splitScalar(u8, line, ' ');
        channel = 0;
        while (iterator.next()) |fragment| {
            const val = try std.fmt.parseFloat(f32, fragment);
            switch (channel) {
                0 => mat[row][col].r = val,
                1 => mat[row][col].g = val,
                2 => mat[row][col].b = val,
                else => {},
            }
            channel += 1;
        }
        col += 1;
        if (col >= IMAGE_SIZE) {
            col = 0;
            row += 1;
        }
    }

    return 0;
}
