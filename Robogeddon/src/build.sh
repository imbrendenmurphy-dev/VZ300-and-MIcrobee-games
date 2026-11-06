#!/bin/sh
# ROBOGEDDON build: needs python3 and sjasmplus on your PATH (or SJASMPLUS=/path/to/sjasmplus)
set -e
cd "$(dirname "$0")"
mkdir -p ../build
python3 gfx.py gfx.inc
python3 music.py music.inc
${SJASMPLUS:-sjasmplus} --nologo --msg=war --sym=../build/robogedn.sym main.asm
python3 mkvz.py robogedn.bin ../build/ROBOGEDN.VZ "ROBOGEDDON" 8000
