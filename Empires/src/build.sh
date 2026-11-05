#!/bin/sh
# EMPIRES build script: art -> images -> disk
set -e
cd "$(dirname "$0")"
mkdir -p build
python3 art/mkart.py
cd src
python3 ../tools/zasm.py main.asm ../build/main.bin ../build/empires.sym
python3 ../tools/zasm.py loader.asm ../build/EMPIRES.COM ../build/loader.sym
python3 ../tools/zasm.py mousetest.asm ../build/MOUSE.COM
cd .. && python3 tools/build_disk.py
