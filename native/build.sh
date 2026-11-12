#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SDK="${ADOBE_SDK_ROOT:?Set ADOBE_SDK_ROOT to the official Photoshop SDK pluginsdk directory}"
ORT="${ORT_ROOT:?Set ORT_ROOT to ONNX Runtime macOS arm64 1.23.2}"
ESRGAN="${ESRGAN_MODEL:?Set ESRGAN_MODEL to esrgan_x2.onnx}"
[ -f "$SDK/photoshopapi/photoshop/PIFilter.h" ]
[ -f "$ORT/lib/libonnxruntime.1.23.2.dylib" ]
[ -f "$ESRGAN" ]
swift build -c release --jobs "${DLSS_BUILD_JOBS:-2}" --product DLSSPhotoshopNative
BIN="$(swift build -c release --show-bin-path)"
bash scripts/build-metal.sh
OUT="$PWD/build/DLSS5 Native.plugin"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources/Engine" "$OUT/Contents/Resources/Upscale/Licenses"
clang++ -std=c++17 -fobjc-arc -arch arm64 -mmacosx-version-min=15.8 -bundle -DMAC_ENV=1 -D__PIMac__=1 -I"$SDK/photoshopapi/photoshop" -I"$SDK/photoshopapi/pica_sp" -I"$SDK/samplecode/common/includes" -framework Cocoa -I"$ORT/include" native/Plugin.mm native/Automation.mm native/Upscale.cpp -L"$ORT/lib" -lonnxruntime -Wl,-rpath,@loader_path/../Resources/Engine -o "$OUT/Contents/MacOS/DLSS5"
cp "$BIN/libDLSSPhotoshopNative.dylib" "$BIN/mlx.metallib" "$OUT/Contents/Resources/Engine/"
cp Sources/PhotoshopNative/Shaders.metal "$OUT/Contents/Resources/"
cp "$ORT/lib/libonnxruntime.1.23.2.dylib" "$OUT/Contents/Resources/Engine/"
cp "$ESRGAN" "$OUT/Contents/Resources/Upscale/esrgan_x2.onnx"
ditto licenses "$OUT/Contents/Resources/Upscale/Licenses"
cp native/PiPLs.json "$OUT/Contents/Resources/"
cp native/Info.plist "$OUT/Contents/"
for lib in "$OUT"/Contents/Resources/Engine/*.dylib; do codesign --force --sign - "$lib"; done
codesign --force --sign - "$OUT"
codesign --verify --deep --strict "$OUT"
cp scripts/Configure.command build/
echo 'Built without NVIDIA weights. Run build/Configure.command to supply your own HT model.'
