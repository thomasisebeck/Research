#!/usr/bin/env bash

# Exit immediately on failure
set -e

# Ensure running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (e.g. sudo ./run_all.sh)"
    exit 1
fi

ROOT_DIR=$(pwd)

# Language directories
LANG_DIRS=("cpp" "rust" "zig")

# Benchmark scripts to run in sequence
# SCRIPTS=("cal.sh" "branching.sh" "lut.sh" "poly.sh")
SCRIPTS=("poly.sh")

TOTAL_RUNS=$(( ${#LANG_DIRS[@]} * ${#SCRIPTS[@]} ))
CURRENT_RUN=0

echo "=================================================="
echo " Starting Full Suite Benchmark Run"
echo " Total scripts to execute: ${TOTAL_RUNS}"
echo "=================================================="

for DIR in "${LANG_DIRS[@]}"; do
    TARGET_DIR="${ROOT_DIR}/${DIR}"

    if [ ! -d "$TARGET_DIR" ]; then
        echo "[WARNING] Directory $TARGET_DIR not found. Skipping..."
        continue
    fi

    echo ""
    echo "=================================================="
    echo " Entering Language Directory: ${DIR}"
    echo "=================================================="

    cd "$TARGET_DIR"

    for SCRIPT in "${SCRIPTS[@]}"; do
        CURRENT_RUN=$((CURRENT_RUN + 1))

        if [ -f "./${SCRIPT}" ]; then
            echo ""
            echo "--------------------------------------------------"
            echo " [${CURRENT_RUN}/${TOTAL_RUNS}] Executing: ${DIR}/${SCRIPT}"
            echo "--------------------------------------------------"
            
            # Ensure script is executable
            chmod +x "./${SCRIPT}"

            # Run benchmark script directly
            ./"${SCRIPT}"

            echo " -> Finished: ${DIR}/${SCRIPT}"
            echo " Cooling down CPU (5s)..."
            sleep 5
        else
            echo "[WARNING] Script ./${SCRIPT} not found in ${TARGET_DIR}. Skipping..."
        fi
    done

    # Return to root directory
    cd "$ROOT_DIR"
done

echo ""
echo "=================================================="
echo " All ${TOTAL_RUNS} benchmark scripts finished successfully!"
echo "=================================================="
