#!/usr/bin/env python3
# capture: run the emulator, keep every frame as a small 4:3 PNG (256x192) for GIFs / picking stills
import os, subprocess, sys, glob
from PIL import Image
vz, inp, name, a, b, step = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6])
out = 'cap/'+name; os.makedirs(out, exist_ok=True)
for f in glob.glob(out+'/*'): os.remove(f)
fields = list(range(a, b, step))
for k in range(0, len(fields), 120):
    chunk = fields[k:k+120]
    cmd = ['tools/vzemu', vz, '-S', 'build/sd', '-f', str(chunk[-1]+1), '-s', ','.join(map(str, chunk)), '-p', out+'/r']
    if inp != '-': cmd += ['-i', inp]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for f in chunk:
        p = '%s/r_%04d.ppm' % (out, f)
        if os.path.exists(p):
            im = Image.open(p).convert('RGB')
            im.resize((512, 384), Image.NEAREST).save('%s/big_%05d.png' % (out, f))
            os.remove(p)
print(name, len(glob.glob(out+'/big_*')))
