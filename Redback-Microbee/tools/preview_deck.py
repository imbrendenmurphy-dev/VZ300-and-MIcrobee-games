import sys
sys.path.insert(0, '.')
import numpy as np
from PIL import Image
import deckart, deckpack

c = deckart.build_deck()
grid, order = deckart.cells_of(c)
print('deck %d cols, %d base cells' % (grid.shape[1], len(order)))
pairs, P, slot_of, blank, worst, OFF = deckpack.build(grid, order)
print('unique pairs %d, max busy slots %d' % (len(pairs), worst))
loads = deckpack.stats(pairs, P, slot_of, blank, grid.shape[1], OFF, grid.shape[0])
print('loads/column: max %d mean %.1f' % (max(loads), sum(loads) / len(loads)))
for name, x0 in (('a', 0), ('b', 40), ('c', 80), ('d', 120)):
    img = deckart.render_cells(grid, order, x0, 40)
    im = Image.fromarray(img)
    im = im.resize((im.width * 2, int(im.height * 3)), Image.NEAREST)
    im.save('/tmp/claude-0/deck_%s.png' % name)
