#include "utils.cpp"
#include <array>
#include <benchmark/benchmark.h>
#include <chrono>
#include <cstddef>
#include <fstream>
#include <print>

namespace comptime {
// Pure constexpr Taylor series for compile-time lookup table population
constexpr double sin(double x) {
  double sum = x;
  double term = x;
  for (int n = 1; n <= 12; ++n) {
    term *= -x * x / ((2 * n) * (2 * n + 1));
    sum += term;
  }
  return sum;
}

constexpr double cos(double x) {
  double sum = 1.0;
  double term = 1.0;
  for (int n = 1; n <= 12; ++n) {
    term *= -x * x / ((2 * n - 1) * (2 * n));
    sum += term;
  }
  return sum;
}
} // namespace comptime

constexpr std::array<double, utils::STEPS> generate_lut() {
  std::array<double, utils::STEPS> table;

  for (int i = 0; i < utils::STEPS; i++) {
    const double result = i * utils::INCREMENT;
    table[i] = std::sin(result) + comptime::cos(result);
  }

  return table;
}

int main() {

  std::ofstream perf_ctl("/tmp/perf.ctl");
  std::ifstream perf_ack("/tmp/perf.ack");

  const auto test_cases =
      utils::read_array_from_file<double, utils::TEST_SIZE>("lookup.txt");

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

  // vmovsd  xmm3, QWORD PTR .LC76[rip]
  //   mov     esi, 100
  //         dec     rcx
  //   jne     .L4724
  //
  for (size_t i = 0; i < ITERS; i++) {
    //     cmp     r13, rax
    //     jne     .L4726
    for (const auto &num : test_cases) {
      // movabs  rcx, -9223372036854775808
      // vcvttsd2si      rdx, xmm0
      // vmulsd  xmm0, xmm3, QWORD PTR [rax]
      // vcomisd xmm0, xmm1
      // jb      .L4833
      // vsubsd  xmm0, xmm0, xmm1
      // vcvttsd2si      rdx, xmm0
      // xor     rdx, rcx
      // jmp     .L4723
      const size_t idx = static_cast<size_t>(num * prediv);

      // 81792: where myLut is relative to the local stack frame
      // vaddsd  xmm2, xmm2, QWORD PTR [rsp+81792+rdx*8]
      warmup_sum += myLut[idx];
    }
  }

  benchmark::DoNotOptimize(warmup_sum);

  utils::send_perf_cmd(perf_ctl, perf_ack, "enable");
  auto start_time = std::chrono::steady_clock::now();

  //++ / Zig Conservative Aliasing: Because raw pointers and standard references
  // in C++ and Zig allow for potential aliasing (where writing to sum might
  // theoretically modify the memory backing the array), LLVM's alias analyzer
  // must take the conservative path and re-read the array from memory on every
  // outer iteration to remain spec-compliant.

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
