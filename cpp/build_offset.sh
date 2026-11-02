#!/usr/bin/env bash

ITERATIONS_BUILD=${1:-15}
BUILD_CSV="build_times.csv"
SETTING_NAME="N/A"

FILES=(
  "build_offset.cpp"
)

# 1. Initialize CSV headers if files don't exist yet
if [ ! -f "$BUILD_CSV" ]; then
  echo "label,setting,run_number,cold_real,cold_user,cold_sys,hot_real,hot_user,hot_sys" > "$BUILD_CSV"
fi


echo "=================================================="
echo " Phase 0: Address Space Randomisation"
echo "=================================================="
echo 0 | sudo tee /proc/sys/kernel/randomize_va_space

# Loop over each target file (dynamic vs static polymorphism)
for FILENAME in "${FILES[@]}"; do
  LABEL="${FILENAME%.*}"

  echo "=================================================="
  echo " Target: ${LABEL}"
  echo "=================================================="

  # ----------------------------------------------------
  # Phase 1: Build Phase (10 Iterations)
  # ----------------------------------------------------
  echo " Phase 1: Measuring ${ITERATIONS_BUILD} Builds..."

  for (( i=1; i<=ITERATIONS_BUILD; i++ )); do
    echo "  -> Build ${i}/${ITERATIONS_BUILD}..."

    rm -rf build
    mkdir -p build
    cd build || exit 1

    # Configure CMake
    CCACHE_DISABLE=1 cmake .. -DOptimise=ON \
             -DTARGET_SRC="${FILENAME}" > /dev/null 2>&1

    # Measure Cold Build
    COLD_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 1 make -s -j$(nproc) > /dev/null; } 2>&1 )

    # Measure Hot Build
    touch "../src/${FILENAME}"
    HOT_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 1 make -s -j$(nproc) > /dev/null; } 2>&1 )

    cd ..

    # Log build row
    echo "${LABEL},${SETTING_NAME},${i},${COLD_TIME},${HOT_TIME}" >> "$BUILD_CSV"
  done

  # ----------------------------------------------------
  # Phase 2: CPU Cooling Phase
  # ----------------------------------------------------

  cd ..
  rm -rf build

done

echo "Build offset Benchmark complete! Data saved to ${BUILD_CSV}"
