
#include <array>
#include <fstream>
#include <iostream>
#include <print>

namespace utils {

struct Color {
  float r, g, b;
};

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

const auto SIZE = 150;

void print_image(const Color (&mat)[SIZE][SIZE]) {
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

void read_image_from_file(std::string_view path, Color (&mat)[SIZE][SIZE]) {

  std::ifstream file(path.data(), std::ios::in);
  if (!file.is_open()) {
    throw "Cannot open file";
  }
  for (size_t row = 0; row < SIZE; ++row) {

    for (size_t col = 0; col < SIZE; ++col) {
      float r = 0, g = 0, b = 0;

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

template <int Size>
std::array<int, Size> read_array_from_file(std::string_view path) {

  std::ifstream file(path.data(), std::ios::in);
  if (!file.is_open()) {
    throw "Cannot open file";
  }
  auto my_arr = std::array<int, Size>();

  int counter = 0;

  for (int i; file >> i;) {
    my_arr[counter++] = i;
  }

  return my_arr;
}

template <int Size> void print_array(const std::array<int, Size> &arr) {
  std::cout << "[";
  for (int i = 0; i < Size; ++i) {
    std::cout << arr[i];
    if (i < Size - 1) {
      std::cout << ", ";
    }
  }
  std::cout << "]\n";
}

} // namespace utils
