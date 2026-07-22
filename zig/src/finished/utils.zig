const std = @import("std");
pub const SIZE = 150;
const print = std.debug.print;

pub const Color = struct { r: f32, g: f32, b: f32 };

pub const Mode = enum { HIGH, MED, LOW };

pub const PipelineConfig = struct { color_mode: Mode, blur_mode: Mode, apply_blur: bool, sharpen_mode: Mode, quantize_mode: Mode, apply_quantization: bool, saturation_mode: Mode, apply_saturation: bool };

// Helper container struct to cleanly bundle neighborhood data for the Blur function
pub const Neighbors = struct {
    topLeft: Color,
    middleLeft: Color,
    bottomLeft: Color,
    bottomMiddle: Color,
    bottomRight: Color,
    middleRight: Color,
    topRight: Color,
    topMiddle: Color,
};

pub fn printImage(mat: [SIZE][SIZE]Color) !void {
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

pub fn writeImageToFile(io: anytype, path: []const u8) !void {
    var file = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
    defer file.close(io);

    var file_writer = file.writer(io, &.{});

    var prng = std.Random.DefaultPrng.init(12345);

    // 2. Safely populate the matrix with example pixel data
    for (0..SIZE) |_| {
        for (0..SIZE) |_| {
            // Generate distinct procedural values between 0.0 and 1.0 based on layout
            const rf = prng.random().float(f32);
            const gf = prng.random().float(f32);
            const bf = prng.random().float(f32);

            std.debug.print("{d:.6} {d:.6} {d:.6}\n", .{ rf, gf, bf });
            try file_writer.interface.print("{d:.6} {d:.6} {d:.6}\n", .{ rf, gf, bf });
        }
    }
}

pub fn readImageFromFile(io: anytype, path: []const u8, mat: *[SIZE][SIZE]Color) !i32 {
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
        if (col >= SIZE) {
            col = 0;
            row += 1;
        }
    }

    return 0;
}
