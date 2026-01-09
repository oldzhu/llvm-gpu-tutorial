# Frontend → LLVM/MLIR → AMDGPU ISA (WSL2 compile-only)

This note is an end-to-end *compiler pipeline* walkthrough you can run in this workspace.
It intentionally avoids executing on a GPU (no ROCm runtime in WSL2);
we focus on *IR shapes, lowering steps, and codegen*.

## Mental model (where Triton fits)

A typical Triton/MLIR/LLVM stack looks like:

- **Triton (out-of-tree)**
  - Python + Triton DSL → Triton IR → MLIR (often via custom dialects)
- **MLIR (in-tree here)**
  - GPU dialect(s), conversion passes, ROCDL dialect, then LLVM dialect
- **LLVM IR (in-tree here)**
  - Target-independent mid-end (`opt`), then target backend (`llc`)
- **AMDGPU backend**
  - Instruction selection, scheduling, regalloc → AMDGPU ISA (GCN/RDNA) assembly

In this repo, you’ll mainly practice in MLIR and LLVM; Triton itself is not in-tree.

## Tools used (from your build)

All commands below assume:

- `BIN=/home/oldzhu/build/llvm-amdgpu-wsl2/bin`
- Examples live in `/home/oldzhu/build/llvm-amdgpu-wsl2/tutorial/examples/`

Key tools:

- `clang`: C → LLVM IR (host-side demo)
- `mlir-opt`: run MLIR passes (GPU → ROCDL/LLVM dialect)
- `mlir-translate`: MLIR (LLVM dialect) → textual LLVM IR (only for supported top-level shapes)
- `llc`: LLVM IR → AMDGPU assembly / object

## One-command: regenerate all example outputs

From `/home/oldzhu/build/llvm-amdgpu-wsl2`:

```bash
chmod +x tutorial/examples/regen_outputs.sh
tutorial/examples/regen_outputs.sh
```

This writes:

- `tutorial/examples/outputs/llvm_add_kernel.gfx1151.s`
- `tutorial/examples/outputs/llvm_add_kernel.gfx1151.o`
- `tutorial/examples/outputs/llvm_add_kernel.gfx1151.readobj-file-header.txt`
- `tutorial/examples/outputs/mlir_gpu_ids.rocdl.mlir`
- `tutorial/examples/outputs/c_vecadd_host.ll`

These files are generated locally (see `tutorial/.gitignore`).

## Example A: C → LLVM IR (host-side)

This demonstrates the *front-end* and LLVM IR emission (host triple).

- Source: [tutorial/examples/c_vecadd_host.c](tutorial/examples/c_vecadd_host.c)
- Command:
  - `"$BIN/clang" -O2 -S -emit-llvm tutorial/examples/c_vecadd_host.c -o - | sed -n '1,40p'`

Sample output excerpt (first lines):

```llvm
; ModuleID = '.../c_vecadd_host.c'
target triple = "x86_64-unknown-linux-gnu"

define dso_local void @vecadd(ptr ...)
```

This is not a GPU kernel yet; it’s just to make the “frontend → LLVM IR” step concrete.

## Example B: LLVM IR kernel → gfx1151 assembly (no runtime required)

This is the most direct “LLVM → AMDGPU ISA” path.

- Source: [tutorial/examples/llvm_add_kernel.ll](tutorial/examples/llvm_add_kernel.ll)
- Build AMDGPU asm:
  - `"$BIN/llc" -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1151 -O3 tutorial/examples/llvm_add_kernel.ll -o - | sed -n '1,60p'`

Sample output excerpt:

```asm
	.amdgcn_target "amdgcn-amd-amdhsa--gfx1151"
	.text
	.globl	vadd_one
vadd_one:
	s_load_b128 s[0:3], s[4:5], 0x0
	...
	s_add_f32 s0, s0, s1
	...
	global_store_b32 v0, v1, s[4:5]
	s_endpgm
```

Notes:

- The function is marked `amdgpu_kernel`, so the backend emits an HSA kernel descriptor section (`.amdhsa_kernel ...`).
- This is a great loop for backend work: tweak LLVM IR → re-run `llc` → inspect asm/MIR.

## Example C: MLIR GPU → ROCDL/LLVM dialect (compile-only)

This shows the “MLIR GPU lowering” portion that’s Triton-adjacent.

- Source: [tutorial/examples/mlir_gpu_ids.mlir](tutorial/examples/mlir_gpu_ids.mlir)
- Lower `gpu.thread_id` into ROCDL + LLVM dialect:
  - `"$BIN/mlir-opt" tutorial/examples/mlir_gpu_ids.mlir -convert-gpu-to-rocdl='chipset=gfx1151' | sed -n '1,80p'`

Sample output excerpt:

```mlir
module {
  gpu.module @kernels attributes {llvm.data_layout = "..."} {
    llvm.func @write_tid_x(...) attributes {gpu.kernel, rocdl.kernel} {
      %4 = rocdl.workitem.id.x : i32
      %5 = llvm.sext %4 : i32 to i64
      ...
    }
  }
}
```

Important limitation (WSL2):

- The lowered LLVM dialect function is still nested in `gpu.module`.
- The common “full compilation” pipeline in MLIR often continues with GPU host lowering and/or `-gpu-module-to-binary` (HSACO emission), which can require ROCm tooling/device libraries.
- In WSL2, treat this step as “verify the lowering and IR shapes”, and use Example B for “LLVM → ISA”.

## Quick next exercises (useful for Triton-adjacent work)

- Change `chipset=` / `-mcpu=` and compare generated code (`gfx1100`, `gfx1151`, etc.).
- Add more GPU ops in [tutorial/examples/mlir_gpu_ids.mlir](tutorial/examples/mlir_gpu_ids.mlir) (barriers, subgroup ops), then re-run `-convert-gpu-to-rocdl` and inspect ROCDL.
- Take a failing AMDGPU LLVM CodeGen test and reproduce its `RUN:` line manually with `llc` (the workflow in tutorial/README.md).
