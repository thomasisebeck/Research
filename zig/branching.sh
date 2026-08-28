#!/usr/bin/env bash

# NBBBBBBBBBBB: must run with sudo
echo "REMEMBER TO RUN WITH SUDO!"

# 1. Define source files to benchmark
FILES=(
  "image_pipeline_runtime.zig"
  "image_pipeline_comptime.zig"
)

ITERATIONS=${1:-5}
CSV_FILE="results.csv"

# 2. Quality and Toggle Configurations
QUALITIES=("LOW" "MED" "HIGH")
TOGGLE_SETS=(
  "false,false,false"
  "true,false,true"
  "true,true,true"
)

PERF_EVENTS="cycles,instructions,cache-misses,cache-references,branches,branch-misses"

# 3. Add CSV header if it doesn't exist
if [ ! -f "$CSV_FILE" ]; then
  echo "label,setting,run_number,cold_real,cold_user,cold_sys,hot_real,hot_user,hot_sys,runtime_ns,$PERF_EVENTS" > "$CSV_FILE"
fi

echo "=================================================="
echo " Phase 0: Address Space Randomisation"
echo "=================================================="
echo 0 | sudo tee /proc/sys/kernel/randomize_va_space > /dev/null

NUM_CONFIGS=${#QUALITIES[@]}

for FILENAME in "${FILES[@]}"; do
  LABEL="${FILENAME%.*}"

  for (( c=0; c<NUM_CONFIGS; c++ )); do
    QUAL="${QUALITIES[$c]}"
    TOGGLES="${TOGGLE_SETS[$c]}"

    IFS=',' read -r A1 A2 A3 <<< "$TOGGLES"
    SETTING_NAME="${QUAL}_${A1}_${A2}_${A3}"

    echo "=================================================="
    echo " Target: ${FILENAME} | Config [${c}]: ${SETTING_NAME}"
    echo "=================================================="

    # Construct the common build flags
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

    for (( i=1; i<=ITERATIONS; i++ )); do
      echo "  -> Run ${i}/${ITERATIONS}..."

      # Clean cache for true cold build baseline
      rm -rf .zig-cache zig-out
      sudo rm -rf /root/.cache/zig

      # --- BUILD TIMES (Cold & Hot) ---

      # Cold Build
      COLD_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0 \
        zig build "${BUILD_FLAGS[@]}" > /dev/null; } 2>&1 )

      # Hot Build (touch file to invalidate single compilation unit)
      touch "src/${FILENAME}"
      HOT_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0 \
        zig build "${BUILD_FLAGS[@]}" > /dev/null; } 2>&1 )

      if [ ! -f "./zig-out/bin/out" ]; then
        echo "Error: Executable not found!"
        exit 1
      fi

      # --- BENCHMARK EXECUTION ---

      # Create perf FIFOs
      sudo rm -rf /tmp/perf.ctl /tmp/perf.ack
      sudo mkfifo /tmp/perf.ctl /tmp/perf.ack
      sudo chmod 666 /tmp/perf.ctl /tmp/perf.ack

      sleep 2

      PERF_RAW_FILE=$(mktemp)

      # Execute benchmark under perf stat
      OUT_DATA=$(sudo perf stat -x, --delay=-1 --control=fifo:/tmp/perf.ctl,/tmp/perf.ack \
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

      # Log single flattened row to CSV
      echo "${LABEL},${SETTING_NAME},${i},${COLD_TIME},${HOT_TIME},${RUN_NS},${PERF_METRICS}" >> "${CSV_FILE}"

    done
  done
done

echo "Image Pipeline Benchmark complete! Data saved to ${CSV_FILE}"
