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
PERF_EVENTS="cycles,instructions,cache-misses,cache-references,branches,branch-misses"
PERF_CTL="/tmp/perf.ctl"
PERF_ACK="/tmp/perf.ack"

FILES=(
  "image_pipeline_runtime.rs"
  "image_pipeline_comptime.rs"
)

QUALITIES=("low" "med" "high")
TOGGLE_SETS=(
  "false,false,false"
  "true,false,true"
  "true,true,true"
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

# Outer loops iterate over target files and setting configurations
for FILENAME in "${FILES[@]}"; do
  LABEL="${FILENAME%.*}"
  BIN_NAME="${LABEL}"

  NUM_CONFIGS=${#QUALITIES[@]}
  for (( c=0; c<NUM_CONFIGS; c++ )); do

    QUAL="${QUALITIES[$c]}"
    TOGGLES="${TOGGLE_SETS[$c]}"

    IFS=',' read -r A1 A2 A3 <<< "$TOGGLES"
    QUAL_UPPER=$(echo "$QUAL" | tr '[:lower:]' '[:upper:]')
    SETTING_NAME="${QUAL_UPPER}_${A1}_${A2}_${A3}"

    echo "=================================================="
    echo " Target: ${LABEL} | Config [${c}]: ${SETTING_NAME}"
    echo "=================================================="

    # ----------------------------------------------------
    # Phase 1: Build Phase
    # ----------------------------------------------------
    echo " Phase 1: Measuring ${ITERATIONS_BUILD} Builds..."

    for (( i=1; i<=ITERATIONS_BUILD; i++ )); do
      echo "  -> Build ${i}/${ITERATIONS_BUILD}..."

      # Clean build artifacts for cold build timing
      sudo -u "${TARGET_USER}" "${CARGO_BIN}" clean > /dev/null 2>&1

      # Measure Cold Build using sh -c
      COLD_TIME=$(sudo -u "${TARGET_USER}" sh -c 'RUSTFLAGS="-A warnings" /usr/bin/time -f "%e,%U,%S" taskset -c 1 "'"${CARGO_BIN}"'" build -q --release --no-default-features --features "'"${QUAL}"'" --bin "'"${BIN_NAME}"'"' 2>&1)

      # Touch source for hot build
      if [ -f "src/${FILENAME}" ]; then
        sudo touch "src/${FILENAME}"
      fi

      # Measure Hot Build using sh -c
      HOT_TIME=$(sudo -u "${TARGET_USER}" sh -c 'RUSTFLAGS="-A warnings" /usr/bin/time -f "%e,%U,%S" taskset -c 1 "'"${CARGO_BIN}"'" build -q --release --no-default-features --features "'"${QUAL}"'" --bin "'"${BIN_NAME}"'"' 2>&1)

      # Log build row
      echo "${LABEL},${SETTING_NAME},${i},${COLD_TIME},${HOT_TIME}" >> "$BUILD_CSV"
    done

    # ----------------------------------------------------
    # Phase 2: CPU Cooling Phase
    # ----------------------------------------------------
    echo " Phase 2: Cooling CPU (5s sleep)"
    sleep 1

# ----------------------------------------------------
    # Phase 3: Benchmark Execution Phase
    # ----------------------------------------------------
    echo " Phase 3: Executing ${ITERATIONS} Benchmarks on Core 1"

    # Ensure executable binary exists prior to perf run
    echo " -> Compiling release executable..."
    sudo -u "${TARGET_USER}" sh -c 'RUSTFLAGS="-A warnings" "'"${CARGO_BIN}"'" build --release --no-default-features --features "'"${QUAL}"'" --bin "'"${BIN_NAME}"'"'

    EXECUTABLE="./target/release/${BIN_NAME}"

    if [ ! -f "$EXECUTABLE" ]; then
        echo "Error: Executable $EXECUTABLE not found!"
        exit 1
    fi

    echo " -> Found executable at: $EXECUTABLE"

for (( i=1; i<=ITERATIONS; i++ )); do
      echo "  -> Run ${i}/${ITERATIONS}..."

      # Create perf FIFOs
      sudo rm -f ${PERF_CTL} ${PERF_ACK}
      mkfifo ${PERF_CTL} ${PERF_ACK}
      sudo chmod 666 ${PERF_CTL} ${PERF_ACK}

      PERF_RAW_FILE=$(mktemp)
      PROGRAM_OUT_FILE=$(mktemp)

      # Run perf and capture the exact exit code
      set +e
      sudo taskset -c 1 perf stat -x, --delay=-1 --control="fifo:${PERF_CTL},${PERF_ACK}" \
        -e "$PERF_EVENTS" \
        "$EXECUTABLE" > "$PROGRAM_OUT_FILE" 2> "$PERF_RAW_FILE"
      EXIT_CODE=$?
      set -e

      OUT_DATA=$(cat "$PROGRAM_OUT_FILE")
      PERF_ERRORS=$(cat "$PERF_RAW_FILE")

      # Print error diagnostics if process failed or output is empty
      if [ $EXIT_CODE -ne 0 ] || [ -z "$OUT_DATA" ]; then
        echo "=================================================="
        echo "[ERROR DIAGNOSTICS] Run ${i} failed!"
        echo " Exit Code : $EXIT_CODE"
        echo " Program Output (stdout):"
        echo "${OUT_DATA:-<EMPTY>}"
        echo " Perf / Error Output (stderr):"
        echo "${PERF_ERRORS:-<EMPTY>}"
        echo "=================================================="
      fi

      RUN_NS=$(echo "$OUT_DATA" | grep "Processed in:" | awk -F'[][]' '{print $2}')
      RUN_NS="${RUN_NS:-0}"

      PERF_CLEAN=$(echo "$PERF_ERRORS" | grep -vE "^Events (enabled|disabled)" || true)

      PERF_METRICS=$(echo "$PERF_CLEAN" | awk -F',' '{
        val = $1;
        if (val ~ /<not supported>/ || val == "") val = "0";
        print val;
      }' | tr '\n' ',' | sed 's/,$//')

      rm -f "$PERF_RAW_FILE" "$PROGRAM_OUT_FILE"

      echo "${LABEL},${SETTING_NAME},${i},${RUN_NS},${PERF_METRICS}" >> "${RUNTIME_CSV}"
    done

  done
done

echo "Rust Branching Benchmark complete! Data saved to ${BUILD_CSV} and ${RUNTIME_CSV}"
