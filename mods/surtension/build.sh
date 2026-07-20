#!/usr/bin/env bash
# Construit l'archive Nexus de SURTENSION, prête à extraire à la racine du
# jeu (ou à installer via Vortex) : la structure bin/x64/... est incluse.
# Usage : ./build.sh [version]   (défaut : lue dans init.lua)
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-$(grep -oP 'SURTENSION \K[0-9]+\.[0-9]+(\.[0-9]+)?' init.lua | head -1)}"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

DEST="$STAGE/bin/x64/plugins/cyber_engine_tweaks/mods/surtension"
mkdir -p "$DEST/coop"
cp init.lua README.md "$DEST/"
cp coop/relay.js coop/README.md "$DEST/coop/"

OUT="$PWD/SURTENSION-$VERSION.zip"
rm -f "$OUT"
(cd "$STAGE" && zip -r -q "$OUT" bin)
echo "OK : $OUT"
unzip -l "$OUT"
