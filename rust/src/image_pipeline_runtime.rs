mod utils;
use std::time::Instant;

use libc::{PR_TASK_PERF_EVENTS_DISABLE, PR_TASK_PERF_EVENTS_ENABLE};

// use a normal struct instead of a trait
struct PipelineConfig {
    blur_mode: utils::Mode,
    apply_blur: bool,
    quantise_mode: utils::Mode,
    apply_quantisation: bool,
    saturation_mode: utils::Mode,
    apply_saturation: bool,
}

// <> is the lifetime param

// if statement
fn quantise(cfg: &PipelineConfig, colour: f32) -> f32 {
    let res;
    if matches!(cfg.quantise_mode, utils::Mode::HIGH) {
        res = f32::round(colour * 255.0) / 255.0;
    } else if matches!(cfg.quantise_mode, utils::Mode::MED) {
        res = f32::round(colour * 16.0) / 16.0;
    } else {
        res = if colour > 0.5 { 1.0 } else { 0.0 }
    }

    res
}

// switch statement
fn blur(cfg: &PipelineConfig, item: &mut utils::Colour, n: utils::Neighbours) {
    match cfg.blur_mode {
        utils::Mode::LOW => {
            item.r = (n.middle_left.r + item.r + n.middle_right.r) / 3.0;
            item.g = (n.middle_left.g + item.g + n.middle_right.g) / 3.0;
            item.b = (n.middle_left.b + item.b + n.middle_right.b) / 3.0;
        }
        utils::Mode::MED => {
            item.r =
                (n.top_middle.r + n.bottom_middle.r + n.middle_left.r + n.middle_right.r + item.r)
                    / 5.0;
            item.g =
                (n.top_middle.g + n.bottom_middle.g + n.middle_left.g + n.middle_right.g + item.g)
                    / 5.0;
            item.b =
                (n.top_middle.b + n.bottom_middle.b + n.middle_left.b + n.middle_right.b + item.b)
                    / 5.0;
        }
        utils::Mode::HIGH => {
            item.r = (n.top_left.r
                + n.middle_left.r
                + n.bottom_left.r
                + n.bottom_middle.r
                + n.bottom_right.r
                + n.middle_right.r
                + n.top_right.r
                + n.top_middle.r
                + item.r)
                / 9.0;
            item.g = (n.top_left.g
                + n.middle_left.g
                + n.bottom_left.g
                + n.bottom_middle.g
                + n.bottom_right.g
                + n.middle_right.g
                + n.top_right.g
                + n.top_middle.g
                + item.g)
                / 9.0;
            item.b = (n.top_left.b
                + n.middle_left.b
                + n.bottom_left.b
                + n.bottom_middle.b
                + n.bottom_right.b
                + n.middle_right.b
                + n.top_right.b
                + n.top_middle.b
                + item.b)
                / 9.0;
        }
    }
}

/*
 
// switch expression
template <utils::PipelineConfig cfg>
constexpr void saturation(utils::Colour &item) {

  const float LUMA = [item]() -> float {
    switch (cfg.saturation_mode) {
    case utils::Mode::LOW:
      return (0.3f * item.r) + (0.6f * item.g) + (0.1f * item.b);

    case utils::Mode::MED:
      return (0.29f * item.r) + (0.59f * item.g) + (0.14f * item.b);

    case utils::Mode::HIGH:
      return (0.294f * item.r) + (0.587f * item.g) + (0.144f * item.b);

    default:
      std::unreachable();
    }
  }();

  const float DELTA = 1.5f;

  item.r = std::clamp(LUMA + (DELTA * (item.r - LUMA)), 0.0f, 1.0f);
  item.g = std::clamp(LUMA + (DELTA * (item.g - LUMA)), 0.0f, 1.0f);
  item.b = std::clamp(LUMA + (DELTA * (item.b - LUMA)), 0.0f, 1.0f);
}

 */ 

