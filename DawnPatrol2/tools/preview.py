import sys; sys.path.insert(0,'.')
from art import *
from PIL import Image
PAL=[[(0x07,0xff,0x00),(0xff,0xff,0x00),(0x3b,0x08,0xff),(0xcc,0x00,0x3b)],[(0xff,0xff,0xff),(0x07,0xe3,0x99),(0xff,0x1c,0xff),(0xff,0x81,0x00)]]
T=themes()
imgs=[]
for i,t in enumerate(T):
    b=build_theme(t,i)
    for cam in (0,300,600):
        scr=[[t['sky']]*128 for _ in range(54)]
        def put(band,y0,sx):
            W=len(band[0])
            for y,row in enumerate(band):
                for x in range(128):
                    scr[y0+y][x]=row[(x+sx)%W]
        put(b['clouds'],10,cam//8); put(b['mount'],20,cam//4); put(b['hills'],30,cam//2)
        put(b['world'],36,cam); put(b['ground'],48,cam); put(b['fg'],51,cam*2)
        im=Image.new('RGB',(128,54))
        for y in range(54):
            for x in range(128):
                im.putpixel((x,y),PAL[t['css']][scr[y][x]])
        imgs.append(im.resize((512,324),Image.NEAREST))
out=Image.new('RGB',(512*3+8,330*4))
for k,im in enumerate(imgs):
    out.paste(im,((k%3)*516,(k//3)*330))
out.save('/tmp/claude-0/prev.png')
