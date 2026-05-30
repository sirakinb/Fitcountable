#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${1:-/Users/sirakinb/Desktop/build-ios-apps/appstoreconnect.local.json}"
VALIDATOR="/Users/sirakinb/Documents/Projects/ios-release-pipeline/scripts/validate-asc-key.py"

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Missing App Store Connect config: $CONFIG_PATH" >&2
  exit 1
fi

if [[ ! -f "$VALIDATOR" ]]; then
  echo "Missing validator script: $VALIDATOR" >&2
  exit 1
fi

python3 "$VALIDATOR" "$CONFIG_PATH"

