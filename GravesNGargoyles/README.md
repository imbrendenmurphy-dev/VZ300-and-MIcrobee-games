# GRAVES 'N' GARGOYLES — Sir Tinplate's Long Night

A gothic fantasy arcade platform adventure for the Dick Smith VZ300.
Inspired by Ghosts 'n Goblins and Ghouls 'n Ghosts, without the cruelty.
Target: VZ300 + BennVenn SD loader + 128K SRAM. Mode 1 (128×64, 4 colours) throughout.
© 2026 — ViBED by BPM

## The game

In the kingdom of Dreadmoor, the sorcerer **Morgrave** has stolen the seven **Sunstones**. The sun will not rise and the
dead walk the land. Only one knight is awake: **Sir Tinplate**, the least impressive knight
in the realm, in borrowed tin armour.

### This build (v0.3.4) contains

- **Seven stages**, each its own SD pack (tiles, eight creature sprites, boss, music, text):

  | # | Stage | Creatures | Boss |
  |---|---|---|---|
  | 1 | Gallows Hill | Grave Zombie, Rattlebones, Crypt Bat, Mourning Ghost, Gallows Crow, Grave Bloom, Gristle the Imp | GRAVEMAW |
  | 2 | The Witchwood | Toadstool Trudger, Scarecrow, Fang Moth, Witch-Wisp, Hoot Owl, Snapvine, Granny Grimweed | The Hungry Oak |
  | 3 | The Drowned Village | Drowned Sailor, Pirate Bones, Gull Ghoul, Lantern Ghost, Storm Crow, Gargoyle Spout, the Sea Hag | Leviathan |
  | 4 | The Swamp of the Damned | Bog Lurker, Mud Golem, Mega Mosquito, Marsh Light, Bog Vulture, Spitting Toad, Snapjaw | Old Croaker |
  | 5 | The Crystal Deeps | Crystal Crawler, Gem Knight, Cave Bat, Shade, Shard Sprite, Crystal Eye, Glimmer Imp | The Prism Golem |
  | 6 | The Demon Castle | Ghoul Guard, Living Armour, Gargoyle Bat, Phantom Bride, Stone Gargoyle, Wall Face, the Red Gargoyle | GARGANTUA |
  | 7 | Morgrave's Citadel | Shambling Tome, Skeleton Mage, Flying Tome, Bound Spirit, Morgrave's Raven, Magic Mirror, the Familiar | MORGRAVE |

  Stages 5 and 7 use the VZ's second colour set (buff, cyan, magenta, orange). After stage 7
  comes the ending.
- **Every creature has its own behaviour** (v0.3). Each stage pack carries its own creature
  code (`src/ai2.asm` to `src/ai7.asm`), for example:
  - **Witchwood:** Toadstool Trudgers hop after you, and Scarecrows stand still as decoys
    until you're close, then lunge. Witch-Wisps freeze while you look at them and creep up
    when you don't. Hoot Owls swoop and climb again, and Granny Grimweed bombs you from her
    broom.
  - **Drowned Village:** Pirate Bones leap obstacles. Gull Ghouls scream past in waves.
    Storm Crows drop lightning from above you. The Sea Hag vanishes and rises again beside you.
  - **Swamp:** Bog Lurkers sink and stalk you unseen. Mosquitoes hover and then dart at you.
    Vultures circle and drop like stones. Toads hop and spit. Snapjaw the gator charges.
  - **Crystal Deeps:** Cave Bats drop from the roof as you pass underneath. The Shade mirrors
    your moves. Shard Sprites home in on you and shatter. Gem Knights leap sword-first.
  - **Demon Castle:** Ghoul Guards ignore you until you're in front of them. Living Armour
    swings at close range. Phantom Brides fade and reappear behind you. Stone Gargoyles wake
    as you pass. The Red Gargoyle strafes along the floor.
  - **Citadel:** Skeleton Mages blink toward you, and Flying Tomes bounce between floor and
    ceiling. Bound Spirits circle you. The Magic Mirror throws back anything you throw at it.
  - Stage 1 keeps its original patterns.
- **Levels built for play** (`tools/levelgen.py`). Each stage is assembled from themed set
  pieces:
  - **Witchwood:** toadstool staircases.
  - **Drowned Village:** rooftop runs over flooded streets.
  - **Swamp:** long bogs with rafts.
  - **Crystal Deeps:** low caverns over lava.
  - **Demon Castle:** ramparts over spiked moats.
  - **Citadel:** floating books over arcane fire.
  - **Every stage:** hills, ledge routes over spikes (treasure above, danger below), and a
    secret armour ledge that takes a bold leap.

  Coin trails guide the jumps, and enemies are placed by section. A reachability checker
  (`tools/reach.py`) simulates the hero's real jump physics. It rejects any layout where the
  boss arena, a checkpoint or a chest can't be reached without damage, and any pit you
  couldn't bounce out of.
