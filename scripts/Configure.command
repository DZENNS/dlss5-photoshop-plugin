#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
trap 'printf "\nSetup failed or cancelled. No installed Photoshop plug-in was modified.\n"; read -r -p "Press Enter to close…" _' ERR
MODEL="${1:-}"
DEST="${2:-}"
if [ -z "$MODEL" ]; then
 MODEL="$(osascript -e 'POSIX path of (choose folder with prompt "Choose your HT model folder (NR.dlss or NeuralRendering.dlssmodel), containing manifest.json and weights.safetensors")')"
fi
MODEL="${MODEL%/}"
[ -f "$MODEL/manifest.json" ] && [ -f "$MODEL/weights.safetensors" ] || { echo 'Select the model folder itself, not its parent or the NVIDIA DLL.'; exit 1; }
if [ -z "$DEST" ]; then
 DEST="$(osascript -e 'POSIX path of (choose folder with prompt "Choose an output folder, for example Desktop. A NEW configured plug-in will be created there.")')"
fi
DEST="${DEST%/}/DLSS5 Native.plugin"
[ ! -e "$DEST" ] || { echo "Already exists: $DEST. Choose a different folder; existing plug-ins are never overwritten."; exit 1; }
SOURCE="$HERE/DLSS5 Native.plugin"
[ -d "$SOURCE" ] || { echo 'Keep this command beside DLSS5 Native.plugin from the release ZIP.'; exit 1; }
STAGE="$(mktemp -d "$(dirname "$DEST")/.dlss5-setup.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ditto "$SOURCE" "$STAGE/DLSS5 Native.plugin"
ditto "$MODEL" "$STAGE/DLSS5 Native.plugin/Contents/Resources/NR.dlss"
codesign --force --sign - "$STAGE/DLSS5 Native.plugin"
codesign --verify --deep --strict "$STAGE/DLSS5 Native.plugin"
mv "$STAGE/DLSS5 Native.plugin" "$DEST"
printf '\nConfigured plug-in: %s\nQuit Photoshop. Copy this plug-in into Photoshop/Plug-ins, then restart Photoshop.\n' "$DEST"
if [ -t 0 ]; then read -r -p 'Press Enter to close…' _; fi
