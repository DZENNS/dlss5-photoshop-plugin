#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
JOBS="${DLSS_BUILD_JOBS:-2}"
BIN_PATH="$(swift build -c release --show-bin-path)"
METAL_SOURCE="$PROJECT_ROOT/.build/checkouts/mlx-swift/Source/Cmlx/mlx"
METAL_BUILD="$PROJECT_ROOT/.build/mlx-metallib"
# Some Xcode installations require a newer asset than the installed Metal
# component. Use Apple's reported installed component when the default shim fails.
if ! xcrun metal --version >/dev/null 2>&1; then
  COMPONENT_PATH="$(xcodebuild -showComponent MetalToolchain -json | python3 -c 'import json,sys; print(json.load(sys.stdin).get("toolchainSearchPath", ""))')"
  export DLSS_METAL_BIN="$COMPONENT_PATH/Metal.xctoolchain/usr/bin"
  if [ ! -x "$DLSS_METAL_BIN/metal" ] || ! "$DLSS_METAL_BIN/metal" --version >/dev/null 2>&1; then
    echo 'Install the Metal Toolchain through Xcode before packaging.' >&2
    exit 1
  fi
  WRAPPERS="$PROJECT_ROOT/.build/metal-tools"
  mkdir -p "$WRAPPERS"
  cat > "$WRAPPERS/xcrun" <<'WRAPPER'
#!/bin/bash
set -euo pipefail
if [ "${1:-}" = '-sdk' ] && [ "${2:-}" = 'macosx' ]; then
  case "${3:-}" in
    metal) shift 3; exec "$DLSS_METAL_BIN/metal" -isysroot "$(/usr/bin/xcrun --sdk macosx --show-sdk-path)" "$@" ;;
    metallib) shift 3; exec "$DLSS_METAL_BIN/metallib" "$@" ;;
  esac
fi
exec /usr/bin/xcrun "$@"
WRAPPER
  chmod +x "$WRAPPERS/xcrun"
  export PATH="$WRAPPERS:$PATH"
  echo 'Using the installed Apple Metal component directly.'
fi
cmake -S "$METAL_SOURCE" -B "$METAL_BUILD" -G Ninja \
  -DFETCHCONTENT_SOURCE_DIR_FMT="$METAL_SOURCE/../fmt" \
  -DFETCHCONTENT_SOURCE_DIR_METAL_CPP="$METAL_SOURCE/../metal-cpp" \
  -DMLX_BUILD_TESTS=OFF -DMLX_BUILD_EXAMPLES=OFF -DMLX_BUILD_BENCHMARKS=OFF \
  -DMLX_BUILD_PYTHON_BINDINGS=OFF -DMLX_BUILD_GGUF=OFF -DMLX_BUILD_SAFETENSORS=OFF \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=15.8 -DCMAKE_OSX_ARCHITECTURES=arm64
cmake --build "$METAL_BUILD" --target mlx-metallib --parallel "$JOBS"
cp "$METAL_BUILD/mlx/backend/metal/kernels/mlx.metallib" "$BIN_PATH/mlx.metallib"
