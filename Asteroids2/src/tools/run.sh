#!/bin/sh
# run.sh <fields> <keys> [extra vzemu options]
# Runs the built game in the vzemu test harness with the standard guards.
# Build the harness first:  cc -O2 -o tools/vzemu tools/vzemu.c tools/z80core/z80.c
# keys: "from:to:KEY,KEY;from:to:KEY"   e.g. "200:204:SPACE;300:400:Z,U"
cd "$(dirname "$0")/.."
S=../build/ast2.sym
sym() { grep "^$1:" $S | sed 's/.*0x0000//' ; }
CE=$(sym code_end); CB=$(sym clear_buf); CK=$(sym check_sram)
F=$1; K=$2; shift 2
tools/vzemu ../build/AST2.VZ --ram bennvenn --frames $F --keys "$K" --sym $S \
  --code 8000-$CE --guard 8000-$CE --sp 7800-7A00 --spskip $CB-$CK \
  --allow pA1,pA2,pB1,pB2,pC1,pC2,mC1,mC2,dr_entry,dr_stride,ds_lastwb "$@"
