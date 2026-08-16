#!/usr/bin/env bash

echo "REMEMBER TO RUN WITH SUDO!"

FILES=(
  "lut_runtime.cpp"
  "lut_comptime.cpp"
)

ITERATIONS=${1:-2}
CSV_FILE="results.csv"

# NB: must regenerate with the zig when you change this
# INCREMENTS=("0.0005" "0.005" "0.05" "0.5" "1")
INCREMENTS=("0.0005")

# 3. Add CSV header if it doesn't exist
if [ ! -f "$CSV_FILE" ]; then
  echo "label,setting,run_number,cold_real,cold_user,cold_sys,hot_real,hot_user,hot_sys,runtime_ns,cycles,instructions,fe_stalls_uops,backend_stalls,branches,branch_misses,cache_refs,cache_misses,l1_loads,l1_misses,ctx_switches,page_faults" > "$CSV_FILE"
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

      mkdir -p build && cd build || exit 1

      # Configure CMake with injected increment parameter
      cmake .. -DOptimise=ON \
               -DTARGET_SRC="${FILENAME}" \
               -DINCREMENT_VAL="${INC}" > /dev/null 2>&1

      # BUILD TIMES (Cold & Hot)
      COLD_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0,1 make -s -j$(nproc) > /dev/null; } 2>&1)
      touch "../src/${FILENAME}"
      HOT_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0,1 make -s -j$(nproc) > /dev/null; } 2>&1)

      make -j$(nproc) > /dev/null 2>&1

      # Ice Lake supported PMU event string
      PERF_EVENTS="cycles,instructions,idq_uops_not_delivered.core,topdown.backend_bound_slots,branches,branch-misses,cache-references,cache-misses,L1-dcache-loads,L1-dcache-load-misses,context-switches,page-faults"

      # Execute benchmark under perf stat (stderr captured for counters)
      PERF_RAW_FILE=$(mktemp)
      OUT_DATA=$(perf stat -x, --delay=-1 -e "$PERF_EVENTS" ./out 2> "$PERF_RAW_FILE")

      # Extract runtime_ns
      RUN_NS=$(echo "$OUT_DATA" | grep "Processed in:" | awk -F'[][]' '{print $2}')

      # Parse values safely (converts unsupported/empty entries into 0)
      PERF_METRICS=$(awk -F',' '{
        val = $1;
        if (val ~ /<not supported>/ || val == "") val = "0";
        print val;
      }' "$PERF_RAW_FILE" | tr '\n' ',' | sed 's/,$//')
      rm -f "$PERF_RAW_FILE"

      # Log single flattened row to CSV
      echo "${LABEL},${SETTING_NAME},${i},${COLD_TIME},${HOT_TIME},${RUN_NS},${PERF_METRICS}" >> "../${CSV_FILE}"

      cd ..
      rm -rf build
    done
  done
done

echo "LUT Benchmark complete! Data saved to ${CSV_FILE}"
