# Installation and user-supplied model

**macOS on Apple Silicon ONLY. The plugin has NOT been ported to Windows. No Windows build exists. Intel Macs are unsupported.**

## Requirements

macOS 15.8+, Apple Silicon, an ARM64-native Photoshop version, RGB 8-bit image and a normal pixel layer. The working workflow was user-tested in Photoshop Beta; not every Photoshop release has been validated. No UXP Developer Mode is needed: this is a native Filter plugin.

## Download

In Releases → v0.9.4 → Assets, download `DLSS5-Native-0.9.4-macOS-arm64-BYO-model.zip`. Double-click the ZIP to extract it. Do not download Source code unless you intend to build or prepare model weights.

The archive includes a compiled `DLSS5 Native.plugin`, Real-ESRGAN ×2, `Configure.command`, documentation and licenses. **NVIDIA weights and Adobe SDK headers are not included.** The plugin is locally ad-hoc signed, without Developer ID signing or notarization.

## Supply a compatible model

This release supports **HT (71 blocks)**. Supply your own prepared folder:

```
NR.dlss/
  manifest.json
  weights.safetensors
```

`NeuralRendering.dlssmodel` is also accepted as the folder name; the setup command copies it as NR.dlss. A lone safetensors file is insufficient. Do not supply Small, SeedVR2, Stable Diffusion or Real-ESRGAN weights here. Only use models you are entitled to use; this repository does not license NVIDIA weights for redistribution.

If you already have a compatible local application/plugin, Finder → right-click the bundle → Show Package Contents → Contents/Resources/NR.dlss. Copy the entire model folder to Documents, not just one file.

### Prepare from your own DLL

This optional preparation step needs Python 3.10+ (python.org). The compiled plugin does not require Python at runtime. Obtain your own authorized `nvngx_dlssnr.dll` **310.8.0.0**, supported by the bundled converter. `nvngx_dlss.dll` and `nvngx_dlssg.dll` are different components. The repository neither distributes nor downloads NVIDIA DLLs.

Download this repository's source ZIP and extract it. In Terminal, type `cd `, drag the extracted source folder into Terminal and press Enter. Then run:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install ./Vendor/MLX-DLSS/python
.venv/bin/mlxdlss-weights sha256 "/path/to/nvngx_dlssnr.dll"
.venv/bin/mlxdlss-weights all "/path/to/nvngx_dlssnr.dll" "$HOME/Documents/DLSS5-models"
```

Dependencies are downloaded by pip. Select `Documents/DLSS5-models/NeuralRendering.dlssmodel` for installation. Do not select the separate PyTorch weights. If the converter rejects the DLL/hash, do not bypass validation: this converter does not support arbitrary newer DLLs. The October Small network requires a separate engine update and is not supported by plugin 0.9.4. Follow the terms of your source software.

## Configure the compiled plugin

1. Keep Configure.command beside DLSS5 Native.plugin in the extracted release folder.
2. Create a new empty output folder, for example `DLSS5 ready` on your Desktop.
3. Double-click Configure.command.
4. In the first folder picker, choose the model folder itself, containing manifest.json and weights.safetensors.
5. In the second picker, choose the empty output folder.
6. Wait for `Configured plug-in`. The script creates a new bundle, copies the model and re-signs the bundle ad-hoc. It never overwrites an existing plugin.

For package-style folders, use Command+Shift+G in the folder picker to enter the path. Alternatively:

```sh
"/path/to/Configure.command" "/path/to/NeuralRendering.dlssmodel" "/path/to/empty-output-folder"
```

If macOS requests Command Line Tools for codesign, install them and rerun. Full Xcode is not needed to use the release. Re-signing locally does not provide notarization or Developer ID trust.

## Install in Photoshop

Save your documents and quit Photoshop with Command+Q. In Finder, open Applications → the intended Adobe Photoshop folder → Plug-ins. Move any previous DLSS5 plugin outside all Plug-ins folders as a backup; do not keep duplicate versions. Copy the **configured** DLSS5 Native.plugin into Plug-ins as a whole bundle. Administrator authentication may be required.

Restart Photoshop, open an image and select a normal pixel layer. Use Image → Mode → RGB Color → 8 Bits/Channel. Launch **Filter → DLSS5 → DLSS5 Native**, not the Plugins panel menu.

## macOS security

After attempting to load an unsigned/unnotarized component, macOS may block it. Open System Settings → Privacy & Security → Security. If an Open Anyway / Allow button is offered for DLSS5, approve it, confirm and fully restart Photoshop. Configure.command may need the same approval after its first launch attempt.

The exact prompt depends on macOS. If no override is offered or organization policy blocks plugins, contact your administrator. Do not disable Gatekeeper or SIP globally.

## First use

Choose Natural/Standard/Cinematic; Off bypasses DLSS. Start at 512 px, then click Preview or enable Automatic. Processing resolution is not the document's export size. Inspect at 100%, then Apply to new layer. Automatic is remembered between sessions; save other settings as named presets.

Double-click a slider thumb to reset that parameter: detail radius 4, all other parameter sliders 1. Stop processing discards the unfinished result.

Real-ESRGAN ×2 is separate: it doubles the document Image Size and requires a full-canvas layer without a selection. Save your PSD first. Generated detail is not guaranteed to preserve facial identity.

## Troubleshooting

- No Filter entry: check the exact Photoshop Plug-ins folder, ARM64 architecture, duplicate installs and full restart. Windows/Intel are unsupported.
- Missing model: verify Contents/Resources/NR.dlss/manifest.json and weights.safetensors, without an extra nested directory.
- Model/hash error: prepare a compatible matching HT package; never mix manifests and weights.
- No visual change: check Off, zero strength and whether Preview was run with Automatic off.
- High memory use: lower processing resolution, disable ×2 and close other documents.
- ×2 unavailable: use a full-canvas layer, clear selection and check image-size limits.
- Old version after update: quit Photoshop fully and remove duplicate bundles.

To uninstall, quit Photoshop and remove the plugin from Plug-ins. Model folders and presets are not automatically deleted.
