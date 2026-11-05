#!/bin/sh
# EMPIRES build script
set -e
cd "$(dirname "$0")"
python3 art/mkart.py
cd src && python3 ../tools/zasm.py main.asm ../build/EMPIRES.COM ../build/empires.sym
python3 ../tools/zasm.py mousetest.asm ../build/MOUSE.COM
cd .. && python3 tools/build_disk.py
