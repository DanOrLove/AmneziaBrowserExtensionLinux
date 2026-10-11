#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This installer is for Linux." >&2
  exit 1
fi

cd "$PROJECT_DIR"
echo "Building the Amnezia Browser VPN native host..."
bash ./native/build.sh

echo "Registering Native Messaging for the current user..."
bash ./native/install.sh

echo
echo "Native host is installed. Next, load the extension in your browser:"
echo "  1. Enable Developer mode on the extensions page."
echo "  2. Choose 'Load unpacked' and select: $PROJECT_DIR/extension"

browser_url="chrome://extensions"
browser_bin=""
for candidate in google-chrome google-chrome-stable google-chrome-for-testing chromium chromium-browser microsoft-edge brave-browser vivaldi; do
  if command -v "$candidate" >/dev/null 2>&1; then
    browser_bin="$(command -v "$candidate")"
    case "$candidate" in
      microsoft-edge) browser_url="edge://extensions" ;;
      brave-browser) browser_url="brave://extensions" ;;
      vivaldi) browser_url="vivaldi://extensions" ;;
    esac
    break
  fi
done

if [[ -n "$browser_bin" ]]; then
  "$browser_bin" "$browser_url" >/dev/null 2>&1 &
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$browser_url" >/dev/null 2>&1 &
else
  echo "Open $browser_url in your Chromium browser."
fi
