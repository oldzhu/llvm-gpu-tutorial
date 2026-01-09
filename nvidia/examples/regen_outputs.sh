#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

BIN_DEFAULT="/home/oldzhu/build/llvm-nvptx-wsl2/bin"
BIN="${LLVM_NVPTX_BIN:-$BIN_DEFAULT}"

EX="$SCRIPT_DIR"
OUT="$EX/outputs"

mkdir -p "$OUT"

# LLVM IR -> PTX (via llc)
"$BIN/llc" -mtriple=nvptx64-nvidia-cuda -mcpu=sm_80 -O3 \
  "$EX/llvm_add_kernel_nvptx.ll" -o "$OUT/llvm_add_kernel.sm80.ptx"

# CUDA C++ frontend -> PTX (device-only, no headers/libs)
"$BIN/clang++" -x cuda --cuda-gpu-arch=sm_80 --cuda-device-only -nocudainc -nocudalib \
  -S "$EX/cuda_minimal.cu" -o "$OUT/cuda_minimal.sm80.ptx"

echo "Wrote outputs to: $OUT"
ls -1 "$OUT"
