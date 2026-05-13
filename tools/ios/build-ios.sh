#!/bin/bash
set -euo pipefail

# Genera ex-novo le due build dir iOS (simulator + device) usando
# le deps gia' precompilate sotto luanti_ios_deps/ios18.2_deps/.
# Lo script wrapper viene invocato con step=build: niente clone,
# niente rebuild deps, solo cmake .. + generazione di luanti.xcodeproj.
#
# Lo script vive in tools/ios/ ma opera dalla root del repo: deps,
# luanti_ios_deps/ e le build dir restano dove sono sempre state.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"

DEPS_SIM="$ROOT/luanti_ios_deps/ios18.2_deps/iPhoneSimulator"
DEPS_DEV="$ROOT/luanti_ios_deps/ios18.2_deps/iPhoneOS"

if [ ! -d "$DEPS_SIM/bin" ] || [ ! -d "$DEPS_DEV/bin" ]; then
  echo "ERRORE: deps precompilate non trovate sotto luanti_ios_deps/ios18.2_deps/"
  echo "Attese: $DEPS_SIM e $DEPS_DEV"
  exit 1
fi

for d in build-ios-simulator build-ios-device; do
  if [ -e "$d" ]; then
    echo "ERRORE: '$d' esiste gia'. Rimuovilo o spostalo prima di lanciare lo script."
    exit 1
  fi
done

echo "==== Genera build-ios-simulator ===="
"$SCRIPT_DIR/ios_build_with_deps_ios26-v2.sh" \
  "" "" "$ROOT" "$DEPS_SIM" \
  Debug iPhoneSimulator 26 build build-ios-simulator

echo
echo "==== Genera build-ios-device ===="
"$SCRIPT_DIR/ios_build_with_deps_ios26-v2.sh" \
  "" "" "$ROOT" "$DEPS_DEV" \
  Debug iPhoneOS 26 build build-ios-device

echo
echo "Fatto. Apri build-ios-simulator/luanti.xcodeproj da Xcode."
