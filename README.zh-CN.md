# LLVM GPU 教程（多目标）

[English](README.md)

这个仓库记录了在 WSL2 中实践 LLVM GPU 后端开发的工作流，重点是**到代码生成工件为止**的完整链路（IR → 汇编 / 对象文件），以及 **lit/FileCheck** 测试。

> WSL2 限制：通常无法直接运行 GPU kernel 或 profiler。本仓库聚焦你现在就能做的部分：编译器 / 代码生成 / 回归测试。

## 目标

- AMDGPU：见 `amdgpu/`（以 gfx1151 为重点）
- NVIDIA：见 `nvidia/`（以 NVPTX / PTX 为重点）

## 构建矩阵

- 参见 `BUILD_MATRIX.md`，了解每个目标应使用哪个 out-of-tree 构建目录。

## 你会得到什么（AMDGPU 构建）

- 一个本地 out-of-tree LLVM 构建：
  - Targets: `AMDGPU;X86`
  - Projects: `clang;mlir`
- 位于 `~/build/llvm-amdgpu-wsl2/bin/` 的工具：
  - `llc`, `opt`, `FileCheck`, `llvm-lit`, `mlir-opt`
  - （通常也有用）`clang`, `mlir-translate`, `llvm-dis`, `llvm-as`, `llvm-link`

## 你会得到什么（NVIDIA 构建）

- 一个单独的 out-of-tree LLVM 构建：
  - Targets: `NVPTX;X86`
  - Projects: `clang;mlir`
- 位于 `~/build/llvm-nvptx-wsl2/bin/` 的工具：
  - `clang`, `clang++`, `llc`, `llvm-readobj`（以及你额外构建的 lit 辅助工具）

## 附加教程

- AMDGPU 端到端编译流程：`amdgpu/frontend-to-amdgpu.md`
- NVIDIA 端到端编译流程：`nvidia/frontend-to-nvidia.md`

## 当前机器版本

- OS: Ubuntu 24.04.3 LTS (WSL2)
- cmake: 3.28.3
- ninja: 1.11.1
- python: 3.12.3
- compiler: g++ 13.3.0
- LLVM: 22.0.0git（来自本地 `llvm-project`）

## 仓库路径假设

- LLVM monorepo：`~/llvm-project`
- AMDGPU 构建目录（out-of-tree）：`~/build/llvm-amdgpu-wsl2`
- NVIDIA 构建目录（out-of-tree）：`~/build/llvm-nvptx-wsl2`

如果你的路径不同，请自行调整。

---

## 1）安装构建前置依赖（WSL2）

```bash
sudo apt update
sudo apt install -y \
  cmake ninja-build build-essential \
  python3 python3-venv python3-pip \
  git \
  zlib1g-dev libzstd-dev libxml2-dev libedit-dev libncurses-dev
```

说明：

- 这是配置和构建核心 LLVM / MLIR 工具所需的最小依赖集合。
- 之后可以再按需要增加其它组件（如 lld、libc++ 等）。

---

## 2）配置一个面向 AMDGPU 的 out-of-tree 构建

先创建构建目录：

```bash
mkdir -p ~/build/llvm-amdgpu-wsl2
```

使用 CMake + Ninja 配置：

```bash
cmake -S ~/llvm-project/llvm -B ~/build/llvm-amdgpu-wsl2 -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS="clang;mlir" \
  -DLLVM_TARGETS_TO_BUILD="AMDGPU;X86" \
  -DLLVM_ENABLE_RTTI=OFF \
  -DLLVM_ENABLE_EH=OFF
```

关键参数说明：

- `-G Ninja`：增量构建快，是 LLVM 开发中常见选择。
- `RelWithDebInfo`：既有优化也保留调试信息，适合开发。
- `LLVM_ENABLE_ASSERTIONS=ON`：能更早暴露很多问题。
- `LLVM_ENABLE_PROJECTS="clang;mlir"`：同时构建 Clang 与 MLIR。
- `LLVM_TARGETS_TO_BUILD="AMDGPU;X86"`：缩小构建范围，但保留 AMDGPU 目标。
- `LLVM_ENABLE_RTTI/EH=OFF`：更接近 LLVM 常见配置，也更小更快。

后续可用以下命令确认配置：

