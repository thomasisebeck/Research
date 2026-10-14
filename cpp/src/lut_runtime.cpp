#include "utils.cpp"
#include <benchmark/benchmark.h>
#include <chrono>
#include <cmath>
#include <fstream>

int main() {

  std::ofstream perf_ctl("/tmp/perf.ctl");
  std::ifstream perf_ack("/tmp/perf.ack");

  const auto test_cases =
      utils::read_array_from_file<utils::TEST_SIZE>("lookup.txt");

  std::print(
      "LUT size: {}, increment: {}, testSize: {}, degrees: {}, steps: {}\n",
      "N/A", utils::INCREMENT, utils::TEST_SIZE, utils::DEGREES, utils::STEPS);

  // 1 ------ WARMUP LOOP ------
  double warmup_sum = 0.0;
  double sum = 0.0;
  size_t ITERS = 100;

  for (auto i = 0; i < ITERS; i++)
    for (const auto &num : test_cases) {
      double float_num = static_cast<double>(num);
      warmup_sum += std::sin(float_num) + std::cos(float_num);
    }

  benchmark::DoNotOptimize(warmup_sum);

  // 2 ---- BENCHMARK LOOP -----

  // start perf, then the clock
  utils::send_perf_cmd(perf_ctl, perf_ack, "enable");
  auto start_time = std::chrono::steady_clock::now();

  for (auto i = 0; i < ITERS; i++)
    for (const auto &num : test_cases) {
      double float_num = static_cast<double>(num);
      sum += std::sin(float_num) + std::cos(float_num);
    }

  benchmark::DoNotOptimize(sum);

  // end the clock, then stop perf
  auto end_time = std::chrono::steady_clock::now();
  utils::send_perf_cmd(perf_ctl, perf_ack, "disable");

  const auto duration = (end_time - start_time).count();
  std::print("Processed in: [{}] ns. Sum: {}, Warmup Sum: {}\n", duration, sum,
             warmup_sum);

  return 0;
}
