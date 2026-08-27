#!/bin/bash
#
# archive-appstore.sh — one repeatable path from source to an App Store .ipa.
#
# Builds a RELEASE device archive (with dSYMs), runs the pre-flight gate, and
# exports an App Store Connect .ipa. Upload is left as an explicit, separate
# manual step (never automated here). No credentials or team ids live in the
# repo: the team id comes from the DEVELOPMENT_TEAM environment variable.
#
# Requirements:
#   - macOS + Xcode 26 (SDK iOS 26), a valid Apple Developer account already
#     signed in to Xcode, and automatic signing able to produce an App Store
#     distribution profile for com.stemblocks.matematicasuperpiatta.
#   - Precompiled deps under luanti_ios_deps/ios18.2_deps/iPhoneOS/ (see README).
#
# Usage:
#   DEVELOPMENT_TEAM=ABCDE12345 tools/ios/archive-appstore.sh [build_number]
#
#   build_number  optional CFBundleVersion to stamp. Default: git commit count
#                 (monotonic, reproducible). Must be strictly greater than the
#                 last exported build number (recorded in the state file below);
#                 the script refuses to go backwards.
#
# Env overrides:
#   MS_LUA        vanilla (default here) | luajit   — release ships vanilla Lua
#                 (App Store guideline 2.5.2; see README "Motore Lua").
#   BUILD_DIR     device build dir (default build-ios-device-release)
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

SCHEME="luanti"
BUNDLE_ID="com.stemblocks.matematicasuperpiatta"
BUILD_DIR="${BUILD_DIR:-build-ios-device-release}"
MS_LUA="${MS_LUA:-vanilla}"
ARCHIVE_PATH="$REPO_ROOT/build-appstore/$SCHEME.xcarchive"
EXPORT_DIR="$REPO_ROOT/build-appstore/export"
STATE_FILE="$REPO_ROOT/tools/ios/.last-build-number"   # git-ignored
EXPORT_TEMPLATE="$REPO_ROOT/tools/ios/ExportOptions-appstore.plist"
DEPS_DEV="$REPO_ROOT/luanti_ios_deps/ios18.2_deps/iPhoneOS"

die() { echo "error: $*" >&2; exit 1; }
step() { printf '\n=== %s ===\n' "$1"; }

: "${DEVELOPMENT_TEAM:?set DEVELOPMENT_TEAM to your 10-char Apple Developer Team ID}"
[ -d "$DEPS_DEV/lib" ] || die "precompiled device deps missing at $DEPS_DEV (see README)"

# --- build number (monotonic) -------------------------------------------------
BUILD_NUMBER="${1:-$(git rev-list --count HEAD)}"
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || die "build number must be an integer, got '$BUILD_NUMBER'"
if [ -f "$STATE_FILE" ]; then
	LAST="$(cat "$STATE_FILE")"
	[ "$BUILD_NUMBER" -gt "$LAST" ] || \
		die "build number $BUILD_NUMBER is not greater than the last exported $LAST"
fi
MARKETING_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' misc/ios/Info.plist.in 2>/dev/null || echo '?')"
echo "Marketing version: $MARKETING_VERSION   Build number: $BUILD_NUMBER   Lua: $MS_LUA"

# --- (re)generate the release device build dir --------------------------------
step "Configure release device project ($BUILD_DIR)"
if [ ! -e "$BUILD_DIR/$SCHEME.xcodeproj" ]; then
	MS_LUA="$MS_LUA" tools/ios/ios_build_with_deps_ios26-v2.sh \
		"" "" "$REPO_ROOT" "$DEPS_DEV" Release iPhoneOS 26 build "$BUILD_DIR"
else
	echo "reusing existing $BUILD_DIR (delete it to reconfigure / switch MS_LUA)"
fi

# --- archive (Release, dSYM) --------------------------------------------------
step "Archive (Release, dwarf-with-dsym)"
rm -rf "$ARCHIVE_PATH"
xcodebuild -project "$BUILD_DIR/$SCHEME.xcodeproj" \
	-scheme "$SCHEME" \
	-configuration Release \
	-sdk iphoneos \
	-destination 'generic/platform=iOS' \
	-archivePath "$ARCHIVE_PATH" \
	DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
	CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
	DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
	archive

[ -d "$ARCHIVE_PATH" ] || die "archive not produced"
# Confirm dSYMs survived into the archive.
if ! /bin/ls -d "$ARCHIVE_PATH"/dSYMs/*.dSYM >/dev/null 2>&1; then
	die "no dSYM in the archive (DEBUG_INFORMATION_FORMAT lost) — refusing to continue"
fi
echo "dSYM present: $(/bin/ls "$ARCHIVE_PATH"/dSYMs)"

# --- pre-flight gate ----------------------------------------------------------
step "Pre-flight ($ARCHIVE_PATH)"
tools/ios/preflight-appstore.sh "$ARCHIVE_PATH" || die "pre-flight failed — not exporting"

# --- export -------------------------------------------------------------------
step "Export App Store .ipa"
EXPORT_OPTS="$(mktemp -t ExportOptions-appstore).plist"
cp "$EXPORT_TEMPLATE" "$EXPORT_OPTS"
/usr/libexec/PlistBuddy -c "Set :teamID $DEVELOPMENT_TEAM" "$EXPORT_OPTS"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
	-archivePath "$ARCHIVE_PATH" \
	-exportPath "$EXPORT_DIR" \
	-exportOptionsPlist "$EXPORT_OPTS"
rm -f "$EXPORT_OPTS"

IPA="$(/bin/ls "$EXPORT_DIR"/*.ipa 2>/dev/null | head -1)"
[ -n "$IPA" ] || die "no .ipa produced in $EXPORT_DIR"
echo "$BUILD_NUMBER" > "$STATE_FILE"

# --- done: upload is a separate, deliberate step ------------------------------
step "Done — upload is a separate manual step"
cat <<EOF
IPA:   $IPA
dSYMs: $ARCHIVE_PATH/dSYMs

Upload is intentionally NOT automated. When you are ready, either:
  • Transporter.app  → drag in the .ipa, then Deliver, or
  • command line (needs an App Store Connect API key or app-specific password):
      xcrun altool --upload-app -f "$IPA" -t ios \\
        --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
EOF
