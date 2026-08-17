#include "utils.cpp"
#include <array>
#include <benchmark/benchmark.h>
#include <chrono>
#include <cstddef>
#include <fstream>
#include <print>

constexpr std::array<double, utils::STEPS> generate_lut() {
  std::array<double, utils::STEPS> table;

  for (int i = 0; i < utils::STEPS; i++) {
    const double result = i * utils::INCREMENT;

    table[i] = __builtin_sin(result) + __builtin_cos(result);
  }

  return table;
}

int main() {

  // ----- setup writer ---------
  // Open the perf control FIFO stream
  std::ofstream perf_ctl("/tmp/perf.ctl");
  // ------------------------------

  const auto test_cases =
      utils::read_array_from_file<utils::TEST_SIZE>("lookup.txt");

  constexpr auto COMPTIME_LUT = generate_lut();
  auto myLut = COMPTIME_LUT;

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


  perf_ctl << "disable\n" << std::flush;
  auto start_time = std::chrono::steady_clock::now();

  for (const auto &num : test_cases) {
    const size_t idx = static_cast<size_t>(num * prediv);

    sum += myLut[idx];
  }

  auto end_time = std::chrono::steady_clock::now();
  perf_ctl << "disable\n" << std::flush;

  const auto duration =
      std::chrono::duration_cast<std::chrono::nanoseconds>(end_time - start_time)
          .count();

  std::print("Processed in: [{}] ns. Sum: {}\n", duration, sum);

  std::print("Sum: {}\n", sum);

  benchmark::DoNotOptimize(sum);

  return 0;
}