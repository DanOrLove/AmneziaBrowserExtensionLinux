#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_EXECUTABLE="$SCRIPT_DIR/AmneziaBrowserVpnHost"
ACTION="${1:-install}"

if [[ "$ACTION" == "--uninstall" ]]; then
  if [[ ! -x "$HOST_EXECUTABLE" ]]; then
    echo "Native host not found. Keep the project folder and run ./native/build.sh before uninstalling." >&2
    exit 1
  fi
  "$HOST_EXECUTABLE" uninstall
  exit 0
fi

if [[ "$ACTION" != "install" ]]; then
  echo "Usage: $0 [--uninstall]" >&2
  exit 2
fi

if [[ ! -x "$HOST_EXECUTABLE" ]]; then
  echo "Native host not found. Run ./native/build.sh first." >&2
  exit 1
fi

"$HOST_EXECUTABLE" install
