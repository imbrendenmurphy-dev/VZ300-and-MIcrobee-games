#!/usr/bin/env python3
"""shot.py in.ppm out.png - emulator screenshot to a 4:3 PNG (640x480)"""
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGB')
im.resize((640, 480), Image.NEAREST).save(sys.argv[2])
