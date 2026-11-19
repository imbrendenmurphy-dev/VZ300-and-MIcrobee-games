#!/bin/sh
# REDBACK build: data banks, then the engine (symbols and listing for the tests)
set -e
cd "$(dirname "$0")"
python3 tools/makedata.py
cd src
python3 ../tools/zasm.py redback.asm --sym=../build/redback.sym --lst=../build/redback.lst
ls -l ../build/REDBACK.BIN
python3 ../tools/zasm.py loader.asm
cd ..
python3 tools/mkdisk.py
