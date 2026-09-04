#include <array>
#include <fstream>
#include <iostream>
#include <print>
#include <random>

#ifndef INCREMENT_VAL
#define INCREMENT_VAL 0.00001
#endif

namespace utils {

constexpr size_t TEST_SIZE = 5000;
constexpr double DEGREES = 360;
const auto SIZE = 500;
constexpr double INCREMENT = INCREMENT_VAL;

constexpr int STEPS = static_cast<size_t>(DEGREES / INCREMENT);

struct Colour {
  float r, g, b;
};

enum class Mode { HIGH, MED, LOW };

// C++20 allows literal class types to be used as template parameters

struct PipelineConfig {
  Mode blur_mode;
  bool apply_blur;
  Mode quantise_mode;
  bool apply_quantisation;
  Mode saturation_mode;
  bool apply_saturation;
};

struct Neighbours {
  Colour topLeft;
  Colour middleLeft;
  Colour bottomLeft;
  Colour bottomMiddle;
  Colour bottomRight;
  Colour middleRight;
  Colour topRight;
  Colour topMiddle;
};

void print_image(const Colour (&mat)[SIZE][SIZE]) {
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

void read_image_from_file(std::string_view path, Colour (&mat)[SIZE][SIZE]) {

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

      // Map the parsed text integers back to your colour floats
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
std::array<double, Size> read_array_from_file(const std::string &path) {
  std::ifstream file(path, std::ios::in);
  if (!file.is_open()) {
    throw std::runtime_error("Cannot open file: " + path);
  }

  auto my_arr = std::array<double, Size>();
  int counter = 0;

  double val = 0.0;
  while (counter < Size && file >> val) {
    my_arr[counter++] = val;
  }

  return my_arr;
}

void send_perf_cmd(std::ofstream &ctl, std::ifstream &ack,
                   const std::string &cmd) {
  ctl << cmd << "\n" << std::flush;
  std::string response;
  std::getline(ack, response);
}

template <int Size> void write_array_to_file(std::string path) {

  std::ofstream file(path.data(), std::ios::trunc);
  std::random_device rd;
  std::mt19937 gen(rd());
  std::uniform_int_distribution<int> distrib(0, 100);

  if (!file.is_open()) {
    throw "Cannot open file";
  }

  for (int i = 0; i < Size; i++) {
    file << distrib(gen) << std::endl;
  }
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
