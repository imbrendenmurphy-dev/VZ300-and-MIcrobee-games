# texts.py - all game text. Pages of up to 2 lines x 32 chars.
# codes: 1 newline, 4 page break (wait for key), 0 end
T = {}            # global texts (in the .VZ)
AT = {}           # area texts: AT[area][name] = pages (in that area's pack on SD)
def t(name, *pages, area=None):
    if area is None: T[name] = pages
    else: AT.setdefault(area, {})[name] = pages

t('GRIGOR1',
  ("GRIGOR: A STRANGER? AT MIDNIGHT?", "THE DEAD ARE RESTLESS TONIGHT."),
  ("VILLAGERS VANISH. THE CASTLE HAS", "WOKEN, AND SOMETHING OLD STIRS."),
  ("ITS DOORS ARE LOCKED. MY KEY WAS", "BURIED WITH POOR OLD WILHELM,"),
  ("IN THE GRAVEYARD TO THE WEST.", "TAKE THESE POTIONS. GOOD LUCK!"), area=0)
t('GRIGOR2', ("GRIGOR: THE IRON KEY LIES WITH", "WILHELM. THE GRAVEYARD - WEST!"), area=0)
t('GRIGOR3', ("GRIGOR: YOU FOUND IT! MAY THE", "SAINTS GO WITH YOU, STRANGER."), area=0)
t('GRAVE1', ("HERE LIES WILHELM, GRAVEDIGGER.", "HE DUG HIS OWN. EVENTUALLY."), area=0)
t('GRAVE2', ("HERE LIES ROSA, WHO TENDED THE", "ANGEL BEHIND THE EASTERN HEDGE."), area=0)
t('ARMOUR1', ("AN EMPTY SUIT OF ARMOUR.", "PROBABLY."), area=1)
t('ARMOUR2', ("THIS SUIT OF ARMOUR IS", "WHISTLING. BEST NOT TO ASK."), area=1)
t('LOCKED', ("THE DOOR IS LOCKED TIGHT.", "YOU NEED THE IRON KEY."))
t('UNLOCK', ("THE IRON KEY TURNS... CLUNK!", "THE GREAT DOOR SWINGS OPEN."))
t('CREAK', ("THE DOOR CREAKS OPEN...",))
t('EMPTY', ("THE CHEST IS EMPTY.",))
t('SHRINE', ("A STONE ANGEL WEEPS. YOU FEEL", "RESTORED.  GAME SAVED."))
t('SECRET', ("A HIDDEN PASSAGE!",))
t('WALL', ("COLD, DAMP STONE.",))
t('HEDGE', ("A THORNY, OVERGROWN HEDGE.",))
t('HEDGEX', ("THE THORNS PART... A HIDDEN", "WAY THROUGH THE HEDGE!"))
t('GATE', ("THE GATE SLAMMED SHUT BEHIND", "YOU. THERE IS NO WAY BACK."))
t('INTRO0', ("CASTLE DRACULA. MIDNIGHT.", "A FIGURE WAITS BY THE PATH."), area=0)
t('INTRO1', ("THE ENTRANCE HALL. CANDLES", "FLICKER IN A COLD DRAUGHT."), area=1)
t('BONES', ("THE BONES BEGIN TO RATTLE...",), area=0)
t('GARGOYLE', ("THE GARGOYLE'S EYES GLOW RED!",), area=1)
t('PLAQUE', ("A BRASS PLAQUE READS:", "THE FORGOTTEN MAZE - 1984"))
t('STAIRS', ("THE GRAND STAIRCASE. DRACULA", "AWAITS ABOVE..."), area=1)
t('GUARDED', ("THE GARGOYLE BARS THE WAY!",), area=1)
t('NOMP', ("NOT ENOUGH MAGIC!",))
t('LEARNFIRE', ("YOU LEARN THE SPELL: FIRE!", "USE IT IN BATTLE WITH MAGIC."))
t('DAGGER', ("SILVER DAGGER EQUIPPED!", "THE UNDEAD FEAR ITS BITE."))
t('NOTHING', ("NOTHING HAPPENS.",))
t('JOKE', ("THAT WASN'T MUCH FUN, WAS IT?", "LET'S PRETEND IT NEVER HAPPENED."))
t('DEFEAT', ("YOU WAKE AT THE LAST ANGEL...", "HALF YOUR GOLD IS GONE."))
t('LEVELUP', ("LEVEL UP!  YOU FEEL STRONGER.",))
t('SAVED', ("GAME SAVED.",))
t('NOSAVE', ("NO SAVED GAME FOUND.",))

ITEMS = ['', 'POTION', 'HOLY WATER', 'IRON KEY', 'SILVER DAGGER', 'FIRE SCROLL', 'CRYPT KEY', 'ELIXIR', 'SWORD', 'CLOAK']
TEXT_IDS = {n: i for i, n in enumerate(T)}
assert len(T) <= 128

def text_id(name, area):
    """global id 0-127, or 128 + index in the area's own table"""
    if name in TEXT_IDS: return TEXT_IDS[name]
    return 128 + list(AT[area]).index(name)

def encode(pages):
    out = bytearray()
    for pi, page in enumerate(pages):
        if pi: out.append(4)
        for li, line in enumerate(page):
            assert len(line) <= 32, line
            if li: out.append(1)
            out += line.encode()
    out.append(0)
    return bytes(out)

def asm():
    s = ['; generated texts']
    for n, pages in T.items():
        s.append('TX_%s equ %d' % (n, TEXT_IDS[n]))
    s.append('text_table:')
    s.append('            dw ' + ','.join('tx_%s' % n.lower() for n in T))
    for n, pages in T.items():
        s.append('tx_%s: db %s' % (n.lower(), ','.join(str(b) for b in encode(pages))))
    s.append('item_names:')
    s.append('            dw ' + ','.join('in_%d' % i for i in range(len(ITEMS))))
    for i, nm in enumerate(ITEMS):
        s.append('in_%d: db "%s",0' % (i, nm))
    return '\n'.join(s) + '\n'
