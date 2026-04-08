#!/usr/bin/env bash
# Fixes ios_screen_time_tools: pubspec declares pluginClass IosScreenTimePlugin but the
# Objective-C class is IosScreenTimeToolsPlugin, which breaks GeneratedPluginRegistrant.
# Run after: flutter pub get
#
# Usage (from repo root):
#   ./parental_control_app/scripts/patch_ios_screen_time_tools.sh
# Or:
#   cd parental_control_app && ./scripts/patch_ios_screen_time_tools.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

PUB_CACHE="${PUB_CACHE:-$(flutter pub cache path 2>/dev/null || echo "$HOME/.pub-cache")}"
PUBSPEC=$(ls -d "$PUB_CACHE"/hosted/pub.dev/ios_screen_time_tools-*/pubspec.yaml 2>/dev/null | head -1)

if [[ -z "$PUBSPEC" || ! -f "$PUBSPEC" ]]; then
  echo "ios_screen_time_tools not found under $PUB_CACHE — run 'flutter pub get' first."
  exit 1
fi

if grep -q 'pluginClass: IosScreenTimeToolsPlugin' "$PUBSPEC"; then
  echo "ios_screen_time_tools pubspec already patched (IosScreenTimeToolsPlugin)."
  exit 0
fi

# Portable in-place edit (GNU sed -i vs BSD sed -i '').
perl -i -pe 's/^(\s*)pluginClass: IosScreenTimePlugin\s*$/\1pluginClass: IosScreenTimeToolsPlugin/' "$PUBSPEC"
echo "Patched $PUBSPEC — now run: flutter pub get (from $APP_DIR) to regenerate iOS plugin registrant."
