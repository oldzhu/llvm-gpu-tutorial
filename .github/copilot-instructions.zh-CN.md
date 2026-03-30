# 项目指南

[English](copilot-instructions.md)

## 适用范围

这个仓库是一个多目标 LLVM GPU 教程仓库。
它包含文档和小型、可复现的示例，主要覆盖：

- `amdgpu/` 下的 AMDGPU
- `nvidia/` 下的 NVIDIA NVPTX / PTX

把这个仓库视为“文档优先”仓库：优先添加小而可运行的示例和简洁说明，而不是大规模代码扩展。

## 构建与测试

代理在这里工作时，应优先使用文档中已经定义好的 out-of-tree LLVM 构建，而不是修改本仓库自己的构建设置。

- AMDGPU 构建目录：`~/build/llvm-amdgpu-wsl2`
- NVIDIA / NVPTX 构建目录：`~/build/llvm-nvptx-wsl2`
- 根说明文档：`README.md`
- 按目标划分的快速参考：`BUILD_MATRIX.md`

常用验证命令：

- AMDGPU 示例重生成：`amdgpu/examples/regen_outputs.sh`
- NVIDIA 示例重生成：`nvidia/examples/regen_outputs.sh`
- LLVM lit 测试应当在外部 LLVM 构建目录中运行，而不是在本仓库中运行。

这个仓库默认是 WSL2 下的“仅编译”工作流。优先生成 IR、汇编、PTX、ELF 头信息等工件，不要默认假设 ROCm 或 CUDA 运行时可用。

## 目录结构

- `README.md`：顶层工作流与环境搭建说明
- `BUILD_MATRIX.md`：目标 → 构建目录 → 产物 的映射
- `amdgpu/`：AMDGPU 教程与示例
- `nvidia/`：NVIDIA / NVPTX 教程与示例

生成产物应放在各目标自己的 `examples/outputs/` 目录下，并继续保持被 git 忽略。

## 文档约定

遵循现有模式：尽量链接到详细文档，而不是在多个地方重复大段说明。

每一份持续维护的项目文档都必须同时有英文版和中文版。

- 默认英文文档保留原始文件名，例如 `README.md` 或 `frontend-to-amdgpu.md`。
- 中文配套文档使用同名加 `.zh-CN.md`，例如 `README.zh-CN.md` 或 `frontend-to-amdgpu.zh-CN.md`。
- 每个英文文档都应在靠前位置链接到对应的中文文档。
- 每个中文文档也应在靠前位置链接回英文文档。
- 更新现有文档时，如果可行，应在同一次修改中同步更新两个语言版本。
- 如果当前只有单语版本，应把缺失的语言版本视为文档债务；当你改动该文档时，应优先补齐。

中英文版本的结构和含义要保持一致，不要让两个版本各自演化成不同的教程。

## 内容风格

优先采用：

- 简短且可直接运行的命令块
- 本环境中的真实路径
- 少量但有代表性的示例输出，帮助读者快速判断是否成功
- 明确写出目标相关限制和必要工具链

避免：

- 在 WSL2 中承诺可以直接跑 GPU runtime
- 提交生成产物
- 当 `README.md`、`BUILD_MATRIX.md` 或目标专属文档已经解释过时，再重复嵌入大段 setup 文本

## 示例与脚本

示例源文件应尽量小、尽量聚焦，只讲清楚一个教学点。
重生成脚本应尽量具备路径鲁棒性，并在可能时允许通过环境变量覆盖工具路径。