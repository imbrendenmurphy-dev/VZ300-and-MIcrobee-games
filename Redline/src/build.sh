#!/bin/sh
set -e
cd "$(dirname "$0")"
mkdir -p build release
rm -f release/RL*.DAT
python3 tools/tables.py >/dev/null
python3 tools/font.py >/dev/null
python3 tools/music.py >/dev/null
python3 tools/gen_rline.py
python3 tools/title.py
python3 tools/scenes.py
python3 tools/legs.py > build/legs.txt
(cd src && /home/claude/tools/sjasmplus/sjasmplus --nologo --msg=war --sym=../build/racer.sym --lst=../build/racer.lst main.asm) > build/asm.log 2>&1 || true
grep -E "error|warning|main code|front end" build/asm.log | head -40
if grep -q "error" build/asm.log; then exit 1; fi
python3 tools/package.py
