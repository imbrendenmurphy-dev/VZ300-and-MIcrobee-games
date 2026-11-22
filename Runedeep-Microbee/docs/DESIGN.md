# RUNEDEEP — design and style guide

*A first-person dungeon crawl for the Microbee Premium Plus. VIBED BY BPM 2026.*

## 1. The idea

RUNEDEEP was made for the Microbee from the start, not ported to it. The starting question was what a first-person crawler looks like when it is built around what the Premium Plus does well:

- **PCG RAM as a tile set**: 16 banks × 128 programmable 8×10 glyphs.
- **One ink and one paper for every cell**, from 16 colours.
- **Two screen pages**, so a picture can be built out of sight.

Its weak spots shaped the design just as much:

- The Z80 is slow at pixel work.
- The CPU stalls whenever it touches video RAM during a displayed line.
- Sound is a single speaker bit with no timer.

So it is a **step-and-turn grid crawler** in the Dungeon Master tradition, not a free-moving raycaster like Dracula's Castle or Dropbear 3D. Moving one square or turning 90° changes the whole view at once, and that suits a machine that composes pictures from pre-made tiles.

## 2. Gameplay

- **Four depths** of 16×16 squares:

  | Depth | Theme | Puzzles |
  |---|---|---|
  | The Gatehouse | Torchlit ashlar stone | Keys, a lever and gate, a hidden wall and button |
  | The Fungal Grotto | Rough green cave rock | Illusory walls, a gate button, a lever that opens a hidden wall, a pit |
  | The Drowned Archive | Cyan dressed stone, bookshelves | A four-rune sequence puzzle, portals, a spinner, a gold-key vault |
  | The Ember Throne | Red brick | The sealed door (three sigils) and the Hollow King |

- **Goal**: recover the **three sigils** (one each on depths 1–3), break the seal on depth 4, and destroy the Hollow King.
- **Turn-based**:
  - Turning is free.
  - Stepping, fighting, casting, drinking and using things each take a turn.
  - After each turn, every awake monster steps towards you or strikes.
  - Monsters wake when you come within 5 squares. Slow ones (skeletons, fungoids) step every other turn.
- **Lightweight RPG**:
  - Health, magic, level (to 9), XP, attack and defence.
  - Gold, and potions, plus three keys (bronze, silver, gold).
  - Two spells, learnt from a scroll and a tome: FIREBOLT (a ranged bolt that flies down the corridor) and MEND.
  - Weapon and armour upgrades, a ring of vigour, mana vials, fountains with three draughts each.
  - A **trader** who sells potions and honing and mending for gold.
- **Puzzle kit** (all data-driven per level):
  - Doors, locked doors, gates toggled by levers or one-shot buttons.
  - Hidden walls opened by actions, illusory walls you can walk through.
  - Rune plaques that must be touched in an order given by an inscription. A wrong touch resets them all.
  - Portals, spinners, pits that drop you to the depth below.
  - Inscribed tablets that give hints.
- **Forgiving**: falling in battle offers *rise again* (half your gold lost) at the depth's stair.

`tools/mklevel.py` checks every level can be finished (keys, levers, buttons, runes, portals) on every build. `tools/bot.py` plays the whole game through the keyboard in the emulator model.

## 3. The graphics language

### 3.1 The grid is law

Everything lives on the 8×10 cell grid of the 40-column mode.

The 3D view is **cell-aligned by construction**. The half-widths of the square boundaries are 96, 48, 32, 24 and 16 pixels. The last one is snapped from a true 19.2 so it lands on the grid. Every vertical edge in the world falls on an 8-pixel column boundary, so a column of cells only ever shows **one** wall surface. Horizontal edges can cut through a cell, but only between a wall and the dark ceiling or floor.

### 3.2 "Torchlight on darkness": one ink on black

- Inside the view, **paper is always black**. Every surface is a single ink, and its texture is cut out of it in black: mortar lines, cracks, book spines.
- Because of that, attribute clash cannot happen. No cell ever needs two foreground colours.
- Where two materials meet inside a cell, the nearer or more important one takes the cell, and the other's pixels in that cell go dark. This reads as a recess or shadow line: a black lintel over a door, a dark niche around a lever, a band of shadow where a wall meets the floor.

### 3.3 Depth is colour, then density

- Each depth has its own **four-step ink ramp** (near, middle, far, farthest):
  - Gatehouse: white, grey, dark grey.
  - Grotto: bright green, green, dark grey.
  - Archive: bright cyan, cyan, blue.
  - Ember: yellow, bright red, red.
- Brightness falls with distance like a torch's light, and is turned into an **ordered-dither density** inside each ink (`walls.py`: `light()`, `INKLUM`).
- The second wall look (B) is the **same glyphs in a second ramp**: mossy green stones on the Gatehouse, pale cyan crystal in the Grotto, ember-magenta in the throne halls. It costs no PCG at all. The Archive's B walls are real bookshelves, on front faces only.

### 3.4 Creatures are woodcuts

- Monsters, items and decorations are drawn in world units (`tools/sprites.py`) and rendered for each of three depths.
- A creature is a **solid silhouette, one ink per cell**, with its features (eye sockets, ribs, the hollow face of the King) cut out in black. A second material, such as a sword, flame or crown, takes whole cells of its own.
- **A sprite cell owns its cell.** Whatever was behind it goes black, so a creature carries a little of its own darkness. Silhouettes are kept chunky so this reads as a deliberate halo, not a smear.
- Close up (one square away) each creature has an **attack pose**.
- Creature colours are picked to stand off their depth's walls: orange rats and white bone on grey stone, magenta spiders on green rock, green ghouls on cyan, cool white and cyan foes on the red throne halls.

### 3.5 Colour is the animation

