"""Boot the actual owner's BN60 ROM and DS8 in the supplied machine model."""
from pathlib import Path
import ppmodel

R = Path(__file__).resolve().parents[1]
OUT = R/'test-output'
OUT.mkdir(exist_ok=True)


def type_text(p, text):
    for c in text:
        key = 'RET' if c == '\r' else c
        p.keys = {ppmodel.KEY[key]}
        p.run_frames(4)
        p.keys = set()
        p.run_frames(4)


if __name__ == '__main__':
    p = ppmodel.PP(rom=(R/'resources/bn60.rom').read_bytes(),
                   disk=(R/'build/BILBIES.DS8').read_bytes())
    p.m.pc = 0x8000
    p.run_frames(60)
    type_text(p,'B')
    for _ in range(80):
        p.run_frames(10)
        if 'A>' in p.text():
            break
    print(p.text(),flush=True)
    assert 'A>' in p.text(), 'CP/M prompt not reached'
    (OUT/'boot-prompt.txt').write_text(p.text())
    type_text(p,'BILBIES\r')
    for _ in range(500):
        p.run_frames(10)
        if p.crtc[1] == 64 and p.crtc[9] == 5:
            break
    print('after launch',hex(p.m.pc),'block',p.lower,'CRTC',p.crtc[:16],flush=True)
    assert p.crtc[1] == 64 and p.crtc[9] == 5, p.text()
    p.run_frames(200)
    p.save_png(OUT/'disk-settings.png',1)
    p.keys = {ppmodel.KEY['SPACE']}
    p.run_frames(100)
    p.keys = set()
    p.run_frames(600)
    p.save_png(OUT/'disk-title.png',1)
    print('PASS: real-ROM/model boot -> CP/M prompt -> BILBIES command -> native title')