```bash
grep -E '^(CMAKE_BUILD_TYPE:|LLVM_ENABLE_PROJECTS:|LLVM_TARGETS_TO_BUILD:|LLVM_ENABLE_ASSERTIONS:|LLVM_ENABLE_RTTI:|LLVM_ENABLE_EH:)' \
  ~/build/llvm-amdgpu-wsl2/CMakeCache.txt
```

---

## 2b）配置一个面向 NVIDIA / NVPTX 的 out-of-tree 构建

这个构建目录与 AMDGPU 分开，避免相互影响。

先创建构建目录：

```bash
mkdir -p ~/build/llvm-nvptx-wsl2
```

使用 CMake + Ninja 配置：

```bash
cmake -S ~/llvm-project/llvm -B ~/build/llvm-nvptx-wsl2 -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS="clang;mlir" \
  -DLLVM_TARGETS_TO_BUILD="NVPTX;X86" \
  -DLLVM_ENABLE_RTTI=OFF \
  -DLLVM_ENABLE_EH=OFF
```

说明：

- `NVPTX` 是 LLVM 中用来生成 NVIDIA PTX 的后端。
- 这个构建足以覆盖 “C/C++/LLVM IR → PTX” 工作流。若要生成可运行 cubin 并实际执行 kernel，通常还需要 NVIDIA driver / CUDA toolkit。

后续可用以下命令确认配置：

```bash
grep -E '^(CMAKE_BUILD_TYPE:|LLVM_ENABLE_PROJECTS:|LLVM_TARGETS_TO_BUILD:|LLVM_ENABLE_ASSERTIONS:|LLVM_ENABLE_RTTI:|LLVM_ENABLE_EH:)' \
  ~/build/llvm-nvptx-wsl2/CMakeCache.txt
```

## 3）构建你需要的最小工具集

在 WSL2 中，通常需要降低并行度来避免内存峰值过高。

```bash
ninja -C ~/build/llvm-amdgpu-wsl2 -j 8 \
  llc opt FileCheck mlir-opt
```

要稳定运行 `llvm-lit`，通常还需要额外构建一些小工具，因为 lit 会把它们当作 substitution 使用（否则可能一开始就因找不到 `count/not/llvm-config` 之类的工具而失败）：

```bash
ninja -C ~/build/llvm-amdgpu-wsl2 -j 8 \
  llvm-config \
  not count
```

有些 AMDGPU 测试还需要 `llvm-readobj`：

```bash
ninja -C ~/build/llvm-amdgpu-wsl2 -j 8 llvm-readobj
```

对于 NVIDIA / NVPTX，PTX 工作流所需的最小工具集是：

```bash
ninja -C ~/build/llvm-nvptx-wsl2 -j 8 \
  clang clang++ llc llvm-readobj
```

如果也想在这个构建目录里运行 `llvm-lit`，可以再构建：

```bash
ninja -C ~/build/llvm-nvptx-wsl2 -j 8 \
  FileCheck not count
```

关于 `llvm-lit` 的一个重要说明：

- `llvm-lit` 通常是 `~/build/llvm-amdgpu-wsl2/bin/llvm-lit` 下的**脚本**。
- 它**不一定**对应名为 `llvm-lit` 的 Ninja target。

构建后可验证：

```bash
~/build/llvm-amdgpu-wsl2/bin/llc --version
~/build/llvm-amdgpu-wsl2/bin/opt --version
~/build/llvm-amdgpu-wsl2/bin/FileCheck --version
~/build/llvm-amdgpu-wsl2/bin/mlir-opt --version
~/build/llvm-amdgpu-wsl2/bin/llvm-lit --version
```

---

## 4）你的第一个“通过工件走完整链路”的练习（不需要 GPU）

目标是在每一层都能看到输出，从而调试 / 验证整条管线。

### A）LLVM IR → AMDGPU 汇编（代码生成）

先挑一个 AMDGPU 测试：

```bash
ls ~/llvm-project/llvm/test/CodeGen/AMDGPU | head
```

用 `llc` 对指定 AMD GPU 目标做代码生成。对较新的 AMD GPU，通常会使用 `-march=amdgcn` 配合 `-mcpu=gfx*`。

示例（根据需要调整 `gfx1151`）：

```bash
~/build/llvm-amdgpu-wsl2/bin/llc \
  -march=amdgcn -mcpu=gfx1151 -O3 \
  ~/llvm-project/llvm/test/CodeGen/AMDGPU/<test>.ll \
  -o - | head -n 80
```

### B）LLVM IR → MIR（后端调试）

MIR 对 AMDGPU 后端调试非常关键。

