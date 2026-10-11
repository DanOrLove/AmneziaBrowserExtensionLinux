#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This installer is for Linux." >&2
  exit 1
fi
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/AmneziaBrowserVPN"
APP_DIR="$(mkdir -p "$APP_DIR" && cd "$APP_DIR" && pwd)"

if [[ "${1:-}" == "--uninstall" ]]; then
  command -v python3 >/dev/null 2>&1 || { echo "python3 is required to uninstall." >&2; exit 1; }
  if [[ -x "$APP_DIR/native/AmneziaBrowserVpnHost" ]]; then
    bash "$APP_DIR/native/install.sh" --uninstall
  fi
  if [[ -f "$APP_DIR/extension/manifest.json" ]]; then
    extension_id="$(python3 - "$APP_DIR/extension/manifest.json" <<'PY'
import base64, hashlib, json, sys
key = base64.b64decode(json.load(open(sys.argv[1]))["key"])
print("".join(chr(ord("a") + nibble) for byte in hashlib.sha256(key).digest()[:16] for nibble in (byte >> 4, byte & 15)))
PY
)"
    declare -a metadata_files=(
      "/opt/google/chrome/extensions/$extension_id.json"
      "/usr/share/google-chrome/extensions/$extension_id.json"
      "/usr/share/chromium/extensions/$extension_id.json"
      "/usr/share/chromium-browser/extensions/$extension_id.json"
      "/usr/lib/chromium/extensions/$extension_id.json"
      "/usr/lib/chromium-browser/extensions/$extension_id.json"
      "/opt/microsoft/msedge/extensions/$extension_id.json"
      "/opt/brave.com/brave/extensions/$extension_id.json"
      "/opt/vivaldi/extensions/$extension_id.json"
    )
    for metadata_file in "${metadata_files[@]}"; do
      if [[ -f "$metadata_file" ]]; then
        sudo rm -f "$metadata_file"
      fi
    done
  fi
  rm -rf "$APP_DIR"
  echo "Amnezia Browser VPN was uninstalled. Restart the browser to finish removing the extension."
  exit 0
fi

for required in go openssl python3; do
  if ! command -v "$required" >/dev/null 2>&1; then
    echo "Required command not found: $required" >&2
    exit 1
  fi
done
command -v sudo >/dev/null 2>&1 || { echo "sudo is required to install the extension for a system browser." >&2; exit 1; }

cd "$PROJECT_DIR"
echo "Building the Linux Native Messaging host..."
bash ./native/build.sh

# Keep the installed host and extension in a stable user data directory, so
# the user can remove the downloaded source folder after installation.
rm -rf "$APP_DIR/extension"
cp -a "$PROJECT_DIR/extension" "$APP_DIR/extension"
mkdir -p "$APP_DIR/native"
install -m 700 "$PROJECT_DIR/native/AmneziaBrowserVpnHost" "$APP_DIR/native/AmneziaBrowserVpnHost"

KEY_FILE="$APP_DIR/extension.pem"
if [[ ! -s "$KEY_FILE" ]]; then
  echo "Creating a local signing key for this installation..."
  openssl genrsa -out "$KEY_FILE" 2048 2>/dev/null
fi
chmod 600 "$KEY_FILE"
PUBLIC_KEY="$(openssl pkey -in "$KEY_FILE" -pubout -outform DER 2>/dev/null | base64 | tr -d '\n')"
python3 - "$PROJECT_DIR/extension" "$APP_DIR/extension/manifest.json" "$PUBLIC_KEY" "$APP_DIR/install-state.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

source_dir, manifest_name, public_key, state_name = sys.argv[1:]
source_dir, manifest_path, state_path = Path(source_dir), Path(manifest_name), Path(state_name)
manifest = json.loads(manifest_path.read_text())
version = manifest["version"]
source_hash = hashlib.sha256()
for path in sorted(source_dir.rglob("*")):
    if path.is_file():
        source_hash.update(path.relative_to(source_dir).as_posix().encode())
        source_hash.update(path.read_bytes())
source_hash = source_hash.hexdigest()

if state_path.exists():
    previous = json.loads(state_path.read_text())
    if previous.get("source_hash") == source_hash:
        version = previous["version"]
    else:
        previous_version = tuple(map(int, previous["version"].split(".")))
        current_version = tuple(map(int, version.split(".")))
        width = max(len(previous_version), len(current_version))
        previous_version += (0,) * (width - len(previous_version))
        current_version += (0,) * (width - len(current_version))
        if current_version <= previous_version:
            bumped = list(previous_version)
            bumped[-1] += 1
            version = ".".join(map(str, bumped))
