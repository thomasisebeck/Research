#!/usr/bin/env bash

echo "REMEMBER TO RUN WITH SUDO!"

FILES=(
  "poly_dyn.cpp"
  "poly_stat.cpp"
)

ITERATIONS=${1:-10}
CSV_FILE="results.csv"
SETTING_NAME="N/A"

if [ ! -f "$CSV_FILE" ]; then
  echo "label,setting,run_number,cold_real,cold_user,cold_sys,hot_real,hot_user,hot_sys,runtime_ns" > "$CSV_FILE"
fi

for FILENAME in "${FILES[@]}"; do
  LABEL="${FILENAME%.*}"

    echo "=================================================="
    echo " Target: ${FILENAME}" 
    echo "=================================================="


    for (( i=1; i<=ITERATIONS; i++ )); do
      echo "  -> Run ${i}/${ITERATIONS}..."

      mkdir -p build && cd build || exit 1

      # Configure CMake with injected increment parameter
      CCACHE_DISABLE=1 cmake .. -DOptimise=ON \
               -DTARGET_SRC="${FILENAME}" \
               -DINCREMENT_VAL="${INC}" > /dev/null 2>&1

      # BUILD TIMES (Cold & Hot)
      COLD_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0,1 make -s -j$(nproc) > /dev/null; } 2>&1)
      touch "../src/${FILENAME}"
      HOT_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0,1 make -s -j$(nproc) > /dev/null; } 2>&1)

      make -j$(nproc) > /dev/null 2>&1

      # create perf files
      sudo rm -rf /tmp/perf.ctl /tmp/perf.ack
      sudo mkfifo /tmp/perf.ctl /tmp/perf.ack

      # Execute benchmark under perf stat (stderr captured for counters)
      PERF_RAW_FILE=$(mktemp)
      OUT_DATA=$(sudo perf stat -x, --delay=-1 --control=fifo:/tmp/perf.ctl,/tmp/perf.ack \
      taskset -c 0,1 \
      -e "$PERF_EVENTS" \
      ./out 2> >(grep -vE "^Events (enabled|disabled)" > "$PERF_RAW_FILE"))

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
