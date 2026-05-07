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

1. ~~Reproduce the current `directive-amdgcn-target.ll` failure manually.~~ (done)
2. ~~Verify the source/build mismatch (`gfx1170` in source, absent in built `llc`).~~ (done)
3. ~~Find the smallest reliable rebuild path that refreshes AMDGPU generated files.~~ (done: ran `cmake` reconfigure + `ninja llc`)
4. Make one tiny tests-first improvement in `llvm/test/CodeGen/AMDGPU/`. (next)