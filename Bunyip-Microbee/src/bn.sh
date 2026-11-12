#!/bin/sh
# Build BUNYIP (VIBED BY BPM 2026)
set -e
cd "$(dirname "$0")"
mkdir -p build
[ build/beemu -nt tools/beemu.c ] || gcc -O2 -o build/beemu tools/beemu.c
python3 tools/gen.py build >/dev/null
python3 tools/art.py build
python3 tools/zones.py build
python3 tools/zasm.py src/main.asm -o build/BN.BIN -l build/main.lst -s build/main.sym
(cd src && python3 ../tools/zasm_sj.py loader.asm --sym=../build/loader.sym)
python3 tools/build_disk.py bunyip
