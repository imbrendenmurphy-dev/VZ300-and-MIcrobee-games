import sys,glob,os
from PIL import Image
for f in sys.argv[1:]:
    im=Image.open(f); im=im.resize((768,576),Image.NEAREST); im.save(f[:-4]+'.png'); os.remove(f)
