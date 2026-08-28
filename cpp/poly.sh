#!/usr/bin/env bash

ITERATIONS=${1:-10}
ITERATIONS_BUILD=${1:-10}
BUILD_CSV="build_times.csv"
RUNTIME_CSV="runtime.csv"
SETTING_NAME="N/A"
PERF_EVENTS="cycles,instructions,cache-misses,cache-references,branches,branch-misses"
PERF_CTL="/tmp/perf.ctl"
PERF_ACK="/tmp/perf.ack"

FILES=(
  "poly_dyn.cpp"
  "poly_stat.cpp"
)

# 1. Initialize CSV headers if files don't exist yet
if [ ! -f "$BUILD_CSV" ]; then
  echo "label,setting,run_number,cold_real,cold_user,cold_sys,hot_real,hot_user,hot_sys" > "$BUILD_CSV"
fi

if [ ! -f "$RUNTIME_CSV" ]; then
  echo "label,setting,run_number,runtime_ns,cycles,instructions,cache-misses,cache-references,branches,branch-misses" > "$RUNTIME_CSV"
fi

echo "=================================================="
echo " Phase 0: Address Space Randomisation"
echo "=================================================="
echo 0 | sudo tee /proc/sys/kernel/randomize_va_space

# Loop over each target file (dynamic vs static polymorphism)
for FILENAME in "${FILES[@]}"; do
  LABEL="${FILENAME%.*}"

  echo "=================================================="
  echo " Target: ${LABEL}"
  echo "=================================================="

  # ----------------------------------------------------
  # Phase 1: Build Phase (10 Iterations)
  # ----------------------------------------------------
  echo " Phase 1: Measuring ${ITERATIONS_BUILD} Builds..."

  for (( i=1; i<=ITERATIONS_BUILD; i++ )); do
    echo "  -> Build ${i}/${ITERATIONS_BUILD}..."

    rm -rf build
    mkdir -p build
    cd build || exit 1

    # Configure CMake
    CCACHE_DISABLE=1 cmake .. -DOptimise=ON \
             -DTARGET_SRC="${FILENAME}" > /dev/null 2>&1

    # Measure Cold Build
    COLD_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 1 make -s -j$(nproc) > /dev/null; } 2>&1 )

    # Measure Hot Build
    touch "../src/${FILENAME}"
    HOT_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 1 make -s -j$(nproc) > /dev/null; } 2>&1 )

    cd ..

    # Log build row
    echo "${LABEL},${SETTING_NAME},${i},${COLD_TIME},${HOT_TIME}" >> "$BUILD_CSV"
  done

  # ----------------------------------------------------
  # Phase 2: CPU Cooling Phase
  # ----------------------------------------------------
  echo " Phase 2: Cooling CPU (5s sleep)"
  sleep 5

  # ----------------------------------------------------
  # Phase 3: Benchmark Execution Phase (10 Iterations)
  # ----------------------------------------------------
  echo " Phase 3: Executing ${ITERATIONS} Benchmarks on Core 1"

  # Ensure executable binary exists prior to perf run
  mkdir -p build && cd build || exit 1
  CCACHE_DISABLE=1 cmake .. -DOptimise=ON \
           -DTARGET_SRC="${FILENAME}" > /dev/null 2>&1
  make -s -j$(nproc) > /dev/null 2>&1

  for (( i=1; i<=ITERATIONS; i++ )); do
    echo "  -> Run ${i}/${ITERATIONS}..."

    # Create perf FIFOs
    sudo rm -rf ${PERF_CTL} ${PERF_ACK}
    mkfifo ${PERF_CTL} ${PERF_ACK}
    sudo chmod 666 ${PERF_CTL} ${PERF_ACK}

    PERF_RAW_FILE=$(mktemp)

    OUT_DATA=$(sudo taskset -c 1 perf stat -x, --delay=-1 --control="fifo:${PERF_CTL},${PERF_ACK}" \
      -e "$PERF_EVENTS" \
      ./out 2> >(grep -vE "^Events (enabled|disabled)" > "$PERF_RAW_FILE"))

    # Extract runtime_ns
    RUN_NS=$(echo "$OUT_DATA" | grep "Processed in:" | awk -F'[][]' '{print $2}')

    # Parse values safely
    PERF_METRICS=$(awk -F',' '{
      val = $1;
      if (val ~ /<not supported>/ || val == "") val = "0";
      print val;
    }' "$PERF_RAW_FILE" | tr '\n' ',' | sed 's/,$//')

    rm -f "$PERF_RAW_FILE"

    # Log runtime row
    echo "${LABEL},${SETTING_NAME},${i},${RUN_NS},${PERF_METRICS}" >> "../${RUNTIME_CSV}"
  done

  cd ..
  rm -rf build

done

echo "Polymorphism Benchmark complete! Data saved to ${BUILD_CSV} and ${RUNTIME_CSV}"
