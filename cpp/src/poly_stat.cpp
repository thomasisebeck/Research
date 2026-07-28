#include <array>
#include <chrono>
#include <cstddef>
#include <linux/prctl.h>
#include <print>
#include <ranges>
#include <sys/prctl.h>
#include <variant>
#include <vector>

enum class SoundEnum { Woof, Meow, Squeek };

template <typename Derived> struct Animal {
  SoundEnum sound() const {
    // cast to the base class using CRTP
    return static_cast<const Derived *>(this)->sound_impl();
  }
};

struct Dog : public Animal<Dog> {
  uint64_t id = 1;

  SoundEnum sound_impl() const {
    if (id == 0)
      return SoundEnum::Meow;
    return SoundEnum::Woof;
  }
};

struct Cat : public Animal<Cat> {
  uint64_t id = 1;

  SoundEnum sound_impl() const {
    if (id == 0)
      return SoundEnum::Woof;
    return SoundEnum::Meow;
  }
};

struct Mouse : public Animal<Mouse> {
  uint64_t id = 1;

  SoundEnum sound_impl() const {
    if (id == 0)
      return SoundEnum::Woof;
    return SoundEnum::Squeek;
  }
};

int main() {
  const std::size_t SIZE = 21;
  const std::size_t ITERS = 100;

  std::array<SoundEnum, SIZE * ITERS> sound_outputs;

  // variant is for a hetrogenous array
  // uses a tagged union under the hood
  using AnimalVariant = std::variant<Cat, Dog, Mouse>;
  std::vector<AnimalVariant> zoo;
  zoo.reserve(SIZE);

  // push 21 random animals that are static
  zoo.push_back(Dog{});
  zoo.push_back(Cat{});
  zoo.push_back(Mouse{});
  zoo.push_back(Cat{});
  zoo.push_back(Dog{});
  zoo.push_back(Mouse{});
  zoo.push_back(Dog{});
  zoo.push_back(Mouse{});
  zoo.push_back(Cat{});
  zoo.push_back(Mouse{});
  zoo.push_back(Cat{});
  zoo.push_back(Dog{});
  zoo.push_back(Mouse{});
  zoo.push_back(Dog{});
  zoo.push_back(Cat{});
  zoo.push_back(Mouse{});
  zoo.push_back(Dog{});
  zoo.push_back(Cat{});
  zoo.push_back(Mouse{});
  zoo.push_back(Cat{});
  zoo.push_back(Dog{});

  // start perf, then the clock
  prctl(PR_TASK_PERF_EVENTS_ENABLE);
  auto start_time = std::chrono::steady_clock::now();

  std::size_t ind = 0;

  for (int j = 0; j < ITERS; j++)
    // std::visit is also a new feature to call the functions
    // in that hetrogenous array
    for (size_t i = 0; i < SIZE; ++i) {
      sound_outputs[ind++] =
          std::visit([](const auto &animal) { return animal.sound(); }, zoo[i]);
    }

  // end the clock, then stop perf
  auto end_time = std::chrono::steady_clock::now();
  prctl(PR_TASK_PERF_EVENTS_DISABLE);

  auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(
                      end_time - start_time)
                      .count();

  std::print("\n---  VERIFYING OUTPUTS ---\n");
  for (auto [ind, sound] : std::views::enumerate(sound_outputs)) {
    std::print("Index {}, sound: {}\n", ind, static_cast<int>(sound));
  }
  std::print("Processed in: {}\n", duration);
}
