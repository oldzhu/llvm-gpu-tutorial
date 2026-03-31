# 前端 → LLVM/MLIR → AMDGPU ISA（WSL2 仅编译）

[English](frontend-to-amdgpu.md)

这是一份你可以在当前工作区中直接运行的端到端**编译管线**说明。
它刻意避开 GPU 实际执行（WSL2 中没有可用的 ROCm 运行时）；
重点是看清楚 *IR 形态、lowering 步骤以及代码生成结果*。

## 心智模型（Triton 在哪里）

典型的 Triton / MLIR / LLVM 栈大致如下：

- **Triton（仓库外）**
  - Python + Triton DSL → Triton IR → MLIR（通常通过自定义 dialect）
- **MLIR（本仓库关联的上游能力）**
  - GPU dialect、转换 pass、ROCDL dialect，最后到 LLVM dialect
- **LLVM IR**
  - 目标无关中端（`opt`），然后进入目标后端（`llc`）
- **AMDGPU backend**
  - 指令选择、调度、寄存器分配 → AMDGPU ISA（GCN / RDNA）汇编

在这个教程仓库里，你主要练习的是 MLIR 和 LLVM；Triton 本身并不在 llvm-project 树内。

## 使用的工具（来自你的构建）

下列命令默认假设：

- `BIN=/home/oldzhu/build/llvm-amdgpu-wsl2/bin`
- 示例文件位于 `amdgpu/examples/`

关键工具：

- `clang`：C → LLVM IR（主机端示例）
- `mlir-opt`：运行 MLIR pass（GPU → ROCDL / LLVM dialect）
- `mlir-translate`：MLIR（LLVM dialect）→ 文本 LLVM IR（仅适用于受支持的顶层形态）
- `llc`：LLVM IR → AMDGPU 汇编 / 对象文件

## 一条命令：重新生成全部示例输出

在教程仓库根目录下执行：

```bash
chmod +x amdgpu/examples/regen_outputs.sh
amdgpu/examples/regen_outputs.sh
```

它会生成：

- `amdgpu/examples/outputs/llvm_add_kernel.gfx1151.s`
- `amdgpu/examples/outputs/llvm_add_kernel.gfx1151.o`
- `amdgpu/examples/outputs/llvm_add_kernel.gfx1151.readobj-file-header.txt`
- `amdgpu/examples/outputs/mlir_gpu_ids.rocdl.mlir`
- `amdgpu/examples/outputs/c_vecadd_host.ll`

这些文件都是本地生成工件（见 `.gitignore`）。

## 示例 A：C → LLVM IR（主机端）

这个示例用于演示**前端**以及 LLVM IR 的生成（host triple）。

- 源文件：[amdgpu/examples/c_vecadd_host.c](amdgpu/examples/c_vecadd_host.c)
- 命令：
  - `"$BIN/clang" -O2 -S -emit-llvm amdgpu/examples/c_vecadd_host.c -o - | sed -n '1,40p'`

示例输出片段（开头几行）：

```llvm
; ModuleID = '.../c_vecadd_host.c'
target triple = "x86_64-unknown-linux-gnu"

define dso_local void @vecadd(ptr ...)
```

这还不是 GPU kernel；它只是把“frontend → LLVM IR”这一步具体化。

## 示例 B：LLVM IR kernel → gfx1151 汇编（不需要运行时）

这是最直接的“LLVM → AMDGPU ISA”路径。

- 源文件：[amdgpu/examples/llvm_add_kernel.ll](amdgpu/examples/llvm_add_kernel.ll)
- 生成 AMDGPU 汇编：
  - `"$BIN/llc" -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1151 -O3 amdgpu/examples/llvm_add_kernel.ll -o - | sed -n '1,60p'`

示例输出片段：

```asm
	.amdgcn_target "amdgcn-amd-amdhsa--gfx1151"
	.text
	.globl	vadd_one
vadd_one:
	s_load_b128 s[0:3], s[4:5], 0x0
	...
	s_add_f32 s0, s0, s1
	...
	global_store_b32 v0, v1, s[4:5]
	s_endpgm
```

说明：

- 函数被标记为 `amdgpu_kernel`，因此后端会生成 HSA kernel descriptor 段（`.amdhsa_kernel ...`）。
- 这是做后端工作的好循环：修改 LLVM IR → 重新跑 `llc` → 检查 asm / MIR。

## 示例 C：MLIR GPU → ROCDL / LLVM dialect（仅编译）

这个示例展示的是与 Triton 较接近的“MLIR GPU lowering”部分。

- 源文件：[amdgpu/examples/mlir_gpu_ids.mlir](amdgpu/examples/mlir_gpu_ids.mlir)
- 把 `gpu.thread_id` lower 成 ROCDL + LLVM dialect：
  - `"$BIN/mlir-opt" amdgpu/examples/mlir_gpu_ids.mlir -convert-gpu-to-rocdl='chipset=gfx1151' | sed -n '1,80p'`

