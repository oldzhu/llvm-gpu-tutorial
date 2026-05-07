# AMDGPU 入门 patch 思路

[English](next-practice-patches.md)

这个文件列出了一些适合当前 WSL2 “仅编译”环境的小型 LLVM / AMDGPU 练习任务。

## 1. ~~调查 `directive-amdgcn-target.ll` 的源码 / 构建不一致问题~~（已解决）

~~在完整重建后，之前观察到的失败已不复存在。~~

`gfx1170` 问题是一个 stale-build 问题，而不是后端支持缺失。在 `cmake` 重新配置并完整重建 `llc` 之后，`directive-amdgcn-target.ll` 现已干净通过：

```text
PASS: LLVM :: CodeGen/AMDGPU/directive-amdgcn-target.ll
Passed: 1 (100.00%)
```

核心经验：当 `llc -march=amdgcn -mcpu=help` 列表中缺失了你在源码里已经看到的某个 target 时，优先怀疑是生成文件过期，做一个完整重建。

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

1. ~~先手工复现当前 `directive-amdgcn-target.ll` 的失败。~~（已完成）
2. ~~验证源码 / 构建不一致（源码里有 `gfx1170`，但已构建的 `llc` 里没有）。~~（已完成）
3. ~~找到能可靠刷新 AMDGPU 生成文件的最小重建路径。~~（已完成：执行 `cmake` 重新配置 + `ninja llc`）
4. 做一个 `llvm/test/CodeGen/AMDGPU/` 下的小型 tests-first 改进。（下一步）
