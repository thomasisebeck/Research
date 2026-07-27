#include <array>
#include <chrono>
#include <cstddef>
#include <print>
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
  SoundEnum sound_impl() const { return SoundEnum::Woof; }
};

struct Cat : public Animal<Cat> {
  SoundEnum sound_impl() const { return SoundEnum::Meow; }
};

struct Mouse : public Animal<Mouse> {
  SoundEnum sound_impl() const { return SoundEnum::Squeek; }
};

int main() {
  const std::size_t SIZE = 3;
  std::array<SoundEnum, SIZE> sound_outputs;

  // variant is for a hetrogenous array
  // uses a tagged union under the hood
  using AnimalVariant = std::variant<Cat, Dog, Mouse>;
  std::vector<AnimalVariant> zoo;
  zoo.reserve(SIZE);

  zoo.push_back(Cat{});
  zoo.push_back(Dog{});
  zoo.push_back(Mouse{});

  const auto start_time = std::chrono::steady_clock::now();

  // std::visit is also a new feature to call the functions
  // in that hetrogenous array
  for (size_t i = 0; i < SIZE; ++i) {
    sound_outputs[i] =
        std::visit([](const auto &animal) { return animal.sound(); }, zoo[i]);
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
