#include "utils.cpp"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <sys/prctl.h>

#ifndef QUAL
#define QUAL utils::Mode::HIGH
#endif

#ifndef APPLY_ONE
#define APPLY_ONE true
#endif

#ifndef APPLY_TWO
#define APPLY_TWO true
#endif

#ifndef APPLY_THREE
#define APPLY_THREE true
#endif

// if statement
[[nodiscard]] float quantise(const utils::PipelineConfig &cfg, float colour) {
  float res = 0;
  if (cfg.quantise_mode == utils::Mode::HIGH) {
    res = std::round(colour * 255.0f) / 255.0f;
  } else if (cfg.quantise_mode == utils::Mode::MED) {
    res = std::round(colour * 16.0f) / 16.0f;
  } else if (cfg.quantise_mode == utils::Mode::LOW) {
    res = (colour > 0.5f) ? 1.0f : 0.0f;
  }
  return res;
}

// switch statement
void blur(const utils::PipelineConfig &cfg, utils::Colour &item,
          const utils::Neighbours &n) {
  switch (cfg.blur_mode) {
  case utils::Mode::LOW: {
    item.r = (n.middleLeft.r + item.r + n.middleRight.r) / 3.0f;
    item.g = (n.middleLeft.g + item.g + n.middleRight.g) / 3.0f;
    item.b = (n.middleLeft.b + item.b + n.middleRight.b) / 3.0f;

    break;
  }
  case utils::Mode::MED: {
    item.r = (n.topMiddle.r + n.bottomMiddle.r + n.middleLeft.r +
              n.middleRight.r + item.r) /
             5.0f;
    item.g = (n.topMiddle.g + n.bottomMiddle.g + n.middleLeft.g +
              n.middleRight.g + item.g) /
             5.0f;
    item.b = (n.topMiddle.b + n.bottomMiddle.b + n.middleLeft.b +
              n.middleRight.b + item.b) /
             5.0f;
    break;
  }
  case utils::Mode::HIGH: {
    item.r = (n.topLeft.r + n.middleLeft.r + n.bottomLeft.r + n.bottomMiddle.r +
              n.bottomRight.r + n.middleRight.r + n.topRight.r + n.topMiddle.r +
              item.r) /
             9.0f;
    item.g = (n.topLeft.g + n.middleLeft.g + n.bottomLeft.g + n.bottomMiddle.g +
              n.bottomRight.g + n.middleRight.g + n.topRight.g + n.topMiddle.g +
              item.g) /
             9.0f;
    item.b = (n.topLeft.b + n.middleLeft.b + n.bottomLeft.b + n.bottomMiddle.b +
              n.bottomRight.b + n.middleRight.b + n.topRight.b + n.topMiddle.b +
              item.b) /
             9.0f;
    break;
  }
  }
}

// switch expression
void saturation(const utils::PipelineConfig &cfg, utils::Colour &item) {

  const float LUMA = [item, cfg]() -> float {
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

  const float DELTA = [cfg]() -> float {
    switch (cfg.saturation_mode) {
    case utils::Mode::LOW:
      return 1.5;
    case utils::Mode::MED:
      return 2.5;
    case utils::Mode::HIGH:
      return 3.5;
    default:
      std::unreachable();
    };
  }();

  item.r = std::clamp(LUMA + (DELTA * (item.r - LUMA)), 0.0f, 1.0f);
  item.g = std::clamp(LUMA + (DELTA * (item.g - LUMA)), 0.0f, 1.0f);
  item.b = std::clamp(LUMA + (DELTA * (item.b - LUMA)), 0.0f, 1.0f);
}

void process(const utils::PipelineConfig &cfg,
             utils::Colour (&mat)[utils::SIZE][utils::SIZE]) {
  for (int row_num = 1; row_num < utils::SIZE - 1; row_num++) {

    for (int col_num = 1; col_num < utils::SIZE - 1; col_num++) {
      // ref to the item
      utils::Colour &item = mat[row_num][col_num];

      if (cfg.apply_blur) {
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

        blur(cfg, item, n);
      };

      if (cfg.apply_quantisation) {
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

int main() {

  utils::Colour my_image[utils::SIZE][utils::SIZE];

  utils::read_image_from_file("input_image.txt", my_image);

  std::ofstream perf_ctl("/tmp/perf.ctl");
  std::ifstream perf_ack("/tmp/perf.ack");

  constexpr auto config =
      utils::PipelineConfig{.blur_mode = QUAL,
                            .apply_blur = APPLY_ONE,
                            .quantise_mode = QUAL,
                            .apply_quantisation = APPLY_TWO,
                            .saturation_mode = QUAL,
                            .apply_saturation = APPLY_THREE};

  // start perf, then the clock
  utils::send_perf_cmd(perf_ctl, perf_ack, "enable");
  auto start_time = std::chrono::steady_clock::now();

  process(config, my_image);

  // end the clock, then stop perf
  utils::send_perf_cmd(perf_ctl, perf_ack, "disable");
  auto end_time = std::chrono::steady_clock::now();

  const auto duration = (end_time - start_time).count();
  std::print("Processed in: [{}] ns\n", duration);

  return 0;
}
