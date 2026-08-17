#!/usr/bin/env bash

echo "REMEMBER TO RUN WITH SUDO!"

FILES=(
  "poly_dyn.cpp"
  "poly_stat.cpp"
)

ITERATIONS=${1:-2}  # Defaults to 10 runs per file if not passed as script arg
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
      cmake .. -DOptimise=ON \
               -DTARGET_SRC="${FILENAME}" \
               -DINCREMENT_VAL="${INC}" > /dev/null 2>&1

      # BUILD TIMES (Cold & Hot)
      COLD_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0,1 make -s -j$(nproc) > /dev/null; } 2>&1)
      touch "../src/${FILENAME}"
      HOT_TIME=$( { /usr/bin/time -f "%e,%U,%S" taskset -c 0,1 make -s -j$(nproc) > /dev/null; } 2>&1)

      make -j$(nproc)

      ./out

      # Extract execution time
      OUT_DATA=$(./out)
      RUN_NS=$(echo "$OUT_DATA" | grep "Processed in:" | awk -F'[][]' '{print $2}')

      # Log single flattened row to CSV
      echo "${LABEL},${SETTING_NAME},${i},${COLD_TIME},${HOT_TIME},${RUN_NS}" >> "../${CSV_FILE}"

      cd ..
      rm -rf build
    done
done
