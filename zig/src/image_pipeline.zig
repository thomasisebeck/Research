const std = @import("std");
const print = std.debug.print;

pub const Quality = enum { HIGH, MED, LOW };

pub const PipelineConfig = struct { color_mode: Quality, blur_mode: Quality, apply_blur: bool, sharpen_mode: Quality, quantize_mode: Quality, apply_quantization: bool };

pub const Color = struct { r: f32, g: f32, b: f32 };

pub fn Quantize(comptime cfg: PipelineConfig, color: f32) f32 {
    // downsample the pixel into different "resolutions"
    const res: f32 = switch (cfg.quantize_mode) {
        .HIGH => @round(color * 255.0) / 255.0,
        .MED => @round(color * 16.0) / 16.0,
        .LOW => if (color > 0.5) 1.0 else 0.0,
    };
    return res;
}

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

pub fn Blur(comptime cfg: PipelineConfig, item: *Color, n: Neighbors) void {
    if (cfg.blur_mode == Quality.LOW) {
        item.r = (n.middleLeft.r + item.r + n.middelRight.r) / 3.0;
        item.g = (n.middleLeft.g + item.g + n.middelRight.g) / 3.0;
        item.b = (n.middleLeft.b + item.b + n.middelRight.b) / 3.0;
    } else if (cfg.blur_mode == Quality.MED) {
        item.r = (n.topMiddle.r + n.bottomMiddle.r + n.middleLeft.r + n.middelRight.r + item.r) / 5.0;
        item.g = (n.topMiddle.g + n.bottomMiddle.g + n.middleLeft.g + n.middelRight.g + item.g) / 5.0;
        item.b = (n.topMiddle.b + n.bottomMiddle.b + n.middleLeft.b + n.middelRight.b + item.b) / 5.0;
    } else if (cfg.blur_mode == Quality.HIGH) {
        item.r = (n.topLeft.r + n.middleLeft.r + n.bottomLeft.r + n.bottomMiddle.r + n.bottomRight.r + n.middelRight.r + n.topRight.r + n.topMiddle.r + item.r) / 9.0;
        item.g = (n.topLeft.g + n.middleLeft.g + n.bottomLeft.g + n.bottomMiddle.g + n.bottomRight.g + n.middelRight.g + n.topRight.g + n.topMiddle.g + item.g) / 9.0;
        item.b = (n.topLeft.b + n.middleLeft.b + n.bottomLeft.b + n.bottomMiddle.b + n.bottomRight.b + n.middelRight.b + n.topRight.b + n.topMiddle.b + item.b) / 9.0;
    }
}

const SIZE = 1000;

pub fn Process(comptime cfg: PipelineConfig, mat: *[SIZE][SIZE]Color) void {
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

pub fn main(init: std.process.Init) !void {
    const io = init.io;

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

    //print("THIS IS THE IMAGE: ", .{});
    //_ = try printImage(&my_image);

    // 3. Set up a sample configuration
    const config = PipelineConfig{
        .color_mode = .HIGH,
        .apply_blur = true,
        .apply_quantization = true,
        .blur_mode = .LOW,
        .sharpen_mode = .LOW,
        .quantize_mode = .HIGH,
    };

    var start_time = std.Io.Clock.now(.awake, io);

    Process(config, &my_image);

    const end_time = std.Io.Clock.now(.awake, io);

    const duration = start_time.durationTo(end_time);

    //print("AFTER BLUR (LOW): ", .{});
    //_ = try printImage(&my_image);

    std.debug.print("Processed in: {} ns\n", .{duration.toNanoseconds()});
}
