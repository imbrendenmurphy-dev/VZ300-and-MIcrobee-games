import sys,glob
from PIL import Image
# usage: shots.py prefix out.png [cols]  -> contact sheet of all prefix_*.ppm scaled 2x
fs=sorted(glob.glob(sys.argv[1]+"_*.ppm")); cols=int(sys.argv[3]) if len(sys.argv)>3 else 3
ims=[Image.open(f) for f in fs]
if not ims: print("none"); sys.exit()
w,h=ims[0].size; s=2 if len(ims)<=4 else 1
rows=(len(ims)+cols-1)//cols
sheet=Image.new("RGB",(min(cols,len(ims))*w*s,rows*h*s),(40,40,40))
for i,im in enumerate(ims):
    sheet.paste(im.resize((w*s,h*s),Image.NEAREST),((i%cols)*w*s,(i//cols)*h*s))
sheet.save(sys.argv[2]); print(len(ims),"frames ->",sys.argv[2])
