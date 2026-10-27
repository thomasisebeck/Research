#!/usr/bin/env bash

ITERATIONS_BUILD=${1:-15}
BUILD_CSV="build_times.csv"
TARGET_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~${TARGET_USER}")
ZIG_GLOBAL_CACHE="${REAL_HOME}/.cache/zig"

FILES=(
  "build_offset.zig"
)

# 1. Initialize CSV headers if files don't exist yet
if [ ! -f "$BUILD_CSV" ]; then
  echo "label,setting,run_number,cold_real,cold_user,cold_sys,hot_real,hot_user,hot_sys" > "$BUILD_CSV"
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


# increase stack limit
ulimit -s

# Outer loops iterate over target files and increment settings
for FILENAME in "${FILES[@]}"; do
  LABEL="${FILENAME%.*}"

    SETTING_NAME="N/A"

    echo "=================================================="
    echo " Target: ${LABEL} | Setting: ${SETTING_NAME}"
    echo "=================================================="

    # ----------------------------------------------------
    # Phase 1: Build Phase
    # ----------------------------------------------------
    echo " Phase 1: Measuring ${ITERATIONS_BUILD} Builds..."

    for (( i=1; i<=ITERATIONS_BUILD; i++ )); do
      echo "  -> Build ${i}/${ITERATIONS_BUILD}..."

      rm -rf .zig-cache zig-out "${ZIG_GLOBAL_CACHE}" /root/.cache/zig

      # Measure Cold Build
      COLD_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 1 \
        zig build -Dtarget_src="src/${FILENAME}" -Doptimize=ReleaseFast \
        > /dev/null; } 2>&1 )

      sleep 1

      echo "// touch" >> "src/${FILENAME}"

      HOT_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 1 \
        zig build -Dtarget_src="src/${FILENAME}" -Doptimize=ReleaseFast \
        > /dev/null; } 2>&1 )

      sed -i '$ d' "src/${FILENAME}"

      # Log build row
      echo "${LABEL},${SETTING_NAME},${i},${COLD_TIME},${HOT_TIME}" >> "$BUILD_CSV"
    done
done

echo "Build Benchmark complete! Data saved to ${BUILD_CSV}"
