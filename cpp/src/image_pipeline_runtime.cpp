#include "utils.cpp"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <print>
#include <utility>

[[nodiscard]] float quantize(const utils::PipelineConfig &cfg, float color) {
  float res = 0;
  if (cfg.quantize_mode == utils::Mode::HIGH) {
    res = std::round(color * 255.0f) / 255.0f;
  } else if (cfg.quantize_mode == utils::Mode::MED) {
    res = std::round(color * 16.0f) / 16.0f;
  } else if (cfg.quantize_mode == utils::Mode::LOW) {
    res = (color > 0.5f) ? 1.0f : 0.0f;
  }
  return res;
}

void blur(const utils::PipelineConfig &cfg, utils::Color &item,
          const utils::Neighbors &n) noexcept {
  if (cfg.blur_mode == utils::Mode::LOW) {
    item.r = (n.middleLeft.r + item.r + n.middleRight.r) / 3.0f;
    item.g = (n.middleLeft.g + item.g + n.middleRight.g) / 3.0f;
    item.b = (n.middleLeft.b + item.b + n.middleRight.b) / 3.0f;
  } else if (cfg.blur_mode == utils::Mode::MED) {

    item.r = (n.topMiddle.r + n.bottomMiddle.r + n.middleLeft.r +
              n.middleRight.r + item.r) /
             5.0f;
    item.g = (n.topMiddle.g + n.bottomMiddle.g + n.middleLeft.g +
              n.middleRight.g + item.g) /
             5.0f;

    item.b = (n.topMiddle.b + n.bottomMiddle.b + n.middleLeft.b +
              n.middleRight.b + item.b) /
             5.0f;
  } else if (cfg.blur_mode == utils::Mode::HIGH) {
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
  }
}

void saturation(const utils::PipelineConfig &cfg, utils::Color &item) {
  const float luma = (0.299f * item.r) + (0.587f * item.g) + (0.144f * item.b);

  // use a IIFE (Immediately Invoked Function Expression)
  float delta = [cfg]() -> float {
    switch (cfg.saturation_mode) {
    case utils::Mode::LOW:
      return 1.5;

    case utils::Mode::MED:
      return 2.5;

    case utils::Mode::HIGH:
      return 3.5;

    default:
      std::unreachable();
    }
  }();

  item.r = std::clamp(luma + (delta * (item.r - luma)), 0.0f, 1.0f);
  item.g = std::clamp(luma + (delta * (item.g - luma)), 0.0f, 1.0f);
  item.b = std::clamp(luma + (delta * (item.b - luma)), 0.0f, 1.0f);
}

void process(const utils::PipelineConfig &cfg,
             utils::Color (&mat)[utils::SIZE][utils::SIZE]) {
  for (int row_num = 1; row_num < utils::SIZE - 1; row_num++) {

    for (int col_num = 1; col_num < utils::SIZE - 1; col_num++) {
      // ref to the item
      utils::Color &item = mat[row_num][col_num];

      if (cfg.apply_blur) {
        const utils::Neighbors n = {.topLeft = mat[row_num - 1][col_num - 1],
                                    .middleLeft = mat[row_num][col_num - 1],
                                    .bottomLeft = mat[row_num + 1][col_num - 1],
                                    .bottomMiddle = mat[row_num + 1][col_num],
                                    .bottomRight =
                                        mat[row_num + 1][col_num + 1],
                                    .middleRight = mat[row_num][col_num + 1],
                                    .topRight = mat[row_num - 1][col_num + 1],
                                    .topMiddle = mat[row_num - 1][col_num]

        };

        blur(cfg, item, n);
      };

      if (cfg.apply_quantization) {
        item.r = quantize(cfg, item.r);
        item.g = quantize(cfg, item.g);
        item.b = quantize(cfg, item.b);
      }

      if (cfg.apply_saturation) {
        saturation(cfg, item);
      }
    }
  }
}

int main() {

  utils::Color my_image[utils::SIZE][utils::SIZE];

  utils::read_image_from_file("input_image.txt", my_image);

  constexpr auto config =
      utils::PipelineConfig{.color_mode = utils::Mode::LOW,
                            .blur_mode = utils::Mode::LOW,
                            .apply_blur = true,
                            .sharpen_mode = utils::Mode::LOW,
                            .quantize_mode = utils::Mode::LOW,
                            .apply_quantization = true,
                            .saturation_mode = utils::Mode::LOW,
                            .apply_saturation = true};

  const auto start_time = std::chrono::steady_clock::now();

  process(config, my_image);

  const auto end_time = std::chrono::steady_clock::now();
  const auto duration = end_time - start_time;

  const auto nanoseconds =
      std::chrono::duration_cast<std::chrono::nanoseconds>(duration).count();
  std::print("Processed in: {} ns\n", nanoseconds);

  return 0;
}
