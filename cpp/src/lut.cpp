#include "utils.cpp"
#include <array>
#include <cstddef>
#include <iostream>
#include <ranges>

constexpr float increment = 0.1f;
constexpr size_t TEST_SIZE = 500;
constexpr float degrees = 360;
constexpr int steps = static_cast<size_t>(degrees / increment);

// template <utils::PipelineConfig cfg>
//  [[nodiscard]] constexpr float Quantize(float color) {

constexpr std::array<float, steps> generateLUT() {
  auto table = std::array<float, steps>();

  // double ref ? eh
  for (auto &&[i, item] : table | std::views::enumerate) {
    const float result = i * increment;

    item = __builtin_sinf(result) + __builtin_cosf(result);
  }

  return table;
}

int main() {

  const auto test_cases = utils::readArrayFromFile<TEST_SIZE>("lookup.txt");

  // Must use C++ 26 (clang is still registering as an error, but it compiles)
  constexpr auto myLut = generateLUT();

  double sum_comp = 0;

  std::cout << "This is the array read from the file: " << std::endl;
  utils::printArray<TEST_SIZE>(test_cases);

  return 0;
}
