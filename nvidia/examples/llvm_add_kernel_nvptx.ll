; Minimal NVPTX kernel in LLVM IR (no CUDA toolkit required).
; Generate PTX with:
;   llc -mtriple=nvptx64-nvidia-cuda -mcpu=sm_80 -O3 llvm_add_kernel_nvptx.ll -o -

target triple = "nvptx64-nvidia-cuda"

define void @vadd_one(ptr addrspace(1) %a, ptr addrspace(1) %b, ptr addrspace(1) %c) {
entry:
  %a0.ptr = getelementptr inbounds float, ptr addrspace(1) %a, i64 0
  %b0.ptr = getelementptr inbounds float, ptr addrspace(1) %b, i64 0
  %c0.ptr = getelementptr inbounds float, ptr addrspace(1) %c, i64 0
  %a0 = load float, ptr addrspace(1) %a0.ptr, align 4
  %b0 = load float, ptr addrspace(1) %b0.ptr, align 4
  %sum = fadd float %a0, %b0
  store float %sum, ptr addrspace(1) %c0.ptr, align 4
  ret void
}
