# AMDGPU starter patch ideas

[中文版本](next-practice-patches.zh-CN.md)

This file lists small, practical LLVM/AMDGPU practice tasks that fit the current WSL2 compile-only setup.

## 1. Investigate the `directive-amdgcn-target.ll` source/build mismatch

Current observation in this build:

```text
'gfx1170' is not a recognized processor for this target (ignoring processor)
error: GFX1170: expected string not found in input
```

What we know so far:

- the checked-out source tree contains `gfx1170`,
- but the current built `llc` binary and generated AMDGPU build files do not,
- so the likely issue is stale generated backend artifacts or a source/build mismatch.

Why it is a good starter task:

- It is narrow and reproducible.
- It teaches you how subtarget names are recognized by the AMDGPU backend.
- It gives you practice reading test expectations versus actual backend support.

Useful places to inspect in `llvm-project`:

- `llvm/lib/Target/AMDGPU/`
- `llvm/test/CodeGen/AMDGPU/directive-amdgcn-target.ll`

Possible outcomes:

- confirm exactly which generated AMDGPU files are stale,
- find the smallest rebuild path that refreshes them correctly,
- or identify why the build graph is not regenerating AMDGPU outputs from newer source files.

## 2. Add or tighten a small AMDGPU CodeGen test

Pick a tiny existing test under `llvm/test/CodeGen/AMDGPU/` and improve it by:

- narrowing checks to the exact instruction or metadata you care about,
- adding one new `CHECK:` line for gfx1151 behavior,
- or splitting a too-broad test into smaller focused cases.

Why this is good:

- tests-first work is the safest way to start contributing,
- you learn `llc`, `FileCheck`, and `update_llc_test_checks.py` immediately.

## 3. Compare two nearby subtargets and explain the delta

Take the same input and run:

```bash
llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1150 ...
llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1151 ...
```

Then inspect:

- target string,
- kernel metadata,
- MIR differences,
- final asm differences.

This is not necessarily a code patch by itself, but it often turns into one once you find a mismatch or missed optimization.

## 4. Extend the tutorial examples with one more MIR-focused case

Add a second minimal LLVM IR example under `amdgpu/examples/` that produces a slightly more interesting MIR shape than a single `s_endpgm` kernel.

Good candidates:

- one load + one store,
- a simple integer add,
- a simple control-flow block.

Why this is useful:

- it improves the tutorial repo,
- and it gives you a controlled input for backend debugging.

## 5. Explore a small MLIR GPU → ROCDL test improvement

If you want something more Triton-adjacent, start with a tiny MLIR test in:

- `mlir/test/Conversion/GPUToROCDL/`
- `mlir/test/Target/LLVMIR/rocdl.mlir`

Good starter work:

- add one focused lowering check,
- clarify a `CHECK:` pattern,
- or add a minimal new op coverage case.

## Recommended order

1. Reproduce the current `directive-amdgcn-target.ll` failure manually.
2. Verify the source/build mismatch (`gfx1170` in source, absent in built `llc`).
3. Find the smallest reliable rebuild path that refreshes AMDGPU generated files.
4. In parallel, make one tiny tests-first improvement in `llvm/test/CodeGen/AMDGPU/`.