```bash
~/build/llvm-amdgpu-wsl2/bin/llc \
  -march=amdgcn -mcpu=gfx1151 -O3 \
  -stop-after=finalize-isel \
  ~/llvm-project/llvm/test/CodeGen/AMDGPU/<test>.ll \
  -o - | head -n 120
```

### C）运行单个 lit 测试

```bash
~/build/llvm-amdgpu-wsl2/bin/llvm-lit -v \
  ~/llvm-project/llvm/test/CodeGen/AMDGPU/<test>.ll
```

---

## 已实践的示例（我们真正执行过的命令）

这一节使用了 `llvm/test/CodeGen/AMDGPU` 中两个真实 AMDGPU 测试文件。
它们体积小、运行快，并且很适合作为 gfx1151 的练习目标。

### 示例 1：`directive-amdgcn-target.ll`（汇编 directive + kernel 元数据）

测试文件：

```text
~/llvm-project/llvm/test/CodeGen/AMDGPU/directive-amdgcn-target.ll
```

#### 1）使用 `llvm-lit` 运行测试

```bash
~/build/llvm-amdgpu-wsl2/bin/llvm-lit -v \
  ~/llvm-project/llvm/test/CodeGen/AMDGPU/directive-amdgcn-target.ll
```

这条命令的作用：

- `llvm-lit` 会读取测试文件并执行每一条 `; RUN: ...`。
- 每条 `RUN:` 的输出会被管道传给 `FileCheck`，并使用指定的 `--check-prefixes=...`。
- 只要所有命令都成功退出，且 `FileCheck` 能匹配到预期模式，测试就会通过。

这个测试本身的工作方式：

- 文件里有许多带不同 `-mcpu=` 值的 `RUN:` 行。
- 对于每个 `-mcpu`，测试都会检查 `llc` 是否发出了匹配该架构的 `.amdgcn_target` 字符串（对 HSA 目标还会检查 kernel metadata）。

#### 2）直接用 `llc` 手工复现一个 case（gfx1151）

这就是某一条 `RUN:` 的“手工版”。

```bash
~/build/llvm-amdgpu-wsl2/bin/llc \
  -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1151 -O3 \
  < ~/llvm-project/llvm/test/CodeGen/AMDGPU/directive-amdgcn-target.ll \
  | head -n 40
```

参数说明：

- `-mtriple=amdgcn-amd-amdhsa`：选择 AMDGPU 的 GCN 后端以及 HSA ABI。
- `-mcpu=gfx1151`：选择具体的子目标。
- `-O3`：开启优化，很多后端行为都对优化级别敏感。
- 通过 stdin 输入（`< file.ll`）是为了尽量贴近 lit 的常见执行方式。
- `head` 只是为了在迭代时让输出保持简短。

如果一切正常，输出开头附近应当能看到：

- `.amdgcn_target "amdgcn-amd-amdhsa--gfx1151"`
- `.amdhsa_code_object_version ...`
- `.amdhsa_kernel ...` 元数据块

#### 3）停在一个 MIR 检查点（`-stop-after=finalize-isel`）

这是“后端调试版”：输出不再是汇编，而是 MIR dump。

```bash
~/build/llvm-amdgpu-wsl2/bin/llc \
  -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1151 -O3 \
  -stop-after=finalize-isel \
  -verify-machineinstrs \
  < ~/llvm-project/llvm/test/CodeGen/AMDGPU/directive-amdgcn-target.ll \
  | head -n 120
```

这条命令的作用：

- `-stop-after=finalize-isel`：在 instruction selection 完成后停止，并打印 MIR。
- `-verify-machineinstrs`：运行 machine verifier；如果你在改 Machine IR 时破坏了某个不变量，它通常能较早地报出来。

为什么 MIR 有帮助：

- AMDGPU 后端的大多数调试都发生在 MIR 层（isel、regalloc、scheduling、pseudo expansion 等）。
- 你可以比较两个构建（修改前 / 修改后）的 MIR，定位最早开始出现行为分歧的 pass。

### 示例 2：`elf-header-flags-mach.ll`（对象文件输出 + llvm-readobj）

测试文件：

```text
~/llvm-project/llvm/test/CodeGen/AMDGPU/elf-header-flags-mach.ll
```

#### 1）使用 `llvm-lit` 运行测试

```bash
~/build/llvm-amdgpu-wsl2/bin/llvm-lit -v \
  ~/llvm-project/llvm/test/CodeGen/AMDGPU/elf-header-flags-mach.ll
```

