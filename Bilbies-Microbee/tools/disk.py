"""DS80 raw image: 80 cylinders, 2 heads, 10 x 512-byte sectors.

System tracks and CCP.SYS are copied from an owner-supplied compatible disk.
No shell or other game files are copied. Uses the repository's 3:1 skew.
"""
from pathlib import Path
import argparse
import json

SIZE = 80 * 2 * 10 * 512
SKEW = (1, 4, 7, 0, 3, 6, 9, 2, 5, 8)


def logical(raw):
    if len(raw) != SIZE:
        raise ValueError('Expected 819200-byte raw DS80 disk')
    b = bytearray(SIZE)
    for t in range(160):
        for s, k in enumerate(SKEW):
            b[t*5120+s*512:t*5120+(s+1)*512] = raw[t*5120+k*512:t*5120+(k+1)*512]
    return b


def physical(b):
    out = bytearray(SIZE)
    for t in range(160):
        for s, k in enumerate(SKEW):
            out[t*5120+k*512:t*5120+(k+1)*512] = b[t*5120+s*512:t*5120+(s+1)*512]
    return out


def files(raw):
    b = logical(raw)
    entries = {}
    for off in range(20480, 20480+2048, 32):
        e = b[off:off+32]
        if e[0] != 0:
            continue
        name = bytes(x & 127 for x in e[1:9]).decode('ascii').strip()
        ext = bytes(x & 127 for x in e[9:12]).decode('ascii').strip()
        data = b''.join(b[20480+k*4096:20480+(k+1)*4096] for k in e[16:32] if k)
        records = ((e[12] & 1)*128 + e[15])
        entries.setdefault(name+'.'+ext, []).append((e[12]//2, data[:records*128]))
    return {name: b''.join(data for _, data in sorted(extents)) for name, extents in entries.items()}


def build(base, payload):
    b = bytearray([0xE5])*SIZE
    b[:20480] = logical(base)[:20480]
    block, directory = 1, 0
    for name, data in payload.items():
        if name.upper().startswith('SHELL'):
            raise ValueError('Microbee Shell prohibited')
        if len(data) > 32768:
            raise ValueError('Writer currently supports one physical extent per file')
        stem, ext = name.split('.')
        count = (len(data)+4095)//4096
        if block+count > 195 or directory >= 64:
            raise ValueError('Disk full')
        records = (len(data)+127)//128
        e = bytearray(32)
        e[1:12] = (stem.ljust(8)+ext.ljust(3)).encode('ascii')
        e[12] = (records-1)//128 if records else 0
        e[15] = records-e[12]*128
        e[16:16+count] = bytes(range(block,block+count))
        b[20480+directory*32:20480+(directory+1)*32] = e
        off = 20480+block*4096
        b[off:off+len(data)] = data
        block += count
        directory += 1
    result = bytes(physical(b))
    recovered = files(result)
    for name, data in payload.items():
        assert recovered[name][:len(data)] == data, name
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--base', type=Path, required=True)
    args = p.parse_args()
    root = Path(__file__).resolve().parents[1]
    b = root/'build'
    base = args.base.read_bytes()
    save = bytearray(4096)
    save[:16] = b'BILBIES-BEE-SAVE'
    payload = {'SAVE.DAT': bytes(save), 'CCP.SYS': files(base)['CCP.SYS'],
               'BILBIES.COM': (b/'BILBIES.COM').read_bytes(),
               'BILBIES.HI': (b/'BILBIES.HI').read_bytes(),
               'PCG.BNK': (b/'PCG.BNK').read_bytes(),
               'LEVELS.BNK': bytes(16384)+(b/'levels.bin').read_bytes(),
               'README.TXT': b'BILBIES NATIVE BRING-UP - EXPERIMENTAL\r\nType BILBIES at A>. Choose C or M, then SPACE.\r\nG: display settings. QAOP/arrows: cursor. SPACE: action.\r\nX/Z: skills. 1-8: direct skills. H: pause. NN: nuke.\r\nComma/period: rate. CTRL-Q: abandon.\r\nPrototype runs too slowly. No mouse or per-pixel scrolling yet.\r\nProgress/preferences use the preallocated SAVE.DAT on this disk.\r\nDo not move/delete SAVE.DAT; keep a backup of your disk.\r\nNot a finished release. See project README.\r\n\x1a'}
    out = b/'BILBIES.DS8'
    out.write_bytes(build(base,payload))
    print(json.dumps({'image':str(out),'bytes':out.stat().st_size,
                      'files':{k:len(v) for k,v in payload.items()}},indent=2))
