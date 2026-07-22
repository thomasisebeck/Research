#include <algorithm>
#include <chrono>
#include <cmath>
#include <fstream>
#include <iostream>
#include <print>

enum class Mode { HIGH, MED, LOW };

// C++20 allows literal class types to be used as template parameters
struct PipelineConfig {
  Mode color_mode;
  Mode blur_mode;
  bool apply_blur;
  Mode sharpen_mode;
  Mode quantize_mode;
  bool apply_quantization;
  Mode saturation_mode;
  bool apply_saturation;
};

// f32 = float in cpp
struct Color {
  float r, g, b;
};

struct Neighbors {
  Color topLeft;
  Color middleLeft;
  Color bottomLeft;
  Color bottomMiddle;
  Color bottomRight;
  Color middleRight;
  Color topRight;
  Color topMiddle;
};

template <PipelineConfig cfg>
[[nodiscard]] constexpr float Quantize(float color) {
  float res = 0;
  if constexpr (cfg.quantize_mode == Mode::HIGH) {
    res = std::round(color * 255.0f) / 255.0f;
  } else if constexpr (cfg.quantize_mode == Mode::MED) {
    res = std::round(color * 16.0f) / 16.0f;
  } else if constexpr (cfg.quantize_mode == Mode::LOW) {
    res = (color > 0.5f) ? 1.0f : 0.0f;
  }
  return res;
}

template <PipelineConfig cfg>
constexpr void Blur(Color *item, const Neighbors &n) noexcept {
  if constexpr (cfg.blur_mode == Mode::LOW) {
    item->r = (n.middleLeft.r + item->r + n.middleRight.r) / 3.0f;
    item->g = (n.middleLeft.g + item->g + n.middleRight.g) / 3.0f;
    item->b = (n.middleLeft.b + item->b + n.middleRight.b) / 3.0f;
  } else if constexpr (cfg.blur_mode == Mode::MED) {

    item->r = (n.topMiddle.r + n.bottomMiddle.r + n.middleLeft.r +
               n.middleRight.r + item->r) /
              5.0f;
    item->g = (n.topMiddle.g + n.bottomMiddle.g + n.middleLeft.g +
               n.middleRight.g + item->g) /
              5.0f;

    item->b = (n.topMiddle.b + n.bottomMiddle.b + n.middleLeft.b +
               n.middleRight.b + item->b) /
              5.0f;
  } else if constexpr (cfg.blur_mode == Mode::HIGH) {
    item->r = (n.topLeft.r + n.middleLeft.r + n.bottomLeft.r +
               n.bottomMiddle.r + n.bottomRight.r + n.middleRight.r +
               n.topRight.r + n.topMiddle.r + item->r) /
              9.0f;
    item->g = (n.topLeft.g + n.middleLeft.g + n.bottomLeft.g +
               n.bottomMiddle.g + n.bottomRight.g + n.middleRight.g +
               n.topRight.g + n.topMiddle.g + item->g) /
              9.0f;
    item->b = (n.topLeft.b + n.middleLeft.b + n.bottomLeft.b +
               n.bottomMiddle.b + n.bottomRight.b + n.middleRight.b +
               n.topRight.b + n.topMiddle.b + item->b) /
              9.0f;
  }
}

template <PipelineConfig cfg> constexpr void Saturation(Color *item) {
  const float luma =
      (0.299f * item->r) + (0.587f * item->g) + (0.144f * item->b);

  // use a IIFE (Immediately Invoked Function Expression)
  constexpr float delta = []() -> float {
    switch (cfg.saturation_mode) {
    case Mode::LOW:
      return 1.5;

    case Mode::MED:
      return 2.5;

    case Mode::HIGH:
      return 3.5;
    }
  }();

  item->r = std::clamp(luma + (delta * (item->r - luma)), 0.0f, 255.0f);
  item->g = std::clamp(luma + (delta * (item->g - luma)), 0.0f, 255.0f);
  item->b = std::clamp(luma + (delta * (item->b - luma)), 0.0f, 255.0f);
}

