"""Contact sheet: sheet.py out.png img1 img2 ... (images downscaled to 320x250, 4 across)."""
import sys
from PIL import Image
out, files = sys.argv[1], sys.argv[2:]
cols = 4
rows = (len(files) + cols - 1) // cols
sheet = Image.new('RGB', (cols * 324, rows * 254), (60, 60, 60))
for i, f in enumerate(files):
    im = Image.open(f).convert('RGB').resize((320, 250), Image.Resampling.NEAREST)
    sheet.paste(im, ((i % cols) * 324 + 2, (i // cols) * 254 + 2))
sheet.save(out)
