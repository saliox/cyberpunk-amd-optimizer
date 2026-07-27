#!/usr/bin/env bash
# Construit l'archive Nexus de BETTER MIX, prête à extraire à la racine du jeu
# (ou à installer via Vortex). N'embarque que init.lua + README.
# Usage : ./build.sh [version]   (défaut : lue dans init.lua)
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-$(grep -oP 'BETTER MIX \K[0-9]+\.[0-9]+(\.[0-9]+)?' init.lua | head -1)}"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

DEST="$STAGE/bin/x64/plugins/cyber_engine_tweaks/mods/better_mix"
mkdir -p "$DEST"
cp init.lua README.md "$DEST/"

OUT="$PWD/BETTER-MIX-$VERSION.zip"
rm -f "$OUT"
(cd "$STAGE" && zip -r -q "$OUT" bin)
echo "OK : $OUT"
unzip -l "$OUT"
