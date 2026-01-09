# Session summary (handoff) — LLVM+AMDGPU practice setup

This file summarizes the chat/work done so far so it can be copied into a new workspace/chat.

## Goal
Practice and learn skills aligned with a Triton/AMDGPU compiler job by contributing to relevant codebases:
- LLVM AMDGPU backend debugging/fixes
- MLIR GPU lowering/passes
- Triton AMD backend (later, when ROCm runtime available)
- Profiling/performance work (requires native Linux/ROCm)

## Key constraints discovered
- WSL2 currently does **not** provide a reliable ROCm/GPU runtime path for the user’s hardware (Ryzen AI MAX+ 395 / Radeon 8060S), consistent with ROCm/ROCm#4952.
- Therefore, in WSL2 we focus on **compile/codegen + tests** (“full-stack via artifacts”), and plan to use **native Ubuntu + ROCm** later for kernel execution/profiling.

## Repo/workspace state
Workspace contains:
- `~/llvm-project` (llvm-project monorepo)
- Out-of-tree build dir created: `~/build/llvm-amdgpu-wsl2`

### Copilot agent instructions file
Created: `.github/copilot-instructions.md` in the repo with LLVM-specific build/test guidance.

## Windows/dual-boot planning (important mapping)
User has two physical 2TB NVMe disks (same model), so must identify by serial.

From Windows PowerShell:
- `Get-Partition | Select DiskNumber,PartitionNumber,DriveLetter,Size | Sort DiskNumber,PartitionNumber`
- Mapping found:
  - Disk 0 contains `C:` (Windows) → serial ends with `...4998`
  - Disk 1 contains `D:` (data) → serial ends with `...A451`

Thus for Ubuntu install:
- **Do not touch** disk serial `...4998` (Windows)
- Install Ubuntu on disk serial `...A451`

The ~16MB partitions shown in Windows are MSR (Microsoft Reserved Partition), normal.

## Moving WSL distro off D: (export/import)
User wanted D fully free for native Ubuntu.

Used workflow (per distro):
1. `wsl --shutdown`
2. `wsl --export <DistroName> C:\wsl-backup\<DistroName>.tar`
3. `wsl --unregister <DistroName>` (destructive to original instance)
4. `wsl --import <DistroName> C:\WSL\<DistroName> C:\wsl-backup\<DistroName>.tar --version 2`
5. Fix default user if needed via `/etc/wsl.conf`.

WSL distros present at the time:
- `Ubuntu-24.04`
- `docker-desktop` (left alone)

## Native Ubuntu 24.04 install plan (onto D disk)
User chose “never worry about partition sizing” → single big root.

Partitioning on **disk serial ...A451**:
- EFI: 1GB FAT32 mounted at `/boot/efi` (flag `esp`)
- Root: rest of disk ext4 mounted at `/`

Tip: In Ubuntu live USB, map disk by serial:
- `sudo nvme list`
- or `lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINTS`

## WSL2 build: LLVM+AMDGPU “full-stack via artifacts”
Purpose: build tools to debug AMDGPU backend and run lit/FileCheck tests without needing ROCm runtime.

### Installed prerequisites (WSL2 Ubuntu 24.04)
```bash
sudo apt update
sudo apt install -y \
  cmake ninja-build build-essential \
  python3 python3-venv python3-pip git \
  zlib1g-dev libzstd-dev libxml2-dev libedit-dev libncurses-dev
```

Tool versions captured:
- Ubuntu 24.04.3 LTS
- cmake 3.28.3
- ninja 1.11.1
- python 3.12.3
- g++ 13.3.0

### Configure (out-of-tree)
Build directory:
- `~/build/llvm-amdgpu-wsl2`

Configure command:
```bash
cmake -S ~/llvm-project/llvm -B ~/build/llvm-amdgpu-wsl2 -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS="clang;mlir" \
  -DLLVM_TARGETS_TO_BUILD="AMDGPU;X86" \
  -DLLVM_ENABLE_RTTI=OFF \
  -DLLVM_ENABLE_EH=OFF
```

Key cache values verified in `~/build/llvm-amdgpu-wsl2/CMakeCache.txt`:
- `CMAKE_BUILD_TYPE=RelWithDebInfo`
- `LLVM_ENABLE_ASSERTIONS=ON`
- `LLVM_ENABLE_EH=OFF`
- `LLVM_ENABLE_PROJECTS=clang;mlir`
- `LLVM_ENABLE_RTTI=OFF`
- `LLVM_TARGETS_TO_BUILD=AMDGPU;X86`
- `CMAKE_GENERATOR=Ninja`

### Build (conservative parallelism)
`llvm-lit` is a script in `bin/` and not always a Ninja target, so build the tools explicitly.

```bash
ninja -C ~/build/llvm-amdgpu-wsl2 -j 8 llc opt FileCheck mlir-opt
```

Tools confirmed present:
- `~/build/llvm-amdgpu-wsl2/bin/llc`
- `~/build/llvm-amdgpu-wsl2/bin/opt`
- `~/build/llvm-amdgpu-wsl2/bin/FileCheck`
- `~/build/llvm-amdgpu-wsl2/bin/mlir-opt`
- `~/build/llvm-amdgpu-wsl2/bin/llvm-lit`

LLVM version reported: `22.0.0git`.

## Documentation created
- Tutorial: `/home/oldzhu/build/llvm-amdgpu-wsl2/tutorial/README.md`
  - Contains the WSL2 build steps, rationale, and basic “IR→MIR→asm + lit” workflow.

## Next actions (recommended)
In WSL2 (no ROCm runtime needed):
1. Pick an AMDGPU lit test and run it:
   - `~/build/llvm-amdgpu-wsl2/bin/llvm-lit -v ~/llvm-project/llvm/test/CodeGen/AMDGPU/<test>.ll`
2. Inspect codegen:
   - `~/build/llvm-amdgpu-wsl2/bin/llc -march=amdgcn -mcpu=gfx1151 -O3 <test.ll> -o - | head`
3. MIR drill:
   - `~/build/llvm-amdgpu-wsl2/bin/llc -march=amdgcn -mcpu=gfx1151 -O3 -stop-after=finalize-isel <test.ll> -o - | head`
4. When modifying/adding AMDGPU tests, use update scripts (commonly `llvm/utils/update_llc_test_checks.py`).

On native Ubuntu + ROCm later:
- Enable real kernel execution/profiling (rocminfo, rocprof/omniperf) and begin Triton runtime + perf work.

## Notes
- We discussed a longer-term contribution plan: monitoring issues in LLVM/MLIR/Triton, starting with tests-first patches, then small backend fixes, then cross-stack debugging and performance.
- There was also a question about enabling “Claude Haiku 4.5” in VS Code; this assistant cannot toggle that setting.
