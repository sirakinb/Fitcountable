#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/ios"
CONFIG_PATH="${1:-/Users/sirakinb/Desktop/build-ios-apps/appstoreconnect.local.json}"

echo "Checking App Store Connect credentials..."
"$ROOT_DIR/scripts/validate-asc-config.sh" "$CONFIG_PATH"

echo "Checking public App Store URLs..."
for url in \
  "https://web-app-build-26.vercel.app" \
  "https://web-app-build-26.vercel.app/privacy" \
  "https://web-app-build-26.vercel.app/terms" \
  "https://web-app-build-26.vercel.app/support"
do
  status="$(curl -sS -o /dev/null -w "%{http_code}" "$url")"
  if [[ "$status" != "200" ]]; then
    echo "URL check failed for $url: HTTP $status" >&2
    exit 1
  fi
done

echo "Checking app icon asset..."
if [[ ! -f "$IOS_DIR/Fitcountable/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" ]]; then
  echo "Missing AppIcon-1024.png. Run ./scripts/generate-placeholder-icon.sh or generate final branded artwork." >&2
  exit 1
fi

echo "Checking local build gates..."
"$ROOT_DIR/scripts/verify-local.sh"

echo "Building release archive without uploading..."
cd "$IOS_DIR"
xcodegen generate
xcodebuild \
  -project Fitcountable.xcodeproj \
  -scheme Fitcountable \
  -configuration Release \
  -allowProvisioningUpdates \
  -destination generic/platform=iOS \
  -archivePath "$ROOT_DIR/artifacts/Fitcountable.xcarchive" \
  archive

echo "Exporting App Store IPA without uploading..."
"$ROOT_DIR/scripts/export-ipa-no-upload.sh" "$ROOT_DIR/artifacts/Fitcountable.xcarchive" "$ROOT_DIR/artifacts/export-app-store"
echo "Release preflight complete. Archive is at $ROOT_DIR/artifacts/Fitcountable.xcarchive"
echo "No-upload IPA is at $ROOT_DIR/artifacts/export-app-store/Fitcountable.ipa"
