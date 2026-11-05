#!/bin/sh
# TENNIS II build: needs python3 + Pillow, and either sjasmplus on your PATH
# (or SJASMPLUS=/path/to/sjasmplus) or the bundled Python assembler tools/zasm.py.
set -e
cd "$(dirname "$0")"
mkdir -p ../build
python3 gen.py
if command -v "${SJASMPLUS:-sjasmplus}" >/dev/null 2>&1; then
    ${SJASMPLUS:-sjasmplus} --nologo --msg=war --sym=../build/tennis2.sym main.asm
else
    python3 ../tools/zasm.py main.asm --sym ../build/tennis2.sym
fi
python3 mkvz.py tennis2.bin ../build/TENNIS2.VZ "TENNIS II" 8000
