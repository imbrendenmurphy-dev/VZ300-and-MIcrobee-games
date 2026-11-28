"""Download pinned Windows assembler/compressor into this project only."""
from pathlib import Path
import hashlib
import io
import urllib.request
import zipfile

R=Path(__file__).resolve().parents[1]
T=R/'.tools'
T.mkdir(exist_ok=True)


def verify(data, expected):
    if hashlib.sha256(data).hexdigest()!=expected:
        raise ValueError('Tool checksum mismatch')


data=urllib.request.urlopen('https://github.com/z00m128/sjasmplus/releases/download/v1.20.3/sjasmplus-1.20.3.win.zip').read()
z=zipfile.ZipFile(io.BytesIO(data))
exe=z.read(next(n for n in z.namelist() if n.endswith('/sjasmplus.exe')))
verify(exe,'ba25c8dd6ea8a3a16ce2d173d768700e576375173f3a678580c7d055b5438bb6')
(T/'sjasmplus.exe').write_bytes(exe)
exe=urllib.request.urlopen('https://raw.githubusercontent.com/einar-saukas/ZX0/ecde3a2ae05061fe06469ed46df81a33b7de7d86/win/zx0.exe').read()
verify(exe,'e6aec5cdfc3535b808610cb54412ce375b5b13e17b59f2bc878a54a00a8acbac')
(T/'zx0.exe').write_bytes(exe)
print('Pinned tools verified in',T)
