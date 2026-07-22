const std = @import("std");
const print = std.debug.print;

pub const Mode = enum { HIGH, MED, LOW };

pub const PipelineConfig = struct { color_mode: Mode, blur_mode: Mode, apply_blur: bool, sharpen_mode: Mode, quantize_mode: Mode, apply_quantization: bool, saturation_mode: Mode, apply_saturation: bool };

pub const Color = struct { r: f32, g: f32, b: f32 };

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

pub fn Quantize(comptime cfg: PipelineConfig, color: f32) f32 {
    // downsample the pixel into different "resolutions"
    const res: f32 = switch (cfg.quantize_mode) {
        .HIGH => @round(color * 255.0) / 255.0,
        .MED => @round(color * 16.0) / 16.0,
        .LOW => if (color > 0.5) 1.0 else 0.0,
    };
    return res;
}

pub fn Blur(comptime cfg: PipelineConfig, item: *Color, n: Neighbors) void {
    if (cfg.blur_mode == Mode.LOW) {
        item.r = (n.middleLeft.r + item.r + n.middleRight.r) / 3.0;
        item.g = (n.middleLeft.g + item.g + n.middleRight.g) / 3.0;
        item.b = (n.middleLeft.b + item.b + n.middleRight.b) / 3.0;
    } else if (cfg.blur_mode == Mode.MED) {
        item.r = (n.topMiddle.r + n.bottomMiddle.r + n.middleLeft.r + n.middleRight.r + item.r) / 5.0;
        item.g = (n.topMiddle.g + n.bottomMiddle.g + n.middleLeft.g + n.middleRight.g + item.g) / 5.0;
        item.b = (n.topMiddle.b + n.bottomMiddle.b + n.middleLeft.b + n.middleRight.b + item.b) / 5.0;
    } else if (cfg.blur_mode == Mode.HIGH) {
        item.r = (n.topLeft.r + n.middleLeft.r + n.bottomLeft.r + n.bottomMiddle.r + n.bottomRight.r + n.middleRight.r + n.topRight.r + n.topMiddle.r + item.r) / 9.0;
        item.g = (n.topLeft.g + n.middleLeft.g + n.bottomLeft.g + n.bottomMiddle.g + n.bottomRight.g + n.middleRight.g + n.topRight.g + n.topMiddle.g + item.g) / 9.0;
        item.b = (n.topLeft.b + n.middleLeft.b + n.bottomLeft.b + n.bottomMiddle.b + n.bottomRight.b + n.middleRight.b + n.topRight.b + n.topMiddle.b + item.b) / 9.0;
    }
}

pub fn Saturation(comptime cfg: PipelineConfig, item: *Color) void {
    const luma = (0.299 * item.r) + (0.587 * item.g) + (0.144 * item.b);

    const delta: f32 = switch (cfg.saturation_mode) {
        .LOW => 1.5,
        .MED => 2.5,
        .HIGH => 3.5,
    };

    item.r = std.math.clamp(luma + (delta * (item.r - luma)), 0.0, 255.0);
    item.g = std.math.clamp(luma + (delta * (item.g - luma)), 0.0, 255.0);
    item.b = std.math.clamp(luma + (delta * (item.b - luma)), 0.0, 255.0);
}

const SIZE = 150;

pub fn Process(comptime cfg: PipelineConfig, mat: *[SIZE][SIZE]Color) void {
    // low: get the avg of next, prev and curr
    // med: get the avg of 3by3
    // high: get the average of 3by3, and add jitter

    for (1..(SIZE - 1)) |row_num| {
        // item is mutable
        for (1..(SIZE - 1)) |col_num| {
            // item is Color
            // want to mutate it here
            const item = &mat[row_num][col_num];

            if (cfg.apply_blur) {
                const n = Neighbors{
                    .topLeft = mat[row_num - 1][col_num - 1],
                    .middleLeft = mat[row_num][col_num - 1],
                    .bottomLeft = mat[row_num + 1][col_num - 1],
                    .bottomMiddle = mat[row_num + 1][col_num],
                    .bottomRight = mat[row_num + 1][col_num + 1],
                    .middleRight = mat[row_num][col_num + 1],
                    .topRight = mat[row_num - 1][col_num + 1],
                    .topMiddle = mat[row_num - 1][col_num],
                };

                Blur(cfg, item, n);
            }

            if (cfg.apply_quantization) {
                // 3. Perform Step 2: Execute element-wise quantization map on the blurred output
                item.r = Quantize(cfg, item.r);
                item.g = Quantize(cfg, item.g);
                item.b = Quantize(cfg, item.b);
            }

            if (cfg.apply_saturation) {
                Saturation(cfg, item);
            }
        }
    }
}

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
            const rf = prng.random().float(f64) * 1.0;
            const gf = prng.random().float(f64) * 1.0;
            const bf = prng.random().float(f64) * 1.0;

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

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // write the image
    // _ = try writeImageToFile(io, "input_image.txt");

    // read the image
    var my_image: [SIZE][SIZE]Color = undefined;
    _ = try readImageFromFile(io, "input_image.txt", &my_image);

    // try printImage(my_image);

    const config = PipelineConfig{
        .color_mode = .MED,
        .blur_mode = .MED,
        .apply_blur = true,
        .sharpen_mode = .MED,
        .quantize_mode = .MED,
        .apply_quantization = true,
        .saturation_mode = .MED,
        .apply_saturation = true,
    };

    var start_time = std.Io.Clock.now(.awake, io);

    Process(config, &my_image);

    const end_time = std.Io.Clock.now(.awake, io);

    const duration = start_time.durationTo(end_time);

    std.debug.print("Processed in: {} ns\n", .{duration.toNanoseconds()});
}
