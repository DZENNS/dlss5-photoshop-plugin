# DLSS5 Native — Photoshop plugin for Mac

**English** | [Русский](README.ru.md)

**macOS / Apple Silicon (ARM64) ONLY. This plugin has NOT been ported to Windows. No Windows build is available. Intel Macs are unsupported.**

A native Adobe Photoshop plugin for photo processing: DLSS Neural Rendering through an independent MLX/Metal port, before/after comparison, and Real-ESRGAN ×2. This is not an official NVIDIA or Adobe product, and its output is not guaranteed to match the NVIDIA runtime.

## Download and installation

- [Download the compiled v0.9.4 release](https://github.com/DZENNS/dlss5-photoshop-plugin/releases/tag/v0.9.4)
- **[Step-by-step installation and model setup](docs/INSTALL_EN.md)**
- [Build from source](docs/BUILD.md)
- [Russian installation guide](docs/INSTALL_RU.md)

The release ZIP contains the compiled `.plugin`, Real-ESRGAN, and a setup command. **NVIDIA weights are not included.** To use DLSS, supply your own compatible HT model folder, named `NR.dlss` or `NeuralRendering.dlssmodel`, containing `manifest.json` and `weights.safetensors`. `Configure.command` copies the model into a new plugin bundle and signs it locally with an ad-hoc signature. Simply copying a Windows DLL into the plugin will not work: macOS does not execute it.

No NVIDIA DLLs or extracted NVIDIA weights are distributed. Adobe SDK headers are not included. The release is ad-hoc signed, without Developer ID signing or notarization. See the installation guide for macOS Privacy & Security approval steps.

## Features

- Launch from **Filter → DLSS5 → DLSS5 Native**.
- DLSS is off by default; choose Natural, Standard, Cinematic, or Neutral.
- Before/after comparison with a draggable divider, preview zoom, and pan.
- Automatic or manual preview, with processing cancellation.
- Apply the result to a new layer.
- Named presets. Only the Automatic checkbox is remembered separately between sessions.
- Processing resolutions: 320 / 384 / 512 / 640 / 768 / 960 / 1280 / 1920 px.
- Double-click a slider thumb to restore that parameter's default value.
- Russian UI when Photoshop is in Russian; English for all other Photoshop languages.
- Optional Real-ESRGAN ×2 doubles the document Image Size; requires a full-canvas layer without a selection.

## Requirements and limitations

Apple Silicon, macOS 15.8+, Photoshop with native ARM64 filter plugin support, and RGB 8-bit images. The workflow was user-tested in Photoshop Beta; compatibility with every Photoshop version is not claimed. Windows and Intel Macs are unsupported. This plugin processes still images only.

DLSS runs at the selected processing resolution. Increasing this setting does not upscale the document; actual enlargement is provided separately by Real-ESRGAN ×2. Generative processing can change details and facial appearance, so inspect the result at 100% zoom.

## Source code and licenses

- `native/`: AppKit interface, native filter entry point, and new-layer handling.
- `Sources/PhotoshopNative/`: Swift/Metal engine bridge.
- `Sources/ScreenCore/`: processing settings.
- `Vendor/MLX-DLSS/`: the vendored MLX/Metal port.

See [third-party notices](THIRD_PARTY_NOTICES.md). The main project source is MIT-licensed; MLX-DLSS is Apache 2.0; other components retain their respective licenses. The repository license **does not cover NVIDIA weights or the Adobe SDK**. Do not upload private photographs, SDK files, NVIDIA DLLs, or NVIDIA models to issues.
