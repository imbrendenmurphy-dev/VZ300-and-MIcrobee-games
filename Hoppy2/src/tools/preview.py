import sys; sys.path.insert(0,'.')
from art import *
from PIL import Image
PAL=[[(0,200,0),(255,255,0),(0,0,230),(230,0,0)],[(240,240,220),(0,255,255),(255,0,255),(255,140,0)]]
def put(im,art,x0,y0,css=0,bgc=None):
    px=im.load()
    for y,row in enumerate(art):
        for x,c in enumerate(row):
            if c=='.': continue
            px[x0+x,y0+y]=PAL[css]['gybr'.index(c)]
def lane(bg,objs,css=0,mir=False):
    im=Image.new('RGB',(128,6)); put(im,[r*4 for r in BG[bg]],0,0,css)
    x=2
    for o in objs:
        a=[r[::-1] for r in o] if mir else o
        put(im,a,x,0,css); x+=len(o[0])+6
    return im
for css in (0,1):
    W=Image.new('RGB',(128,64),(0,0,0))
    rows=[lane('grass',[]),lane('water',[log(4),[r*3 for r in TURTLE['up']],log(3)],css),
          lane('water2',[CROC,[r*2 for r in TURTLE['warn']],TURTLE['half'],TURTLE['down']],css),
          lane('water',[LILY,FROG['up'],HOPPINA,PICK['bubble'],PICK['snail'],PICK['star'],PICK['heart'],FLY],css),
          lane('median',[SNAKE,SNAKE2,FROG['right'],FROG['rightj'],FROG['upj']],css),
          lane('roadk',[VEH['car'],VEH['beetle'],VEH['racer'],VEH['tractor']],css),
          lane('road',[VEH['truck'],VEH['dozer'],FROG['squash']],css,True),
          lane('road',[VEH['bus'],FROG['ring1'],FROG['ring2'],FROG['faint'],FROG['angel']],css),
          lane('start',[FROG['up']],css),lane('water',[CROC_OPEN,[r[::-1] for r in log(6)]],css)]
    for i,r in enumerate(rows): W.paste(r,(0,i*6))
    W.resize((128*6,64*9),Image.NEAREST).save('/home/claude/hoppy2/build/prev%d.png'%css)