manifest["key"] = public_key
manifest["version"] = version
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
state_path.write_text(json.dumps({"source_hash": source_hash, "version": version}) + "\n")
PY

browser=""
for candidate in google-chrome google-chrome-stable chromium chromium-browser microsoft-edge microsoft-edge-stable brave-browser brave-browser-stable vivaldi vivaldi-stable; do
  if command -v "$candidate" >/dev/null 2>&1; then
    browser="$(command -v "$candidate")"
    break
  fi
done
if [[ -z "$browser" ]]; then
  echo "No supported browser was found (Chrome, Chromium, Edge, Brave, or Vivaldi)." >&2
  echo "The native host was built and copied to $APP_DIR, but is not registered yet. Install a supported browser, then rerun this script." >&2
  exit 1
fi

echo "Packaging the extension with $browser..."
"$browser" "--pack-extension=$APP_DIR/extension" "--pack-extension-key=$KEY_FILE" >/dev/null 2>&1
if [[ ! -s "$APP_DIR/extension.crx" ]]; then
  echo "The browser did not create $APP_DIR/extension.crx." >&2
  exit 1
fi
chmod 644 "$APP_DIR/extension.crx"

echo "Registering the native host for this user..."
# The source install helper is copied next to the executable so its manifest
# lookup resolves the installed extension, not the downloaded checkout.
install -m 700 "$PROJECT_DIR/native/install.sh" "$APP_DIR/native/install.sh"
bash "$APP_DIR/native/install.sh"

extension_id="$(python3 - "$APP_DIR/extension/manifest.json" <<'PY'
import base64, hashlib, json, sys
key = base64.b64decode(json.load(open(sys.argv[1]))["key"])
print("".join(chr(ord("a") + nibble) for byte in hashlib.sha256(key).digest()[:16] for nibble in (byte >> 4, byte & 15)))
PY
)"

declare -a extension_dirs=()
case "$(basename "$browser")" in
  google-chrome*|google-chrome-for-testing)
    if [[ -d /opt/google/chrome ]]; then extension_dirs+=(/opt/google/chrome/extensions); fi
    if [[ -d /usr/share/google-chrome ]]; then extension_dirs+=(/usr/share/google-chrome/extensions); fi
    ;;
  chromium|chromium-browser)
    for root in /usr/share/chromium /usr/share/chromium-browser /usr/lib/chromium /usr/lib/chromium-browser; do
      [[ -d "$root" ]] && extension_dirs+=("$root/extensions")
    done
    ;;
  microsoft-edge*) [[ -d /opt/microsoft/msedge ]] && extension_dirs+=(/opt/microsoft/msedge/extensions) ;;
  brave-browser*) [[ -d /opt/brave.com/brave ]] && extension_dirs+=(/opt/brave.com/brave/extensions) ;;
  vivaldi*) [[ -d /opt/vivaldi ]] && extension_dirs+=(/opt/vivaldi/extensions) ;;
esac

if (( ${#extension_dirs[@]} == 0 )); then
  echo "Could not find this browser's system extension directory; automatic extension registration is unavailable." >&2
  echo "The native host is installed. Load this folder via the browser's Load unpacked option: $APP_DIR/extension" >&2
  exit 1
fi

echo "Installing the extension for the current Linux browser (administrator permission may be requested)..."
sudo -v
for extension_dir in "${extension_dirs[@]}"; do
  metadata="$(python3 - "$APP_DIR/extension.crx" "$APP_DIR/extension/manifest.json" <<'PY'
import json, sys
manifest = json.load(open(sys.argv[2]))
print(json.dumps({"external_crx": sys.argv[1], "external_version": manifest["version"]}))
PY
)"
  sudo install -d -m 755 "$extension_dir"
  printf '%s\n' "$metadata" | sudo tee "$extension_dir/$extension_id.json" >/dev/null
  sudo chmod 644 "$extension_dir/$extension_id.json"
done

echo
echo "Installation is complete. The extension will appear when the browser next starts."
echo "If it is already open, restart it to load the extension."
echo "Installed app files: $APP_DIR"

case "$(basename "$browser")" in
  microsoft-edge*) browser_url="edge://extensions" ;;
  brave-browser*) browser_url="brave://extensions" ;;
  vivaldi*) browser_url="vivaldi://extensions" ;;
  *) browser_url="chrome://extensions" ;;
esac
"$browser" "$browser_url" >/dev/null 2>&1 &
