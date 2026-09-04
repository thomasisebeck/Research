#!/usr/bin/env bash

echo "REMEMBER TO RUN WITH SUDO!"

set -e # Exit immediately if an unhandled command fails

# 1. Resolve User & Paths
TARGET_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~${TARGET_USER}")
CARGO_BIN="/usr/bin/cargo"

# 2. Benchmark Configuration
ITERATIONS=${1:-15}
ITERATIONS_BUILD=${1:-15}
BUILD_CSV="build_times.csv"
RUNTIME_CSV="runtime.csv"
SETTING_NAME="N/A"
PERF_EVENTS="cycles,instructions,cache-misses,cache-references,branches,branch-misses"
PERF_CTL="/tmp/perf.ctl"
PERF_ACK="/tmp/perf.ack"

FILES=(
  "poly_dyn.rs"
  "poly_stat.rs"
)

# Safe ownership adjustment on target dir
if [ -d "${REAL_HOME}/git-repos/Research/rust/target" ]; then
    sudo chown -R "${TARGET_USER}:${TARGET_USER}" "${REAL_HOME}/git-repos/Research/rust/target"
fi

# 3. Initialize CSV headers if files don't exist yet
if [ ! -f "$BUILD_CSV" ]; then
  echo "label,setting,run_number,cold_real,cold_user,cold_sys,hot_real,hot_user,hot_sys" > "$BUILD_CSV"
  sudo chown "${TARGET_USER}:${TARGET_USER}" "$BUILD_CSV"
fi

if [ ! -f "$RUNTIME_CSV" ]; then
  echo "label,setting,run_number,runtime_ns,cycles,instructions,cache-misses,cache-references,branches,branch-misses" > "$RUNTIME_CSV"
  sudo chown "${TARGET_USER}:${TARGET_USER}" "$RUNTIME_CSV"
fi

echo "=================================================="
echo " Phase 0: Address Space Randomisation"
echo "=================================================="
echo 0 | sudo tee /proc/sys/kernel/randomize_va_space

# Loop over each target file
for FILENAME in "${FILES[@]}"; do
  LABEL="${FILENAME%.*}"
  BIN_NAME="${LABEL}"

  echo "=================================================="
  echo " Target: ${LABEL}"
  echo "=================================================="

  # ----------------------------------------------------
  # Phase 1: Build Phase
  # ----------------------------------------------------
  echo " Phase 1: Measuring ${ITERATIONS_BUILD} Builds..."

  for (( i=1; i<=ITERATIONS_BUILD; i++ )); do
    echo "  -> Build ${i}/${ITERATIONS_BUILD}..."


    echo "cleaning..."

    # Clean build artifacts for cold build timing
    sudo -u "${TARGET_USER}" "${CARGO_BIN}" clean 

    echo "building..."

    # Measure Cold Build
    COLD_TIME=$(sudo -u "${TARGET_USER}" sh -c 'RUSTFLAGS="-A warnings" /usr/bin/time -f "%e,%U,%S" taskset -c 1 "'"${CARGO_BIN}"'" build -q --release --bin "'"${BIN_NAME}"'"' 2>&1)

    # Touch source for hot build (forces recompilation of the binary)
    sudo touch "src/${FILENAME}"

    # Measure Hot Build
    HOT_TIME=$(sudo -u "${TARGET_USER}" sh -c 'RUSTFLAGS="-A warnings" /usr/bin/time -f "%e,%U,%S" taskset -c 1 "'"${CARGO_BIN}"'" build -q --release --bin "'"${BIN_NAME}"'"' 2>&1)

    # Log build row
    echo "${LABEL},${SETTING_NAME},${i},${COLD_TIME},${HOT_TIME}" >> "$BUILD_CSV"
  done

  # ----------------------------------------------------
  # Phase 2: CPU Cooling Phase
  # ----------------------------------------------------
  echo " Phase 2: Cooling CPU (5s sleep)"
  sleep 5

  # ----------------------------------------------------
  # Phase 3: Benchmark Execution Phase
  # ----------------------------------------------------
  echo " Phase 3: Executing ${ITERATIONS} Benchmarks on Core 1"

  # Ensure executable binary exists prior to perf run
  sudo -u "${TARGET_USER}" sh -c 'RUSTFLAGS="-A warnings" /usr/bin/time -f "%e,%U,%S" taskset -c 1 "'"${CARGO_BIN}"'" build -q --release --bin "'"${BIN_NAME}"'"' 

  EXECUTABLE="./target/release/${BIN_NAME}"

  if [ ! -f "$EXECUTABLE" ]; then
      echo "Error: Executable $EXECUTABLE not found!"
      exit 1
  fi

  for (( i=1; i<=ITERATIONS; i++ )); do
    echo "  -> Run ${i}/${ITERATIONS}..."

    # Create perf FIFOs
    sudo rm -rf ${PERF_CTL} ${PERF_ACK}
    mkfifo ${PERF_CTL} ${PERF_ACK}
    sudo chmod 666 ${PERF_CTL} ${PERF_ACK}

    PERF_RAW_FILE=$(mktemp)

    OUT_DATA=$(sudo taskset -c 1 perf stat -x, --delay=-1 --control="fifo:${PERF_CTL},${PERF_ACK}" \
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

    # Log runtime row
    echo "${LABEL},${SETTING_NAME},${i},${RUN_NS},${PERF_METRICS}" >> "${RUNTIME_CSV}"
  done

done

echo "Rust Polymorphism Benchmark complete! Data saved to ${BUILD_CSV} and ${RUNTIME_CSV}"
