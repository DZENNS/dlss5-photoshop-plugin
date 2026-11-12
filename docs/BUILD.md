# Build from source (macOS ARM64 only)

No Windows port or Windows build is provided.

Requirements: Apple Silicon, macOS 15.8+, Xcode with Swift 6.2 and Metal Toolchain, Python 3 for build tools, CMake and Ninja. Accept the Xcode license and select Xcode as the active developer directory.

Obtain the official **Photoshop C++ SDK**, not the UXP Hybrid SDK. Adobe headers are proprietary and must be obtained separately from Adobe Developer. Set ADOBE_SDK_ROOT to its `pluginsdk` directory containing `photoshopapi/photoshop/PIFilter.h`.

Download ONNX Runtime **1.23.2 macOS arm64** from https://github.com/microsoft/onnxruntime/releases/tag/v1.23.2 and extract it. ORT_ROOT must contain `include/` and `lib/libonnxruntime.1.23.2.dylib`.

Obtain the `esrgan_x2.onnx` model used by https://gitlab.com/cassianokc/upscaler (or copy the model from this project's binary release, Contents/Resources/Upscale/esrgan_x2.onnx). Its license notices are in licenses/. Set ESRGAN_MODEL to that file.

```sh
export ADOBE_SDK_ROOT="/path/to/PhotoshopSDK/pluginsdk"
export ORT_ROOT="/path/to/onnxruntime-osx-arm64-1.23.2"
export ESRGAN_MODEL="/path/to/esrgan_x2.onnx"
bash native/build.sh
```

The script builds the Swift engine, compiles the MLX Metal library and native filter, then ad-hoc signs `build/DLSS5 Native.plugin`. SwiftPM downloads pinned dependencies from Package.resolved. Source edits to MLX-DLSS are retained in Vendor/; its license and notices remain there.

No NVIDIA model is bundled by this build. Run `build/Configure.command` to create a configured copy using your own HT model, following INSTALL_EN.md or INSTALL_RU.md. An Adobe SDK, NVIDIA runtime or extracted model must never be committed to this repository.

Verification:

```sh
swift test -c release --jobs 2
codesign --verify --deep --strict "build/DLSS5 Native.plugin"
```

The v0.9.4 release binary is the previously built local v0.9.4 with NVIDIA model data removed and re-signed. Its UI implementation and Swift bridge sources are supplied here; packaging paths were rewritten for public builds. A clean public-source rebuild is not claimed as bit-for-bit reproducible. Actual Photoshop host behavior must be verified after rebuilding.
