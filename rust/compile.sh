#!/usr/bin/env bash
set -e

# Pass opt-level 3 and target-cpu native directly to rustc
RUSTFLAGS="-C opt-level=3 -C target-cpu=native" cargo build --release
