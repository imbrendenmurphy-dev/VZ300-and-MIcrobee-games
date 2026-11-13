import sys
from gfx import Quant, show
from walls import *
import materials
from PIL import Image
def build(mat, kinds=('A','B')):
    q=Quant(mat.css)
    P={}
    for k in kinds:
        mat.kind=k
        P[k]={'front':{d:render_front(mat,q,d) for d in (1,2,3)},
              'side':{s:render_side(mat,q,*s) for s in SIDE_SLOTS}}
    bg=[render_background(mat,q,variant=v) for v in (0,1)]
    return P,bg
def compose(P,bg,view,variant=0):
    pix=[row[:] for row in bg[variant]]
    for d in (3,2,1,0):
        for l in (-2,2,-1,1,0):
            k=view.get((d,l))
            if not k: continue
            if d>=1:
                fr=P[k]['front'][d]; w=WB[d]
                for (x,y),c in fr.items():
                    sx=x+l*w
                    if 0<=sx<VW: pix[y][sx]=c
            if l!=0 and (d,-abs(l)) in P[k]['side']:
                sd=P[k]['side'][(d,-abs(l))]
                for (x,y),c in sd.items():
                    sx = x if l<0 else VW-1-x
                    pix[y][sx]=c
    return pix
if __name__=='__main__':
    for name,mat,var in (('grounds',materials.Grounds(),1),('hall',materials.Hall(),0)):
        P,bg=build(mat)
        views=[
          {(0,-1):'A',(0,1):'A',(1,-1):'A',(1,1):'B',(2,-1):'A',(2,1):'A',(3,0):'B',(3,-1):'A',(3,1):'A'},
          {(0,-1):'A',(0,1):'A',(1,-1):'B',(2,1):'A',(1,1):'A',(2,0):'A',(2,-1):'B'},
          {(0,-1):'B',(0,1):'A',(1,0):'B'},
          {(0,-1):'A',(1,-1):'A',(2,-1):'A',(3,-1):'A',(3,-2):'A',(2,-2):'A'},
        ]
        ims=[show(compose(P,bg,v,var if i==3 else 0),0,4) for i,v in enumerate(views)]
        W=Image.new('RGB',(ims[0].width*2+8,ims[0].height*2+8),(0,0,0))
        for i,im in enumerate(ims): W.paste(im,((i%2)*(im.width+8),(i//2)*(im.height+8)))
        W.save('/home/claude/dc2/shots/mock_%s.png'%name)
