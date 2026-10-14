#!/usr/bin/env bash

# NB: must run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run with sudo!"
  exit 1
fi

set -e # Exit immediately if an unhandled command fails

# 1. Resolve User & Paths
TARGET_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~${TARGET_USER}")

# 2. Benchmark Configuration
FILES=(
  "poly_stat.zig"
  "poly_dyn.zig"
)

ITERATIONS=${1:-15}
ITERATIONS_BUILD=${1:-15}
BUILD_CSV="build_times.csv"
RUNTIME_CSV="runtime.csv"
SETTING_NAME="N/A"
PERF_EVENTS="cycles,instructions,cache-misses,cache-references,branches,branch-misses"
PERF_CTL="/tmp/perf.ctl"
PERF_ACK="/tmp/perf.ack"

# 3. Initialize CSV headers if files don't exist yet
if [ ! -f "$BUILD_CSV" ]; then
  echo "label,setting,run_number,cold_real,cold_user,cold_sys,hot_real,hot_user,hot_sys" > "$BUILD_CSV"
fi

if [ ! -f "$RUNTIME_CSV" ]; then
  echo "label,setting,run_number,runtime_ns,$PERF_EVENTS" > "$RUNTIME_CSV"
fi

# Ensure CSV permissions belong to target user
chown "${TARGET_USER}:${TARGET_USER}" "$BUILD_CSV" "$RUNTIME_CSV" 2>/dev/null || true

# Phase 0: System Isolation & Environment Preparation
echo "=================================================="
echo " Phase 0: Address Space Rand, Freq scaling, Turbo"
echo "=================================================="
echo 0 | tee /proc/sys/kernel/randomize_va_space
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
  echo 1 | tee /sys/devices/system/cpu/intel_pstate/no_turbo
fi

# Increase stack limit
ulimit -s unlimited

# Outer loops iterate over target files
for FILENAME in "${FILES[@]}"; do
  LABEL="${FILENAME%.*}"

  echo "=================================================="
  echo " Target: ${LABEL} | Setting: ${SETTING_NAME}"
  echo "=================================================="

  # ----------------------------------------------------
  # Phase 1: Build Phase
  # ----------------------------------------------------
  echo " Phase 1: Measuring ${ITERATIONS_BUILD} Builds..."

  for (( i=1; i<=ITERATIONS_BUILD; i++ )); do
    echo "  -> Build ${i}/${ITERATIONS_BUILD}..."

    # Clean cache and build artifacts for a true cold build
    rm -rf .zig-cache zig-out
    rm -rf /root/.cache/zig "${REAL_HOME}/.cache/zig"

    # Measure Cold Build on core 1
    COLD_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 1 \
      zig build -Dtarget_src="src/${FILENAME}" -Doptimize=ReleaseFast \
      > /dev/null; } 2>&1 )

    # Measure Hot Build on core 1
    touch "src/${FILENAME}"
    HOT_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 1 \
      zig build -Dtarget_src="src/${FILENAME}" -Doptimize=ReleaseFast \
      > /dev/null; } 2>&1 )

    # Log build row
    echo "${LABEL},${SETTING_NAME},${i},${COLD_TIME},${HOT_TIME}" >> "$BUILD_CSV"
  done

  # ----------------------------------------------------
  # Phase 2: CPU Cooling Phase & Final Artifact Prep
  # ----------------------------------------------------
  echo " Phase 2: Cooling CPU & Preparing Binary (10s sleep)"

  rm -rf .zig-cache zig-out
  zig build -Dtarget_src="src/${FILENAME}" -Doptimize=ReleaseFast \
     > /dev/null 2>&1

  sleep 10

  # ----------------------------------------------------
  # Phase 3: Benchmark Execution Phase
  # ----------------------------------------------------
  echo " Phase 3: Executing ${ITERATIONS} Benchmarks on Core 1"

  for (( i=1; i<=ITERATIONS; i++ )); do
    echo "  -> Run ${i}/${ITERATIONS}..."

    # Create perf FIFOs
    rm -f ${PERF_CTL} ${PERF_ACK}
    mkfifo ${PERF_CTL} ${PERF_ACK}
    chmod 666 ${PERF_CTL} ${PERF_ACK}

    PERF_RAW_FILE=$(mktemp)

    # Execute benchmark pinned to core 1 with perf control FIFOs
    OUT_DATA=$(taskset -c 1 perf stat -x, --delay=-1 --control="fifo:${PERF_CTL},${PERF_ACK}" \
      -e "$PERF_EVENTS" \
      ./zig-out/bin/out 2> >(grep -vE "^Events (enabled|disabled)" > "$PERF_RAW_FILE"))

    # Extract runtime_ns
    RUN_NS=$(echo "$OUT_DATA" | grep "Processed in:" | awk -F'[][]' '{print $2}')

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

# Ensure ownership of output files belongs to target non-root user
chown "${TARGET_USER}:${TARGET_USER}" "$BUILD_CSV" "$RUNTIME_CSV" 2>/dev/null || true

echo "Zig Polymorphism Benchmark complete! Data saved to ${BUILD_CSV} and ${RUNTIME_CSV}"
