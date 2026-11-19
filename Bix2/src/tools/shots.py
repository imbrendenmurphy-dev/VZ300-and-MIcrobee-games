import sys,glob
from PIL import Image
files=sorted(glob.glob(sys.argv[1]+'/*.ppm'))
ims=[Image.open(f).resize((512,256),Image.NEAREST) for f in files]
cols=int(sys.argv[3]) if len(sys.argv)>3 else 2
rows=(len(ims)+cols-1)//cols
sheet=Image.new('RGB',(cols*520,rows*264),(30,30,30))
for i,im in enumerate(ims): sheet.paste(im,((i%cols)*520,(i//cols)*264))
sheet.save(sys.argv[2])
