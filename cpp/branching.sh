#!/usr/bin/env bash

# REMEMBER TO RUN WITH SUDO!
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run with sudo!"
  exit 1
fi

set -e

ITERATIONS=${1:-15}
ITERATIONS_BUILD=${1:-1}
BUILD_CSV="build_times.csv"
RUNTIME_CSV="runtime.csv"
PERF_EVENTS="cycles,instructions,cache-misses,cache-references,branches,branch-misses"
PERF_CTL="/tmp/perf.ctl"
PERF_ACK="/tmp/perf.ack"

FILES=(
  # "image_pipeline_comptime.cpp"
  "image_pipeline_runtime.cpp"
)

QUALITIES=("utils::Mode::LOW" "utils::Mode::MED" "utils::Mode::HIGH")
TOGGLE_SETS=(
  "false,false,false"
  "true,false,true"
  "true,true,true"
)

# 1. Initialize CSV headers if files don't exist yet
if [ ! -f "$BUILD_CSV" ]; then
  echo "label,setting,run_number,cold_real,cold_user,cold_sys,hot_real,hot_user,hot_sys" > "$BUILD_CSV"
fi

if [ ! -f "$RUNTIME_CSV" ]; then
  echo "label,setting,run_number,runtime_ns,$PERF_EVENTS" > "$RUNTIME_CSV"
fi

# ----------------------------------------------------
# Phase 0: System Isolation & Environment Preparation
# ----------------------------------------------------
echo "=================================================="
echo " Phase 0: Address Space Rand, Freq scaling, Turbo"
echo "=================================================="
echo 0 | tee /proc/sys/kernel/randomize_va_space
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
  echo 1 | tee /sys/devices/system/cpu/intel_pstate/no_turbo
fi

ulimit -s unlimited

NUM_CONFIGS=${#QUALITIES[@]}

# Outer loops iterate over target files and setting configurations
for FILENAME in "${FILES[@]}"; do
  LABEL="${FILENAME%.*}"

  for (( c=0; c<NUM_CONFIGS; c++ )); do

    QUAL="${QUALITIES[$c]}"
    TOGGLES="${TOGGLE_SETS[$c]}"

    QUAL_SHORT="${QUAL##*::}"
    IFS=',' read -r A1 A2 A3 <<< "$TOGGLES"
    SETTING_NAME="${QUAL_SHORT}_${A1}_${A2}_${A3}"

    echo "=================================================="
    echo " Target: ${LABEL} | Config [${c}]: ${SETTING_NAME}"
    echo "=================================================="

    # Derive CONFIG_VAL cleanly based on QUAL string rather than loop index
    case "$QUAL_SHORT" in
      LOW)  CONFIG_VAL=0 ;;
      MED)  CONFIG_VAL=1 ;;
      HIGH) CONFIG_VAL=2 ;;
      *)    CONFIG_VAL=0 ;;
    esac

    rm "image_config.txt"

    # Step 1: Write config value to project root
    echo "$CONFIG_VAL" > "image_config.txt"

    # ----------------------------------------------------
    # Phase 1: Build Phase (Multiple Iterations)
    # ----------------------------------------------------
    echo " Phase 1: Measuring ${ITERATIONS_BUILD} Builds..."

    for (( i=1; i<=ITERATIONS_BUILD; i++ )); do
      echo "  -> Build ${i}/${ITERATIONS_BUILD}..."

      rm -rf build
      mkdir -p build
      cd build || exit 1

      # Step 2: Configure CMake
      CCACHE_DISABLE=1 cmake .. -DOptimise=ON \
               -DTARGET_SRC="${FILENAME}" \
               -DQUAL_VAL="${QUAL}" \
               -DAPPLY_ONE_VAL="${A1}" \
               -DAPPLY_TWO_VAL="${A2}" \
               -DAPPLY_THREE_VAL="${A3}" > /dev/null 2>&1

      # Step 3: Measure Cold Build
      COLD_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0 make -s -j$(nproc) > /dev/null; } 2>&1 )

      # Measure Hot Build
      touch "../src/${FILENAME}"
      HOT_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0 make -s -j$(nproc) > /dev/null; } 2>&1 )

      cd ..

      # Log build row
      echo "${LABEL},${SETTING_NAME},${i},${COLD_TIME},${HOT_TIME}" >> "$BUILD_CSV"
    done

    # ----------------------------------------------------
    # Phase 2: CPU Cooling Phase
    # ----------------------------------------------------
    echo " Phase 2: Cooling CPU (5s sleep)"

    # Final build sequence before running binary
    rm -rf build
    mkdir -p build
    cp image_config.txt build/
    cd build || exit 1

    CCACHE_DISABLE=1 cmake .. -DOptimise=ON \
             -DTARGET_SRC="${FILENAME}" \
             -DQUAL_VAL="${QUAL}" \
             -DAPPLY_ONE_VAL="${A1}" \
             -DAPPLY_TWO_VAL="${A2}" \
             -DAPPLY_THREE_VAL="${A3}" > /dev/null 2>&1
    make -s -j$(nproc) > /dev/null 2>&1
    cd ..

    sleep 5

    # ----------------------------------------------------
    # Phase 3: Benchmark Execution Phase
    # ----------------------------------------------------
    echo " Phase 3: Executing ${ITERATIONS} Benchmarks on Core 0"

    for (( i=1; i<=ITERATIONS; i++ )); do
      echo "  -> Run ${i}/${ITERATIONS}..."

      # Step 4: Run executable with perf stat
      rm -f ${PERF_CTL} ${PERF_ACK}
      mkfifo ${PERF_CTL} ${PERF_ACK}
      chmod 666 ${PERF_CTL} ${PERF_ACK}

    # perf stat -x, --delay=-1 --control="fifo:${PERF_CTL},${PERF_ACK}" -e "$PERF_EVENTS" taskset -c  0  ./build/out

      PERF_RAW_FILE=$(mktemp)

      OUT_DATA=$(perf stat -x, --delay=-1 --control="fifo:${PERF_CTL},${PERF_ACK}" \
        -e "$PERF_EVENTS" \
        taskset -c 0 \
        ./build/out 2> >(grep -vE "^Events (enabled|disabled)" > "$PERF_RAW_FILE"))

      RUN_NS=$(echo "$OUT_DATA" | grep "Processed in:" | awk -F'[][]' '{print $2}')

      PERF_METRICS=$(awk -F',' '{
        val = $1;
        if (val ~ /<not supported>/ || val == "") val = "0";
        print val;
      }' "$PERF_RAW_FILE" | tr '\n' ',' | sed 's/,$//')

      rm -f "$PERF_RAW_FILE"

      echo "${LABEL},${SETTING_NAME},${i},${RUN_NS},${PERF_METRICS}" >> "${RUNTIME_CSV}"
    done

    rm -rf build

  done
done

echo "Image Pipeline Benchmark complete! Data saved to ${BUILD_CSV} and ${RUNTIME_CSV}"
