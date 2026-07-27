#include "utils.cpp"
#include <chrono>
#include <cmath>
#include <sys/prctl.h>

int main() {

  const auto test_cases =
      utils::read_array_from_file<utils::TEST_SIZE>("lookup.txt");

  double sum = 0.0;

  std::print(
      "LUT size: {}, increment: {}, testSize: {}, degrees: {}, steps: {}\n",
      "N/A", utils::INCREMENT, utils::TEST_SIZE, utils::DEGREES, utils::STEPS);

  auto start_time = std::chrono::steady_clock::now();

  prctl(PR_TASK_PERF_EVENTS_ENABLE);

  for (const auto &num : test_cases) {

    double float_num = static_cast<double>(num);
    sum += std::sin(float_num) + std::cos(float_num);
  }

  prctl(PR_TASK_PERF_EVENTS_DISABLE);

  auto end_time = std::chrono::steady_clock::now();
  const auto duration_comp = end_time - start_time;

  std::print("Processed in: {} ns\n", duration_comp);
  std::print("Sum: {}\n", sum);

  return 0;
}
