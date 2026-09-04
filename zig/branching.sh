#!/usr/bin/env bash

# REMEMBER TO RUN WITH SUDO!
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run with sudo!"
  exit 1
fi

set -e

# 1. Define source files to benchmark
FILES=(
  "image_pipeline_comptime.zig"
  "image_pipeline_runtime.zig"
)

ITERATIONS=${1:-15}
ITERATIONS_BUILD=${1:-15}
BUILD_CSV="build_times.csv"
RUNTIME_CSV="runtime.csv"

PERF_EVENTS="cycles,instructions,cache-misses,cache-references,branches,branch-misses"
PERF_CTL="/tmp/perf.ctl"
PERF_ACK="/tmp/perf.ack"

# 2. Quality and Toggle Configurations
QUALITIES=("LOW" "MED" "HIGH")
TOGGLE_SETS=(
  "false,false,false"
  "true,false,true"
  "true,true,true"
)

# 3. Initialize CSV headers if files don't exist yet
if [ ! -f "$BUILD_CSV" ]; then
  echo "label,setting,run_number,cold_real,cold_user,cold_sys,hot_real,hot_user,hot_sys" > "$BUILD_CSV"
fi

if [ ! -f "$RUNTIME_CSV" ]; then
  echo "label,setting,run_number,runtime_ns,$PERF_EVENTS" > "$RUNTIME_CSV"
fi

# Phase 0: System Isolation & Environment Preparation
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

for FILENAME in "${FILES[@]}"; do
  LABEL="${FILENAME%.*}"

  for (( c=0; c<NUM_CONFIGS; c++ )); do
    QUAL="${QUALITIES[$c]}"
    TOGGLES="${TOGGLE_SETS[$c]}"

    IFS=',' read -r A1 A2 A3 <<< "$TOGGLES"
    SETTING_NAME="${QUAL}_${A1}_${A2}_${A3}"

    echo "=================================================="
    echo " Target: ${LABEL} | Config [${c}]: ${SETTING_NAME}"
    echo "=================================================="

    # Construct the common build flags array
    BUILD_FLAGS=(
      "-Dtarget_src=src/${FILENAME}"
      "-Doptimize=ReleaseFast"
      "-Dblur_mode=${QUAL}"
      "-Dapply_blur=${A1}"
      "-Dquantise_mode=${QUAL}"
      "-Dapply_quantisation=${A2}"
      "-Dsaturation_mode=${QUAL}"
      "-Dapply_saturation=${A3}"
    )

    # ----------------------------------------------------
    # Phase 1: Build Phase
    # ----------------------------------------------------
    echo " Phase 1: Measuring ${ITERATIONS_BUILD} Builds..."

    for (( i=1; i<=ITERATIONS_BUILD; i++ )); do
      echo "  -> Build ${i}/${ITERATIONS_BUILD}..."

      rm -rf .zig-cache zig-out
      rm -rf /root/.cache/zig

      # Measure Cold Build
      COLD_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0 \
        zig build "${BUILD_FLAGS[@]}" > /dev/null; } 2>&1 )

      # Measure Hot Build
      touch "src/${FILENAME}"
      HOT_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0 \
        zig build "${BUILD_FLAGS[@]}" > /dev/null; } 2>&1 )

      # Log build row
      echo "${LABEL},${SETTING_NAME},${i},${COLD_TIME},${HOT_TIME}" >> "$BUILD_CSV"
    done

    # ----------------------------------------------------
    # Phase 2: CPU Cooling Phase
    # ----------------------------------------------------
    echo " Phase 2: Cooling CPU (10s sleep)"

    # Ensure executable exists before execution runs
    rm -rf .zig-cache zig-out
    zig build "${BUILD_FLAGS[@]}" > /dev/null 2>&1

    sleep 10

    # ----------------------------------------------------
    # Phase 3: Benchmark Execution Phase
    # ----------------------------------------------------
    echo " Phase 3: Executing ${ITERATIONS} Benchmarks on Core 0"

    for (( i=1; i<=ITERATIONS; i++ )); do
      echo "  -> Run ${i}/${ITERATIONS}..."

      # Create perf FIFOs
      rm -f ${PERF_CTL} ${PERF_ACK}
      mkfifo ${PERF_CTL} ${PERF_ACK}
      chmod 666 ${PERF_CTL} ${PERF_ACK}

      PERF_RAW_FILE=$(mktemp)

      OUT_DATA=$(perf stat -x, --delay=-1 --control="fifo:${PERF_CTL},${PERF_ACK}" \
        -e "$PERF_EVENTS" \
        taskset -c 0 \
        ./zig-out/bin/out 2> >(grep -vE "^Events (enabled|disabled)" > "$PERF_RAW_FILE"))

      # Extract runtime_ns cleanly from $OUT_DATA
      RUN_NS=$(echo "$OUT_DATA" | grep "Processed in:" | awk -F'[][]' '{print $2}')

      # Parse perf values safely
      PERF_METRICS=$(awk -F',' '{
        val = $1;
        if (val ~ /<not supported>/ || val == "") val = "0";
        print val;
      }' "$PERF_RAW_FILE" | tr '\n' ',' | sed 's/,$//')

      rm -f "$PERF_RAW_FILE"

      # Log runtime row
      echo "${LABEL},${SETTING_NAME},${i},${RUN_NS},${PERF_METRICS}" >> "$RUNTIME_CSV"

    done
  done
done

echo "Image Pipeline Benchmark complete! Data saved to ${BUILD_CSV} and ${RUNTIME_CSV}"
