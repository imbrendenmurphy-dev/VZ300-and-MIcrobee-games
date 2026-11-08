#!/bin/sh
# Build ASTEROIDS II -> ../build/AST2.VZ
# needs python3 (+ Pillow) and sjasmplus (https://github.com/z00m128/sjasmplus) on the PATH
set -e
cd "$(dirname "$0")"
mkdir -p ../build
python3 tools/gen_assets.py
python3 tools/gen_tables.py >/dev/null
python3 tools/gen_music.py
${SJASMPLUS:-sjasmplus} --nologo --msg=war --sym=../build/ast2.sym --lst=../build/ast2.lst main.asm
python3 tools/mkvz.py ../build/ast2.bin ../build/AST2.VZ "ASTEROIDS II" 0x8000
