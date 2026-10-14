#include <array>
#include <benchmark/benchmark.h>
#include <chrono>
#include <cstddef>
#include <linux/prctl.h>
#include <print>
#include <ranges>
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

  // start perf, then the clock
  prctl(PR_TASK_PERF_EVENTS_ENABLE);
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
      sound_outputs[ind++] = zoo[i]->sound();
    }

  // end the clock, then stop perf
  auto end_time = std::chrono::steady_clock::now();
  prctl(PR_TASK_PERF_EVENTS_DISABLE);

  std::print("\n---  VERIFYING OUTPUTS ---\n");
  for (auto [ind, sound] : std::views::enumerate(sound_outputs)) {
    std::print("Index {}, sound: {}\n", ind, static_cast<int>(sound));
  }

  const auto duration = (end_time - start_time).count();
  std::print("Processed in: [{}] ns\n", duration);

  benchmark::DoNotOptimize(sound_outputs);
  benchmark::DoNotOptimize(zoo);
}
