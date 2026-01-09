# LLVM+AMDGPU “full-stack via artifacts” in WSL2 (Ubuntu 24.04)

This tutorial documents a practical WSL2 setup to *build and debug the LLVM AMDGPU backend* end-to-end **up to codegen artifacts** (LLVM IR → MIR → AMDGPU asm) and run **lit/FileCheck** tests.

> WSL2 limitation: you generally **cannot** run ROCm kernels/profilers unless your GPU/driver stack supports it. This tutorial focuses on what you *can* do immediately: compiler/codegen + regression tests.

## What you get
- A local out-of-tree LLVM build with:
  - Targets: `AMDGPU;X86`
  - Projects: `clang;mlir`
- Tooling available under `~/build/llvm-amdgpu-wsl2/bin/`:
  - `llc`, `opt`, `FileCheck`, `llvm-lit`, `mlir-opt`
  - (often useful) `clang`, `mlir-translate`, `llvm-dis`, `llvm-as`, `llvm-link`

## Extra walkthroughs

- End-to-end compilation flow (frontend → MLIR/LLVM → AMDGPU ISA): `frontend-to-amdgpu.md`

## Versions (this machine)
- OS: Ubuntu 24.04.3 LTS (WSL2)
- cmake: 3.28.3
- ninja: 1.11.1
- python: 3.12.3
- compiler: g++ 13.3.0
- LLVM: 22.0.0git (from this repo checkout)

## Repo location assumptions
- LLVM monorepo checkout: `~/llvm-project`
- Build dir (out-of-tree): `~/build/llvm-amdgpu-wsl2`

Adjust paths if yours differ.

---

## 1) Install build prerequisites (WSL2)

```bash
sudo apt update
sudo apt install -y \
  cmake ninja-build build-essential \
  python3 python3-venv python3-pip \
  git \
  zlib1g-dev libzstd-dev libxml2-dev libedit-dev libncurses-dev
```

Notes:
- This is a *minimal* dependency set sufficient to configure and build core LLVM/MLIR tools.
- You may add extras later (lld, libc++, etc.) depending on what you work on.

---

## 2) Configure an AMDGPU-focused out-of-tree build

Create the build directory:

```bash
mkdir -p ~/build/llvm-amdgpu-wsl2
```

Configure with CMake + Ninja:

```bash
cmake -S ~/llvm-project/llvm -B ~/build/llvm-amdgpu-wsl2 -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS="clang;mlir" \
  -DLLVM_TARGETS_TO_BUILD="AMDGPU;X86" \
  -DLLVM_ENABLE_RTTI=OFF \
  -DLLVM_ENABLE_EH=OFF
```

Explanation of key flags:
- `-G Ninja`: fast incremental builds; widely used in LLVM.
- `RelWithDebInfo`: optimized but still debuggable (good default for dev).
- `LLVM_ENABLE_ASSERTIONS=ON`: catches many bugs early.
- `LLVM_ENABLE_PROJECTS="clang;mlir"`: builds Clang and MLIR alongside LLVM.
- `LLVM_TARGETS_TO_BUILD="AMDGPU;X86"`: keeps build smaller but includes AMDGPU.
- `LLVM_ENABLE_RTTI/EH=OFF`: closer to typical LLVM settings; faster/smaller.

To confirm your configure settings later:

```bash
grep -E '^(CMAKE_BUILD_TYPE:|LLVM_ENABLE_PROJECTS:|LLVM_TARGETS_TO_BUILD:|LLVM_ENABLE_ASSERTIONS:|LLVM_ENABLE_RTTI:|LLVM_ENABLE_EH:)' \
  ~/build/llvm-amdgpu-wsl2/CMakeCache.txt
```

---

## 3) Build the minimum tools you need

In WSL2, it’s common to reduce parallelism to avoid memory spikes.

```bash
ninja -C ~/build/llvm-amdgpu-wsl2 -j 8 \
  llc opt FileCheck mlir-opt
```

To run `llvm-lit` reliably for LLVM regression tests, also build a few small
LLVM utilities that lit commonly uses as substitutions (otherwise lit can fail
early with messages like “Did not find count/not/llvm-config…”):

```bash
ninja -C ~/build/llvm-amdgpu-wsl2 -j 8 \
  llvm-config \
  not count
```

Some AMDGPU tests also require helper tools such as `llvm-readobj`:

```bash
ninja -C ~/build/llvm-amdgpu-wsl2 -j 8 llvm-readobj
```

Important note about `llvm-lit`:
- `llvm-lit` is typically generated as a **script** at `~/build/llvm-amdgpu-wsl2/bin/llvm-lit`.
- It is **not always** a Ninja target named `llvm-lit`.

