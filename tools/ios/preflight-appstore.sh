#!/bin/bash
#
# preflight-appstore.sh — App Store readiness checks for the Matematica
# Superpiatta iOS build. Give it a built .app or an .xcarchive; it verifies the
# things that would otherwise be discovered only after an upload to App Store
# Connect, and exits non-zero on the FIRST problem with a clear message.
#
#   tools/ios/preflight-appstore.sh path/to/Matematica.app
#   tools/ios/preflight-appstore.sh path/to/Matematica.xcarchive
#
# Notes:
# - The device-only checks (arm64, no simulator slice, signed entitlements)
#   are meaningful on a Release device build / archive; on a simulator .app
#   they will (correctly) fail — that is not a release artifact.
# - PrivacyInfo.xcprivacy is required (STEP 3, done): shipped from
#   misc/ios/PrivacyInfo.xcprivacy to the .app root by install_resources.cmake.

set -u

EXPECTED_BUNDLE_ID="com.stemblocks.matematicasuperpiatta"
EXPECTED_EXECUTABLE="luanti"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE_ICON_1024="$REPO_ROOT/misc/ios/Assets.xcassets/AppIcon.appiconset/icon-1024.png"

fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1" >&2; exit 1; }
ok()   { printf '  \033[32mok\033[0m    %s\n' "$1"; }
info() { printf '        %s\n' "$1"; }

[ $# -eq 1 ] || { echo "usage: $0 <path-to-.app-or-.xcarchive>" >&2; exit 2; }
TARGET="$1"
[ -e "$TARGET" ] || fail "path does not exist: $TARGET"

# --- Resolve the .app ---------------------------------------------------------
case "$TARGET" in
	*.xcarchive)
		APP="$(/bin/ls -d "$TARGET"/Products/Applications/*.app 2>/dev/null | head -1)"
		[ -n "$APP" ] && [ -d "$APP" ] || fail "no .app inside $TARGET/Products/Applications"
		;;
	*.app)
		APP="$TARGET"
		;;
	*)
		fail "expected a .app or .xcarchive, got: $TARGET"
		;;
esac
PLIST="$APP/Info.plist"
[ -f "$PLIST" ] || fail "missing Info.plist in $APP"
echo "Pre-flight: $APP"

