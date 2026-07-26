#include "utils.cpp"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <print>
#include <utility>

// if statement
template <utils::PipelineConfig cfg>
[[nodiscard]] constexpr float quantise(float colour) {
  float res = 0;
  if constexpr (cfg.quantise_mode == utils::Mode::HIGH) {
    res = std::round(colour * 255.0f) / 255.0f;
  } else if constexpr (cfg.quantise_mode == utils::Mode::MED) {
    res = std::round(colour * 16.0f) / 16.0f;
  } else if constexpr (cfg.quantise_mode == utils::Mode::LOW) {
    res = (colour > 0.5f) ? 1.0f : 0.0f;
  }
  return res;
}

// switch statement
template <utils::PipelineConfig cfg>
constexpr void blur(utils::Colour &item, const utils::Neighbours &n) noexcept {
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
template <utils::PipelineConfig cfg>
constexpr void saturation(utils::Colour &item) {
  const float luma = (0.299f * item.r) + (0.587f * item.g) + (0.144f * item.b);

  // use a IIFE (Immediately Invoked Function Expression)
  float delta = []() -> float {
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

template <utils::PipelineConfig cfg>
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

      if constexpr (cfg.apply_quantisation) {
        item.r = quantise<cfg>(item.r);
        item.g = quantise<cfg>(item.g);
        item.b = quantise<cfg>(item.b);
      }

      if constexpr (cfg.apply_saturation) {
        saturation<cfg>(item);
      }
    }
  }
}

int main() {

  utils::Colour my_image[utils::SIZE][utils::SIZE];

  utils::read_image_from_file("input_image.txt", my_image);

  constexpr auto config =
      utils::PipelineConfig{.colour_mode = utils::Mode::LOW,
                            .blur_mode = utils::Mode::LOW,
                            .apply_blur = true,
                            .sharpen_mode = utils::Mode::LOW,
                            .quantise_mode = utils::Mode::LOW,
                            .apply_quantisation = true,
                            .saturation_mode = utils::Mode::LOW,
                            .apply_saturation = true};

  const auto start_time = std::chrono::steady_clock::now();

  process<config>(my_image);

  const auto end_time = std::chrono::steady_clock::now();
  const auto duration = end_time - start_time;

  const auto nanoseconds =
      std::chrono::duration_cast<std::chrono::nanoseconds>(duration).count();
  std::print("Processed in: {} ns\n", nanoseconds);

  return 0;
}
