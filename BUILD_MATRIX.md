# Build matrix (what to build for each GPU target)

This repo is **documentation + examples**.
You build LLVM out-of-tree in separate build directories (recommended) and point the scripts at the right `bin/`.

## Overview

| Target | LLVM build dir | `LLVM_TARGETS_TO_BUILD` | Produces (compiler artifacts) | Primary tutorial entry |
|---|---|---|---|---|
| AMDGPU (ROCm/HSA) | `~/build/llvm-amdgpu-wsl2` | `AMDGPU;X86` | AMDGPU asm (`.s`), AMDGPU ELF objects (`.o`), ROCDL/LLVM-dialect MLIR | `amdgpu/frontend-to-amdgpu.md` |
| NVIDIA (CUDA/PTX) | `~/build/llvm-nvptx-wsl2` | `NVPTX;X86` | PTX text (`.ptx`) via `llc` and `clang -x cuda` (device-only) | `nvidia/frontend-to-nvidia.md` |

## AMDGPU build (recommended for AMD work)

Configure:

```bash
mkdir -p ~/build/llvm-amdgpu-wsl2
cmake -S ~/llvm-project/llvm -B ~/build/llvm-amdgpu-wsl2 -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS="clang;mlir" \
  -DLLVM_TARGETS_TO_BUILD="AMDGPU;X86" \
  -DLLVM_ENABLE_RTTI=OFF \
  -DLLVM_ENABLE_EH=OFF
```

Build minimum tools:

```bash
ninja -C ~/build/llvm-amdgpu-wsl2 -j 8 \
  llc opt FileCheck mlir-opt llvm-readobj llvm-config not count
```

Scripts use:

- `LLVM_AMDGPU_BIN` (defaults to `~/build/llvm-amdgpu-wsl2/bin`)

## NVIDIA/NVPTX build (recommended for NVIDIA work)

Configure:

```bash
mkdir -p ~/build/llvm-nvptx-wsl2
cmake -S ~/llvm-project/llvm -B ~/build/llvm-nvptx-wsl2 -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS="clang;mlir" \
  -DLLVM_TARGETS_TO_BUILD="NVPTX;X86" \
  -DLLVM_ENABLE_RTTI=OFF \
  -DLLVM_ENABLE_EH=OFF
```

Build minimum tools:

```bash
ninja -C ~/build/llvm-nvptx-wsl2 -j 8 \
  clang clang++ llc llvm-readobj
```

Optional (if you want to run `llvm-lit` in that tree too):

```bash
ninja -C ~/build/llvm-nvptx-wsl2 -j 8 FileCheck not count
```

Scripts use:

- `LLVM_NVPTX_BIN` (defaults to `~/build/llvm-nvptx-wsl2/bin`)

## Why two builds?

- Keeps build times and binary sets smaller.
- Avoids reconfiguring/rebuilding when switching between AMDGPU and NVPTX.
- Mirrors how you’ll typically work when contributing to specific backends.
