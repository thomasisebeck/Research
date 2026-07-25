#include "utils.cpp"
#include <array>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <print>
#include <ranges>

constexpr double INCREMENT = 0.01;
constexpr size_t TEST_SIZE = 500;
constexpr double DEGREES = 360;
constexpr int STEPS = static_cast<size_t>(DEGREES / INCREMENT);

// template <utils::PipelineConfig cfg>
//  [[nodiscard]] constexpr float Quantize(float color) {

constexpr std::array<double, STEPS> generate_lut() {
  auto table = std::array<double, STEPS>();

  // double ref ? eh
  for (auto &&[i, item] : table | std::views::enumerate) {
    const double result = i * INCREMENT;

    item = __builtin_sin(result) + __builtin_cos(result);
  }

  return table;
}

int main() {

  const auto test_cases = utils::read_array_from_file<TEST_SIZE>("lookup.txt");

  // std::print("This is the array read from the file: ");
  //  utils::printArray<TEST_SIZE>(test_cases);

  // Must use C++ 26 (clang is still registering as an error, but it compiles)
  constexpr auto MY_LUT = generate_lut();

  std::print(
      "LUT size: {}, increment: {}, testSize: {}, degrees: {}, steps: {}\n",
      MY_LUT.size(), INCREMENT, TEST_SIZE, DEGREES, STEPS);

  double sum_comp = 0;

  auto start_time = std::chrono::steady_clock::now();

  for (const auto &num : test_cases) {

    sum_comp += MY_LUT[num];

    //  std::print("curr comptime test case: {}, lut value: {}\n", num,
    //  myLut[num]);
  }

  auto end_time = std::chrono::steady_clock::now();
  const auto duration_comp = end_time - start_time;

  double sum_run = 0;

  start_time = std::chrono::steady_clock::now();

  for (const auto &num : test_cases) {

    const double input = num * INCREMENT;

    sum_run += std::sin(input) + std::cos(input);

    // std::print("curr runtime test case: {}, live value: {}\n", num,
    //            std::sin(input) + std::cos(input));
  }

  end_time = std::chrono::steady_clock::now();
  const auto duration_run = (end_time - start_time).count();

  std::print("Runtime processed in: {} ns\n", duration_run);
  std::print("Comptime processed in: {} ns\n", duration_comp);
  std::print("Sum comp: {}\n", sum_comp);
  std::print("Sum run: {}\n", sum_run);

  return 0;
}
