#include "utils.cpp"
#include <chrono>
#include <fstream>
#include <iostream>

int main() {
  std::ofstream perf_ctl("/tmp/perf.ctl");
  std::ifstream perf_ack("/tmp/perf.ack");

  // --------------- start perf, then the clock ---------------- //
  utils::send_perf_cmd(perf_ctl, perf_ack, "enable");
  const auto start_time = std::chrono::steady_clock::now();
  // ----------------------------------------------------------- //

  // Measured payload
  std::cout << "Hello, World!\n";

  // -------------- stop the clock, then end perf -------------- //
  const auto end_time = std::chrono::steady_clock::now();
  utils::send_perf_cmd(perf_ctl, perf_ack, "disable");
  // ----------------------------------------------------------- //

  const auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(
                            end_time - start_time)
                            .count();

  //---------------------- print and clean ------------------
  std::cout << "Processed in: [" << duration << "] ns\n";
  //---------------------------------------------------------

  return 0;
}
