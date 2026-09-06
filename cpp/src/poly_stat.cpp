#include "utils.cpp"
#include <array>
#include <benchmark/benchmark.h>
#include <chrono>
#include <cstddef>
#include <fstream>
#include <linux/prctl.h>
#include <print>
#include <ranges>
#include <sys/prctl.h>
#include <variant>

enum class SoundEnum { Woof, Meow, Squeek };

struct Dog {
  uint64_t id = 1;

  SoundEnum sound() const {
    if (id == 0)
      return SoundEnum::Meow;
    return SoundEnum::Woof;
  }
};

struct Cat {
  uint64_t id = 1;

  SoundEnum sound() const {
    if (id == 0)
      return SoundEnum::Woof;
    return SoundEnum::Meow;
  }
};

struct Mouse {
  uint64_t id = 1;

  SoundEnum sound() const {
    if (id == 0)
      return SoundEnum::Woof;
    return SoundEnum::Squeek;
  }
};

int main() {
  const std::size_t SIZE = 500;
  const std::size_t ITERS = 1000;

  std::ofstream perf_ctl("/tmp/perf.ctl");
  std::ifstream perf_ack("/tmp/perf.ack");

  std::array<SoundEnum, SIZE * ITERS> sound_outputs;
  std::array<SoundEnum, SIZE * ITERS> sound_outputs_warmup;

  // Single stack instances
  Dog dog;
  Cat cat;
  Mouse mouse;

  using AnimalVariant = std::variant<Cat *, Dog *, Mouse *>;
  std::array<AnimalVariant, SIZE> zoo;

  // Load animal array from file
  auto input_arr = utils::read_array_from_file<int, SIZE>("animals.txt");

  for (std::size_t i = 0; i < SIZE; ++i) {
    switch (input_arr[i]) {
    case 1:
      zoo[i] = &dog;
      break;
    case 2:
      zoo[i] = &cat;
      break;
    case 3:
      zoo[i] = &mouse;
      break;
    default:
      std::unreachable();
    }
  }

  benchmark::DoNotOptimize(zoo);

  std::size_t ind = 0;

  // 1. ----------- WARMUP -------------
  for (std::size_t j = 0; j < ITERS; j++) {
    for (const auto &el : zoo) {
      std::visit(
          [&ind, &sound_outputs_warmup](const auto &x) {
            sound_outputs_warmup[ind++] = x->sound();
          },
          el);
    }
  }

  ind = 0;

  benchmark::DoNotOptimize(zoo);

  // start perf, then the clock
  utils::send_perf_cmd(perf_ctl, perf_ack, "enable");
  auto start_time = std::chrono::steady_clock::now();

  // 2. ----------- BENCHMARK -------------
  for (std::size_t j = 0; j < ITERS; j++) {
    for (const auto &el : zoo) {
      std::visit([&ind, &sound_outputs](
                     const auto &x) { sound_outputs[ind++] = x->sound(); },
                 el);
    }
  }

  // end the clock, then stop perf
  auto end_time = std::chrono::steady_clock::now();
  utils::send_perf_cmd(perf_ctl, perf_ack, "disable");

  std::print("\n---  VERIFYING OUTPUTS ---\n");
  for (auto [ind, sound] : std::views::enumerate(sound_outputs)) {
    std::print("Index {}, sound: {}\n", ind, static_cast<int>(sound));
  }

  for (auto [ind, sound] : std::views::enumerate(sound_outputs_warmup)) {
    std::print("Index {}, sound_warmup: {}\n", ind, static_cast<int>(sound));
  }

  const auto duration = (end_time - start_time).count();
  std::print("Processed in: [{}] ns\n", duration);

  benchmark::DoNotOptimize(sound_outputs);
}
