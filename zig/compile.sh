#!/usr/bin/env bash
set -e

zig run src/lut_runtime.zig -O ReleaseFast -mcpu=native --name lut_runtime
