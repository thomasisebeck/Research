#include "utils.cpp"
#include <benchmark/benchmark.h>
#include <chrono>
#include <cstdint>

__attribute__((noinline)) uint64_t benchmark_loop(uint64_t x,
                                                  uint64_t iterations) {
  for (uint64_t i = 0; i < iterations; ++i) {
    x = x * 6364136223846793005ULL + 1;
    asm volatile("" : "+r"(x));
  }
  return x;
}

int main() {
  std::ofstream perf_ctl("/tmp/perf.ctl");
  std::ifstream perf_ack("/tmp/perf.ack");

  const int ITERS = 100;
  uint64_t warmup_res = 0;
  uint64_t res = 0;

  uint64_t init_val = 200;
  uint64_t iters = 200;
  benchmark::DoNotOptimize(init_val);
  benchmark::DoNotOptimize(iters);

  for (auto i = 0; i < ITERS; i++) {
    warmup_res += benchmark_loop(init_val, iters);
  }

  benchmark::DoNotOptimize(warmup_res);

  // --------------- start perf, then the clock ---------------- //
  utils::send_perf_cmd(perf_ctl, perf_ack, "enable");
  const auto start_time = std::chrono::steady_clock::now();
  // ----------------------------------------------------------- //

  for (auto i = 0; i < ITERS; i++) {
    res += benchmark_loop(init_val, iters);
  }

  benchmark::DoNotOptimize(res);

  // -------------- stop the clock, then end perf -------------- //
  const auto end_time = std::chrono::steady_clock::now();
  utils::send_perf_cmd(perf_ctl, perf_ack, "disable");
  // ----------------------------------------------------------- //

  const auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(
                            end_time - start_time)
                            .count();

  //---------------------- print and clean ------------------
  std::cout << "Processed in: [" << duration << "] ns, warmup res "
            << warmup_res << " res " << res << std::endl;
  //---------------------------------------------------------

  return 0;
}
