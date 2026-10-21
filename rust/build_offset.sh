#!/usr/bin/env bash

echo "REMEMBER TO RUN WITH SUDO!"

set -e # Exit immediately if an unhandled command fails

# 1. Resolve User & Paths
TARGET_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~${TARGET_USER}")
CARGO_BIN="/usr/bin/cargo"

# 2. Benchmark Configuration
ITERATIONS_BUILD=${1:-15}
BUILD_CSV="build_times.csv"
SETTING_NAME="N/A"

FILES=(
  "build_offset.rs"
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

    sleep 1

    # Touch source for hot build (forces recompilation of the binary)
    sudo touch "src/${FILENAME}"

    # Measure Hot Build
    HOT_TIME=$(sudo -u "${TARGET_USER}" sh -c 'RUSTFLAGS="-A warnings" /usr/bin/time -f "%e,%U,%S" taskset -c 1 "'"${CARGO_BIN}"'" build -q --release --bin "'"${BIN_NAME}"'"' 2>&1)

    # Log build row
    echo "${LABEL},${SETTING_NAME},${i},${COLD_TIME},${HOT_TIME}" >> "$BUILD_CSV"
  done

done

echo "Rust Build Benchmark complete! Data saved to ${BUILD_CSV} and ${RUNTIME_CSV}"
