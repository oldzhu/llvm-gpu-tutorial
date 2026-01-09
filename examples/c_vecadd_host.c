// Host-side C example (clang -> LLVM IR).
//
// In WSL2 we focus on compile/codegen rather than executing ROCm kernels.
// This file demonstrates: C -> LLVM IR.
//
// Build:
//   clang -O2 -S -emit-llvm c_vecadd_host.c -o - | sed -n '1,80p'

void vecadd(const float *a, const float *b, float *c, int n) {
  for (int i = 0; i < n; ++i)
    c[i] = a[i] + b[i];
}
