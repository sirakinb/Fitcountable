#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${1:-$ROOT_DIR/artifacts/Fitcountable.xcarchive}"
EXPORT_DIR="${2:-$ROOT_DIR/artifacts/export-app-store}"

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "Missing archive: $ARCHIVE_PATH" >&2
  echo "Run ./scripts/preflight-release.sh first." >&2
  exit 1
fi

rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

xcodebuild -exportArchive \
  -allowProvisioningUpdates \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$ROOT_DIR/ios/ExportOptions-AppStore.plist"

echo "Export complete: $EXPORT_DIR"
