"""Build VZ-ED: out/VZED.VZ (run from VZ-DECK) and out/PLAYTXT.VZ (VZ-DECK plug-in for .TXT).
Needs Python 3 only.  The assembler is tools/zasm.py."""
import os, sys, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import gen

def build():
    gen.gen_vars(); gen.gen_tables()
    os.makedirs(os.path.join(ROOT, 'out'), exist_ok=True)
    binf = os.path.join(ROOT, 'out', 'vzed.bin'); symf = os.path.join(ROOT, 'out', 'vzed.sym')
    r = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'zasm.py'), 'vzed.asm',
                        '-o', binf, '--sym', symf, '--lst', os.path.join(ROOT, 'out', 'vzed.lst'),
                        '--start', '0xA000'], cwd=HERE, capture_output=True, text=True)
    print(r.stdout.strip(), r.stderr.strip())
    if r.returncode or 'ERROR' in r.stdout: sys.exit(1)
    sym = {}
    for line in open(symf):
        a, n = line.split(); sym[n] = int(a, 16)
    code = bytearray(open(binf, 'rb').read())
    code = code[:sym['code_end'] - 0xA000]
    assert code[3] == 0
    def vz(name, body):
        return b'VZF0' + name.encode().ljust(17, b'\0') + b'\xf1' + bytes([0x00, 0xA0]) + bytes(body)
    open(os.path.join(ROOT, 'out', 'VZED.VZ'), 'wb').write(vz('VZ-ED', code))
    plug = bytearray(code); plug[3] = 1
    open(os.path.join(ROOT, 'out', 'PLAYTXT.VZ'), 'wb').write(vz('VZ-ED', plug))
    print('code $A000-$%04X (%d bytes), text buffer $%04X-$F5FF (%d bytes)' % (
        sym['code_end'] - 1, len(code), sym['BUFS'], 0xF600 - sym['BUFS']))
    return sym

if __name__ == '__main__':
    build()
