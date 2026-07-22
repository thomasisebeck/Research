#include <array>
#include <cmath>
#include <cstddef>
#include <ranges>

constexpr float increment = 0.1;
constexpr size_t TEST_SIZE = 1000;
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
  constexpr float increment = 0.1f;
  constexpr std::size_t steps = 3600;

  constexpr toLookUp = generateTestCases();

  // This line will fail to compile under C++20 and C++23
  constexpr auto test_lut = generateLUT();
  return 0;
}
