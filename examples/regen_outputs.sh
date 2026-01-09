#!/usr/bin/env bash
set -euo pipefail

BIN="/home/oldzhu/build/llvm-amdgpu-wsl2/bin"
EX="/home/oldzhu/build/llvm-amdgpu-wsl2/tutorial/examples"
OUT="$EX/outputs"

mkdir -p "$OUT"

"$BIN/llc" -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1151 -O3 \
  "$EX/llvm_add_kernel.ll" -o "$OUT/llvm_add_kernel.gfx1151.s"

"$BIN/llc" -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1151 -O3 -filetype=obj \
  "$EX/llvm_add_kernel.ll" -o "$OUT/llvm_add_kernel.gfx1151.o"

"$BIN/llvm-readobj" --file-header "$OUT/llvm_add_kernel.gfx1151.o" \
  > "$OUT/llvm_add_kernel.gfx1151.readobj-file-header.txt"

"$BIN/mlir-opt" "$EX/mlir_gpu_ids.mlir" \
  -convert-gpu-to-rocdl='chipset=gfx1151' > "$OUT/mlir_gpu_ids.rocdl.mlir"

"$BIN/clang" -O2 -S -emit-llvm \
  "$EX/c_vecadd_host.c" -o "$OUT/c_vecadd_host.ll"

echo "Wrote outputs to: $OUT"
ls -1 "$OUT"
