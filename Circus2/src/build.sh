#!/bin/sh
# Circus 2 build: python3 (+Pillow) and sjasmplus
set -e
cd "$(dirname "$0")"
mkdir -p build
python3 tools/mkgfx.py build/gfx.inc
(cd asm && sjasmplus --nologo --msg=war --lst=../build/circus2.lst main.asm)
python3 tools/mkvz.py build/circus2.bin build/CIRCUS2.VZ "CIRCUS 2" 8000
