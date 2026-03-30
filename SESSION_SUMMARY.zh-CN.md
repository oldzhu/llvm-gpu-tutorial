# 会话总结（交接）— LLVM+AMDGPU 练习环境

[English](SESSION_SUMMARY.md)

这个文件总结了当前聊天/工作进展，方便复制到新的工作区或新会话中继续使用。

## 目标

围绕 Triton/AMDGPU 编译器岗位需要的能力进行练习与学习，重点包括：

- LLVM AMDGPU 后端调试与修复
- MLIR GPU lowering / pass
- Triton AMD 后端（之后在有 ROCm 运行时时再做）
- Profiling / 性能分析（需要原生 Linux + ROCm）

## 已发现的关键限制

- 当前在 WSL2 中，用户的硬件（Ryzen AI MAX+ 395 / Radeon 8060S）没有可靠的 ROCm/GPU 运行时路径，这与 ROCm/ROCm#4952 的结论一致。
- 因此在 WSL2 中聚焦于**编译/代码生成 + 测试**（“通过工件走完整链路”），后续在**原生 Ubuntu + ROCm** 环境中再做内核执行和性能分析。

## 仓库 / 工作区状态

工作区包含：

- `~/llvm-project`（llvm-project 单体仓库）
- 已创建的 out-of-tree 构建目录：`~/build/llvm-amdgpu-wsl2`

### Copilot 代理说明文件

已在仓库中创建 `.github/copilot-instructions.md`，包含 LLVM 相关的构建/测试指导。

## Windows / 双系统规划（重要映射）

用户有两块实体 2TB NVMe（同型号），因此必须按序列号识别。

在 Windows PowerShell 中使用：

- `Get-Partition | Select DiskNumber,PartitionNumber,DriveLetter,Size | Sort DiskNumber,PartitionNumber`

得到的映射为：

- Disk 0 包含 `C:`（Windows）→ 序列号结尾 `...4998`
- Disk 1 包含 `D:`（数据盘）→ 序列号结尾 `...A451`

因此安装 Ubuntu 时：

- **不要动**序列号为 `...4998` 的磁盘（Windows）
- 将 Ubuntu 安装到序列号为 `...A451` 的磁盘

Windows 中看到的约 16MB 分区是正常的 MSR（Microsoft Reserved Partition）。

## 将 WSL 发行版从 D 盘迁走（export/import）

用户希望把 D 盘完全腾出来给原生 Ubuntu。

当时使用的流程（每个发行版）：

1. `wsl --shutdown`
2. `wsl --export <DistroName> C:\wsl-backup\<DistroName>.tar`
3. `wsl --unregister <DistroName>`（会销毁原实例）
4. `wsl --import <DistroName> C:\WSL\<DistroName> C:\wsl-backup\<DistroName>.tar --version 2`
5. 如有需要，通过 `/etc/wsl.conf` 修复默认用户。

当时存在的 WSL 发行版：

- `Ubuntu-24.04`
- `docker-desktop`（未处理）

## 原生 Ubuntu 24.04 安装计划（安装到 D 盘所在磁盘）

用户选择“以后都不用担心分区大小”的方案，因此采用单个大根分区。

在**序列号 ...A451** 的磁盘上分区：

- EFI：1GB FAT32，挂载到 `/boot/efi`（带 `esp` 标记）
- Root：其余全部空间 ext4，挂载到 `/`

在 Ubuntu live USB 中通过序列号确认磁盘：

- `sudo nvme list`
- 或 `lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINTS`

## WSL2 构建：LLVM+AMDGPU “通过工件走完整链路”

目的：在不依赖 ROCm 运行时的前提下，构建可用于调试 AMDGPU 后端并运行 lit/FileCheck 测试的工具。

### 已安装前置依赖（WSL2 Ubuntu 24.04）

```bash
sudo apt update
sudo apt install -y \
  cmake ninja-build build-essential \
  python3 python3-venv python3-pip git \
  zlib1g-dev libzstd-dev libxml2-dev libedit-dev libncurses-dev
```

记录到的工具版本：

- Ubuntu 24.04.3 LTS
- cmake 3.28.3
- ninja 1.11.1
- python 3.12.3
- g++ 13.3.0

### 配置（out-of-tree）

构建目录：

- `~/build/llvm-amdgpu-wsl2`

配置命令：

```bash
cmake -S ~/llvm-project/llvm -B ~/build/llvm-amdgpu-wsl2 -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS="clang;mlir" \
  -DLLVM_TARGETS_TO_BUILD="AMDGPU;X86" \
  -DLLVM_ENABLE_RTTI=OFF \
  -DLLVM_ENABLE_EH=OFF
```

在 `~/build/llvm-amdgpu-wsl2/CMakeCache.txt` 中确认的关键缓存项：

- `CMAKE_BUILD_TYPE=RelWithDebInfo`
- `LLVM_ENABLE_ASSERTIONS=ON`
- `LLVM_ENABLE_EH=OFF`
- `LLVM_ENABLE_PROJECTS=clang;mlir`
- `LLVM_ENABLE_RTTI=OFF`
- `LLVM_TARGETS_TO_BUILD=AMDGPU;X86`
- `CMAKE_GENERATOR=Ninja`

### 构建（保守并行度）

`llvm-lit` 是 `bin/` 下的脚本，不一定对应一个叫 `llvm-lit` 的 Ninja target，因此需要显式构建所需工具。

```bash
ninja -C ~/build/llvm-amdgpu-wsl2 -j 8 llc opt FileCheck mlir-opt
```

确认存在的工具：

- `~/build/llvm-amdgpu-wsl2/bin/llc`
- `~/build/llvm-amdgpu-wsl2/bin/opt`
- `~/build/llvm-amdgpu-wsl2/bin/FileCheck`
- `~/build/llvm-amdgpu-wsl2/bin/mlir-opt`
- `~/build/llvm-amdgpu-wsl2/bin/llvm-lit`

LLVM 版本输出为：`22.0.0git`。

## 已创建文档

- 教程：`/home/oldzhu/build/llvm-amdgpu-wsl2/tutorial/README.md`
  - 包含 WSL2 构建步骤、背景解释，以及基础的 “IR→MIR→asm + lit” 工作流。

## 建议的下一步动作

在 WSL2 中（不需要 ROCm 运行时）：

1. 选择一个 AMDGPU lit 测试并运行：
   - `~/build/llvm-amdgpu-wsl2/bin/llvm-lit -v ~/llvm-project/llvm/test/CodeGen/AMDGPU/<test>.ll`
2. 检查代码生成：
   - `~/build/llvm-amdgpu-wsl2/bin/llc -march=amdgcn -mcpu=gfx1151 -O3 <test.ll> -o - | head`
3. 做 MIR 练习：
   - `~/build/llvm-amdgpu-wsl2/bin/llc -march=amdgcn -mcpu=gfx1151 -O3 -stop-after=finalize-isel <test.ll> -o - | head`
4. 修改/新增 AMDGPU 测试时，使用更新脚本（通常是 `llvm/utils/update_llc_test_checks.py`）。

之后在原生 Ubuntu + ROCm 环境中：

- 开启真实内核执行与性能分析（rocminfo、rocprof/omniperf），并开始做 Triton 运行时与性能相关工作。

## 备注

- 我们讨论过一个更长期的贡献计划：关注 LLVM/MLIR/Triton 中的问题，从 tests-first patch 开始，再到小型后端修复，最终做跨栈调试和性能分析。
- 还讨论过如何在 VS Code 中启用 “Claude Haiku 4.5”；这个助手无法直接切换该设置。