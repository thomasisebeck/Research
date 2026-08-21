#include "utils.cpp"
#include <chrono>
using namespace std;

int main() {

  std::ofstream perf_ctl("/tmp/perf.ctl");
  std::ifstream perf_ack("/tmp/perf.ack");

  const auto FILE = "calibration.txt";

  const int ITERATIONS = 100;
  utils::write_array_to_file<10000>(FILE);

  // get the array to add
  const auto arr = utils::read_array_from_file<10000>(FILE);

  long warmup_sum = 0;

  for (int i = 0; i < ITERATIONS; i++)
    for (const auto &el : arr) {
      warmup_sum += el;
    }

  long sum = 0;

  utils::send_perf_cmd(perf_ctl, perf_ack, "enable");
  const auto start_time = std::chrono::steady_clock::now();

  for (int i = 0; i < ITERATIONS; i++)
    for (const auto &el : arr) {
      sum += el;
    }

  const auto end_time = std::chrono::steady_clock::now();
  utils::send_perf_cmd(perf_ctl, perf_ack, "disable");

  const auto duration = (end_time - start_time).count();

  std::print("Processed in: [{}] ns, sum: {}, warmup: {}\n", duration, sum,
             warmup_sum);

  return 0;
}
