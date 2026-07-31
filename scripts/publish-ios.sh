#!/bin/bash
set -e -o pipefail


usage() {
  cat <<'EOF'
Usage:
  ./eas-publish.sh [options] [path/to/app.ipa]

Opens an iOS .ipa in Apple's Transporter app.

Options:
  -p, --preview             Create Preview version of IPA.
  -t, --transporter         Use Transporter.app path (default)
  -e, --eas                 Use EAS CLI to submit IPA.
  -h, --help                Show this help

The default is to use Transporter.app to upload the IPA. Use --eas to submit via EAS CLI instead.
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

# Defaults
preview_mode=false
transporter_app=true
eas_submit=false

# Arguments
while (( $# > 0 )); do
  case "$1" in
    -p|--preview)
      preview_mode=true
      shift
      ;;
    -t|--transporter)
      transporter_app=true
      eas_submit=false
      shift
      ;;
    -e|--eas)
      eas_submit=true
      transporter_app=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break   
      ;;
    -*)
      fail "Unknown option: $1"
      ;;  
    *)
      shift
  esac
done


PROJECT_ROOT=$(git rev-parse --show-toplevel)
APP_DIR="$PROJECT_ROOT"


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

cd "$APP_DIR"
echo "Deploying iOS using eas local build and eas submit"
echo "$APP_DIR"
export EAS_BUILD_NO_EXPO_GO_WARNING=true 
export EX_UPDATES_NATIVE_DEBUG=1

VERSION=$(node -p "require('./app.config.js').default.expo.version")


if [ "$preview_mode" = true ]; then
  echo "Preview mode enabled: building Preview version of IPA."
  echo "checking devices..."
  eas device:list
  echo "----------------------"
  TARGET_DIR="$APP_DIR/distribute/build/preview"
  mkdir -p "$TARGET_DIR"
  echo "Preview mode enabled: building Preview version of IPA."
  IPA_PATH="$TARGET_DIR/theWallet-${VERSION}-preview-$(date +%Y%m%d%H%M%S).ipa"
  echo "Building iOS app with EAS and outputting to $IPA_PATH"
  eas build --platform ios --profile preview --local --output "$IPA_PATH"
  open $TARGET_DIR
  echo "Now use EAS Orbit macOS app to install the ipa on your device."
  exit 0
else 
  echo "Building production version of IPA."
fi

TARGET_DIR="$APP_DIR/distribute/build/production"
mkdir -p "$TARGET_DIR"
IPA_PATH="$TARGET_DIR/theWallet-${VERSION}-$(date +%Y%m%d%H%M%S).ipa"

echo "Building iOS app with EAS and outputting to $IPA_PATH"
echo "eas build --platform ios --profile production --local --output \"$IPA_PATH\""
eas build --platform ios --profile production --local --output "$IPA_PATH"

if [ "$transporter_app" == true ]; then
  echo "Opening IPA in Transporter.app..."
  transporter_app=true
  open -a "Transporter" "$IPA_PATH"
else
  echo "Submitting iOS app to App Store Connect with EAS"
  echo "About to submit IPA path: $IPA_PATH"
  echo "eas submit --platform ios --path \"$IPA_PATH\" --profile production"
  eas submit --platform ios --path "$IPA_PATH" --profile production
fi
