#!/usr/bin/env bash


echo "REMEMBER TO RUN WITH SUDO!"

set -e # Exit immediately if an unhandled command fails

# 1. Resolve User & Paths
TARGET_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~${TARGET_USER}")
CARGO_BIN="${REAL_HOME}/.cargo/bin/cargo"

# 2. Benchmark Configuration
FILES=("lut_comptime.rs", "lut_runtime.rs")
INCREMENTS=("0.015625" "0.03125" "0.0625" "0.125" "0.25" "0.5" "1.0" "2.0" "4.0")
ITERATIONS=${1:-10}
CSV_FILE="results.csv"
PERF_EVENTS="cycles,instructions,cache-misses,cache-references,branches,branch-misses"

# Ensure output directory exists for the CSV file
mkdir -p "$(dirname "$CSV_FILE")"

# Safe ownership adjustment on target dir
if [ -d "${REAL_HOME}/git-repos/Research/rust/target" ]; then
    sudo chown -R "${TARGET_USER}:${TARGET_USER}" "${REAL_HOME}/git-repos/Research/rust/target"
fi


# 3. Add CSV header if it doesn't exist
if [ ! -f "$CSV_FILE" ]; then
  echo "label,setting,run_number,cold_real,cold_user,cold_sys,hot_real,hot_user,hot_sys,runtime_ns,$PERF_EVENTS" > "$CSV_FILE"
fi

# Ensure CSV file has proper user permissions if it exists
if [ -f "$CSV_FILE" ]; then
  echo "OWNING..."
  sudo chown "${TARGET_USER}:${TARGET_USER}" "$CSV_FILE"
fi

for FILENAME in "${FILES[@]}"; do
  LABEL="${FILENAME%.*}"
  BIN_NAME="${LABEL}"

  for INC in "${INCREMENTS[@]}"; do
    SETTING_NAME="INC_${INC}"

    echo "=================================================="
    echo " Target: ${FILENAME} | Increment: ${INC}"
    echo "=================================================="

    for (( i=1; i<=ITERATIONS; i++ )); do
      echo "  -> Run ${i}/${ITERATIONS}..."

      # Explicitly set EXECUTABLE path for the current binary
      EXECUTABLE="./target/release/${BIN_NAME}"

      sudo -u "${TARGET_USER}" "${CARGO_BIN}" +stable clean > /dev/null 2>&1

      CMD="sudo -u \"${TARGET_USER}\" sh -c 'env INCREMENT_VAL=\"${INC}\" RUSTFLAGS=\"-A warnings\" /usr/bin/time -f \"%e,%U,%S\" taskset -c 0,1 \"${CARGO_BIN}\" +stable build -q --release --bin \"${BIN_NAME}\"'"
      COLD_TIME=$(eval "$CMD" 2>&1)

      sudo touch "src/${FILENAME}"

      # HOT BUILD STEP
      HOT_TIME=$(sudo -u "${TARGET_USER}" sh -c 'env INCREMENT_VAL="'"${INC}"'" RUSTFLAGS="-A warnings" /usr/bin/time -f "%e,%U,%S" taskset -c 0,1 "'"${CARGO_BIN}"'" +stable build -q --release --bin "'"${BIN_NAME}"'"' 2>&1)

      if [ ! -f "$EXECUTABLE" ]; then
        echo "Error: Executable $EXECUTABLE not found!"
        exit 1
      fi


      # Create perf control FIFOs
      sudo rm -f /tmp/perf.ctl /tmp/perf.ack
      sudo mkfifo /tmp/perf.ctl /tmp/perf.ack
      sudo chmod 666 /tmp/perf.ctl /tmp/perf.ack

      # Execute benchmark under perf stat
      PERF_RAW_FILE=$(mktemp)

      OUT_DATA=$(sudo perf stat -x, --delay=-1 --control=fifo:/tmp/perf.ctl,/tmp/perf.ack \
      taskset -c 0,1 \
        -e "$PERF_EVENTS" \
        "$EXECUTABLE" 2> >(grep -vE "^Events (enabled|disabled)" > "$PERF_RAW_FILE"))

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

echo "Rust LUT Benchmark complete! Data saved to ${CSV_FILE}"
