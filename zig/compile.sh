#!/usr/bin/env bash
set -e

zig run src/image_pipeline_comptime.zig -O ReleaseFast -mcpu=native --name cmp_high