- **Passwords.** Each stage-clear card shows a four-character password for the next stage
  (alphabet A-Z without I and O, plus 2-9). It stores the stage, armour level, weapons owned,
  enchanted weapons and difficulty, with a checksum. Choose PASSWORD on the menu and type it
  on the keyboard, or pick letters with up/down and left/right; fire on the last letter starts
  the game there.
- The attract-mode demo shows a different stage each time round.

The rest of this list describes the engine as first built with stage 1:


- **Stage 1: Gallows Hill**, a 176-tile-wide scrolling graveyard. It has a fenced meadow, a hill of
  graves, the bog with plank bridges, a crypt you can run across, spikes, high ledges, a
  second hill, two checkpoints, and a boss arena.
- **Visibly evolving armour on the sprite itself:** Undies → Tin → Steel (pauldrons) →
  Enchanted (sparkles) → Royal (cape and crest) → Legendary (winged helm).
  Hits knock armour off a stage at a time, with pieces flying. You only lose a life when hit in
  your undies. Armour pickups repair you, or upgrade you once you're at full strength.
  Checkpoints also repair you. Upgrades are permanent and survive continues.
- **Weapons:** lance, twin daggers, arcing battle axe, and a fire torch that leaves a burning
  flame on the ground. Picking up a weapon you already own **enchants** it (glowing lance that
  pierces, double daggers). Swap between owned weapons at any time.
- **Magic:** hold fire to charge, or press M, to call a **lightning storm**. The palette
  flashes, bolts fall and everything on screen is struck. Potions refill up to three charges.
- **Enemies:** Grave Zombies (rise out of the ground), Rattlebones (keeps fighting after his
  head is knocked off), Crypt Bats, Mourning Ghosts (flicker-transparent, drift through walls),
  Gallows Crows, the fire-spitting Grave Bloom, and **Gristle the Imp** (mini-boss).
- **Boss: GRAVEMAW, the Skull Under the Hill.** A 32×28 composite skull and jaw rises out of
  the ground. It's only vulnerable while its jaw is open and its eyes blaze; otherwise shots
  clink off the bone. It spits fireball volleys. In phase 2 it slams the ground (telegraphed
  by a shudder) and summons bats. Its health bar replaces the HUD divider.
- Chests, coins, jewels, potions, weapon pickups, extra lives, random drops.
- **Front end:** a lightning-lit animated title (castle, flickering windows, bats, ghost,
  the two-line gothic logo descending). There's also a menu, story pages, a "Creatures of the Night"
  bestiary, a self-playing demo, a hall of heroes, controls and credits pages, stage cards,
  game over with continue countdown, stage clear, and an ending.
- **Difficulty:** Casual (5 lives, longer invulnerability, weaker boss) / Normal / Expert
  (faster zombies, hits strip two armour stages).
- **Music:** gothic title organ (D minor), a macabre march for Gallows Hill, a chromatic
  boss theme, and jingles, plus 16 sound effects. The S key toggles music in-game.

### Controls

| Keyboard | Joystick | Action |
|---|---|---|
| O / P | left / right | walk |
| Q | up | jump (hold for higher) |
| A | down | crouch |
| SPACE | fire | throw; hold to charge magic |
| W or RETURN | arm button | change weapon |
| M | | cast magic |
| H | | pause |
| S | | music on/off |

Both joysticks work interchangeably (directions read via ports $2C/$29).

### Real-hardware fixes (v0.3.1-v0.3.4)

- **SD calls (v0.3.4).** v0.3.3 still hung opening the first file. The DOS calls now match
  Dracula's Castle II, which loads from SD on the real machine:
  - the DOS sector buffer is at $F800-$F9FF, the same buffer 13 Ghosts uses;
  - the DOS gets a 2.5K stack (it needs well over 1K): the frame buffer, moved to
    $EE00-$F7FF;
  - interrupts are disabled after every DOS call.

  The game's own stack is now $7D00-$7D7C, with `jp isr` at $7D7D and YTAB at $7D80. The IM2
  table is still at $7F00, and the program's first byte is $7D.