示例输出片段：

```mlir
module {
  gpu.module @kernels attributes {llvm.data_layout = "..."} {
    llvm.func @write_tid_x(...) attributes {gpu.kernel, rocdl.kernel} {
      %4 = rocdl.workitem.id.x : i32
      %5 = llvm.sext %4 : i32 to i64
      ...
    }
  }
}
```

重要限制（WSL2）：

- Lower 后的 LLVM dialect 函数仍然嵌套在 `gpu.module` 中。
- 在 MLIR 中，常见的“完整编译”流程还会继续做 GPU host lowering，或者使用 `-gpu-module-to-binary` 生成 HSACO；这些步骤可能需要 ROCm 工具链和 device library。
- 因此在 WSL2 中，更适合把这一步当作“验证 lowering 是否正确、IR 形态是否符合预期”，而真正的“LLVM → ISA”则优先用示例 B。

## 示例 D：在上游 AMDGPU 测试上做真实的 `llc` / MIR 调试循环

这就是你在做 LLVM AMDGPU 后端工作时最常用的实际调试循环。

- 测试文件：`~/llvm-project/llvm/test/CodeGen/AMDGPU/directive-amdgcn-target.ll`
- 目标：即使完整 lit 测试会因为别的子目标失败，也先手工检查一个明确的 gfx1151 case。

### 1）直接生成 gfx1151 汇编

```bash
BIN=/home/oldzhu/build/llvm-amdgpu-wsl2/bin
TEST=~/llvm-project/llvm/test/CodeGen/AMDGPU/directive-amdgcn-target.ll

"$BIN/llc" -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1151 -O3 < "$TEST" | sed -n '1,40p'
```

当前机器上观察到的输出片段：

```asm
  .amdgcn_target "amdgcn-amd-amdhsa--gfx1151"
  .amdhsa_code_object_version 6
  .text
  .globl	directive_amdgcn_target
directive_amdgcn_target:
  s_endpgm
  .section	.rodata,"a",@progbits
  .amdhsa_kernel directive_amdgcn_target
```

这一步的价值：

- 它把你真正关心的 `-mcpu` case 单独拎出来。
- 它能确认后端是否真的为 gfx1151 发出了正确的 target string 和 HSA 元数据。

### 2）停在一个 MIR 检查点

```bash
"$BIN/llc" -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1151 -O3 \
  -stop-after=finalize-isel -verify-machineinstrs < "$TEST" | sed -n '1,120p'
```

当前机器上观察到的 MIR 片段：

```yaml
name:            directive_amdgcn_target
failedISel:      false
tracksRegLiveness: true
registers:
  - { id: 0, class: vgpr_32, preferred-register: '', flags: [  ] }
  - { id: 1, class: sgpr_64, preferred-register: '', flags: [  ] }
  - { id: 2, class: sgpr_64, preferred-register: '', flags: [  ] }
```

这一步的价值：

- `failedISel: false` 能直接说明 instruction selection 已经成功。
- MIR dump 是做 pass-by-pass 后端调试的合适起点。
- `-verify-machineinstrs` 可以尽早暴露很多后端不变量问题。

### 3）为什么 `llvm-lit` 仍然可能失败，即使你的 gfx1151 case 看起来没问题

在当前机器上，这个完整 lit 测试会失败，因为该文件还检查了一个当前构建并不识别的后续子目标：

```text
'gfx1170' is not a recognized processor for this target (ignoring processor)
error: GFX1170: expected string not found in input
```

这意味着：

- 你的 gfx1151 手工调试循环仍然是有效的；
- 只是这个完整测试文件在当前构建里已经不再是一个干净的 PASS 基线。

遇到这种情况时，优先这样做：

- 直接运行你关心的那个子目标对应的 `llc` 命令；
- 换成当前构建中仍然能稳定通过的更小测试；
- 或者把这个 lit 失败本身当成一个值得继续调查的问题。

## 下一步练习（适合 Triton 邻近方向）

- 修改 `chipset=` / `-mcpu=`，比较不同目标（如 `gfx1100`、`gfx1151`）的生成代码差异。
- 在 [amdgpu/examples/mlir_gpu_ids.mlir](amdgpu/examples/mlir_gpu_ids.mlir) 中加入更多 GPU op（barrier、subgroup op 等），然后重新运行 `-convert-gpu-to-rocdl` 检查 ROCDL 输出。
- 挑一个失败的 AMDGPU LLVM CodeGen 测试，用 `llc` 手工复现它的 `RUN:` 行（配合 README 中的工作流）。
- 参见 `amdgpu/next-practice-patches.md`，里面列了适合入门的实战 patch 方向。