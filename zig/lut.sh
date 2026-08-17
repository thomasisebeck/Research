#!/usr/bin/env bash

# NBBBBBBBBBBB: must run with sudo
echo "REMEMBER TO RUN WITH SUDO!"

# 1. Define LUT files to benchmark
FILES=(
  "lut_runtime.zig"
  "lut_comptime.zig"
)

ITERATIONS=${1:-10}
CSV_FILE="results.csv"

# 2. Target increment values, NB: change with zig if you change this!
INCREMENTS=("0.0005" "0.005" "0.05" "0.5" "1")

PERF_EVENTS="cycles,instructions,cache-misses,cache-references,branches,branch-misses"

# 3. Add CSV header if it doesn't exist
if [ ! -f "$CSV_FILE" ]; then
  echo "label,setting,run_number,cold_real,cold_user,cold_sys,hot_real,hot_user,hot_sys,runtime_ns,$PERF_EVENTS" > "$CSV_FILE"
fi

for FILENAME in "${FILES[@]}"; do
  LABEL="${FILENAME%.*}"

  for INC in "${INCREMENTS[@]}"; do
    SETTING_NAME="INC_${INC}"

    echo "=================================================="
    echo " Target: ${FILENAME} | Increment: ${INC}"
    echo "=================================================="

    for (( i=1; i<=ITERATIONS; i++ )); do
      echo "  -> Run ${i}/${ITERATIONS}..."

      rm -rf .zig-cache zig-out
      sudo rm -rf  /root/.cache/zig

      # BUILD TIMES (Cold & Hot)
      COLD_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0,1 \
        zig build -Dtarget_src="src/${FILENAME}" \
        -Dincrement="${INC}" > /dev/null; } 2>&1 )

      touch "src/${FILENAME}"

      HOT_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0,1 \
        zig build -Dtarget_src="src/${FILENAME}" \
        -Dincrement="${INC}" > /dev/null; } 2>&1 )

      if [ ! -f "./zig-out/bin/out" ]; then
        echo "Error: Executable not found!"
        exit 1
      fi

      # create the perf files
      sudo rm -rf /tmp/perf.ctl /tmp/perf.ack
      sudo mkfifo /tmp/perf.ctl /tmp/perf.ack

      # Execute benchmark under perf stat (stderr redirected to temp file, stdout saved to OUT_DATA)
      PERF_RAW_FILE=$(mktemp)

      # control with the file 
      # Capture stdout into RUNTIME_NS while keeping stderr routed through grep
      OUT_DATA=$(sudo perf stat -x, --delay=-1 --control=fifo:/tmp/perf.ctl,/tmp/perf.ack \
      -e "$PERF_EVENTS" \
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

echo "LUT Benchmark complete! Data saved to ${CSV_FILE}"
