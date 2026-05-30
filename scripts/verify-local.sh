#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT/scripts/check-secrets.sh"

if command -v xcodegen >/dev/null 2>&1; then
  (cd "$ROOT/ios" && xcodegen generate)
  (cd "$ROOT/ios" && xcodebuild -project Fitcountable.xcodeproj -scheme Fitcountable -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build)
else
  echo "xcodegen is required for iOS project generation." >&2
  exit 1
fi

if command -v npm >/dev/null 2>&1; then
  (cd "$ROOT/backend" && npm run build && npm audit --audit-level=high)
  (cd "$ROOT/web" && npm run build && npm audit --audit-level=high)
fi
