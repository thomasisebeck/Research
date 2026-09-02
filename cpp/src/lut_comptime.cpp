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

  constexpr auto myLut = generate_lut();
  // faster but not fair
  // auto myLut = COMPTIME_LUT;

  const double prediv = 1.0 / utils::INCREMENT;
  double warmup_sum = 0.0;
  double sum = 0.0;
  size_t ITERS = 100;

  std::print(
      "LUT size: {}, increment: {}, testSize: {}, degrees: {}, steps: {}\n",
      myLut.size(), utils::INCREMENT, utils::TEST_SIZE, utils::DEGREES,
      utils::STEPS);

  for (auto i = 0; i < ITERS; i++)
    for (const auto &num : test_cases) {
      const size_t idx = static_cast<size_t>(num * prediv);

      warmup_sum += myLut[idx];
    }

  benchmark::DoNotOptimize(warmup_sum);

  utils::send_perf_cmd(perf_ctl, perf_ack, "enable");
  auto start_time = std::chrono::steady_clock::now();

  //++ / Zig Conservative Aliasing: Because raw pointers and standard references
  //in C++ and Zig allow for potential aliasing (where writing to sum might
  //theoretically modify the memory backing the array), LLVM's alias analyzer
  //must take the conservative path and re-read the array from memory on every
  //outer iteration to remain spec-compliant.

  for (auto i = 0; i < ITERS; i++)
    for (const auto &num : test_cases) {
      const size_t idx = static_cast<size_t>(num * prediv);

      sum += myLut[idx];
    }

  benchmark::DoNotOptimize(sum);

  auto end_time = std::chrono::steady_clock::now();
  utils::send_perf_cmd(perf_ctl, perf_ack, "disable");

  const auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(
                            end_time - start_time)
                            .count();

  std::print("Processed in: [{}] ns. Sum: {}, Warmup Sum: {}\n", duration, sum,
             warmup_sum);

  return 0;
}
