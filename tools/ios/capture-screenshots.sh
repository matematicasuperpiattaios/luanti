#!/bin/bash
#
# capture-screenshots.sh — App Store screenshots for Matematica Superpiatta.
#
# The app is landscape-locked, so the raw simulator framebuffer comes out in
# the device's PORTRAIT pixel dimensions with the content rotated inside it.
# This script rotates each capture 90° to produce the exact LANDSCAPE pixel
# sizes App Store Connect requires, and refuses to save anything that isn't
# exactly the target size.
#
# Required App Store sizes (landscape):
#   iPhone 6.9"  -> 2868 x 1320   (captured on iPhone 17 Pro Max)
#   iPad 13"     -> 2752 x 2064   (captured on iPad Pro 13-inch)
#
# Output goes to appstore-screenshots/<device>/ which is git-ignored.
#
# IMPORTANT (iPad): on iPadOS 26 the app opens in a resizable WINDOW, so a
# capture taken as-is includes the simulator desktop/wallpaper around it. The
# pixel size still matches, but App Store screenshots must show only the app —
# so MAXIMIZE the app window to true full screen first (drag it to fill the
# screen / use the window's full-screen control), then run `shot`. iPhone apps
# are always full screen, so no maximizing is needed there.
#
# Usage:
#   tools/ios/capture-screenshots.sh boot  <iphone|ipad>          boot the sim + install the latest build + launch
#   tools/ios/capture-screenshots.sh menu  <iphone|ipad>          boot+launch, wait, auto-capture the MS menu
#   tools/ios/capture-screenshots.sh shot  <iphone|ipad> <name>   capture the CURRENT screen (for in-world shots)
#
# The login, world, HUD and math-activity shots must be captured with `shot`
# after you have navigated there yourself (this script never types credentials).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BID="com.stemblocks.matematicasuperpiatta"
OUT_ROOT="$REPO_ROOT/appstore-screenshots"

IPHONE_MODEL="iPhone 17 Pro Max"   # 6.9"
IPAD_MODEL="iPad Pro 13-inch"      # 13"   (matches M4/M5/... — first iOS-26 match)
IPHONE_W=2868; IPHONE_H=1320
IPAD_W=2752;   IPAD_H=2064

die() { echo "error: $*" >&2; exit 1; }

# Resolve a device UDID by model name under the iOS 26 runtime (booted or not).
udid_for() {
	local model="$1"
	xcrun simctl list devices \
		| awk '/-- iOS 26/{f=1} /-- iOS 18/{f=0} f' \
		| grep -F "$model" | grep -oE '[0-9A-Fa-f-]{36}' | head -1
}

resolve() {
	case "$1" in
		iphone) MODEL="$IPHONE_MODEL"; TW=$IPHONE_W; TH=$IPHONE_H ;;
		ipad)   MODEL="$IPAD_MODEL";   TW=$IPAD_W;   TH=$IPAD_H ;;
		*) die "unknown device '$1' (use iphone|ipad)" ;;
	esac
	UDID="$(udid_for "$MODEL")"
	[ -n "$UDID" ] || die "no iOS-26 simulator matching '$MODEL' found (xcrun simctl list devices)"
	DEV="$1"
}

latest_app() {
	# Prefer a Release build if present, else the Debug simulator build.
	local app
	app="$(/bin/ls -dt "$REPO_ROOT"/build-ios-simulator*/build/*-iphonesimulator/luanti.app 2>/dev/null | head -1)"
	[ -n "$app" ] || die "no built luanti.app found — build the simulator target first"
	echo "$app"
}

boot_and_launch() {
	local app; app="$(latest_app)"
	open -a Simulator >/dev/null 2>&1 || true
	xcrun simctl boot "$UDID" 2>/dev/null || true
	local i=0; until xcrun simctl list devices | grep "$UDID" | grep -q Booted || [ $i -ge 30 ]; do sleep 1; i=$((i+1)); done
	xcrun simctl terminate "$UDID" "$BID" 2>/dev/null || true
	xcrun simctl install "$UDID" "$app"
	xcrun simctl launch "$UDID" "$BID" >/dev/null
	echo "launched $BID on $MODEL ($UDID)"
	echo "  app: $app"
}

capture() {
	local name="$1"
	local dir="$OUT_ROOT/$DEV"
	mkdir -p "$dir"
	local raw="$dir/.raw_$name.png"
	local out="$dir/$name.png"
	xcrun simctl io "$UDID" screenshot "$raw" >/dev/null
	# The landscape-locked app renders rotated inside a portrait framebuffer;
	# rotate 270° CW to bring it upright at the landscape pixel size.
	sips -r 270 "$raw" >/dev/null 2>&1
	local w h
	w="$(sips -g pixelWidth  "$raw" | awk '/pixelWidth/{print $2}')"
	h="$(sips -g pixelHeight "$raw" | awk '/pixelHeight/{print $2}')"
	if [ "$w" != "$TW" ] || [ "$h" != "$TH" ]; then
		rm -f "$raw"
		die "captured ${w}x${h}, expected ${TW}x${TH} for $DEV — wrong device orientation or model."
	fi
	mv "$raw" "$out"
	echo "saved $out  (${w}x${h})"
}

CMD="${1:-}"; shift || true
case "$CMD" in
	boot)  resolve "${1:?device}"; boot_and_launch ;;
	menu)  resolve "${1:?device}"; boot_and_launch; echo "waiting for menu…"; sleep 8; capture "01-menu" ;;
	shot)  resolve "${1:?device}"; capture "${2:?name}" ;;
	*) sed -n '2,30p' "$0"; exit 2 ;;
esac
