# Project Guidelines

## Scope

This repository is a multi-target LLVM GPU tutorial repo.
It contains documentation and small reproducible examples for:

- AMDGPU under `amdgpu/`
- NVIDIA NVPTX/PTX under `nvidia/`

Treat this repo as documentation-first: prefer small, runnable examples and concise explanations over large code additions.

## Build And Test

Agents should prefer the documented out-of-tree LLVM builds instead of changing build settings in this repo.

- AMDGPU build dir: `~/build/llvm-amdgpu-wsl2`
- NVIDIA/NVPTX build dir: `~/build/llvm-nvptx-wsl2`
- Root overview: `README.md`
- Per-target quick reference: `BUILD_MATRIX.md`

Common validation commands:

- AMDGPU example regeneration: `amdgpu/examples/regen_outputs.sh`
- NVIDIA example regeneration: `nvidia/examples/regen_outputs.sh`
- LLVM lit tests should be run from the external LLVM build tree, not from this repo.

This repo is WSL2 compile-only by default. Prefer generating IR, asm, PTX, ELF headers, and other artifacts. Do not assume ROCm or CUDA runtime execution is available.

## Structure

- `README.md`: top-level workflow and setup
- `BUILD_MATRIX.md`: maps target -> build dir -> outputs
- `amdgpu/`: AMDGPU walkthroughs and examples
- `nvidia/`: NVIDIA/NVPTX walkthroughs and examples

Generated artifacts belong under each target's `examples/outputs/` directory and should remain ignored by git.

## Documentation Conventions

Follow the existing pattern of linking to detailed docs instead of duplicating long explanations.

Every maintained project document must have both English and Chinese versions.

- Default English document keeps the base name, for example `README.md` or `frontend-to-amdgpu.md`.
- Chinese companion should use the same base name with `.zh-CN.md`, for example `README.zh-CN.md` or `frontend-to-amdgpu.zh-CN.md`.
- Each English document should link to its Chinese companion near the top.
- Each Chinese document should link back to its English companion near the top.
- When updating an existing document, update both language versions in the same change when practical.
- If only one language version exists today, treat that as documentation debt and prefer adding the missing companion when you touch that document.

Keep translations aligned in structure and meaning. Do not let one version drift into a different tutorial.

## Content Style

Prefer:

- short runnable command blocks
- real file paths used in this environment
- small sample outputs that show what success looks like
- explicit notes about target-specific limitations or required toolchains

Avoid:

- promising GPU runtime execution in WSL2
- committing generated outputs
- embedding large duplicated setup text when `README.md`, `BUILD_MATRIX.md`, or target-specific docs already cover it

## Examples And Scripts

Keep example source files minimal and focused on one teaching point.
Keep regen scripts path-robust and allow overriding tool locations with environment variables when possible.