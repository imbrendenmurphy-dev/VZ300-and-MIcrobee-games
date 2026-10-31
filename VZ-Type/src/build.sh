#!/bin/sh
# VZ-TYPE build: data generators, then assemble until the packed front-end overlay is stable
cd "$(dirname "$0")" || exit 1
python3 gen.py >/dev/null && python3 fgen.py >/dev/null || exit 1
[ -f ovl.pak ] || printf '\000' > ovl.pak
for i in 1 2 3 4 5; do
  sjasmplus --nologo --sym=sym.txt main.asm > asm.log 2>&1
  python3 -c "
import sys; sys.path.insert(0,'.'); import lzb
d=open('ovl.bin','rb').read(); p=lzb.pack(d); assert lzb.unpack(p)==d
old=open('ovl.pak','rb').read()
open('ovl.pak','wb').write(p); sys.exit(0 if p==old else 1)" 2>/dev/null && break
done
grep -E "error|warning|free at top|overlay size" asm.log
python3 mkvz.py vztype.bin VZTYPE.VZ "VZ-TYPE"