After building, verify:

```bash
~/build/llvm-amdgpu-wsl2/bin/llc --version
~/build/llvm-amdgpu-wsl2/bin/opt --version
~/build/llvm-amdgpu-wsl2/bin/FileCheck --version
~/build/llvm-amdgpu-wsl2/bin/mlir-opt --version
~/build/llvm-amdgpu-wsl2/bin/llvm-lit --version
```

---

## 4) Your first “full-stack via artifacts” drill (no GPU required)

The idea is to debug/validate the pipeline by inspecting outputs at each layer.

### A) LLVM IR → AMDGPU asm (codegen)
Pick any AMDGPU test:

```bash
ls ~/llvm-project/llvm/test/CodeGen/AMDGPU | head
```

Run `llc` for an AMD GPU target. For newer AMD GPUs you’ll typically use `-march=amdgcn` plus a `-mcpu=gfx*`.

Example (adjust `gfx1151` as needed):

```bash
~/build/llvm-amdgpu-wsl2/bin/llc \
  -march=amdgcn -mcpu=gfx1151 -O3 \
  ~/llvm-project/llvm/test/CodeGen/AMDGPU/<test>.ll \
  -o - | head -n 80
```

### B) LLVM IR → MIR (backend debugging)
MIR is crucial for real AMDGPU backend fixes.

```bash
~/build/llvm-amdgpu-wsl2/bin/llc \
  -march=amdgcn -mcpu=gfx1151 -O3 \
  -stop-after=finalize-isel \
  ~/llvm-project/llvm/test/CodeGen/AMDGPU/<test>.ll \
  -o - | head -n 120
```

### C) Run a single lit test

```bash
~/build/llvm-amdgpu-wsl2/bin/llvm-lit -v \
  ~/llvm-project/llvm/test/CodeGen/AMDGPU/<test>.ll
```

---

## Worked examples (exact commands we used)

This section uses two real AMDGPU tests from `llvm/test/CodeGen/AMDGPU`.
They are small, fast, and good practice targets for gfx1151.

### Example 1: `directive-amdgcn-target.ll` (asm directive + kernel metadata)

Test file:

```text
~/llvm-project/llvm/test/CodeGen/AMDGPU/directive-amdgcn-target.ll
```

#### 1) Run the test with `llvm-lit`

```bash
~/build/llvm-amdgpu-wsl2/bin/llvm-lit -v \
  ~/llvm-project/llvm/test/CodeGen/AMDGPU/directive-amdgcn-target.ll
```

What this does:
- `llvm-lit` reads the test file and executes each `; RUN: ...` line.
- Each `RUN:` line pipes its output into `FileCheck` with a chosen
  `--check-prefixes=...` list.
- The test passes if all commands exit successfully and `FileCheck` finds the
  expected patterns.

How this particular test works:
- The file contains many `RUN:` lines with different `-mcpu=` values.
- For each `-mcpu`, the test checks that `llc` emits an `.amdgcn_target` string
  matching that architecture (and for HSA targets it also emits kernel metadata).

#### 2) Reproduce a single case directly with `llc` (gfx1151)

This is the “manual” version of one `RUN:` line.

```bash
~/build/llvm-amdgpu-wsl2/bin/llc \
  -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1151 -O3 \
  < ~/llvm-project/llvm/test/CodeGen/AMDGPU/directive-amdgcn-target.ll \
  | head -n 40
```

Notes on flags:
- `-mtriple=amdgcn-amd-amdhsa` picks the AMDGPU “GCN” backend and the HSA ABI.
- `-mcpu=gfx1151` selects the subtarget.
- `-O3` enables optimization (many backend behaviors are optimization-sensitive).
- Input is provided via stdin (`< file.ll`) to match how lit often runs tools.
- `head` is just to keep output short while iterating.

If everything is wired correctly, near the top you should see:
- `.amdgcn_target "amdgcn-amd-amdhsa--gfx1151"`
- `.amdhsa_code_object_version ...`
- `.amdhsa_kernel ...` metadata block

#### 3) Stop at a MIR checkpoint (`-stop-after=finalize-isel`)

This is the “backend debugging” version: you get MIR dumped instead of asm.

```bash
~/build/llvm-amdgpu-wsl2/bin/llc \
  -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1151 -O3 \
  -stop-after=finalize-isel \
  -verify-machineinstrs \
  < ~/llvm-project/llvm/test/CodeGen/AMDGPU/directive-amdgcn-target.ll \
  | head -n 120
```

What this does:
- `-stop-after=finalize-isel` stops the pipeline right after instruction
  selection is finalized and prints MIR.
- `-verify-machineinstrs` runs the machine verifier; if you break a Machine IR
  invariant while hacking, this often catches it early.

