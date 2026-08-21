#!/usr/bin/env bash

ITERATIONS=${1:-2}  
ITERATIONS_BUILD=${1:-2}  
BUILD_CSV="build_times.csv"
RUNTIME_CSV="runtime.csv"
LABEL="calibration"
PERF_EVENTS="cycles,instructions,cache-misses,cache-references,branches,branch-misses"
PERF_CTL="/tmp/perf.ctl"
PERF_ACK="/tmp/perf.ack"

# 1. Initialize CSV headers if files don't exist yet
if [ ! -f "$BUILD_CSV" ]; then
  echo "label,setting,run_number,cold_real,cold_user,cold_sys,hot_real,hot_user,hot_sys" > "$BUILD_CSV"
fi

if [ ! -f "$RUNTIME_CSV" ]; then
  echo "label,setting,run_number,runtime_ns,cycles,instructions,cache-misses,cache-references,branches,branch-misses" > "$RUNTIME_CSV"
fi


echo "=================================================="
echo " Phase 0: Adress Space Randomisation"
echo "=================================================="
echo 0 | sudo tee /proc/sys/kernel/randomize_va_space

echo "=================================================="
echo " Phase 1: Measuring ${ITERATIONS} Builds"
echo "=================================================="

for (( i=1; i<=ITERATIONS_BUILD; i++ )); do
  echo "  -> Build ${i}/${ITERATIONS}..."

  rm -rf build

  mkdir -p build 

  cd build || exit 1

  cmake .. -DOptimise=ON  -DTARGET_SRC="${LABEL}"

  # Measure Cold Build
  COLD_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 1 make -s -j$(nproc) > /dev/null; } 2>&1 )

  # Measure Hot Build
  touch "../src/calibration.cpp"
  HOT_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 1 make -s -j$(nproc) > /dev/null; } 2>&1 )

  cd ..


  # Log build row
  echo "${LABEL},N/A,${i},${COLD_TIME},${HOT_TIME}" >> "$BUILD_CSV"
done

echo "Build phase complete. Data saved to ${BUILD_CSV}"

echo "=================================================="
echo " Phase 2: Cooling CPU (10s sleep)"
echo "=================================================="
sleep 1

echo "=================================================="
echo " Phase 3: Executing ${ITERATIONS} Benchmarks on Core 1"
echo "=================================================="

cd build

for (( i=1; i<=ITERATIONS; i++ )); do
  echo "  -> Run ${i}/${ITERATIONS}..."

  # create perf files
  sudo rm -rf ${PERF_CTL} ${PERF_ACK}
  mkfifo ${PERF_CTL} ${PERF_ACK}
  sudo chmod 666 ${PERF_CTL} ${PERF_ACK}

  PERF_RAW_FILE=$(mktemp)

  OUT_DATA=$(sudo taskset -c 1 perf stat -x, --delay=-1 --control="fifo:${PERF_CTL},${PERF_ACK}" \
    -e "$PERF_EVENTS" \
    ./out 2> >(grep -vE "^Events (enabled|disabled)" > "$PERF_RAW_FILE"))

  # Extract runtime_ns
  RUN_NS=$(echo "$OUT_DATA" | grep "Processed in:" | awk -F'[][]' '{print $2}')

  # Parse values safely (converts unsupported/empty entries into 0)
  PERF_METRICS=$(awk -F',' '{
    val = $1;
    if (val ~ /<not supported>/ || val == "") val = "0";
    print val;
  }' "$PERF_RAW_FILE" | tr '\n' ',' | sed 's/,$//')

  rm -f "$PERF_RAW_FILE"

  # Log runtime row
  echo "${LABEL},N/A,${i},${RUN_NS},${PERF_METRICS}" >> "../${RUNTIME_CSV}"
done

cd ..
rm -rf build

echo "Benchmark complete! Data saved to ${RUNTIME_CSV}"