这个测试的工作方式：

- 每条 `RUN:` 都会让 `llc` 把对象文件输出到 stdout（`-filetype=obj`），然后将其管道给：
  `llvm-readobj --file-header -`。
- 最终由 `FileCheck` 匹配打印出来的 ELF header 和 flags。

#### 2）手工复现 gfx1151 对应的 `RUN:` 行

```bash
~/build/llvm-amdgpu-wsl2/bin/llc \
  -filetype=obj -mtriple=amdgcn -mcpu=gfx1151 \
  < ~/llvm-project/llvm/test/CodeGen/AMDGPU/elf-header-flags-mach.ll \
  | ~/build/llvm-amdgpu-wsl2/bin/llvm-readobj --file-header - \
  | head -n 80
```

重点关注：

- `Format: elf64-amdgpu`
- `Arch: amdgcn`
- `Flags [` 块中是否包含预期的 `EF_AMDGPU_MACH_*` 值

---

## lit + FileCheck 是怎么配合工作的（心智模型）

- `llvm-lit` 是测试运行器。它会：
  1. 发现测试文件；
  2. 执行 `RUN:` 行中的命令；
  3. 报告 PASS / FAIL。
- `FileCheck` 是模式匹配器。它会读取工具输出（通常来自管道），并与测试文件中的 `; CHECK:` 指令做匹配。
- `--check-prefixes=A,B` 用来选择哪些检查行生效（例如 `A:`、`B:`）。一个测试文件里经常用它来同时覆盖多个 GPU / target。

实用调试建议：

- 如果 `llvm-lit` 失败，先把失败的 `RUN:` 行复制出来直接在 shell 里运行。这是最快的迭代方式。
- 手工复现命令要尽量贴近原始 `RUN:` 行（相同的 `-mtriple`、`-mcpu`、`-mattr`、`-O*` 等）。
- 做后端调试时，加入 `-stop-after=<pass>`（或 `-stop-before=<pass>`）以及 `-verify-machineinstrs`，更容易尽早发现问题。

---

## 5）更新 `FileCheck` 行（常见工作流）

LLVM 中常用脚本来更新输出变化后的 `CHECK:` 行。

- 脚本：`~/llvm-project/llvm/utils/update_llc_test_checks.py`

典型流程：

1. 编辑 / 精简 `.ll` 测试。
2. 运行更新脚本。
3. 再对该测试执行一次 `llvm-lit`。

---

## 6）故障排查

### 配置成功了，但 `build.ninja` 不见了

重新执行 configure：

```bash
cmake -S ~/llvm-project/llvm -B ~/build/llvm-amdgpu-wsl2 -G Ninja <same flags>
```

### WSL2 构建会话容易挂掉 / 不稳定

- 降低 `-j`（例如 `-j 8` 或 `-j 4`）。
- 优先使用 `RelWithDebInfo` 而不是完整的 `Debug`（构建体积更小）。

### `ninja: unknown target 'llvm-lit'`

这有时是正常现象。直接使用脚本：

```bash
~/build/llvm-amdgpu-wsl2/bin/llvm-lit --version
```

### `llvm-lit` 因缺少工具而 fatal（例如 `count`、`not`、`llvm-config`）

如果 `llvm-lit` 因为 `~/build/llvm-amdgpu-wsl2/bin` 中缺少某些工具而报 fatal “Did not find ...”，就用 Ninja 构建缺少的工具（见第 3 节）。

注意：`llvm-lit` 也可能打印很多 “note: Did not find <tool> ...”。
这些通常**不是致命错误**，除非你正在运行的那个测试确实需要该工具。

快速判断规则：

- 如果测试最后显示 `PASS`，那么这些 “note: Did not find ...” 可以忽略。
- 如果测试失败并伴随 `fatal:` / “Could not run process ...” / “not found”，就把失败的 `RUN:` 行复制出来，并使用：
  `ninja -C ~/build/llvm-amdgpu-wsl2 <tool>`
  去构建缺失工具。

---

## 下一步（等原生 Ubuntu + ROCm 环境就绪后）

- 在真实 GPU 上验证 kernel 执行（Triton / HIP）。
- 使用 ROCm 工具做性能分析，并把性能瓶颈回溯到：
  - MLIR lowering 模式
  - LLVM AMDGPU instruction selection / scheduling
  - 生成出的 ISA