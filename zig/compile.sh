#!/usr/bin/env bash
set -e

zig run src/poly_stat.zig -O ReleaseFast -mcpu=native --name out
