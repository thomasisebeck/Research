mod utils;

enum Mode {
    HIGH,
    MED,
    LOW,
}

trait PipelineConfig {
    const COLOUR_MODE: Mode;
    const BLUR_MODE: Mode;
    const APPLY_BLUR: bool;
    const SHARPEN_MODE: Mode;
    const QUANTISE_MODE: Mode;
    const APPLY_QUANTIZATION: bool;
    const SATURATION_MODE: Mode;
    const APPLY_SATURATION: bool;
}

struct HighQualityConfig;

impl PipelineConfig for HighQualityConfig {
    const COLOUR_MODE: Mode = Mode::HIGH;
    const BLUR_MODE: Mode = Mode::HIGH;
    const APPLY_BLUR: bool = true;
    const SHARPEN_MODE: Mode = Mode::HIGH;
    const QUANTISE_MODE: Mode = Mode::HIGH;
    const APPLY_QUANTIZATION: bool = true;
    const SATURATION_MODE: Mode = Mode::HIGH;
    const APPLY_SATURATION: bool = true;
}

struct MediumQualityConfig;

impl PipelineConfig for MediumQualityConfig {
    const COLOUR_MODE: Mode = Mode::MED;
    const BLUR_MODE: Mode = Mode::MED;
    const APPLY_BLUR: bool = true;
    const SHARPEN_MODE: Mode = Mode::MED;
    const QUANTISE_MODE: Mode = Mode::MED;
    const APPLY_QUANTIZATION: bool = true;
    const SATURATION_MODE: Mode = Mode::MED;
    const APPLY_SATURATION: bool = false;
}

// 3. Low Quality Configuration
struct LowQualityConfig;

impl PipelineConfig for LowQualityConfig {
    const COLOUR_MODE: Mode = Mode::LOW;
    const BLUR_MODE: Mode = Mode::LOW;
    const APPLY_BLUR: bool = true;
    const SHARPEN_MODE: Mode = Mode::LOW;
    const QUANTISE_MODE: Mode = Mode::LOW;
    const APPLY_QUANTIZATION: bool = false; // Skip entirely
    const SATURATION_MODE: Mode = Mode::LOW;
    const APPLY_SATURATION: bool = true;
}

struct Colour {
    pub r: f32,
    pub g: f32,
    pub b: f32,
}

// <> is the lifetime param
pub struct Neighbours<'a> {
    pub top_left: &'a Colour,
    pub middle_left: &'a Colour,
    pub bottom_left: &'a Colour,
    pub bottom_middle: &'a Colour,
    pub bottom_right: &'a Colour,
    pub middle_right: &'a Colour,
    pub top_right: &'a Colour,
    pub top_middle: &'a Colour,
}

// if statement
fn quantise<CFG: PipelineConfig>(colour: f32) -> f32 {
    let res;
    if matches!(CFG::QUANTISE_MODE, Mode::LOW) {
        res = f32::round(colour * 255.0) / 255.0;
    } else if matches!(CFG::QUANTISE_MODE, Mode::MED) {
        res = f32::round(colour * 16.0) / 16.0;
    } else {
        res = if colour > 0.5 { 1.0 } else { 0.0 }
    }

    res
}

// switch statement
fn blur<CFG: PipelineConfig>(item: &mut Colour, n: Neighbours) {
    match CFG::BLUR_MODE {
        Mode::LOW => {
            item.r = (n.middle_left.r + item.r + n.middle_right.r) / 3.0;
            item.g = (n.middle_left.g + item.g + n.middle_right.g) / 3.0;
            item.b = (n.middle_left.b + item.b + n.middle_right.b) / 3.0;
        }
        Mode::MED => {
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
        Mode::HIGH => {
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

// switch expression
fn saturation<CFG: PipelineConfig>(item: &mut Colour) {
    let LUMA: f32 = (0.299 * item.r) + (0.587 * item.g) + (0.144 * item.b);

    let delta: f32 = match CFG::COLOUR_MODE {
        Mode::LOW => 1.5,
        Mode::MED => 2.5,
        Mode::HIGH => 3.5,
    };

    item.r = (LUMA + (delta * (item.r - LUMA))).clamp(0.0, 1.0);
    item.g = LUMA + (delta * (item.g - LUMA)).clamp(0.0, 1.0);
    item.b = LUMA + (delta * (item.b - LUMA)).clamp(0.0, 1.0);
}

// constexpr void process(utils::Colour (&mat)[utils::SIZE][utils::SIZE]) {
fn process<CFG: PipelineConfig>(mat: &mut [[Colour; utils::SIZE]; utils::SIZE]) {
    for row_num in 1..=(utils::SIZE - 1) {
        for col_num in 1..=(utils::SIZE - 1) {
            let item: &mut Colour = &mut mat[row_num][col_num];

            if CFG::APPLY_BLUR {
                // these are non-mutable refs
                // no need to fight with the borrow checker
                let n = Neighbours {
                    top_left: &mat[row_num - 1][col_num - 1],
                    middle_left: &mat[row_num][col_num - 1],
                    bottom_left: &mat[row_num + 1][col_num - 1],
                    bottom_middle: &mat[row_num + 1][col_num],
                    bottom_right: &mat[row_num + 1][col_num + 1],
                    middle_right: &mat[row_num][col_num + 1],
                    top_right: &mat[row_num - 1][col_num + 1],
                    top_middle: &mat[row_num - 1][col_num],
                };
            }
        }
    }
}

/*


constexpr void process(utils::Colour (&mat)[utils::SIZE][utils::SIZE]) {
  for (int row_num = 1; row_num < utils::SIZE - 1; row_num++) {

    for (int col_num = 1; col_num < utils::SIZE - 1; col_num++) {
      // ref to the item
      utils::Colour &item = mat[row_num][col_num];

      if constexpr (cfg.apply_blur) {
        const utils::Neighbours n = {
            .topLeft = mat[row_num - 1][col_num - 1],
            .middleLeft = mat[row_num][col_num - 1],
            .bottomLeft = mat[row_num + 1][col_num - 1],
            .bottomMiddle = mat[row_num + 1][col_num],
            .bottomRight = mat[row_num + 1][col_num + 1],
            .middleRight = mat[row_num][col_num + 1],
            .topRight = mat[row_num - 1][col_num + 1],
            .topMiddle = mat[row_num - 1][col_num]

        };

        blur<cfg>(item, n);
      };
*/
fn main() {}
