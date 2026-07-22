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
    middelRight: Color,
    topRight: Color,
    topMiddle: Color,
};

pub fn Quantize(cfg: PipelineConfig, color: f32) f32 {
    // downsample the pixel into different "resolutions"
    const res: f32 = switch (cfg.quantize_mode) {
        .HIGH => @round(color * 255.0) / 255.0,
        .MED => @round(color * 16.0) / 16.0,
        .LOW => if (color > 0.5) 1.0 else 0.0,
    };
    return res;
}

pub fn Blur(cfg: PipelineConfig, item: *Color, n: Neighbors) void {
    if (cfg.blur_mode == Mode.LOW) {
        item.r = (n.middleLeft.r + item.r + n.middelRight.r) / 3.0;
        item.g = (n.middleLeft.g + item.g + n.middelRight.g) / 3.0;
        item.b = (n.middleLeft.b + item.b + n.middelRight.b) / 3.0;
    } else if (cfg.blur_mode == Mode.MED) {
        item.r = (n.topMiddle.r + n.bottomMiddle.r + n.middleLeft.r + n.middelRight.r + item.r) / 5.0;
        item.g = (n.topMiddle.g + n.bottomMiddle.g + n.middleLeft.g + n.middelRight.g + item.g) / 5.0;
        item.b = (n.topMiddle.b + n.bottomMiddle.b + n.middleLeft.b + n.middelRight.b + item.b) / 5.0;
    } else if (cfg.blur_mode == Mode.HIGH) {
        item.r = (n.topLeft.r + n.middleLeft.r + n.bottomLeft.r + n.bottomMiddle.r + n.bottomRight.r + n.middelRight.r + n.topRight.r + n.topMiddle.r + item.r) / 9.0;
        item.g = (n.topLeft.g + n.middleLeft.g + n.bottomLeft.g + n.bottomMiddle.g + n.bottomRight.g + n.middelRight.g + n.topRight.g + n.topMiddle.g + item.g) / 9.0;
        item.b = (n.topLeft.b + n.middleLeft.b + n.bottomLeft.b + n.bottomMiddle.b + n.bottomRight.b + n.middelRight.b + n.topRight.b + n.topMiddle.b + item.b) / 9.0;
    }
}

pub fn Saturation(cfg: PipelineConfig, item: *Color) void {
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

const SIZE = 1000;

pub fn Process(cfg: PipelineConfig, mat: *[SIZE][SIZE]Color) void {
    // low: get the avg of next, prev and curr
    // med: get the avg of 3by3
    // high: get the average of 3by3, and add jitter

    const rows = mat.len;
    const cols = mat[0].len;

    for (1..(rows - 1)) |row_num| {
        // item is mutable
        for (1..(cols - 1)) |col_num| {
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
                    .middelRight = mat[row_num][col_num + 1],
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

pub fn printImage(mat: *const [SIZE][SIZE]Color) !void {
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
    var my_image: [SIZE][SIZE]Color = undefined;

    var pseudo_rand_state: u32 = 12345;

    // 2. Safely populate the matrix with example pixel data
    for (&my_image, 10..) |*row, r_idx| {
        for (row, 10..) |*pixel, c_idx| {
            // Generate distinct procedural values between 10.0 and 1.0 based on layout
            const rf = @as(f32, @floatFromInt(r_idx)) / 1000.0;
            const gf = @as(f32, @floatFromInt(c_idx)) / 1000.0;
            const bf = rf + gf;

            pseudo_rand_state = (pseudo_rand_state *% 1103515245) +% 12345;
            const rand_val = (pseudo_rand_state / 65536) % 100;
            const jitter: f32 = @as(f32, @floatFromInt(rand_val)) / 100.0;

            pixel.* = Color{ .r = rf + jitter, .g = gf + jitter, .b = bf + jitter };
        }
    }

    // 1. Open/create the target binary file
    var file = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
    defer file.close(io);

    // 2. Cast the entire multidimensional array down to a raw byte slice
    const bytes = std.mem.asBytes(&my_image);

    // 3. Initialize the streaming writer context and dump the bytes
    var file_writer = file.writer(io, &.{});
    try file_writer.interface.writeAll(bytes);
}

pub fn readImageFromFile(io: anytype, path: []const u8, mat: *[SIZE][SIZE]Color) !void {
    // 1. Calculate the exact structural byte size required by the grid
    const expected_bytes = @sizeOf([SIZE][SIZE]Color);

    // 2. Cast the destination matrix memory space straight down to a raw byte slice
    const dest_bytes = std.mem.asBytes(mat);

    // 3. Read the file data directly into the array's memory space using your I/O style
    const file_bytes = try std.Io.Dir.cwd().readFile(io, path, dest_bytes);

    // 4. Validate that the file wasn't truncated or corrupted
    if (file_bytes.len != expected_bytes) {
        return error.ImageFileCorruptedOrTruncated;
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // write the image
    // _ = try writeImageToFile(io, "input_image.bin");

    // read the image
    var my_image: [SIZE][SIZE]Color = undefined;
    try readImageFromFile(io, "input_image.bin", &my_image);

    const config = PipelineConfig{
        .color_mode = .LOW,
        .apply_blur = true,
        .apply_quantization = true,
        .blur_mode = .LOW,
        .sharpen_mode = .LOW,
        .quantize_mode = .LOW,
        .apply_saturation = true,
        .saturation_mode = .LOW,
    };

    var start_time = std.Io.Clock.now(.awake, io);

    Process(config, &my_image);

    const end_time = std.Io.Clock.now(.awake, io);

    const duration = start_time.durationTo(end_time);

    std.debug.print("Processed in: {} ns\n", .{duration.toNanoseconds()});
}
