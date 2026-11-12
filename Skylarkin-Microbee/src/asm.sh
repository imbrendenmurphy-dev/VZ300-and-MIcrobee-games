#!/bin/sh
cd "$(dirname "$0")/src" && python3 ../tools/zasm.py main.asm --sym=../build/main.sym 2>&1 | head -5
