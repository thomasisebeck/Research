#!/usr/bin/env bash

echo "REMEMBER TO RUN WITH SUDO!"

set -e # Exit immediately if an unhandled command fails

# 1. Resolve User & Paths
TARGET_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~${TARGET_USER}")
CARGO_BIN="/usr/bin/cargo"

# 2. Benchmark Configuration
ITERATIONS=${1:-10}
ITERATIONS_BUILD=${1:-10}

BUILD_CSV="build_times.csv"
RUNTIME_CSV="runtime.csv"
PERF_EVENTS="cycles,instructions,cache-misses,cache-references,branches,branch-misses"
PERF_CTL="/tmp/perf.ctl"
PERF_ACK="/tmp/perf.ack"

FILES=("lut_comptime.rs" "lut_runtime.rs")
INCREMENTS=("0.001" "0.005" "0.01" "0.05" "0.1" "0.5" "5")

# done
# "1" 

# failed
# "0.0005"

# Ensure target directory ownership if it exists
if [ -d "${REAL_HOME}/git-repos/Research/rust/target" ]; then
    sudo chown -R "${TARGET_USER}:${TARGET_USER}" "${REAL_HOME}/git-repos/Research/rust/target"
fi

# 3. Initialize CSV headers if files don't exist yet
if [ ! -f "$BUILD_CSV" ]; then
  echo "label,setting,run_number,cold_real,cold_user,cold_sys,hot_real,hot_user,hot_sys" > "$BUILD_CSV"
fi

if [ ! -f "$RUNTIME_CSV" ]; then
  echo "label,setting,run_number,runtime_ns,$PERF_EVENTS" > "$RUNTIME_CSV"
fi

# Set proper ownership for CSV files
sudo chown "${TARGET_USER}:${TARGET_USER}" "$BUILD_CSV" "$RUNTIME_CSV" 2>/dev/null || true

echo "=================================================="
echo " Phase 0: Address Space Randomisation"
echo "=================================================="
echo 0 | sudo tee /proc/sys/kernel/randomize_va_space > /dev/null

# Outer loops iterate over target files and increment settings
for FILENAME in "${FILES[@]}"; do
  LABEL="${FILENAME%.*}"
  BIN_NAME="${LABEL}"

  for INC in "${INCREMENTS[@]}"; do
    SETTING_NAME="INC_${INC}"

    echo "=================================================="
    echo " Target: ${LABEL} | Setting: ${SETTING_NAME}"
    echo "=================================================="

    # ----------------------------------------------------
    # Phase 1: Build Phase
    # ----------------------------------------------------
    echo " Phase 1: Measuring ${ITERATIONS_BUILD} Builds..."

    for (( i=1; i<=ITERATIONS_BUILD; i++ )); do
      echo "  -> Build ${i}/${ITERATIONS_BUILD}..."

    # 1. Clean target directory for Cold Build
    if [ -d "target" ]; then
      sudo -u "${TARGET_USER}" "${CARGO_BIN}" clean > /dev/null 2>&1
    fi

    # 2. Measure Cold Build
    COLD_TIME=$(sudo -u "${TARGET_USER}" env INCREMENT_VAL="${INC}" RUSTFLAGS="-A warnings" \
      /usr/bin/time -f "%e,%U,%S" taskset -c 1 "${CARGO_BIN}" build -q --release --bin "${BIN_NAME}" 2>&1)

    # Touch source file to trigger Hot Build
    if [ -f "src/${FILENAME}" ]; then
      sudo touch "src/${FILENAME}"
    fi

    # 3. Measure Hot Build
    HOT_TIME=$(sudo -u "${TARGET_USER}" env INCREMENT_VAL="${INC}" RUSTFLAGS="-A warnings" \
      /usr/bin/time -f "%e,%U,%S" taskset -c 1 "${CARGO_BIN}" build -q --release --bin "${BIN_NAME}" 2>&1)

          # Log build row
          echo "${LABEL},${SETTING_NAME},${i},${COLD_TIME},${HOT_TIME}" >> "$BUILD_CSV"
        done

    # ----------------------------------------------------
    # Phase 2: CPU Cooling Phase
    # ----------------------------------------------------
    echo " Phase 2: Cooling CPU (10s sleep)"

    # Ensure executable exists before benchmark execution runs
    EXECUTABLE="./target/release/${BIN_NAME}"
    sudo -u "${TARGET_USER}" sh -c "env INCREMENT_VAL=\"${INC}\" RUSTFLAGS=\"-A warnings\" \"${CARGO_BIN}\" build -q --release --bin \"${BIN_NAME}\"" > /dev/null 2>&1

    if [ ! -f "$EXECUTABLE" ]; then
      echo "Error: Executable $EXECUTABLE not found!"
      exit 1
    fi

    sleep 10

    # ----------------------------------------------------
    # Phase 3: Benchmark Execution Phase
    # ----------------------------------------------------
    echo " Phase 3: Executing ${ITERATIONS} Benchmarks on Core 1"

    for (( i=1; i<=ITERATIONS; i++ )); do
      echo "  -> Run ${i}/${ITERATIONS}..."

      # Create perf FIFOs
      sudo rm -f ${PERF_CTL} ${PERF_ACK}
      mkfifo ${PERF_CTL} ${PERF_ACK}
      sudo chmod 666 ${PERF_CTL} ${PERF_ACK}

      PERF_RAW_FILE=$(mktemp)

      OUT_DATA=$(sudo taskset -c 1 perf stat -x, --delay=-1 --control="fifo:${PERF_CTL},${PERF_ACK}" \
        -e "$PERF_EVENTS" \
        "$EXECUTABLE" 2> >(grep -vE "^Events (enabled|disabled)" > "$PERF_RAW_FILE"))

      # Extract runtime_ns
      RUN_NS=$(echo "$OUT_DATA" | grep "Processed in:" | awk -F'[][]' '{print $2}')
      RUN_NS="${RUN_NS:-0}"

      # Parse perf metrics safely
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

# Ensure output CSV files are owned by regular user
sudo chown "${TARGET_USER}:${TARGET_USER}" "$BUILD_CSV" "$RUNTIME_CSV" 2>/dev/null || true

echo "Rust LUT Benchmark complete! Data saved to ${BUILD_CSV} and ${RUNTIME_CSV}"
