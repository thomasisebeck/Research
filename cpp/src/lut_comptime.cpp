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

  std::ofstream perf_ctl("/tmp/perf.ctl");
  std::ifstream perf_ack("/tmp/perf.ack");

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

  utils::send_perf_cmd(perf_ctl, perf_ack, "enable");
  auto start_time = std::chrono::steady_clock::now();

  for (const auto &num : test_cases) {
    const size_t idx = static_cast<size_t>(num * prediv);

    sum += myLut[idx];
  }

  auto end_time = std::chrono::steady_clock::now();
  utils::send_perf_cmd(perf_ctl, perf_ack, "disable");

  const auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(
                            end_time - start_time)
                            .count();

  std::print("Processed in: [{}] ns. Sum: {}\n", duration, sum);

  benchmark::DoNotOptimize(sum);

  return 0;
}
