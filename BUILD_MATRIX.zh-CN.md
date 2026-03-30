# 构建矩阵（每个 GPU 目标该构建什么）

[English](BUILD_MATRIX.md)

这个仓库是**文档 + 示例**仓库。
建议为不同目标分别做 LLVM 的 out-of-tree 构建，然后让脚本指向对应的 `bin/`。

## 总览

| 目标 | LLVM 构建目录 | `LLVM_TARGETS_TO_BUILD` | 产物（编译器工件） | 主要教程入口 |
|---|---|---|---|---|
| AMDGPU（ROCm/HSA） | `~/build/llvm-amdgpu-wsl2` | `AMDGPU;X86` | AMDGPU 汇编（`.s`）、AMDGPU ELF 对象（`.o`）、ROCDL/LLVM 方言 MLIR | `amdgpu/frontend-to-amdgpu.md` |
| NVIDIA（CUDA/PTX） | `~/build/llvm-nvptx-wsl2` | `NVPTX;X86` | 通过 `llc` 与 `clang -x cuda`（仅 device-only）生成 PTX 文本（`.ptx`） | `nvidia/frontend-to-nvidia.md` |

## AMDGPU 构建（适合 AMD 相关工作）

配置：

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

构建最小工具集：

```bash
ninja -C ~/build/llvm-amdgpu-wsl2 -j 8 \
  llc opt FileCheck mlir-opt llvm-readobj llvm-config not count
```

脚本使用：

- `LLVM_AMDGPU_BIN`（默认指向 `~/build/llvm-amdgpu-wsl2/bin`）

## NVIDIA/NVPTX 构建（适合 NVIDIA 相关工作）

配置：

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

构建最小工具集：

```bash
ninja -C ~/build/llvm-nvptx-wsl2 -j 8 \
  clang clang++ llc llvm-readobj
```

可选（如果也想在这个构建目录里跑 `llvm-lit`）：

```bash
ninja -C ~/build/llvm-nvptx-wsl2 -j 8 FileCheck not count
```

脚本使用：

- `LLVM_NVPTX_BIN`（默认指向 `~/build/llvm-nvptx-wsl2/bin`）

## 为什么要两个构建目录？

- 可以减小构建时间和二进制集合规模。
- 避免在 AMDGPU 和 NVPTX 之间来回重新配置/重建。
- 这也更贴近实际参与特定后端开发时的工作方式。