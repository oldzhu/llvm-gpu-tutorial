// Minimal CUDA device code (compile-only).
//
// Goal: demonstrate clang frontend -> NVPTX/PTX without requiring CUDA headers/libs.
//
// Try (device-only, no CUDA install required for this tiny kernel):
//   clang++ -x cuda --cuda-gpu-arch=sm_80 --cuda-device-only -nocudainc -nocudalib \
//     -S cuda_minimal.cu -o - | sed -n '1,80p'
//
// Note: anything that pulls in libdevice (math intrinsics, etc.) may require a CUDA toolkit.

// With -nocudainc we don't have CUDA headers, so define minimal qualifiers.
#ifndef __global__
#define __global__ __attribute__((global))
#endif

extern "C" __global__ void k_add1(float *out) {
  out[0] = 1.0f;
}
