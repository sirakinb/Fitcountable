#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON_DIR="$ROOT_DIR/ios/Fitcountable/Assets.xcassets/AppIcon.appiconset"
SVG_PATH="$ROOT_DIR/artifacts/fitcountable-icon-placeholder.svg"
PNG_PATH="$ICON_DIR/AppIcon-1024.png"

mkdir -p "$ROOT_DIR/artifacts" "$ICON_DIR"

cat > "$SVG_PATH" <<'SVG'
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="128" y1="128" x2="896" y2="896" gradientUnits="userSpaceOnUse">
      <stop stop-color="#111827"/>
      <stop offset="0.45" stop-color="#0F766E"/>
      <stop offset="1" stop-color="#84CC16"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="220" fill="url(#bg)"/>
  <path d="M278 356c0-46 37-83 83-83h302c46 0 83 37 83 83v312c0 46-37 83-83 83H361c-46 0-83-37-83-83V356Z" fill="#F8FAFC" fill-opacity="0.95"/>
  <path d="M362 667V357h304v79H459v72h168v77H459v82h-97Z" fill="#111827"/>
  <path d="M356 229h312v86H356v-86Z" fill="#F8FAFC"/>
  <path d="M214 423h97v178h-97V423Zm499 0h97v178h-97V423Z" fill="#F8FAFC"/>
  <circle cx="706" cy="706" r="82" fill="#84CC16"/>
  <path d="M669 707l25 26 54-68" fill="none" stroke="#111827" stroke-width="28" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
SVG

qlmanage -t -s 1024 -o "$ROOT_DIR/artifacts" "$SVG_PATH" >/dev/null
mv "$ROOT_DIR/artifacts/fitcountable-icon-placeholder.svg.png" "$PNG_PATH"

echo "Generated $PNG_PATH"