- **SD calls (v0.3.3).** v0.3.2 no longer reset, but it hung inside the first SD read. The
  DOS is now called the way RASTEST (proven on the real machine) calls it:
  - with interrupts enabled (the ISR only waits out field sync while the DOS runs);
  - with the IX, IY and stack pointer the loader started the game with.

  Extra start-up bands mark each DOS call: band 7 means the file opened, band 8 the first
  sector arrived, and band 9 the whole file. To make room, the password screen moved into
  the front-end pack and the ending text into the stage 7 pack.

- **Low RAM (v0.3.2).** On a real VZ300, v0.3.1 reached the first SD read (6 progress bands)
  and then reset. The game had put its IM2 table at $7800, its ISR jump at $7979 and its
  stack at $7A00-$7AFF. Those addresses are the ROM's system area (RST vectors, input buffer),
  which the SD DOS relies on. Now nothing lives below $7AE9:
  - the IM2 table is at $7F00-$8000, and the program's first byte is $F9, so every vector
    reads $F9F9;
  - `jp isr` sits at $F9F9;
  - the stack runs down from $F9F9 into the free RAM above the frame buffer.

- **Keyboard.** Each keyboard row reads its keys as bits 5..0 in the order they are usually
  listed (checked on a real VZ300: `$68EF` gives M SPACE , - . N). Every key test was mirrored
  before, so O and P were swapped and SPACE, Q, A and M read the wrong keys. This is now fixed,
  and the test emulator uses the same map.
- **Interrupts.** The VZ's interrupt line stays low for the whole field sync (56 lines), so the
  ISR now waits for bit 7 of the latch (field sync over) before re-enabling interrupts. Without
  this, a short ISR is re-entered again and again. The emulator now models this
  level-triggered interrupt (`-E` restores the old one-shot model).
- **Start-up progress bands.** The screen starts blue and fills with yellow bands from the
  top. The ninth band means the first SD file loaded; the title then replaces them. If
  start-up ever stops, the number of bands shows where:

  | Bands | What happened |
  |---|---|
  | 1 | started |
  | 2 | SD DOS mapping probed |
  | 3 | SRAM written and checked (a red third band means the SRAM check failed) |
  | 4 | tables, interrupts and mode 1 set |
  | 5 | the first interrupt arrived |
  | 6 | about to open the first SD file |
  | 7 | file opened |
  | 8 | first sector read |
  | 9 | whole file read (the title follows) |

## Technical design

### Rendering (flicker-free, snow-free)

- **Background rings in SRAM:** the level is pre-rendered into two 48-byte-wide ring buffers
  in SRAM bank B, one for each 2-pixel scroll phase. New columns are rendered at the edges as
  the camera moves, so scrolling never redraws the whole map. The camera and objects sit on
  even pixels: 2-pixel steps match the hero's walking speed.
- **Off-screen frame buffer:** each frame the visible window is copied from the ring to a
  frame buffer with 4-byte side margins (so sprites never need horizontal clipping). Then
  scenery-aware extras (a moon that only draws over pure sky, so trees and pillars pass in front
  of it), objects, shots, the hero and particles are composed over it.
- **Interrupt-driven blit:** the frame-sync interrupt (IM2) copies the finished frame to
  video RAM with an unrolled stack-based copy (12.75 T-states per byte). It finishes inside
  vertical blank, which the emulator confirms with zero snow accesses in every test run. The
  HUD is only re-sent when it changes, in a field of its own.
- **Sprites:** sprites are pre-shifted for both phases at build time and mirrored at run time
  through a lookup table. The hero's 8 frames × 2 phases are **built at run time** from
  layered "class" data (body plus armour pieces), so all six armour stages cost ~1.5 KB.
- **Performance:** about 25 fps in gameplay, with roughly 30% of the CPU left over.

### Audio

Two pulse channels mixed by time-multiplexing on the 1-bit speaker (~27.5 kHz sample loop).
Pulse width doubles as volume: notes attack at ~25% duty and decay to ~5%, with a gap
before the next note. That makes the sound quiet, blippy and detached rather than shrill. The
sequencer and sound effects run in the 50 Hz interrupt. The tone loop fills the idle time of
every frame, which gives the in-game music a gritty 25 Hz texture.

### Memory map

```
$4000-$4A7F  SRAM bank B  ring buffer, phase 0   (title art while in menus)
$4A80-$54FF  SRAM bank B  ring buffer, phase 2   (logo sprite while in menus)
$5500-$6068  SRAM bank B  frame blit routine
$6100-$66FF  SRAM bank B  hero layered class data
$7000-$77FF  video RAM    rows 0-8 HUD, 9-59 playfield, 60-63 border
$7800-$7AE8  left alone: ROM/BASIC system area used by the SD DOS
$7B00-$7FFF  HUD buffer, lookup tables, DOS flags, IM2 table ($7F00-$8000)
$8000-$CCFF  resident engine, shared graphics, sound, text
$CD00-$E46C  pack area: GNGFRONT or one of GNGSTAG1-7, loaded from SD
$E342-$EDE6  variables
$EE00-$F7FF  frame buffer (the DOS's stack during SD loads)
$F800-$F9FF  DOS sector buffer
$FA00-$FFFF  BennVenn DOS RAM - never touched
```

