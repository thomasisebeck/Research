#include <array>
#include <chrono>
#include <cstddef>
#include <memory>
#include <print>
#include <vector>
enum class SoundEnum { Woof, Meow, Squeek };

struct AnimalInterface {
  virtual SoundEnum sound() const = 0;
  // virtual destructor, since it is abstract
  virtual ~AnimalInterface() = default;
};

struct Dog : public AnimalInterface {
  SoundEnum sound() const override { return SoundEnum::Woof; }
};

struct Cat : public AnimalInterface {
  SoundEnum sound() const override { return SoundEnum::Meow; }
};

struct Mouse : public AnimalInterface {
  SoundEnum sound() const override { return SoundEnum::Squeek; }
};

int main() {
  const std::size_t SIZE = 3;
  std::array<SoundEnum, SIZE> sound_outputs;

  std::vector<std::unique_ptr<AnimalInterface>> zoo;
  zoo.reserve(SIZE);

  zoo.push_back(std::make_unique<Cat>());
  zoo.push_back(std::make_unique<Dog>());
  zoo.push_back(std::make_unique<Mouse>());

  const auto start_time = std::chrono::steady_clock::now();

  for (size_t i = 0; i < SIZE; ++i) {
    sound_outputs[i] = zoo[i]->sound();
  }

  auto end_time = std::chrono::steady_clock::now();
  auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(
                      end_time - start_time)
                      .count();

  std::print("\n---  VERIFYING OUTPUTS ---\n");
  for (size_t i = 0; i < SIZE; ++i) {
    std::print("Index {}: {}\n", i, static_cast<int>(sound_outputs[i]));
  }
  std::print("Processed in: {}\n", duration);
}
