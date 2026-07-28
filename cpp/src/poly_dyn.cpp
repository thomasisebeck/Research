#include <array>
#include <chrono>
#include <cstddef>
#include <linux/prctl.h>
#include <memory>
#include <print>
#include <ranges>
#include <sys/prctl.h>
#include <vector>
enum class SoundEnum { Woof, Meow, Squeek };

struct AnimalInterface {
  virtual SoundEnum sound() const = 0;
  // virtual destructor, since it is abstract
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

  std::vector<std::unique_ptr<AnimalInterface>> zoo;
  zoo.reserve(SIZE);

  // push 21 random animals that are polymorphic
  zoo.push_back(std::make_unique<Dog>());
  zoo.push_back(std::make_unique<Cat>());
  zoo.push_back(std::make_unique<Mouse>());
  zoo.push_back(std::make_unique<Cat>());
  zoo.push_back(std::make_unique<Dog>());
  zoo.push_back(std::make_unique<Mouse>());
  zoo.push_back(std::make_unique<Dog>());
  zoo.push_back(std::make_unique<Mouse>());
  zoo.push_back(std::make_unique<Cat>());
  zoo.push_back(std::make_unique<Mouse>());
  zoo.push_back(std::make_unique<Cat>());
  zoo.push_back(std::make_unique<Dog>());
  zoo.push_back(std::make_unique<Mouse>());
  zoo.push_back(std::make_unique<Dog>());
  zoo.push_back(std::make_unique<Cat>());
  zoo.push_back(std::make_unique<Mouse>());
  zoo.push_back(std::make_unique<Dog>());
  zoo.push_back(std::make_unique<Cat>());
  zoo.push_back(std::make_unique<Mouse>());
  zoo.push_back(std::make_unique<Cat>());
  zoo.push_back(std::make_unique<Dog>());

  std::size_t ind = 0;

  // start perf, then the clock
  prctl(PR_TASK_PERF_EVENTS_ENABLE);
  auto start_time = std::chrono::steady_clock::now();

  for (int j = 0; j < ITERS; j++)
    for (size_t i = 0; i < SIZE; ++i) {
      sound_outputs[ind++] = zoo[i]->sound();
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
