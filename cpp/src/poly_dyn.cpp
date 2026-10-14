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

  std::array<AnimalInterface *, SIZE> zoo;

  // Load animal array from file
  std::array<int, SIZE> input_arr =
      utils::read_array_from_file<int, SIZE>("animals.txt");

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
      sound_outputs_warmup[ind++] = el->sound();
    }
  }

  ind = 0;

  benchmark::DoNotOptimize(zoo);

  // start perf, then the clock
  utils::send_perf_cmd(perf_ctl, perf_ack, "enable");
  auto start_time = std::chrono::steady_clock::now();

  for (int j = 0; j < ITERS; j++)
    for (size_t i = 0; i < SIZE; ++i) {

      // speculative devirtualisation

      /*
               .loc 1 67 13 is_stmt 1 view .LVU89
# /app/example.cpp:67:             sound_outputs[ind++] = zoo[i]->sound();
        .loc 1 67 49 is_stmt 0 discriminator 1 view .LVU90
        mov     rdi, QWORD PTR [rbx]      # _98, MEM[(struct AnimalInterface *
*)_70] cmp     rax, OFFSET FLAT:"Mouse::sound() const"     # pretmp_142, je .L22
#, cmp     rax, OFFSET FLAT:"Cat::sound() const"       # pretmp_142, je .L23 #,
        cmp     rax, OFFSET FLAT:"Dog::sound() const"       # pretmp_142,
        jne     .L16      #,
       */
      // 2. ----------- BENCHMARK -------------
      for (std::size_t j = 0; j < ITERS; j++) {
        for (const auto &el : zoo) {
          sound_outputs[ind++] = el->sound();
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
        std::print("Index {}, sound_warmup: {}\n", ind,
                   static_cast<int>(sound));
      }

      const auto duration = (end_time - start_time).count();
      std::print("Processed in: [{}] ns\n", duration);

      benchmark::DoNotOptimize(sound_outputs);
    }