const auto SIZE = 100;

template <PipelineConfig cfg> constexpr void Process(Color (&mat)[SIZE][SIZE]) {
  for (int row_num = 1; row_num < SIZE; row_num++) {

    for (int col_num = 1; col_num < SIZE; col_num++) {
      // ref to the item
      Color *item = &mat[row_num][col_num];

      if constexpr (cfg.apply_blur) {
        const Neighbors n = {.topLeft = mat[row_num - 1][col_num - 1],
                             .middleLeft = mat[row_num][col_num - 1],
                             .bottomLeft = mat[row_num + 1][col_num - 1],
                             .bottomMiddle = mat[row_num + 1][col_num],
                             .bottomRight = mat[row_num + 1][col_num + 1],
                             .middleRight = mat[row_num][col_num + 1],
                             .topRight = mat[row_num - 1][col_num + 1],
                             .topMiddle = mat[row_num - 1][col_num]

        };

        Blur<cfg>(item, n);
      };

      if constexpr (cfg.apply_quantization) {
        item->r = Quantize<cfg>(item->r);
        item->g = Quantize<cfg>(item->g);
        item->b = Quantize<cfg>(item->b);
      }

      if constexpr (cfg.apply_saturation) {
        Saturation<cfg>(item);
      }
    }
  }
}

template <size_t SIZE> bool writeImageToFile(std::string path) {

  srand(123);

  std::ofstream file(path, std::ios::out | std::ios::trunc);
  if (!file.is_open())
    return false;

  for (size_t row = 0; row < SIZE; ++row) {
    for (size_t col = 0; col < SIZE; ++col) {

      int r = rand() % 256;
      int g = rand() % 256;
      int b = rand() % 256;

      file << std::format("{} {} {}\n", r, g, b);
    }
  }

  return file.good();
}
void printImage(const Color (&mat)[SIZE][SIZE]) {
  std::print("[\n");

  for (const auto &row : mat) {
    std::print("  [ ");

    for (const auto &pixel : row) {
      // :.2f handles formatting the floats to 2 decimal places
      std::print("({:.2f},{:.2f},{:.2f}) ", pixel.r, pixel.g, pixel.b);
    }

    std::print("]\n");
  }

  std::print("]\n");
}

void readImageFromFile(std::string_view path, Color (&mat)[SIZE][SIZE]) {

  std::ifstream file(path.data(), std::ios::in);
  if (!file.is_open()) {
    throw "Cannot open file";
  }
  for (size_t row = 0; row < SIZE; ++row) {

    for (size_t col = 0; col < SIZE; ++col) {
      int r = 0, g = 0, b = 0;

      // Stream extraction handles the spaces and newlines natively
      if (!(file >> r >> g >> b)) {
        throw "File corrupted";
      }

      // Map the parsed text integers back to your Color floats
      mat[row][col].r = static_cast<float>(r);
      mat[row][col].g = static_cast<float>(g);
      mat[row][col].b = static_cast<float>(b);
    }
  }
  if (!file.good() && !file.eof()) {
    throw "did not reach the end of the file";
  }
  file.close();
}

int main() {

  Color my_image[SIZE][SIZE];

  // const auto good = writeImageToFile<SIZE>("image.txt");

  readImageFromFile("image.txt", my_image);

  constexpr auto config = PipelineConfig{.color_mode = Mode::LOW,
                                         .blur_mode = Mode::LOW,
                                         .apply_blur = true,
                                         .sharpen_mode = Mode::LOW,
                                         .quantize_mode = Mode::LOW,
                                         .apply_quantization = true,
                                         .saturation_mode = Mode::LOW,
                                         .apply_saturation = true};

  const auto start_time = std::chrono::steady_clock::now();

  Process<config>(my_image);

  const auto end_time = std::chrono::steady_clock::now();
  const auto duration = end_time - start_time;

  const auto nanoseconds =
      std::chrono::duration_cast<std::chrono::nanoseconds>(duration).count();
  std::print("Processed in: {} ns\n", nanoseconds);

  return 0;
}
