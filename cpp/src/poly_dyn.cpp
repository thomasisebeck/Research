#include "utils.cpp"
#include <array>
#include <benchmark/benchmark.h>
#include <chrono>
#include <cstddef>
#include <fstream>
#include <linux/prctl.h>
#include <print>
#include <sys/prctl.h>

enum class SoundEnum { Woof, Meow, Squeek };

struct AnimalInterface {
  virtual SoundEnum sound() const = 0;
  virtual ~AnimalInterface() = default;
};

struct Dog : public AnimalInterface {
  uint64_t id = 1;

  SoundEnum sound() const override {
    if (id == 0)
      return SoundEnum::Meow;
    return SoundEnum::Woof;
  }
};

struct Cat : public AnimalInterface {
  uint64_t id = 1;

  SoundEnum sound() const override {
    if (id == 0)
      return SoundEnum::Woof;
    return SoundEnum::Meow;
  }
};

struct Mouse : public AnimalInterface {
  uint64_t id = 1;

  SoundEnum sound() const override {
    if (id == 0)
      return SoundEnum::Woof;
    return SoundEnum::Squeek;
  };
};

int main() {
  const std::size_t SIZE = 21;
  const std::size_t ITERS = 100;

  std::ofstream perf_ctl("/tmp/perf.ctl");
  std::ifstream perf_ack("/tmp/perf.ack");

  std::array<SoundEnum, SIZE * ITERS> sound_outputs;

  // allocate on stack, not heap
  Dog d1, d2, d3, d4, d5, d6, d7;
  Cat c1, c2, c3, c4, c5, c6, c7;
  Mouse m1, m2, m3, m4, m5, m6, m7;

  // populate with the addresses
  std::array<AnimalInterface *, SIZE> zoo = {&d1, &c1, &m1, &d2, &c2, &m2, &d3,
                                             &c3, &m3, &d4, &c4, &m4, &d5, &c5,
                                             &m5, &d6, &c6, &m6, &d7, &c7, &m7};

  std::size_t ind = 0;

  benchmark::DoNotOptimize(zoo);

  // start perf, then the clock
  utils::send_perf_cmd(perf_ctl, perf_ack, "enable");
  auto start_time = std::chrono::steady_clock::now();

  for (int j = 0; j < ITERS; j++)
    for (size_t i = 0; i < SIZE; ++i) {
      sound_outputs[ind++] = zoo[i]->sound();
    }

  // end the clock, then stop perf
  auto end_time = std::chrono::steady_clock::now();
  utils::send_perf_cmd(perf_ctl, perf_ack, "disable");

  std::print("\n---  VERIFYING OUTPUTS ---\n");
  for (auto [ind, sound] : std::views::enumerate(sound_outputs)) {
    std::print("Index {}, sound: {}\n", ind, static_cast<int>(sound));
  }

  const auto duration = (end_time - start_time).count();
  std::print("Processed in: [{}] ns\n", duration);

  // black box sound outputs after
  benchmark::DoNotOptimize(sound_outputs);
}
