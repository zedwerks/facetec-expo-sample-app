#!/bin/bash
set -e -o pipefail


usage() {
  cat <<'EOF'
Usage:
  ./scripts/publish-ios.sh [options]

Builds an iOS .ipa with a selected EAS profile.

Options:
  -p, --profile PROFILE     EAS build profile (default: preview).
      --preview             Alias for --profile preview.
  -t, --transporter         Use Transporter.app path (default)
  -e, --eas                 Use EAS CLI to submit IPA.
  -h, --help                Show this help

Non-production profiles create an IPA for local installation and do not submit it.
Production builds open Transporter by default. Use --eas to submit with EAS CLI instead.
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

# Defaults
build_profile="preview"
transporter_app=true
eas_submit=false

# Arguments
while (( $# > 0 )); do
  case "$1" in
    -p|--profile)
      (( $# >= 2 )) || fail "$1 requires a profile name"
      [[ -n "$2" && "$2" != -* ]] || fail "$1 requires a profile name"
      build_profile="$2"
      shift 2
      ;;
    --profile=*)
      build_profile="${1#*=}"
      [[ -n "$build_profile" ]] || fail "--profile requires a profile name"
      shift
      ;;
    --preview)
      build_profile="preview"
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


if [ "$build_profile" != "production" ]; then
  echo "Building iOS IPA with EAS profile: $build_profile"
  if [ "$build_profile" = "preview" ]; then
    echo "Checking registered devices..."
    eas device:list
    echo "----------------------"
  fi
  TARGET_DIR="$APP_DIR/distribute/build/$build_profile"
  mkdir -p "$TARGET_DIR"
  IPA_PATH="$TARGET_DIR/sampleapp-${VERSION}-${build_profile}-$(date +%Y%m%d%H%M%S).ipa"
  echo "Building iOS app with EAS and outputting to $IPA_PATH"
  eas build --platform ios --profile "$build_profile" --local --output "$IPA_PATH"
  open "$TARGET_DIR"
  echo "Use EAS Orbit to install the IPA on a registered device."
  exit 0
fi

echo "Building production version of IPA."
TARGET_DIR="$APP_DIR/distribute/build/production"
mkdir -p "$TARGET_DIR"
IPA_PATH="$TARGET_DIR/sampleapp-${VERSION}-$(date +%Y%m%d%H%M%S).ipa"

echo "Building iOS app with EAS and outputting to $IPA_PATH"
echo "eas build --platform ios --profile $build_profile --local --output \"$IPA_PATH\""
eas build --platform ios --profile "$build_profile" --local --output "$IPA_PATH"

if [ "$transporter_app" == true ]; then
  echo "Opening IPA in Transporter.app..."
  transporter_app=true
  open -a "Transporter" "$IPA_PATH"
else
  echo "Submitting iOS app to App Store Connect with EAS"
  echo "About to submit IPA path: $IPA_PATH"
  echo "eas submit --platform ios --path \"$IPA_PATH\" --profile $build_profile"
  eas submit --platform ios --path "$IPA_PATH" --profile "$build_profile"
fi
