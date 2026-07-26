cmake_minimum_required(VERSION 3.10)
project(Practice)

set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# 1. Define the custom toggle (Defaults to OFF/Debug mode)
option(Optimise "Build with high optimizations and no assertions" OFF)

# 1. Source files
set(SOURCES src/image_pipeline_runtime.cpp)

configure_file("${CMAKE_CURRENT_SOURCE_DIR}/input_image.txt"
               "${CMAKE_CURRENT_BINARY_DIR}/input_image.txt" COPYONLY)

configure_file("${CMAKE_CURRENT_SOURCE_DIR}/lookup.txt"
               "${CMAKE_CURRENT_BINARY_DIR}/lookup.txt" COPYONLY)

add_executable(out ${SOURCES})

# 1. Apply Flags based on the Optimize option
if(Optimise)
  message(STATUS "Build Mode: OPTIMIZED (Assertions disabled)")
  if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(
      out
      PRIVATE -O3
              -std=c++26
              -march=native
              -mtune=native
              -flto
              -ffast-math
              -fno-tree-vectorize)
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
