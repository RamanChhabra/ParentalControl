#!/usr/bin/env bash
# Patches the telephony plugin's Android build.gradle to add the required namespace
# (required for newer Android Gradle Plugin). Run after: flutter pub get
#
# Usage (from repo root):
#   ./parental_control_app/scripts/patch_telephony.sh
# Or:
#   cd parental_control_app && ./scripts/patch_telephony.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

PUB_CACHE="${PUB_CACHE:-$(flutter pub cache path 2>/dev/null || echo "$HOME/.pub-cache")}"
TELEPHONY_GRADLE="$PUB_CACHE/hosted/pub.dev/telephony-0.2.0/android/build.gradle"

if [[ ! -f "$TELEPHONY_GRADLE" ]]; then
  echo "Telephony plugin not found at $TELEPHONY_GRADLE — run 'flutter pub get' first."
  exit 1
fi

if grep -q "namespace 'com.shounakmulay.telephony'" "$TELEPHONY_GRADLE"; then
  echo "Telephony plugin already patched (namespace present)."
  exit 0
fi

# Insert namespace line after first "android {" (portable: awk)
awk '/^android \{/ && !inserted { print; print "    namespace '\''com.shounakmulay.telephony'\''"; inserted=1; next }1' \
  "$TELEPHONY_GRADLE" > "${TELEPHONY_GRADLE}.tmp" && mv "${TELEPHONY_GRADLE}.tmp" "$TELEPHONY_GRADLE"

echo "Patched telephony plugin: added namespace to $TELEPHONY_GRADLE"
