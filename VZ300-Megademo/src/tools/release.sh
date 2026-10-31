#!/bin/bash
# build the five effect tests, the full demo and RASTEST into build/release
set -e -o pipefail
cd /root/vzmega
R=build/release; mkdir -p $R
b() { python3 tools/build.py "$@" 2>&1 | grep -E "error|DAT:" ; }
b p3  STARTORD=14 LOOPTEST=1 NAME=FXKEFREN && cp build/FXKEFREN.VZ build/FXKEFREN.DAT $R/
b p2  STARTORD=6  LOOPTEST=1 NAME=FXPLASMA && cp build/FXPLASMA.VZ build/FXPLASMA.DAT $R/
b p4a STARTORD=22 LOOPTEST=1 NAME=FX3DCUBE && cp build/FX3DCUBE.VZ build/FX3DCUBE.DAT $R/
b p4b STARTORD=26 LOOPTEST=1 NAME=FXTUNNEL && cp build/FXTUNNEL.VZ build/FXTUNNEL.DAT $R/
b p5a,p5b STARTORD=30 LOOPTEST=1 NAME=FXSEMIGR && cp build/FXSEMIGR.VZ build/FXSEMIGR.DAT $R/
b p1,p2,p3,p4a,p4b,p5a,p5b,p6 NAME=VZMEGA && cp build/VZMEGA.VZ build/VZMEGA.DAT $R/
cd src && ../tools/sjasmplus --nologo --msg=war --sym=../build/rastest.sym --lst=../build/rastest.lst rastest.asm | grep -i error || true
python3 ../tools/mkvz.py ../build/rastest.bin ../build/release/RASTEST.VZ RASTEST 0x8000
ls -la ../build/release