plist_get() { /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" 2>/dev/null; }
plist_has() { /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" >/dev/null 2>&1; }

# --- Bundle identifier --------------------------------------------------------
BID="$(plist_get CFBundleIdentifier)"
[ "$BID" = "$EXPECTED_BUNDLE_ID" ] || \
	fail "CFBundleIdentifier is '$BID', expected '$EXPECTED_BUNDLE_ID' (not the .dev variant)"
ok "CFBundleIdentifier = $BID"

# --- Versions -----------------------------------------------------------------
SHORT="$(plist_get CFBundleShortVersionString)"
BUILD="$(plist_get CFBundleVersion)"
[ -n "$SHORT" ] || fail "CFBundleShortVersionString is missing"
[ -n "$BUILD" ] || fail "CFBundleVersion is missing"
ok "CFBundleShortVersionString = $SHORT, CFBundleVersion = $BUILD"

# --- Export compliance --------------------------------------------------------
plist_has ITSAppUsesNonExemptEncryption || \
	fail "ITSAppUsesNonExemptEncryption is missing (STEP 1)"
ok "ITSAppUsesNonExemptEncryption = $(plist_get ITSAppUsesNonExemptEncryption)"

# --- Launch screen ------------------------------------------------------------
plist_has UILaunchScreen || plist_has UILaunchStoryboardName || \
	fail "no UILaunchScreen / UILaunchStoryboardName (app would be letterboxed)"
ok "launch screen present"

# --- No local-networking / no forced fullscreen -------------------------------
if plist_has NSAppTransportSecurity:NSAllowsLocalNetworking; then
	fail "NSAllowsLocalNetworking is present (STEP 2 removes it; triggers Local Network prompt)"
fi
ok "no NSAllowsLocalNetworking"
if plist_has UIRequiresFullScreen; then
	fail "UIRequiresFullScreen is present (deprecated on iPadOS 26; must be absent)"
fi
ok "no UIRequiresFullScreen"

# --- Privacy manifest ---------------------------------------------------------
[ -f "$APP/PrivacyInfo.xcprivacy" ] || \
	fail "PrivacyInfo.xcprivacy missing at bundle root (STEP 3; ITMS-91053 otherwise)"
ok "PrivacyInfo.xcprivacy present at bundle root"

# --- App icon -----------------------------------------------------------------
[ -f "$APP/Assets.car" ] || fail "Assets.car missing (compiled asset catalog with AppIcon)"
if command -v assetutil >/dev/null 2>&1; then
	if assetutil --info "$APP/Assets.car" 2>/dev/null | grep -qi 'AppIcon'; then
		ok "AppIcon found in Assets.car"
	else
		fail "AppIcon not found in Assets.car"
	fi
else
	info "assetutil not available — skipping Assets.car AppIcon name check"
	ok "Assets.car present"
fi
if [ -f "$SOURCE_ICON_1024" ]; then
	ALPHA="$(sips -g hasAlpha "$SOURCE_ICON_1024" 2>/dev/null | awk '/hasAlpha/{print $2}')"
	W="$(sips -g pixelWidth "$SOURCE_ICON_1024" 2>/dev/null | awk '/pixelWidth/{print $2}')"
	H="$(sips -g pixelHeight "$SOURCE_ICON_1024" 2>/dev/null | awk '/pixelHeight/{print $2}')"
	[ "$ALPHA" = "no" ] || fail "source icon $SOURCE_ICON_1024 has an alpha channel (App Store rejects it)"
	[ "$W" = "1024" ] && [ "$H" = "1024" ] || fail "source icon is ${W}x${H}, expected 1024x1024"
	ok "source icon 1024x1024, no alpha"
else
	info "source 1024 icon not found at $SOURCE_ICON_1024 — skipping"
fi

# --- Architecture (device build only) -----------------------------------------
BIN="$APP/$EXPECTED_EXECUTABLE"
[ -f "$BIN" ] || fail "executable '$EXPECTED_EXECUTABLE' not found in bundle"
ARCHS="$(lipo -archs "$BIN" 2>/dev/null)"
info "binary archs: $ARCHS"
case " $ARCHS " in
	*" x86_64 "*) fail "binary contains an x86_64 (simulator) slice — not a device/release build" ;;
esac
case " $ARCHS " in
	*" arm64 "*) ok "binary is arm64" ;;
	*) fail "binary has no arm64 slice: '$ARCHS'" ;;
esac

# --- Entitlements: no JIT / executable memory (App Store 2.5.2) ----------------
ENTS="$(codesign -d --entitlements :- "$APP" 2>/dev/null)"
if [ -z "$ENTS" ]; then
	info "no signed entitlements (unsigned build?) — JIT check meaningful only on a signed archive"
else
	for KEY in \
		com.apple.security.cs.allow-jit \
		com.apple.security.cs.allow-unsigned-executable-memory \
		com.apple.security.cs.disable-executable-page-protection \
		dynamic-codesigning ; do
		if printf '%s' "$ENTS" | grep -q "$KEY"; then
			fail "entitlement '$KEY' present — App Store forbids runtime code generation (2.5.2)"
		fi
	done
	ok "no JIT / executable-memory entitlements"
fi

# --- No stray dev artifacts in the bundle -------------------------------------
STRAY="$(find "$APP" \( -name '.DS_Store' -o -name '*.trace' -o -name '*.dSYM' \) -print 2>/dev/null | head)"
[ -z "$STRAY" ] || fail "stray dev artifacts inside the bundle:
$STRAY"
ok "no .DS_Store / .trace / .dSYM inside the bundle"

echo
echo "All pre-flight checks passed."
