; Minimal AMDGPU kernel in LLVM IR (no ROCm runtime required).
; Build/inspect with:
;   llc -mtriple=amdgcn-amd-amdhsa -mcpu=gfx1151 -O3 llvm_add_kernel.ll -o -

target triple = "amdgcn-amd-amdhsa"

define amdgpu_kernel void @vadd_one(ptr addrspace(1) readonly %a,
                                   ptr addrspace(1) readonly %b,
                                   ptr addrspace(1) %c) {
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
