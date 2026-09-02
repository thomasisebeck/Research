cmake_minimum_required(VERSION 3.10)
project(Practice)

set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_compile_options(-fconstexpr-ops-limit=100000000)
add_compile_options(-fconstexpr-loop-limit=100000000)

if(DEFINED INCREMENT_VAL)
  add_compile_definitions(INCREMENT_VAL=${INCREMENT_VAL})
endif()

if(DEFINED QUAL_VAL)
  add_compile_definitions(QUAL=${QUAL_VAL})
endif()

if(DEFINED APPLY_ONE_VAL)
  add_compile_definitions(APPLY_ONE=${APPLY_ONE_VAL})
endif()

if(DEFINED APPLY_TWO_VAL)
  add_compile_definitions(APPLY_TWO=${APPLY_TWO_VAL})
endif()

if(DEFINED APPLY_THREE_VAL)
  add_compile_definitions(APPLY_THREE=${APPLY_THREE_VAL})
endif()

# 1. Define the custom toggle (Defaults to OFF/Debug mode)
option(Optimise "Build with high optimizations and no assertions" OFF)

if(NOT DEFINED TARGET_SRC)
  set(TARGET_SRC "poly_stat.cpp")
endif()

set(SOURCES "src/${TARGET_SRC}")

configure_file("${CMAKE_CURRENT_SOURCE_DIR}/input_image.txt"
               "${CMAKE_CURRENT_BINARY_DIR}/input_image.txt" COPYONLY)

configure_file("${CMAKE_CURRENT_SOURCE_DIR}/calibration.txt"
               "${CMAKE_CURRENT_BINARY_DIR}/calibration.txt" COPYONLY)

configure_file("${CMAKE_CURRENT_SOURCE_DIR}/lookup.txt"
               "${CMAKE_CURRENT_BINARY_DIR}/lookup.txt" COPYONLY)

find_package(benchmark REQUIRED)

add_executable(out ${SOURCES})

target_precompile_headers(
  out
  PRIVATE
  <algorithm>
  <array>
  <benchmark/benchmark.h>
  <chrono>
  <cmath>
  <cstddef>
  <fstream>
  <iostream>
  <linux/prctl.h>
  <print>
  <ranges>
  <sys/prctl.h>
  <utility>
  <variant>)

target_link_libraries(out PRIVATE benchmark::benchmark pthread)

# 1. Apply Flags based on the Optimize option
if(Optimise)
  message(STATUS "Build Mode: OPTIMIZED (Assertions disabled)")
  if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(out PRIVATE -O3 -std=c++26 -march=native
                                       -mtune=native)
    target_compile_definitions(out PRIVATE NDEBUG) # This removes the
                                                   # assertions!
  endif()
else()
  message(STATUS "Build Mode: DEBUG (Assertions enabled, slow)")
  if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(out PRIVATE -g -O0 -std=c++26)
    # Note: We do NOT define NDEBUG here, so assert() stays active.
  endif()
endif()
