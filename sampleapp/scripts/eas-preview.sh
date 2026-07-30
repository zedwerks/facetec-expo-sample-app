#!/bin/bash
set -e

PROJECT_ROOT=$(git rev-parse --show-toplevel)
MOBILE_DIR="$PROJECT_ROOT/FaceTec-React-Native-SampleApp"

MOBILE_DEVICE_DIR="$HOME/Library/MobileDevice"
PROV_PROFILES_DIR="$MOBILE_DEVICE_DIR/Provisioning Profiles"

CURRENT_OWNER="$(stat -f '%Su:%Sg' "$MOBILE_DEVICE_DIR" 2>/dev/null)"
DESIRED_OWNER="$(whoami):staff"

if [ "$CURRENT_OWNER" != "$DESIRED_OWNER" ]; then
  echo "Fixing ownership of $MOBILE_DEVICE_DIR (requires sudo)..."
  sudo chown -R "$(whoami):staff" "$MOBILE_DEVICE_DIR"
else
  echo "Ownership already correct — skipping sudo."
fi

chmod 755 "$PROV_PROFILES_DIR"

pushd .
cd "$MOBILE_DIR"
echo "Deploying iOS using eas local build and eas submit"
echo "$MOBILE_DIR"
export EAS_BUILD_NO_EXPO_GO_WARNING=true 
export EX_UPDATES_NATIVE_DEB1

mkdir -p "$MOBILE_DIR/dist/eas-preview/build"

VERSION=$(node -p "require('./app.json').version")
IPA_PATH="$MOBILE_DIR/dist/eas-preview/build/sampleapp-${VERSION}-$(date +%Y%m%d%H%M%S).ipa"

echo "Building iOS app with EAS and outputting to $IPA_PATH"
echo "eas build --platform ios --profile production --local --output \"$IPA_PATH\""
eas build --platform ios --profile preview --local --output "$IPA_PATH"