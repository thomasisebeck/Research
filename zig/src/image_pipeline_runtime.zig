const std = @import("std");
const print = std.debug.print;
const utils = @import("utils.zig");

const PR_TASK_PERF_EVENTS_ENABLE: usize = 32;
const PR_TASK_PERF_EVENTS_DISABLE: usize = 33;

// if statement
pub fn quantise(cfg: utils.PipelineConfig, colour: f32) f32 {
    // downsample the pixel into different "resolutions"
    var res: f32 = 0;

    if (cfg.quantise_mode == .HIGH)
        res = @round(colour * 255.0) / 255.0
    else if (cfg.quantise_mode == .MED)
        res = @round(colour * 16.0) / 16.0
    else if (colour > 0.5) res = 1.0 else res = 0.0;

    return res;
}

// switch statement
pub fn blur(cfg: utils.PipelineConfig, item: *utils.Colour, n: utils.Neighbours) void {
    switch (cfg.blur_mode) {
        utils.Mode.LOW => {
            item.r = (n.middleLeft.r + item.r + n.middleRight.r) / 3.0;
            item.g = (n.middleLeft.g + item.g + n.middleRight.g) / 3.0;
            item.b = (n.middleLeft.b + item.b + n.middleRight.b) / 3.0;
        },

        utils.Mode.MED => {
            item.r = (n.topMiddle.r + n.bottomMiddle.r + n.middleLeft.r + n.middleRight.r + item.r) / 5.0;
            item.g = (n.topMiddle.g + n.bottomMiddle.g + n.middleLeft.g + n.middleRight.g + item.g) / 5.0;
            item.b = (n.topMiddle.b + n.bottomMiddle.b + n.middleLeft.b + n.middleRight.b + item.b) / 5.0;
        },

        utils.Mode.HIGH => {
            item.r = (n.topLeft.r + n.middleLeft.r + n.bottomLeft.r + n.bottomMiddle.r + n.bottomRight.r + n.middleRight.r + n.topRight.r + n.topMiddle.r + item.r) / 9.0;
            item.g = (n.topLeft.g + n.middleLeft.g + n.bottomLeft.g + n.bottomMiddle.g + n.bottomRight.g + n.middleRight.g + n.topRight.g + n.topMiddle.g + item.g) / 9.0;
            item.b = (n.topLeft.b + n.middleLeft.b + n.bottomLeft.b + n.bottomMiddle.b + n.bottomRight.b + n.middleRight.b + n.topRight.b + n.topMiddle.b + item.b) / 9.0;
        },
    }
}

// switch expression
pub fn saturation(cfg: utils.PipelineConfig, item: *utils.Colour) void {
    const luma = (0.299 * item.r) + (0.587 * item.g) + (0.144 * item.b);

    const delta: f32 = switch (cfg.saturation_mode) {
        .LOW => 1.5,
        .MED => 2.5,
        .HIGH => 3.5,
    };

    // calculte the new value, and then clamp it
    item.r = std.math.clamp(luma + (delta * (item.r - luma)), 0.0, 1.0);
    item.g = std.math.clamp(luma + (delta * (item.g - luma)), 0.0, 1.0);
    item.b = std.math.clamp(luma + (delta * (item.b - luma)), 0.0, 1.0);
}

pub fn process(cfg: utils.PipelineConfig, mat: *[utils.IMAGE_SIZE][utils.IMAGE_SIZE]utils.Colour) void {
    // low: get the avg of next, prev and curr
    // med: get the avg of 3by3
    // high: get the average of 3by3, and add jitter

    for (1..(utils.IMAGE_SIZE - 1)) |row_num| {
        // item is mutable
        for (1..(utils.IMAGE_SIZE - 1)) |col_num| {
            // item is utils.Colour
            // want to mutate it here
            const item = &mat[row_num][col_num];

            if (cfg.apply_blur) {
                const n = utils.Neighbours{
                    .topLeft = mat[row_num - 1][col_num - 1],
                    .middleLeft = mat[row_num][col_num - 1],
                    .bottomLeft = mat[row_num + 1][col_num - 1],
                    .bottomMiddle = mat[row_num + 1][col_num],
                    .bottomRight = mat[row_num + 1][col_num + 1],
                    .middleRight = mat[row_num][col_num + 1],
                    .topRight = mat[row_num - 1][col_num + 1],
                    .topMiddle = mat[row_num - 1][col_num],
                };

                blur(cfg, item, n);
            }

            if (cfg.apply_quantisation) {
                // 3. Perform Step 2: Execute element-wise quantisation map on the blurred output
                item.r = quantise(cfg, item.r);
                item.g = quantise(cfg, item.g);
                item.b = quantise(cfg, item.b);
            }

            if (cfg.apply_saturation) {
                saturation(cfg, item);
            }
        }
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // write the image
    // _ = try utils.writeImageToFile(io, "input_image.txt");

    // read the image
    var my_image: [utils.IMAGE_SIZE][utils.IMAGE_SIZE]utils.Colour = undefined;
    _ = try utils.readImageFromFile(io, "input_image.txt", &my_image);

    // try printImage(my_image);

 // LOW
//const config = utils.PipelineConfig{
//    .colour_mode = .LOW,
//    .blur_mode = .LOW,
//    .apply_blur = true,
//    .sharpen_mode = .LOW,
//    .quantise_mode = .LOW,
//    .apply_quantisation = false,
//    .saturation_mode = .LOW,
//    .apply_saturation = false,
//};
 
    // MED
 // const config = utils.PipelineConfig{
 //     .colour_mode = .MED,
 //     .blur_mode = .MED,
 //     .apply_blur = true,
 //     .sharpen_mode = .MED,
 //     .quantise_mode = .MED,
 //     .apply_quantisation = true,
 //     .saturation_mode = .MED,
 //     .apply_saturation = true,
 // };

    // HIGH
  const config = utils.PipelineConfig{
      .colour_mode = .HIGH,
      .blur_mode = .HIGH,
      .apply_blur = true,
      .sharpen_mode = .HIGH,
      .quantise_mode = .HIGH,
      .apply_quantisation = true,
      .saturation_mode = .HIGH,
      .apply_saturation = true,
  };

    var start_time = std.Io.Clock.now(.awake, io);

    process(config, &my_image);

    const end_time = std.Io.Clock.now(.awake, io);

    const duration = start_time.durationTo(end_time);

    std.debug.print("Processed in: {} ns\n", .{duration.toNanoseconds()});
}