At start-up the program probes the DOS mapping exactly as the 13 Ghosts loader does, then
maps SRAM bank B (port $37 = 3) for play. Each pack load switches back to the DOS mapping with
interrupts off, reads 512-byte sectors into the frame buffer and copies them into the pack
area. The frame buffer is redrawn afterwards anyway. Packs are about 5.5-6K and load in a
fraction of a second.

### Stage packs

Each pack starts with a magic byte ('F' or 'S' plus the stage number). Packs are
assembled from the same source tree as the engine (`src/packs.asm`, using the assembler's
`segment` directive), so the engine refers to pack data by label. A new stage is a new
segment: its own map, tiles, enemy sprites, boss, music and text, plus stage-specific code if
it needs any. It's loaded into the same area.

A stage pack has a fixed 99-byte header (see the `STG_*` equates in `src/main.asm`):
- pointers to its map, tiles and objects;
- its songs, boss sprites, boss settings, colour set and card text;
- the 28 creature frames;
- a table of seven behaviour routines that the object loop calls for that stage's creatures.

Maps are stored as a column dictionary: one index byte per map column, plus 8 bytes for each
distinct column. That saves about 500 bytes per pack, which is room for the creature code.

### BennVenn SD DOS interface (decoded from the 13 Ghosts loader)

The DOS lives in SRAM bank A (port $37 = 1) at $5F00 and keeps its variables at $FB00 upward,
so $FA00-$FFFF must be left alone by anything that calls it at run time.

| Call | In | Out / effect |
|---|---|---|
| `($FB80)` | | address of the 512-byte sector buffer |
| `call $5F00` | A=1, HL → `"NAME"` (in quotes, 8 chars) | open file; OK if `($FB03)=1` and `($FB05)≠1` |
| `call $5F03` | A=1 | read the first sector into `($FB80)` |
| `call $5F09` | | read the next sector into `($FB80)` |

13 Ghosts copies each sector to its destination with `out ($37),3` around the LDIR when the
target is SRAM bank B, then restores the DOS mapping. Its file table entries are
destination (2), length (2), bank flag (1), then the quoted name (10).

### Not yet in this build (next milestones)

- High scores on SD (needs a DOS write call; progress is kept with passwords instead).
- Per-boss attack patterns beyond speed, volley size and summons.
- More weapons (crossbow, boomerang, holy orb, bombs, enchanted sword) and more spells
  (fire wave, shield, freeze).
- Parallax cloud layer, 1-bit speech ("READY!", "GAME OVER"), bonus vaults.

## Building

Requirements: Python 3 (with Pillow, only for previews) and gcc (for the test emulator).

```
./build.sh                         # -> build/sd/: GRAVGARG.VZ + GNGFRONT.DAT + GNGSTAG1-7.DAT
./build.sh dbg START ARM OWNED CHEAT [STAGE]   # test build: start x, armour 0-5, weapon bits, invincible, stage
```

- `tools/z80asm.py`: the two-pass Z80 assembler used for this project. It supports local labels,
  `phase`, `dsect`, and automatic jr→jp relaxation.
- `tools/art.py`: all pixel art (tiles, sprites, hero layers, font).
- `tools/mkassets.py`: generates tiles, pre-shifted sprites, the level, music, blit
  routines and the RLE-packed title art.
- `tools/stages.py`: themes, creatures, bosses, music and pack headers for stages 2-7.
- `tools/levelgen.py` and `tools/reach.py`: the set-piece level builder and the jump-physics
  reachability checker. `tools/preview_levels.py N` renders a level with its objects and every
  reachable standing spot marked.
- `emu/vzemu`: a headless VZ300 test emulator (PAL timing, IM2, BennVenn SRAM banking,
  keyboard and joystick). It also does snow detection, screenshots, a mono preview, WAV capture,
  a profiler, write watchpoints and a crash PC trail.
  `-S folder` emulates the BennVenn DOS calls, serving `NAME.DAT` files from that folder
  (checked against the real 13 Ghosts loader). Snow timing assumes the display starts 94
  lines after the field-sync interrupt; that needs confirming on real hardware.
