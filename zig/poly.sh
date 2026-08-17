#!/usr/bin/env bash

# NB: must run with sudo
echo "REMEMBER TO RUN WITH SUDO!"

set -e # Exit immediately if an unhandled command fails

# 1. Resolve User & Paths
TARGET_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~${TARGET_USER}")

# 2. Benchmark Configuration
FILES=(
  "poly_stat.zig"
  "poly_dyn.zig"
)

ITERATIONS=${1:-2}  # Defaults to 2 runs per file if not passed as script arg
CSV_FILE="results.csv"
SETTING_NAME="N/A"
PERF_EVENTS="cycles,instructions,cache-misses,cache-references,branches,branch-misses"

# Ensure output directory exists for the CSV file
mkdir -p "$(dirname "$CSV_FILE")"

# 3. Add CSV header if it doesn't exist
if [ ! -f "$CSV_FILE" ]; then
  echo "label,setting,run_number,cold_real,cold_user,cold_sys,hot_real,hot_user,hot_sys,runtime_ns,$PERF_EVENTS" > "$CSV_FILE"
fi

# Ensure CSV file has proper user permissions if it exists
if [ -f "$CSV_FILE" ]; then
  sudo chown "${TARGET_USER}:${TARGET_USER}" "$CSV_FILE"
fi

for FILENAME in "${FILES[@]}"; do
  LABEL="${FILENAME%.*}"

  echo "=================================================="
  echo " Target: ${FILENAME}"
  echo "=================================================="

  for (( i=1; i<=ITERATIONS; i++ )); do
    echo "  -> Run ${i}/${ITERATIONS}..."

    # Clean cache and build artifacts for a true cold build
    rm -rf .zig-cache zig-out

    sudo rm -rf /root/.cache/zig "${REAL_HOME}/.cache/zig"

    echo "DOING COLD"

    /usr/bin/time -f "%e,%U,%S" taskset -c 0,1 \
    zig build -Dtarget_src="src/${FILENAME}" -Doptimize=ReleaseFast;

    COLD_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0,1 \
        zig build -Dtarget_src="src/${FILENAME}" > /dev/null; } 2>&1 )

    echo "COLD TIME $COLD_TIME"

      touch "src/${FILENAME}"

      HOT_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0,1 \
        zig build -Dtarget_src="src/${FILENAME}" \
         > /dev/null; } 2>&1 )

    echo "HOT TIME $HOT_TIME"


    # Create perf control FIFOs
    sudo rm -f /tmp/perf.ctl /tmp/perf.ack
    sudo mkfifo /tmp/perf.ctl /tmp/perf.ack
    sudo chmod 666 /tmp/perf.ctl /tmp/perf.ack

    # Execute benchmark under perf stat
    PERF_RAW_FILE=$(mktemp)

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

echo "Zig Polymorphism Benchmark complete! Data saved to ${CSV_FILE}"