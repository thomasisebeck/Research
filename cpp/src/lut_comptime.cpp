#include "utils.cpp"
#include <array>
#include <benchmark/benchmark.h>
#include <chrono>
#include <cstddef>
#include <sys/prctl.h>

constexpr std::array<double, utils::STEPS> generate_lut() {
  std::array<double, utils::STEPS> table;

  // double ref ? eh
  for (int i = 0; i < utils::STEPS; i++) {
    const double result = i * utils::INCREMENT;

    table[i] = __builtin_sin(result) + __builtin_cos(result);
  }

  return table;
}

int main() {

  const auto test_cases =
      utils::read_array_from_file<utils::TEST_SIZE>("lookup.txt");

  // Must use C++ 26 (clang is still registering as an error, but it compiles)

  constexpr auto COMPTIME_LUT = generate_lut();

  // not really needed for cpp, stack allocation by default,
  // but keeping for consistency
  auto myLut = COMPTIME_LUT;

  // don't do division in the hot loop
  const double prediv = 1.0 / utils::INCREMENT;

  std::print(
      "LUT size: {}, increment: {}, testSize: {}, degrees: {}, steps: {}\n",
      myLut.size(), utils::INCREMENT, utils::TEST_SIZE, utils::DEGREES,
      utils::STEPS);

  // 1 ------ WARMUP LOOP ------
  double warmup_sum = 0.0;
  for (const auto &num : test_cases) {
    const size_t idx = static_cast<size_t>(num * prediv);

    warmup_sum += myLut[idx];
  }
  benchmark::DoNotOptimize(warmup_sum);

  double sum = 0.0;

  // start perf, then the clock
  prctl(PR_TASK_PERF_EVENTS_ENABLE);
  auto start_time = std::chrono::steady_clock::now();

  for (const auto &num : test_cases) {
    // num is strictly a raw test case value here
    const size_t idx = static_cast<size_t>(num * prediv);

    sum += myLut[idx];
  }

  // end the clock, then stop perf
  auto end_time = std::chrono::steady_clock::now();
  prctl(PR_TASK_PERF_EVENTS_DISABLE);

  const auto duration = (end_time - start_time).count();
  std::print("Processed in: [{}] ns\n", duration);

  std::print("Sum: {}\n", sum);

  benchmark::DoNotOptimize(sum);

  return 0;
}
