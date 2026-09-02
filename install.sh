#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$SCRIPT_DIR/installer/install.py" "$@"
fi

if command -v python >/dev/null 2>&1; then
  exec python "$SCRIPT_DIR/installer/install.py" "$@"
fi

echo "Pokemon Z Mods requires Python 3 for the Linux/macOS/Steam Deck installer." >&2
echo "See PLATFORMS.md for the manual installation method." >&2
exit 1
