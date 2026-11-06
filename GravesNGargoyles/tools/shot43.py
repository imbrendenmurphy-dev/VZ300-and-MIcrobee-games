import sys
from PIL import Image
# convert emulator 512x192 ppm(s) to true 4:3 png(s), optional grid montage
fs=sys.argv[2:]; ims=[Image.open(f).resize((512,384),Image.NEAREST) for f in fs]
cols=min(2,len(ims)); rows=(len(ims)+cols-1)//cols
M=Image.new('RGB',(cols*520,rows*392),(40,40,40))
for i,im in enumerate(ims): M.paste(im,((i%cols)*520,(i//cols)*392))
M.save(sys.argv[1])
