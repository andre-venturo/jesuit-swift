#!/usr/bin/env bash
#
# testflight.sh — archive, export, and upload Jesuit to TestFlight.
#
# Usage:
#   ASC_APPLE_ID="you@example.com" ASC_APP_PASSWORD="abcd-efgh-ijkl-mnop" ./scripts/testflight.sh
#
# ASC_APP_PASSWORD is an app-specific password from https://appleid.apple.com
# (Sign-In and Security → App-Specific Passwords), NOT your Apple ID password.
#
set -euo pipefail

# Resolve repo root from this script's location so it runs from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="Jesuit.xcodeproj"
SCHEME="Jesuit"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/Jesuit.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTIONS="scripts/ExportOptions.plist"
BUILD_NUMBER_FILE="scripts/build_number.txt"

# --- Validate credentials ---------------------------------------------------
if [[ -z "${ASC_APPLE_ID:-}" || -z "${ASC_APP_PASSWORD:-}" ]]; then
  echo "error: set ASC_APPLE_ID and ASC_APP_PASSWORD before running." >&2
  echo "  ASC_APPLE_ID      — your Apple ID email" >&2
  echo "  ASC_APP_PASSWORD  — app-specific password from https://appleid.apple.com" >&2
  echo "" >&2
  echo "  Example:" >&2
  echo "    ASC_APPLE_ID=\"you@example.com\" ASC_APP_PASSWORD=\"abcd-efgh-ijkl-mnop\" ./scripts/testflight.sh" >&2
  exit 1
fi

# --- Increment build number -------------------------------------------------
CURRENT_BUILD="$(tr -d '[:space:]' < "$BUILD_NUMBER_FILE")"
BUILD="$((CURRENT_BUILD + 1))"
echo "$BUILD" > "$BUILD_NUMBER_FILE"
echo "==> Build number: $BUILD"

# --- Clean previous artifacts -----------------------------------------------
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"

# --- Archive ----------------------------------------------------------------
echo "==> Archiving…"
xcodebuild clean archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  CURRENT_PROJECT_VERSION="$BUILD"

# --- Export the .ipa ---------------------------------------------------------
echo "==> Exporting .ipa…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates

IPA_PATH="$(/usr/bin/find "$EXPORT_DIR" -name '*.ipa' -maxdepth 1 | head -n 1)"
if [[ -z "$IPA_PATH" ]]; then
  echo "error: no .ipa produced in $EXPORT_DIR" >&2
  exit 1
fi
echo "==> Built: $IPA_PATH"

# --- Upload to App Store Connect --------------------------------------------
echo "==> Uploading to TestFlight…"
xcrun altool --upload-app \
  -f "$IPA_PATH" \
  -t ios \
  -u "$ASC_APPLE_ID" \
  -p "$ASC_APP_PASSWORD"

echo "==> Done. Build $BUILD uploaded; check App Store Connect → TestFlight (processing takes a few minutes)."
