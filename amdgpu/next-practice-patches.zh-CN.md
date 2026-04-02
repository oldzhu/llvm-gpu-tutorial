# AMDGPU 入门 patch 思路

[English](next-practice-patches.md)

这个文件列出了一些适合当前 WSL2 “仅编译”环境的小型 LLVM / AMDGPU 练习任务。

## 1. 调查 `directive-amdgcn-target.ll` 的源码 / 构建不一致问题

当前这个构建中观察到的现象：

```text
'gfx1170' is not a recognized processor for this target (ignoring processor)
error: GFX1170: expected string not found in input
```

目前已经知道的情况：

- 当前 checkout 的源码树里已经有 `gfx1170`，
- 但当前构建出来的 `llc` 二进制以及 AMDGPU 生成文件里没有它，
- 因此更可能是 AMDGPU 生成产物陈旧，或者源码 / 构建产物不一致。

为什么它适合作为入门任务：

- 范围小，而且很容易复现。
- 它能帮助你理解 AMDGPU 后端是如何识别子目标名字的。
- 你会练到如何对照测试期望与后端的真实支持情况。

在 `llvm-project` 中值得查看的位置：

- `llvm/lib/Target/AMDGPU/`
- `llvm/test/CodeGen/AMDGPU/directive-amdgcn-target.ll`

可能的结论：

- 确认到底是哪些 AMDGPU 生成文件已经过期，
- 找到能正确刷新这些文件的最小重建路径，
- 或者定位为什么当前构建图没有根据更新后的源码重新生成 AMDGPU 输出。

## 2. 增加或收紧一个小型 AMDGPU CodeGen 测试

从 `llvm/test/CodeGen/AMDGPU/` 里挑一个很小的现有测试，然后做下面其中一种改进：

- 把检查收紧到你真正关心的那条指令或元数据上，
- 为 gfx1151 行为增加一条新的 `CHECK:`，
- 或者把一个过于宽泛的测试拆成更小、更聚焦的 case。

为什么这是好的起点：

- 以测试为先通常是最安全的入门方式；
- 你会立刻学会 `llc`、`FileCheck` 和 `update_llc_test_checks.py` 的工作流。

## 3. 比较两个相近子目标，并解释差异

对同一个输入分别运行：

```bash
llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1150 ...
llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1151 ...
```

然后检查：

- target string，
- kernel metadata，
- MIR 差异，
- 最终汇编差异。

这本身不一定直接成为代码 patch，但一旦你发现行为不一致或漏优化，通常就能进一步演化成 patch。

## 4. 给教程示例再加一个更偏 MIR 的 case

在 `amdgpu/examples/` 下再增加一个极简 LLVM IR 示例，让它生成的 MIR 比单个 `s_endpgm` kernel 更有信息量。

合适的候选：

- 一个 load + 一个 store，
- 一个简单的整数加法，
- 一个简单的控制流块。

为什么这有价值：

- 它能直接改进教程仓库，
- 同时也给你一个更可控的后端调试输入。

## 5. 试一个小型 MLIR GPU → ROCDL 测试改进

如果你想做更接近 Triton 的方向，可以从这些位置里挑一个很小的测试开始：

- `mlir/test/Conversion/GPUToROCDL/`
- `mlir/test/Target/LLVMIR/rocdl.mlir`

合适的入门工作：

- 增加一条聚焦的 lowering 检查，
- 明确一个 `CHECK:` 模式，
- 或者补一个最小的新 op 覆盖用例。

## 建议顺序

1. 先手工复现当前 `directive-amdgcn-target.ll` 的失败。
2. 验证源码 / 构建不一致（源码里有 `gfx1170`，但已构建的 `llc` 里没有）。
3. 找到能可靠刷新 AMDGPU 生成文件的最小重建路径。
4. 并行做一个 `llvm/test/CodeGen/AMDGPU/` 下的小型 tests-first 改进。
