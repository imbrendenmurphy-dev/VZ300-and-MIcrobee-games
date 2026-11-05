#!/bin/sh
# uB-TYPE build: data + art generators, then the Z80 assembler
set -e
cd "$(dirname "$0")"
mkdir -p build
python3 tools/mkdata.py
[ -f tools/mkfront.py ] && python3 tools/mkfront.py
cd src && python3 ../tools/zasm.py main.asm --sym=../build/main.sym
