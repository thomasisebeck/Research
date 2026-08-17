#include "utils.cpp"
#include <cmath>
#include <benchmark/benchmark.h>
#include <chrono>
#include <fstream>
#include <print>

int main() {
  // ----- setup writer ---------
  // Open the perf control FIFO stream
  std::ofstream perf_ctl("/tmp/perf.ctl");
  // ------------------------------

  const auto test_cases =
      utils::read_array_from_file<utils::TEST_SIZE>("lookup.txt");

  std::print(
      "LUT size: {}, increment: {}, testSize: {}, degrees: {}, steps: {}\n",
      "N/A", utils::INCREMENT, utils::TEST_SIZE, utils::DEGREES, utils::STEPS);

  // 1 ------ WARMUP LOOP ------
  double warmup_sum = 0.0;
  for (const auto &num : test_cases) {
    double float_num = static_cast<double>(num);
    warmup_sum += std::sin(float_num) + std::cos(float_num);
  }
  benchmark::DoNotOptimize(warmup_sum);

  // 2 ---- BENCHMARK LOOP -----
  double sum = 0.0;

  // start perf, then the clock
  perf_ctl << "enable\n" << std::flush;
  auto start_time = std::chrono::steady_clock::now();

  for (const auto &num : test_cases) {
    double float_num = static_cast<double>(num);
    sum += std::sin(float_num) + std::cos(float_num);
  }

  // end the clock, then stop perf
  auto end_time = std::chrono::steady_clock::now();
  perf_ctl << "disable\n" << std::flush;

  const auto duration = (end_time - start_time).count();
  std::print("Processed in: [{}] ns\n", duration);

  std::print("Sum: {}\n", sum);

  benchmark::DoNotOptimize(sum);

  return 0;
}
