#!/usr/bin/env bash
# Build, validate, and upload the iOS app to App Store Connect (TestFlight).
# Reuses the App Store Connect API key (the same .p8 as create_iap.py) — altool
# accepts it directly, so no extra credentials.
#
# Requires (env):
#   ASC_KEY_ID       e.g. M48P7U2A8A
#   ASC_ISSUER_ID    e.g. c9a25367-...
#   ASC_PRIVATE_KEY  path to AuthKey_<KEY_ID>.p8
# Requires App Store *distribution* signing in Xcode (automatic signing with your
# team is fine — a prior successful TestFlight upload means it's already set up).
#
# Usage:
#   tools/appstore/release.sh                  # build + validate + upload
#   tools/appstore/release.sh --validate-only  # build + validate, no upload
#   tools/appstore/release.sh --build-number 7 # pin the build number
set -euo pipefail

VALIDATE_ONLY=0
BUILD_NUMBER="$(date +%s)"   # epoch: always higher than the last, so no clashes
while [[ $# -gt 0 ]]; do
  case "$1" in
    --validate-only) VALIDATE_ONLY=1; shift ;;
    --build-number)  BUILD_NUMBER="$2"; shift 2 ;;
    *) echo "unknown arg: $1"; exit 1 ;;
  esac
done

: "${ASC_KEY_ID:?set ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
: "${ASC_PRIVATE_KEY:?set ASC_PRIVATE_KEY (path to .p8)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../../app_flutter"

# altool finds the key as AuthKey_<KEY_ID>.p8 in ~/.appstoreconnect/private_keys
KEYDIR="$HOME/.appstoreconnect/private_keys"
mkdir -p "$KEYDIR"
cp "${ASC_PRIVATE_KEY/#\~/$HOME}" "$KEYDIR/AuthKey_${ASC_KEY_ID}.p8"

echo "==> flutter build ipa  (build number: $BUILD_NUMBER)"
flutter build ipa --release --build-number "$BUILD_NUMBER"

IPA="$(ls -t build/ios/ipa/*.ipa | head -1)"
echo "==> IPA: $IPA"

echo "==> Validating with App Store Connect"
xcrun altool --validate-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

if [[ "$VALIDATE_ONLY" == "1" ]]; then
  echo "Validation passed. Skipping upload (--validate-only)."
  exit 0
fi

echo "==> Uploading to App Store Connect"
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo "Done. The build appears in App Store Connect -> TestFlight after Apple"
echo "finishes processing (~5-15 min). You'll get an email when it's ready."
