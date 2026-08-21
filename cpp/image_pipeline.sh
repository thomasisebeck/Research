#!/usr/bin/env bash

# 1. Define the array of source files to benchmark
FILES=(
  "image_pipeline_runtime.cpp"
  "image_pipeline_comptime.cpp"
)

ITERATIONS=${1:-2}  # Defaults to 10 runs per file if not passed as script arg
CSV_FILE="results.csv"

QUALITIES=("utils::Mode::LOW" "utils::Mode::MED" "utils::Mode::HIGH")
# Example toggle combinations (e.g., all off, partial, all on)
TOGGLE_SETS=(
  "false,false,false"
  "true,false,true"
  "true,true,true"
)

# 2. Add CSV header if the file doesn't exist yet
if [ ! -f "$CSV_FILE" ]; then
  echo "label,setting,run_number,cold_real,cold_user,cold_sys,hot_real,hot_user,hot_sys,runtime_ns" > "$CSV_FILE"
fi

for FILENAME in "${FILES[@]}"; do
  LABEL="${FILENAME%.*}"

  # Single loop over the configuration index
  NUM_CONFIGS=${#QUALITIES[@]}
  for (( c=0; c<NUM_CONFIGS; c++ )); do

    QUAL="${QUALITIES[$c]}"
    TOGGLES="${TOGGLE_SETS[$c]}"

    # Extract short mode name (e.g. HIGH)
    QUAL_SHORT="${QUAL##*::}"

    # Split comma-separated toggles
    IFS=',' read -r A1 A2 A3 <<< "$TOGGLES"
    SETTING_NAME="${QUAL_SHORT}_${A1}_${A2}_${A3}"

    echo "=================================================="
    echo " Target: ${FILENAME} | Config [${c}]: ${SETTING_NAME}"
    echo "=================================================="

    for (( i=1; i<=ITERATIONS; i++ )); do
      echo "  -> Run ${i}/${ITERATIONS}..."

      mkdir -p build && cd build || exit 1

      # Configure CMake
      cmake .. -DOptimise=ON \
               -DTARGET_SRC="${FILENAME}" \
               -DQUAL_VAL="${QUAL}" \
               -DAPPLY_ONE_VAL="${A1}" \
               -DAPPLY_TWO_VAL="${A2}" \
               -DAPPLY_THREE_VAL="${A3}" > /dev/null 2>&1

      # BUILD TIMES
      COLD_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0,1 make -s -j$(nproc) > /dev/null; } 2>&1)
      touch "../src/${FILENAME}"
      HOT_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0,1 make -s -j$(nproc)  > /dev/null; } 2>&1)

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
done

echo "Benchmark complete! Data saved to ${CSV_FILE}"
