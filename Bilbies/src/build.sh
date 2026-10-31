#!/bin/sh
set -e
cd "$(dirname "$0")"
python3 tools/gen.py
cd src && sjasmplus --nologo --sym=../build/vz.sym --lst=../build/vz.lst main.asm > ../build/asm.log 2>&1 || true
grep -q "Errors: 0" ../build/asm.log || { grep -i -B1 "error" ../build/asm.log | head -40; exit 1; }; grep "code end" ../build/asm.log; cd ..
python3 tools/package.py
