#!/bin/sh
# Builds ../release/KILLTOM2.VZ  (needs sjasmplus and Python 3 with Pillow)
set -e
cd "$(dirname "$0")"
mkdir -p build
python3 build_data.py >/dev/null      # mazes, stages, text, music, sfx, sprites -> gen_data.inc
python3 title_art.py >/dev/null       # giant title tomato -> gen_title.inc
sjasmplus --nologo --sym=build/game.sym main.asm
python3 mkvz.py build/game.bin ../release/KILLTOM2.VZ "KILLER TOMATOES" 8000
