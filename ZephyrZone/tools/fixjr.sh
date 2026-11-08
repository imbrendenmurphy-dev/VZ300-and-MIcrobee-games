#!/bin/bash
# build; convert any out-of-range jr to jp and rebuild (up to 30 times)
for i in $(seq 1 30); do
  out=$(python3 tools/build.py "$@" 2>&1)
  l=$(echo "$out" | grep -o "[a-z0-9_/.]*\.\(asm\|inc\):[0-9]*: relative jump out of range" | tail -1)
  if [ -z "$l" ]; then echo "$out" | tail -14; exit 0; fi
  f=$(echo "$l" | cut -d: -f1); n=$(echo "$l" | cut -d: -f2)
  sed -i "${n}s/\bjr\b/jp/" "$f"; echo "fixed $f:$n"
done
