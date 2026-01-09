// Minimal MLIR GPU module lowered to ROCDL/LLVM dialect.
// This stays compile-only (WSL2-friendly).
//
// Try:
//   mlir-opt mlir_gpu_ids.mlir -convert-gpu-to-rocdl='chipset=gfx1151' | sed -n '1,120p'
//
// Note: Translating to LLVM IR from a nested `gpu.module` generally requires
// additional GPU lowering steps (often culminating in `-gpu-module-to-binary`,
// which may require ROCm tooling). This example focuses on the IR shapes.

module {
  gpu.module @kernels {
    gpu.func @write_tid_x(%out : memref<i32, 1>) kernel {
      %tid = gpu.thread_id x
      %v = arith.index_cast %tid : index to i32
      memref.store %v, %out[] : memref<i32, 1>
      gpu.return
    }
  }
}
