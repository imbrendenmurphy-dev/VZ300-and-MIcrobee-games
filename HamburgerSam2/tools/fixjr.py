#!/usr/bin/env python3
"""build loop helper: promote 'jr' to 'jp' wherever the assembler reports
'relative jump out of range', until the build succeeds or another error appears."""
import re, subprocess, sys
for _ in range(200):
    r = subprocess.run(["python3", "../tools/zasm.py", "main.asm", "--sym", "../build/hamsam2.sym"],
                       capture_output=True, text=True)
    out = r.stdout + r.stderr
    m = re.search(r"([\w/.\-]+\.asm):(\d+): relative jump out of range", out)
    if not m:
        print(out.strip()[-1500:])
        sys.exit(r.returncode)
    fn, ln = m.group(1), int(m.group(2))
    L = open(fn).read().split("\n")
    L[ln - 1] = re.sub(r"\bjr\b", "jp", L[ln - 1], count=1)
    open(fn, "w").write("\n".join(L))
    print("jr->jp", fn.split('/')[-1], ln)