Re-composing a view costs a little. Changing a colour byte costs almost nothing. So everything that moves on its own **cycles its ink** in the blanking:

| Class | What | Ink cycle |
|---|---|---|
| Flame | Torches, imp fireballs, hound spines, the firebolt | Yellow, bright red, white |
| Rune | Lit rune plaques, sigils, the sealed door's circle | Magenta pulse |
| Water | Fountains | Blue, cyan, bright cyan shimmer |
| Portal | Portals | A rainbow swirl |
| Glow | Wisps | Green and cyan breathing |

A struck creature flashes white for a few frames by overriding its cells' colour.

### 3.6 Reserved colours

| Colour | Means |
|---|---|
| Yellow | Things you can use or take: levers, keys, gold, labels |
| Magenta | Magic: runes, sigils, portals, potions |
| Red | Danger and damage: monster hits, the health bar |
| Cyan | Water, mana and inscriptions in the log |
| Green | Life and healing |
| Bronze and gold | The frame |

### 3.7 The frame and UI

- A bronze double rule with knotted corners frames:
  - the view (24×16 cells, 192×160 pixels);
  - the panel (level name, health and magic bars, level and XP, attack, defence, gold, potions, keys, sigils, spells, an 8×8-cell minimap, the compass);
  - a six-line message log.
- The font is a small serif face, mixed case, with descenders.
- Bars are 13 cells of nine partial-fill glyphs.
- The minimap is drawn at run time into 64 glyphs, at 2×2 squares per cell. The player's cell turns yellow.

## 4. How it runs

### 4.1 No pixel is drawn at run time

Every cell a wall, door, floor, creature, item or decoration can put on the screen is rendered offline and de-duplicated into a **per-level tile dictionary**, loaded into the PCG when you enter a depth:

| Depth | Glyphs used (of 1,856) |
|---|---|
| 1 | 1,355 |
| 2 | 1,580 |
| 3 | 1,838 |
| 4 | 1,310 |

The Z80 composes a view in four passes:

1. Copy the level's floor and ceiling backdrop into a shadow buffer (codes, attributes, colours).
2. Walk the 32 wall slots near to far. The first solid slot over a column fills it with its pre-made tile column, and its depth key is kept.
3. Draw decorations on front faces that won their columns.
4. Draw items, creatures and spells far to near, only in columns whose wall lies beyond them.

### 4.2 The Premium's video-RAM wait

The Premium holds the CPU when it touches video RAM during a displayed line, so **all video writes happen in the vertical blanking**:

- the shadow is copied into the hidden page, a row at a time while the blanking lasts (about two frames);
- then the 6545 start address flips pages;
- the message log is copied in the blanking too;
- panel text is written through a cell shadow, so only changed cells are touched.

### 4.3 Memory

| Where | What |
|---|---|
| Upper 32K | The 16.5K program, the live level (map, monsters, items, decorations), view shadows, cell shadows |
| Block 8 | Font and frame |
| Block 9 | Title logo |
| Blocks 17–24 | Two blocks per depth: tiles and sprites, then wall tile lists, backdrop, level, actions, texts |
| Block 25 | Each depth's live state while you are elsewhere, so it is exactly as you left it |
| Block 16 | CP/M's own screen, saved by the loader, so ESC returns cleanly to the A> prompt |

## 5. Sound

One speaker bit, no interrupts. In the time each frame waits for the blanking, which in a turn-based game is most of the frame, three voices take turns at the speaker inside every 214-T sample, so they mix instead of masking each other:

- **Melody**: a pulse whose duty swells over two frames and then decays. It is a soft, bowed note, and quieter than the effects, so the score sits behind the action.
- **Bass**: a pluck. Its duty starts wide and narrows, so it goes "dum", not "beep".
- **Effects and drums**: tone with a per-frame glide, or noise. Kick, snare, hat and a drip tick play when no effect is sounding.

Effects never stop the music. Composing a view silences the speaker for less than one frame per step.

Each depth has its own original theme, in its own mode and pulse:

| Theme | Mode and pulse |
|---|---|
| Title | D minor march |
| Gatehouse | A aeolian, steady |
| Grotto | E phrygian, sparse drips |
| Archive | D dorian waltz with harpsichord-like broken chords |
| Ember Throne | Driving C minor |

There is also a dirge and a victory fanfare. Two dozen effects cover footsteps, bumps, doors, keys, swings, hits, kills, hurts, coins, fanfares, sigils, levelling up, levers, gates, runes, wrong runes, healing, the firebolt, stairs, falling, portals and spinners. `T` cycles music and effects, effects only, and silence.

## 6. Files

| Path | What it is |
|---|---|
| `tools/build.py` | Builds everything |
| `tools/views.py` | View geometry and slots |
| `tools/walls.py` | Wall, door and floor art, themes |
| `tools/sprites.py` | Creatures, items, features and decorations |
| `tools/levels.py` | The four depths |
| `tools/mklevel.py` | Level blocks and the solvability check |
| `tools/mkmusic.py` | Score and effects |
| `tools/title.py` | The logo |
| `tools/uiart.py`, `tools/font.py` | UI glyphs |
| `tools/rd.py` | Run in the emulator model |
| `tools/bot.py` | Whole-game bot |
| `src/main.asm` | Entry point, frame loop, quit to CP/M |
| `src/video.asm` | Pages, commit, text, colour cycling |
| `src/view.asm` | The compositor |
| `src/game.asm` | Levels, moving, acting, items, actions |
| `src/combat.asm` | Monsters, fighting, spells, the trader, death, victory |
| `src/ui.asm`, `src/mini.asm` | Panel, log, minimap |
| `src/sound.asm` | The three-voice engine |
| `src/front.asm` | Title pages |
| `src/loader.asm` | The CP/M loader (from REDBACK/Starhive, adapted) |
