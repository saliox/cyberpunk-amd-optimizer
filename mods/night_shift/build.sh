#!/usr/bin/env bash
# Construit l'archive Nexus de NIGHT SHIFT, prête à extraire à la racine du
# jeu (ou à installer via Vortex) : la structure bin/x64/... est incluse.
# N'embarque que init.lua + README.md (ni tests, ni sources nexus/).
# Usage : ./build.sh [version]   (défaut : lue dans init.lua)
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-$(grep -oP 'NIGHT SHIFT \K[0-9]+\.[0-9]+(\.[0-9]+)?' init.lua | head -1)}"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

DEST="$STAGE/bin/x64/plugins/cyber_engine_tweaks/mods/night_shift"
mkdir -p "$DEST"
cp init.lua README.md "$DEST/"

OUT="$PWD/NIGHT-SHIFT-$VERSION.zip"
rm -f "$OUT"
(cd "$STAGE" && zip -r -q "$OUT" bin)
echo "OK : $OUT"
unzip -l "$OUT"
