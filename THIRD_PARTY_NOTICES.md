# Third-party notices

This is an independent macOS-only Photoshop filter, not an Adobe/NVIDIA product.

- App/bridge code derives from gtrg55/dlss5-macos-overlay, MIT: https://github.com/gtrg55/dlss5-macos-overlay. Local Photoshop changes and packaging are included in native/ and Sources/.
- MLX-DLSS, Apache 2.0: https://github.com/iamwavecut/MLX-DLSS. The local vendored snapshot (with local compatibility adaptations) is preserved in Vendor/MLX-DLSS, including LICENSE and NOTICE. Its publication/model boundaries remain applicable; no NVIDIA weights or DLLs are included.
- MLX Swift / MLX and Swift Numerics: dependencies pinned by Package.resolved. Corresponding notices accompany the compiled release in Licenses/.
- ONNX Runtime 1.23.2: MIT and third-party notices in licenses/ONNX-*.
- Real-ESRGAN: BSD-3-Clause; licenses/Real-ESRGAN-BSD.txt.
- cassianokc/upscaler: BSD-3-Clause; licenses/Upscaler-BSD.txt. The release includes esrgan_x2.onnx used by that project.
- Adobe Photoshop SDK: required only for source builds, obtained separately under Adobe's terms; no Adobe SDK headers or samples are redistributed.
- NVIDIA runtime and extracted neural weights: user supplied locally; not covered by the MIT/Apache licenses in this repository. No redistribution permission is implied.

Release v0.9.4 contains native ARM64 binaries compiled before public packaging, without NVIDIA models. It is ad-hoc signed and not notarized. It has not been ported to Windows.
