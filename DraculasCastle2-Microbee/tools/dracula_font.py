"""Original 7x10 angular display alphabet inspired by the supplied Dracula sample.

Hand-drawn pixels, not extracted font software. One blank column and bottom
scanline keep 8x11 PCG text readable. Lowercase uses the same small capitals.
"""
from PIL import Image

ROWS = {
 'A':'18 3c 66 66 7e 66 66 66 66 24',
 'B':'7c 66 66 66 7c 66 66 66 66 3c',
 'C':'7e 66 60 60 60 60 60 60 66 3c',
 'D':'78 6c 66 66 66 66 66 66 6c 78',
 'E':'7e 60 60 60 7c 60 60 60 66 3c',
 'F':'7e 60 60 60 7c 60 60 60 60 20',
 'G':'7e 66 60 60 6e 66 66 66 66 3c',
 'H':'66 66 66 66 7e 66 66 66 66 24',
 'I':'3c 18 18 18 18 18 18 18 18 3c',
 'J':'0e 06 06 06 06 06 06 66 66 3c',
 'K':'66 66 66 6c 78 6c 66 66 66 24',
 'L':'60 60 60 60 60 60 60 60 62 7e',
 'M':'66 7e 7e 5a 5a 42 42 42 42 42',
 'N':'66 76 76 7e 6e 6e 66 66 66 24',
 'O':'7e 66 66 66 66 66 66 66 66 3c',
 'P':'7c 66 66 66 7c 60 60 60 60 20',
 'Q':'7e 66 66 66 66 66 66 6e 3c 06',
 'R':'7c 66 66 66 7c 6c 66 66 66 24',
 'S':'7e 66 60 60 3c 06 06 06 66 3c',
 'T':'7e 18 18 18 18 18 18 18 18 08',
 'U':'66 66 66 66 66 66 66 66 66 3c',
 'V':'66 66 66 66 66 66 66 6c 78 60',
 'W':'42 42 42 42 42 5a 5a 7e 7e 24',
 'X':'66 66 66 3c 18 3c 66 66 66 24',
 'Y':'66 66 66 66 3c 18 18 18 18 08',
 'Z':'7e 06 06 0c 18 30 60 60 66 3c',
 '0':'3c 66 66 6e 7e 76 66 66 66 3c',
 '1':'38 18 18 18 18 18 18 18 18 10',
 '2':'7e 66 06 0c 18 30 60 60 66 3e',
 '3':'7e 06 06 0c 1c 06 06 06 66 3c',
 '4':'66 66 66 66 3e 06 06 06 06 02',
 '5':'7e 60 60 60 7c 06 06 06 66 3c',
 '6':'7e 60 60 60 7c 66 66 66 66 3c',
 '7':'7e 06 06 0c 18 18 18 18 18 10',
 '8':'3c 66 66 66 3c 66 66 66 66 3c',
 '9':'3c 66 66 66 3e 06 06 06 06 02',
}
PUNCT = {
 ' ':'00 00 00 00 00 00 00 00 00 00',
 '.':'00 00 00 00 00 00 00 18 18 00',
 ',':'00 00 00 00 00 00 18 18 10 20',
 ':':'00 00 18 18 00 00 18 18 00 00',
 ';':'00 00 18 18 00 00 18 18 10 20',
 "'":'18 18 10 00 00 00 00 00 00 00',
 '"':'36 36 24 00 00 00 00 00 00 00',
 '!':'18 18 18 18 18 18 00 18 18 00',
 '?':'3c 66 06 0c 18 18 00 18 18 00',
 '-':'00 00 00 00 7e 00 00 00 00 00',
 '=':'00 00 00 7e 00 7e 00 00 00 00',
 '+':'00 00 18 18 7e 18 18 00 00 00',
 '/':'06 06 0c 0c 18 18 30 30 60 60',
 '\\':'60 60 30 30 18 18 0c 0c 06 06',
 '*':'00 24 18 7e 18 24 00 00 00 00',
 '>':'00 60 30 18 0c 18 30 60 00 00',
 '<':'00 06 0c 18 30 18 0c 06 00 00',
 '(':'0c 18 30 30 30 30 30 18 0c 00',
 ')':'30 18 0c 0c 0c 0c 0c 18 30 00',
 '[':'3c 30 30 30 30 30 30 30 3c 00',
 ']':'3c 0c 0c 0c 0c 0c 0c 0c 3c 00',
 '@':'00 36 7e 7e 7e 3c 18 00 00 00',
 '%':'62 66 0c 18 30 66 46 00 00 00',
 '&':'38 6c 6c 38 76 66 66 3e 00 00',
 '_':'00 00 00 00 00 00 00 00 7e 00',
 '#':'24 24 7e 24 24 7e 24 24 00 00',
 '$':'18 3e 60 60 3c 06 06 7c 18 00',
 '^':'18 3c 66 00 00 00 00 00 00 00',
 '|':'18 18 18 18 18 18 18 18 18 18',
 '~':'00 00 32 7e 4c 00 00 00 00 00',
}

def rows(char):
    char={'`':"'",'{':'[','}':']',chr(127):'?'}.get(char,char.upper())
    values=bytes(int(v,16)<<1 for v in (ROWS|PUNCT).get(char,PUNCT['?']).split())
    assert len(values)==10
    return values+bytes(6)

def pcg():
    return b''.join(rows(chr(c)) for c in range(32,128))

def mask(text,height=11):
    image=Image.new('L',(max(1,len(text)*8-1),11))
    for i,ch in enumerate(text):
        for y,bits in enumerate(rows(ch)[:11]):
            for x in range(8):
                if bits & (128>>x):image.putpixel((i*8+x,y),255)
    width=max(1,round(image.width*height/11))
    return image.resize((width,height),Image.Resampling.NEAREST)

def draw(image,xy,text,height=11,fill=(255,255,255),center=False):
    bitmap=mask(text,height)
    x,y=xy
    if center:x-=bitmap.width//2
    image.paste(fill,(x,y,x+bitmap.width,y+bitmap.height),bitmap)
