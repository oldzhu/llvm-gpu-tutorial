# C/C++ → LLVM → NVIDIA PTX（NVPTX，仅编译）

[English](frontend-to-nvidia.md)

这份说明与 AMDGPU 的思路对应，但目标改成了 NVIDIA GPU，使用 LLVM 的 **NVPTX** 后端。
它同样保持为**仅编译**（适合 WSL2）：我们生成 PTX 文本，但不实际运行 kernel。

## 你现在有的，以及你现在没有的

- LLVM / Clang 可以通过 NVPTX 后端生成 **PTX**。
- 要生成可运行的 **cubin** 并实际执行，通常还需要 NVIDIA driver / CUDA toolkit。
- 这个教程聚焦于“frontend → IR → PTX”这条链路上的工件。

## 构建 / 工具

这个仓库默认你已经有一个单独的 NVPTX-enabled LLVM 构建：

- `BIN=/home/oldzhu/build/llvm-nvptx-wsl2/bin`

之所以和 AMDGPU 分开，是为了避免两个目标的构建互相干扰。

## 一条命令：重新生成全部示例输出

在教程仓库根目录下执行：

```bash
chmod +x nvidia/examples/regen_outputs.sh
nvidia/examples/regen_outputs.sh
```

它会生成：

- `nvidia/examples/outputs/llvm_add_kernel.sm80.ptx`
- `nvidia/examples/outputs/cuda_minimal.sm80.ptx`

这些文件都是本地生成工件（见 `.gitignore`）。

## 示例 A：LLVM IR kernel → PTX（通过 llc）

- 源文件：[nvidia/examples/llvm_add_kernel_nvptx.ll](nvidia/examples/llvm_add_kernel_nvptx.ll)
- 命令：
  - `"$BIN/llc" -mtriple=nvptx64-nvidia-cuda -mcpu=sm_80 -O3 nvidia/examples/llvm_add_kernel_nvptx.ll -o - | sed -n '1,80p'`

输出中应该能看到这类 PTX 指令头：

```ptx
.version
.target sm_80
.address_size 64
```

## 示例 B：CUDA C++ frontend → PTX（仅 device-only）

- 源文件：[nvidia/examples/cuda_minimal.cu](nvidia/examples/cuda_minimal.cu)
- 命令（不依赖 CUDA headers / libs）：

```bash
"$BIN/clang++" -x cuda --cuda-gpu-arch=sm_80 --cuda-device-only -nocudainc -nocudalib \
  -S nvidia/examples/cuda_minimal.cu -o - | sed -n '1,120p'
```

说明：

- 对于不依赖 CUDA 头文件或 libdevice 的简单 kernel，这种方式可以工作。
- 如果开始使用数学 intrinsic 或更复杂的 CUDA 特性，通常就需要安装 CUDA toolkit，并通过 `--cuda-path=...` 指定路径。

## 下一步练习

- 修改 `--cuda-gpu-arch=sm_70 / sm_80 / sm_90`，比较生成 PTX 的差异。
- 加入 load / store，观察 PTX 中的地址空间使用方式。
- 如果后续安装了 CUDA toolkit，可以把教程扩展到生成 LLVM IR（`-emit-llvm`）以及链接 device library。