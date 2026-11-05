#!/bin/sh
# copy the project into the GitHub repo folder and the PC drop folder
set -e
SRC=/home/claude/ubtype
REPO=/home/claude/vz300-and-microbee-games/uB-Type
rm -rf "$REPO/src"; mkdir -p "$REPO/src" "$REPO/screenshots" "$REPO/release"
(cd "$SRC" && tar cf - --exclude=.git --exclude=build --exclude=__pycache__ --exclude='*.so' .) | (cd "$REPO/src" && tar xf -)
[ -d "$SRC/docs/screenshots" ] && cp -r "$SRC/docs/screenshots/." "$REPO/screenshots/"
[ -d "$SRC/release" ] && cp -r "$SRC/release/." "$REPO/release/"
cp "$SRC/docs/README.md" "$REPO/README.md"
OUT=/mnt/user-data/outputs/uBType_Microbee
mkdir -p "$OUT"
rm -f "$OUT/uBType_source.zip"
(cd "$SRC/.." && zip -qr "$OUT/uBType_source.zip" ubtype -x 'ubtype/build/*' 'ubtype/.git/*' '*/__pycache__/*' '*.so')
cp "$SRC/docs/README.md" "$OUT/README.md"
[ -d "$SRC/docs/screenshots" ] && cp -r "$SRC/docs/screenshots" "$OUT/" || true
