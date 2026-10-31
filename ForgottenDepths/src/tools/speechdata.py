"""Speech phrases for THE FORGOTTEN DEPTHS (1-bit, 15556 Hz)."""
import os
import speech
PHRASES = [('title', 'The forgotten depths', dict(speed=125, pitch=30)),
           ('warden', 'The bone warden', dict(speed=130, pitch=25)),
           ('king', 'The drowned king', dict(speed=130, pitch=25)),
           ('wyrm', 'The ember wyrm', dict(speed=130, pitch=25)),
           ('end', 'The ember burns again', dict(speed=130, pitch=40))]
HB0, HB1 = 0xC000, 0xFA00

def build(out):
    blob = bytearray()
    table = []
    for n, t, kw in PHRASES:
        b, d = speech.make(t, os.path.join(out, f'sp_{n}.wav'), **kw)
        table.append((n, HB0 + len(blob), len(b)))
        blob += b
    assert HB0 + len(blob) <= HB1, len(blob)
    return bytes(blob), table
