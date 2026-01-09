# C/C++ → LLVM → NVIDIA PTX (NVPTX, compile-only)

This note mirrors the AMDGPU flow, but for NVIDIA GPUs using LLVM’s **NVPTX** backend.
It stays *compile-only* (WSL2-friendly): we generate PTX text, but we don’t run kernels.

## What you do and do not have

- LLVM/Clang can generate **PTX** via the NVPTX backend.
- Producing a runnable **cubin** and executing it typically requires the NVIDIA driver/CUDA toolkit.
- This tutorial focuses on “frontend → IR → PTX” artifacts.

## Build/tooling

This repo assumes you have a separate NVPTX-enabled LLVM build at:

- `BIN=/home/oldzhu/build/llvm-nvptx-wsl2/bin`

(Kept separate from the AMDGPU build so the two don’t interfere.)

## One-command: regenerate all example outputs

From the tutorial repo root:

```bash
chmod +x nvidia/examples/regen_outputs.sh
nvidia/examples/regen_outputs.sh
```

This writes:

- `nvidia/examples/outputs/llvm_add_kernel.sm80.ptx`
- `nvidia/examples/outputs/cuda_minimal.sm80.ptx`

These files are generated locally (see `.gitignore`).

## Example A: LLVM IR kernel → PTX (via llc)

- Source: [nvidia/examples/llvm_add_kernel_nvptx.ll](nvidia/examples/llvm_add_kernel_nvptx.ll)
- Command:
  - `"$BIN/llc" -mtriple=nvptx64-nvidia-cuda -mcpu=sm_80 -O3 nvidia/examples/llvm_add_kernel_nvptx.ll -o - | sed -n '1,80p'`

You should see PTX directives like:

```ptx
.version
.target sm_80
.address_size 64
```

## Example B: CUDA C++ frontend → PTX (device-only)

- Source: [nvidia/examples/cuda_minimal.cu](nvidia/examples/cuda_minimal.cu)
- Command (no CUDA headers/libs):

```bash
"$BIN/clang++" -x cuda --cuda-gpu-arch=sm_80 --cuda-device-only -nocudainc -nocudalib \
  -S nvidia/examples/cuda_minimal.cu -o - | sed -n '1,120p'
```

Notes:

- This works for simple kernels that don’t need CUDA headers or libdevice.
- If you start using math intrinsics or more complex CUDA features, you’ll likely need a CUDA toolkit and `--cuda-path=...`.

## Quick next exercises

- Change `--cuda-gpu-arch=sm_70/sm_80/sm_90` and diff the PTX.
- Introduce loads/stores and watch address spaces in the generated PTX.
- If you later add a CUDA toolkit, extend the tutorial to emit LLVM IR (`-emit-llvm`) and/or link device libraries.
