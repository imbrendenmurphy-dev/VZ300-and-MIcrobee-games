#!/bin/sh
export PATH=/home/claude/bin:$PATH
cd /home/claude/gh3/src
python3 gen.py > /dev/null && sjasmplus --nologo --sym=../build/gh3.sym main.asm 2>&1 | grep -v "^Pass\|^Errors: 0" && python3 mkvz.py gh3.bin ../build/GHOST3.VZ "GHOST HUNTER 3D" 8000
grep "^frame_wait.low:" ../build/gh3.sym | sed 's/.*0x0000//' > ../build/fw.txt
