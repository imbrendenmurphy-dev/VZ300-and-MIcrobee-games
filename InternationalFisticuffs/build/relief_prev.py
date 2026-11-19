import sys; sys.path.insert(0,'tools')
import pack, fighters as F, mockup as mk, tourmock as tm
from PIL import Image
built=F.build_all()
def comp(i, relief, dark=None):
    pack.RELIEF=relief
    if dark: pack.RELIEF_DARK=dark
    st=pack.STAGES[i]; A,B=pack.phases(st)
    P=tm.view(A,32)
    mk.hud(P,names=(built[i][0]['name'],built[(i+1)%9][0]['name']),hp=(70,40),time=54,wins=(1,0))
    sc=0 if st[3]==0 else 1
    tm.shadow(P,40,0,sc); tm.shadow(P,86,0,sc)
    fa={f['name']:f for f in built[i][1]}; fb={f['name']:f for f in built[(i+1)%9][1]}
    mk.sprite(P,fa['IDLE'],40,False,2); mk.sprite(P,fb['IDLE'],86,True,3)
    im=Image.new('RGB',(128,64))
    for y in range(64):
        for x in range(128): im.putpixel((x,y),tm.CSS[st[3]][P.p[y][x]])
    return im.resize((128*5,64*7),Image.NEAREST)
if __name__=='__main__':
    if sys.argv[2]=='all':
        sh=Image.new('RGB',(650*3,456*3),(20,20,20))
        for i in range(9): sh.paste(comp(i,True),((i%3)*650,(i//3)*456))
        sh.save(sys.argv[1]); sys.exit()
    idx=[int(a) for a in sys.argv[2:]]
    sh=Image.new('RGB',(640*2+10,(448+8)*len(idx)),(20,20,20))
    for r,i in enumerate(idx):
        sh.paste(comp(i,False),(0,r*456)); sh.paste(comp(i,True),(650,r*456))
    sh.save(sys.argv[1])
