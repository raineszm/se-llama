# Use snap `opengl` interface for Vulkan; rely on host ICDs

GPU access for Vulkan inference is provided through the snap `opengl` interface, with Vulkan ICD discovery delegated to host-provided drivers.

This was chosen over bundling GPU vendor ICD packages in the snap because driver/runtime mismatches are high-risk and expensive to debug across kernels and host stacks. Host ICD use keeps compatibility aligned with the running system while preserving strict confinement.

Trade-off: behavior depends on host driver correctness and interface connection state. This is acceptable because driver coupling already exists at the kernel boundary, and host-managed drivers are the canonical compatibility point.

## Considered Options

**Bundle vendor Vulkan ICDs in the snap:** Rejected because embedded drivers age quickly and can mismatch host kernels.

**Custom-device interface with tight device allowlists:** Rejected for substantially higher operational complexity without meaningful security gain for this product scope.