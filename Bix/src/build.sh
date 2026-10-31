#!/bin/sh
set -e
cd "$(dirname "$0")"
python3 tools/build_assets.py
python3 tools/music.py
python3 tools/demo.py
asm() { (cd src && /root/tools/sjasmplus/sjasmplus --nologo --msg=war --fullpath --sym=../build/bix.sym main.asm > ../build/asm.log 2>&1); }
[ -f build/ovl.lz ] || head -c 1 /dev/zero > build/ovl.lz
asm || true                                   # pass 1: produces ovl.bin
python3 -c "import sys;sys.path.insert(0,'tools');import lz;d=open('build/ovl.bin','rb').read();open('build/ovl.lz','wb').write(lz.compress(d))"
asm || true                                   # pass 2: final image with the packed overlay
cat build/asm.log
if grep -q "error" build/asm.log; then exit 1; fi
python3 tools/mkvz.py build/bix.bin build/BIX.VZ BIX