// switch expression
fn saturation(cfg: &PipelineConfig, item: &mut utils::Colour) {

    let LUMA: f32 = match cfg.saturation_mode {
        utils::Mode::LOW => (0.3 * item.r) + (0.6 * item.g) + (0.1 * item.b),
        utils::Mode::MED => (0.29 * item.r) + (0.59 * item.g) + (0.14 * item.b),
        utils::Mode::HIGH => (0.294 * item.r) + (0.587 * item.g) + (0.144 * item.b),
    };

    let delta: f32 = match cfg.saturation_mode {
        utils::Mode::LOW => 1.5,
        utils::Mode::MED => 2.5,
        utils::Mode::HIGH => 3.5,
    };

    item.r = (LUMA + (delta * (item.r - LUMA))).clamp(0.0, 1.0);
    item.g = (LUMA + (delta * (item.g - LUMA))).clamp(0.0, 1.0);
    item.b = (LUMA + (delta * (item.b - LUMA))).clamp(0.0, 1.0);
}

// constexpr void process(utils::Colour (&mat)[utils::SIZE][utils::SIZE]) {
fn process(
    cfg: &PipelineConfig,
    mat: &mut [[utils::Colour; utils::IMAGE_SIZE]; utils::IMAGE_SIZE],
) {
    // not ..= (we want exclusive loop)
    for row_num in 1..(utils::IMAGE_SIZE - 1) {
        for col_num in 1..(utils::IMAGE_SIZE - 1) {
            if cfg.apply_blur {
                // these are non-mutable refs
                // no need to fight with the borrow checker

                // must be immutable
                let n = utils::Neighbours {
                    top_left: mat[row_num - 1][col_num - 1],
                    middle_left: mat[row_num][col_num - 1],
                    bottom_left: mat[row_num + 1][col_num - 1],
                    bottom_middle: mat[row_num + 1][col_num],
                    bottom_right: mat[row_num + 1][col_num + 1],
                    middle_right: mat[row_num][col_num + 1],
                    top_right: mat[row_num - 1][col_num + 1],
                    top_middle: mat[row_num - 1][col_num],
                };

                // need to grab it here
                // because we want to copy out the mat refs
                // before we take the middle one as mutable
                let item: &mut utils::Colour = &mut mat[row_num][col_num];

                // must be mutable
                blur(cfg, item, n);
            }

            if cfg.apply_quantisation {
                let item = &mut mat[row_num][col_num];
                item.r = quantise(cfg, item.r);
                item.g = quantise(cfg, item.g);
                item.b = quantise(cfg, item.b);
            }

            if cfg.apply_saturation {
                let item = &mut mat[row_num][col_num];
                saturation(cfg, item);
            }
        }
    }
}

fn main() {
    // have to init the array in rust
    let init_pixel = utils::Colour {
        r: 0.0,
        g: 0.0,
        b: 0.0,
    };

    // pass the init pixel in here
    // type is derived
    let mut my_image = [[init_pixel; utils::IMAGE_SIZE]; utils::IMAGE_SIZE];

    // pass the image in as mutable
    utils::read_image_from_file("input_image.txt", &mut my_image);


  let config = PipelineConfig {
      blur_mode: utils::Mode::LOW,
      apply_blur: false,
      quantise_mode: utils::Mode::LOW,
      apply_quantisation: false,
      saturation_mode: utils::Mode::LOW,
      apply_saturation: true,
  };

 // let config = PipelineConfig {
 //     blur_mode: utils::Mode::MED,
 //     apply_blur: true,
 //     quantise_mode: utils::Mode::MED,
 //     apply_quantisation: true,
 //     saturation_mode: utils::Mode::MED,
 //     apply_saturation: false,
 // };


//let config = PipelineConfig {
//    blur_mode: utils::Mode::HIGH,
//    apply_blur: true,
//    quantise_mode: utils::Mode::HIGH,
//    apply_quantisation: true,
//    saturation_mode: utils::Mode::HIGH,
//    apply_saturation: true,
//};

    unsafe {
        libc::prctl(PR_TASK_PERF_EVENTS_ENABLE, 0, 0, 0, 0);
    }
    let start_time = Instant::now();

    // configs are declared above as traits...
    process(&config, &mut my_image);

    let end_time = Instant::now();
    unsafe {
        libc::prctl(PR_TASK_PERF_EVENTS_DISABLE, 0, 0, 0, 0);
    }

    let duration = end_time.duration_since(start_time).as_nanos();

    println!("Processed in: {} ns", duration);
}
