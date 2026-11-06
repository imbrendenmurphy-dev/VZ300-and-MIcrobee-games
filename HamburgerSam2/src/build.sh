#!/bin/sh
# HAMBURGER SAM II build: needs python3 + Pillow, and either sjasmplus on your PATH
# (or SJASMPLUS=/path/to/sjasmplus) or the bundled Python assembler tools/zasm.py.
set -e
cd "$(dirname "$0")"
mkdir -p ../build ../release
python3 gen.py
if command -v "${SJASMPLUS:-sjasmplus}" >/dev/null 2>&1; then
    ${SJASMPLUS:-sjasmplus} --nologo --msg=war --sym=../build/hamsam2.sym main.asm
else
    python3 ../tools/zasm.py main.asm --sym ../build/hamsam2.sym
fi
python3 mkvz.py hamsam2.bin ../release/HAMSAM2.VZ "HAMSAM II" 8000