Why MIR helps:
- MIR is where most AMDGPU backend debugging happens (isel, regalloc,
  scheduling, pseudo expansion, etc.).
- You can compare MIR between two builds (before/after your change) to pinpoint
  the first pass where behavior diverges.

### Example 2: `elf-header-flags-mach.ll` (object emission + llvm-readobj)

Test file:

```text
~/llvm-project/llvm/test/CodeGen/AMDGPU/elf-header-flags-mach.ll
```

#### 1) Run the test with `llvm-lit`

```bash
~/build/llvm-amdgpu-wsl2/bin/llvm-lit -v \
  ~/llvm-project/llvm/test/CodeGen/AMDGPU/elf-header-flags-mach.ll
```

How this test works:
- Each `RUN:` line tells `llc` to emit an object file to stdout
  (`-filetype=obj`), then pipes it into:
  `llvm-readobj --file-header -`.
- `FileCheck` matches the printed ELF header and flags.

#### 2) Reproduce just the gfx1151 `RUN:` line manually

```bash
~/build/llvm-amdgpu-wsl2/bin/llc \
  -filetype=obj -mtriple=amdgcn -mcpu=gfx1151 \
  < ~/llvm-project/llvm/test/CodeGen/AMDGPU/elf-header-flags-mach.ll \
  | ~/build/llvm-amdgpu-wsl2/bin/llvm-readobj --file-header - \
  | head -n 80
```

What to look for:
- `Format: elf64-amdgpu`
- `Arch: amdgcn`
- A `Flags [` block that includes the expected `EF_AMDGPU_MACH_*` value.

---

## How lit + FileCheck fit together (mental model)

- `llvm-lit` is a test runner. It:
  1) discovers tests (files),
  2) runs the commands in `RUN:` lines,
  3) reports PASS/FAIL.
- `FileCheck` is a pattern matcher. It reads tool output (usually from a pipe)
  and checks it against `; CHECK:` directives in the test file.
- `--check-prefixes=A,B` selects which check lines apply (e.g. `A:` and `B:`).
  Tests often use this to cover multiple GPUs/targets in one file.

Practical debugging tips:
- If `llvm-lit` fails, copy the failing `RUN:` line and run it directly in your
  shell. That’s the fastest way to iterate.
- Keep your reproduction command *as close as possible* to the `RUN:` line
  (same `-mtriple`, `-mcpu`, `-mattr`, `-O*`, etc.).
- For backend work, add `-stop-after=<pass>` (or `-stop-before=<pass>`) and
  `-verify-machineinstrs` to catch problems earlier.

---

## 5) Updating `FileCheck` lines (common workflow)
LLVM commonly uses scripts to update `CHECK:` lines when output changes.

- Script: `~/llvm-project/llvm/utils/update_llc_test_checks.py`

Typical flow:
1) Edit/minimize a `.ll` test.
2) Run the update script.
3) Re-run `llvm-lit` on that test.

---

## 6) Troubleshooting

### Configure succeeded but `build.ninja` missing
Re-run configure:

```bash
cmake -S ~/llvm-project/llvm -B ~/build/llvm-amdgpu-wsl2 -G Ninja <same flags>
```

### WSL2 build sessions dying / instability
- Use smaller `-j` (e.g. `-j 8` or `-j 4`).
- Prefer `RelWithDebInfo` over full `Debug` (smaller builds).

### `ninja: unknown target 'llvm-lit'`
That’s expected sometimes. Use the script:

```bash
~/build/llvm-amdgpu-wsl2/bin/llvm-lit --version
```

### `llvm-lit` fatals about missing tools (e.g. `count`, `not`, `llvm-config`)
If `llvm-lit` aborts with a fatal “Did not find … in ~/build/llvm-amdgpu-wsl2/bin”,
build the missing tool(s) with Ninja (see section 3).

Note: `llvm-lit` may also print many “note: Did not find <tool> …” lines.
Those are typically *non-fatal* unless the specific test you are running needs
that tool.

Quick rule of thumb:
- If the test ends in `PASS`, the “note: Did not find …” messages are safe to
  ignore for that run.
- If the test fails with a `fatal:` / “Could not run process …” / “not found”,
  copy the failing `RUN:` line and build the missing tool(s) with:
  `ninja -C ~/build/llvm-amdgpu-wsl2 <tool>`

---

## Next steps (once native Ubuntu + ROCm is ready)
- Validate kernel execution (Triton/HIP) on the real GPU.
- Profile with ROCm tools and correlate perf bottlenecks back to:
  - MLIR lowering patterns
  - LLVM AMDGPU instruction selection/scheduling
  - generated ISA
