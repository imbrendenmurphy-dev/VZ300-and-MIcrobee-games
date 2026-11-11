"""Expanded-RAM pilot: eight distinct floating/blinking Ghost idle poses."""
from pathlib import Path
from PIL import ImageDraw
import native_art as art
import native_detail,dracula_font

ROOT=Path(__file__).resolve().parent.parent
def build():
    out=ROOT/'build/native'
    for variant in ('monster','battle'):
        for mode in ('colour','mono'):
            for phase in range(8):
                im=art.backdrop(1,mode=='mono').crop((0,0,320,256))
                sp=native_detail.ghost(art.PAL,0,phase)
                im.paste(sp,(80,18),sp)
                d=ImageDraw.Draw(im);d.rectangle((0,200,319,255),fill=(0,0,0))
                if variant=='monster':
                    dracula_font.draw(im,(12,207),'GHOST',22,tuple(art.PAL[15]))
                    dracula_font.draw(im,(12,239),'SPACE: NEXT   P: BACK',11,tuple(art.PAL[11]))
                else:
                    d.line((1,199,318,199),fill=tuple(art.PAL[11]));d.line((1,249,318,249),fill=tuple(art.PAL[11]))
                    d.line((1,199,1,249),fill=tuple(art.PAL[11]));d.line((318,199,318,249),fill=tuple(art.PAL[11]))
                    for x in (5,310):
                        for y in (204,220,236):d.polygon([(x,y),(x+3,y+4),(x,y+8),(x-3,y+4)],outline=tuple(art.PAL[12]))
                raw,pic=art.encode(im,mode=='mono',8)
                stem=f'anim-{variant}03-{phase}-{mode}'
                (out/(stem+'.raw')).write_bytes(raw);pic.save(out/(stem+'.png'))
    (out/'animation.stamp').write_text('8 distinct Ghost idle frames, both modes and presentations')

if __name__=='__main__':build()
