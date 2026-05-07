# AMDGPU starter patch ideas

[中文版本](next-practice-patches.zh-CN.md)

This file lists small, practical LLVM/AMDGPU practice tasks that fit the current WSL2 compile-only setup.

## 1. ~~Investigate the `directive-amdgcn-target.ll` source/build mismatch~~ (RESOLVED)

~~Current observation in this build:~~ (resolved after full rebuild)

The `gfx1170` issue was a stale-build problem, not a backend support gap. After a full `cmake` reconfigure + `ninja llc` rebuild, `directive-amdgcn-target.ll` now passes cleanly:

```text
PASS: LLVM :: CodeGen/AMDGPU/directive-amdgcn-target.ll
Passed: 1 (100.00%)
```

Key lesson: when `llc -march=amdgcn -mcpu=help` is missing a target present in source, suspect stale generated files and do a full rebuild.

## 2. ~~Add or tighten a small AMDGPU CodeGen test~~ (FIRST PATCH DONE)

Added one gfx1151 RUN line to `rotr.ll` in `llvm-project`:

- `llvm/test/CodeGen/AMDGPU/rotr.ll`: +1 line
- gfx1151 function body codegen is identical to gfx1100 with `+real-true16` on this test, so it shares the existing `GFX11,GFX11-TRUE16` check prefix.
- Verified via `llvm-lit` on this build: **PASS**.

Next time, pick a test where gfx1151 codegen actually differs from gfx1100 and requires a new `GFX1151` check prefix.

### Original task description:

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

1. ~~Investigate `directive-amdgcn-target.ll` lit failure~~ (done: stale-build, resolved)
2. ~~Add a gfx1151 check to a small AMDGPU test~~ (done: rotr.ll, PASS)
3. Find a test where gfx1151 codegen differs from gfx1100 and add a real `GFX1151` check prefix.
4. In parallel, extend the tutorial with one more MIR-focused example.