# Frontend → LLVM/MLIR → AMDGPU ISA (WSL2 compile-only)

[中文版本](frontend-to-amdgpu.zh-CN.md)

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
- Examples live under `amdgpu/examples/`

Key tools:

- `clang`: C → LLVM IR (host-side demo)
- `mlir-opt`: run MLIR passes (GPU → ROCDL/LLVM dialect)
- `mlir-translate`: MLIR (LLVM dialect) → textual LLVM IR (only for supported top-level shapes)
- `llc`: LLVM IR → AMDGPU assembly / object

## One-command: regenerate all example outputs

From the tutorial repo root:

```bash
chmod +x amdgpu/examples/regen_outputs.sh
amdgpu/examples/regen_outputs.sh
```

This writes:

- `amdgpu/examples/outputs/llvm_add_kernel.gfx1151.s`
- `amdgpu/examples/outputs/llvm_add_kernel.gfx1151.o`
- `amdgpu/examples/outputs/llvm_add_kernel.gfx1151.readobj-file-header.txt`
- `amdgpu/examples/outputs/mlir_gpu_ids.rocdl.mlir`
- `amdgpu/examples/outputs/c_vecadd_host.ll`

These files are generated locally (see `.gitignore`).

## Example A: C → LLVM IR (host-side)

This demonstrates the *front-end* and LLVM IR emission (host triple).

- Source: [amdgpu/examples/c_vecadd_host.c](amdgpu/examples/c_vecadd_host.c)
- Command:
  - `"$BIN/clang" -O2 -S -emit-llvm amdgpu/examples/c_vecadd_host.c -o - | sed -n '1,40p'`

Sample output excerpt (first lines):

```llvm
; ModuleID = '.../c_vecadd_host.c'
target triple = "x86_64-unknown-linux-gnu"

define dso_local void @vecadd(ptr ...)
```

This is not a GPU kernel yet; it’s just to make the “frontend → LLVM IR” step concrete.

## Example B: LLVM IR kernel → gfx1151 assembly (no runtime required)

This is the most direct “LLVM → AMDGPU ISA” path.

- Source: [amdgpu/examples/llvm_add_kernel.ll](amdgpu/examples/llvm_add_kernel.ll)
- Build AMDGPU asm:
  - `"$BIN/llc" -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1151 -O3 amdgpu/examples/llvm_add_kernel.ll -o - | sed -n '1,60p'`

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

- Source: [amdgpu/examples/mlir_gpu_ids.mlir](amdgpu/examples/mlir_gpu_ids.mlir)
- Lower `gpu.thread_id` into ROCDL + LLVM dialect:
  - `"$BIN/mlir-opt" amdgpu/examples/mlir_gpu_ids.mlir -convert-gpu-to-rocdl='chipset=gfx1151' | sed -n '1,80p'`

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

## Example D: Real `llc` / MIR debug loop on an upstream AMDGPU test

This is the practical backend-debug loop you will use often when working on LLVM AMDGPU.

- Test file: `~/llvm-project/llvm/test/CodeGen/AMDGPU/directive-amdgcn-target.ll`
- Goal: inspect one concrete gfx1151 case manually, even if the full lit test currently fails for some other subtarget.

### 1) Generate gfx1151 assembly directly

```bash
BIN=/home/oldzhu/build/llvm-amdgpu-wsl2/bin
TEST=~/llvm-project/llvm/test/CodeGen/AMDGPU/directive-amdgcn-target.ll

"$BIN/llc" -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1151 -O3 < "$TEST" | sed -n '1,40p'
```

Observed output excerpt on this machine:

```asm
  .amdgcn_target "amdgcn-amd-amdhsa--gfx1151"
  .amdhsa_code_object_version 6
  .text
  .globl	directive_amdgcn_target
directive_amdgcn_target:
  s_endpgm
  .section	.rodata,"a",@progbits
  .amdhsa_kernel directive_amdgcn_target
```

Why this is useful:

- It isolates the exact `-mcpu` case you care about.
- It confirms the backend is selecting the expected target string and HSA metadata for gfx1151.

### 2) Stop at a MIR checkpoint

```bash
"$BIN/llc" -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1151 -O3 \
  -stop-after=finalize-isel -verify-machineinstrs < "$TEST" | sed -n '1,120p'
```

Observed MIR excerpt on this machine:

```yaml
name:            directive_amdgcn_target
failedISel:      false
tracksRegLiveness: true
registers:
  - { id: 0, class: vgpr_32, preferred-register: '', flags: [  ] }
  - { id: 1, class: sgpr_64, preferred-register: '', flags: [  ] }
  - { id: 2, class: sgpr_64, preferred-register: '', flags: [  ] }
```

Why this is useful:

- `failedISel: false` tells you instruction selection succeeded.
- The MIR dump gives you the right starting point for pass-by-pass backend debugging.
- `-verify-machineinstrs` catches many backend invariants early.

### 3) Why `llvm-lit` may still fail even when your gfx1151 case looks fine

On this machine, the full lit test initially failed because the built `llc` binary did not recognize a later subtarget that the source tree already knew about:

```text
'gfx1170' is not a recognized processor for this target (ignoring processor)
error: GFX1170: expected string not found in input
```

**How this was resolved:**

- `gfx1170` is present in the checked-out source tree (`llvm/include/llvm/TargetParser/AMDGPUTargetParser.def`).
- The generated AMDGPU build artifacts (e.g. `AMDGPUGenSubtargetInfo.inc`) were stale/older and did not include `gfx1170`.
- A full rebuild (`ninja -C ~/build/llvm-amdgpu-wsl2 llc` after a fresh `cmake` reconfigure) refreshed the generated files.
- After that rebuild, `directive-amdgcn-target.ll` now passes cleanly:
  ```text
  PASS: LLVM :: CodeGen/AMDGPU/directive-amdgcn-target.ll (1 of 1)
  ```

Takeaways:

- your manual gfx1151 debug loop was valid all along,
- always suspect stale generated files when `-mcpu=help` is missing a target you see in source,
- a full rebuild is often the fix, not a code change.

## Quick next exercises (useful for Triton-adjacent work)

- Change `chipset=` / `-mcpu=` and compare generated code (`gfx1100`, `gfx1151`, etc.).
- Add more GPU ops in [amdgpu/examples/mlir_gpu_ids.mlir](amdgpu/examples/mlir_gpu_ids.mlir) (barriers, subgroup ops), then re-run `-convert-gpu-to-rocdl` and inspect ROCDL.
- Take a failing AMDGPU LLVM CodeGen test and reproduce its `RUN:` line manually with `llc` (the workflow in README.md).
- See `amdgpu/next-practice-patches.md` for small, practical starter patch ideas.
