#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Checking for obvious committed secret patterns..."
if rg -n "sk_|vck_|AuthKey_|issuerId|private_key|INSFORGE_[A-Z_]*(KEY|TOKEN)[[:space:]]*[:=]|REVENUECAT_[A-Z_]*SECRET[[:space:]]*[:=]" "$ROOT" \
  --glob '!docs/**' \
  --glob '!backend/.env.example' \
  --glob '!scripts/check-secrets.sh' \
  --glob '!README.md' \
  --glob '!node_modules/**' \
  --glob '!ios/Fitcountable.xcodeproj/**'; then
  echo "Potential secret found. Review before committing." >&2
  exit 1
fi

echo "No obvious secret patterns found in source files."
