# KABOOMERANG — design and technical plan

Status: **design stage.** The look, gameplay and engine plan are settled in a browser mockup (`mockup/kaboomerang.html`). No Z80 code has been written yet. Nothing here has run on a real Premium Plus.

ViBED by BPM 2026.

## 1. The game

Wally the demolition wombat takes his gumnut bombs and his lucky boomerang across the outback to stop **Baron Von Croak**, a cane toad tycoon paving the bush into car parks.

The core is classic arena bombing: open the maze, chain your blasts, collect power-ups, outwit the wildlife and reach the hollow-log exit. Four ideas make it its own game:

- **The Kaboomerang.** Wally's boomerang flies four tiles and comes back. It stuns enemies and fetches power-ups from across the arena. If it passes a lit bomb, it snatches the bomb and drops it at the far end of its flight. Upgrades add range and a curved throw that turns one corner.
- **Burrows.** Standing in a burrow hole lets blasts pass over Wally, with only his hat showing. Burrows collapse after a few uses. Later, Wally can dig new ones in soft ground.
- **More than "clear and exit".** Stages mix objectives: herding lost joeys back to their mum, bombing pressure plates to open sluice gates, demolishing the Baron's machinery against the clock, collecting five golden gumnuts, or surviving a stampede. Each world adds one stage mechanic and builds puzzles from it.
- **Forgiving by design.** Three hearts (up to five), flashing safety after a hit, power-ups kept when a heart is lost, a checkpoint at every stage, unlimited continues and progress saved to disk after every stage. Easy, Normal and Hard change enemy speed, fuse length and the blast preview.

### Controls and fairness

- Corners slide you into the gap. The newest direction pressed wins, and a direction tapped just before a junction is remembered for a moment.
- You can always walk off a bomb you just dropped.
- Bombs flash red in their last second. On Easy, every floor tile a bomb will hit is hatched in red during that second.
- Flames fill whole tiles, so the danger area is never ambiguous, even in a long chain.

### Power-ups

| Item | Effect | Lasts |
|---|---|---|
| Gumnut | One more bomb at a time (max 8) | until the world ends |
| Fire | Blast reach +1 tile (max 8) | until the world ends |
| Thongs | Faster walking (two levels) | until the world ends |
| Steel-cap boots | Walk into a bomb to kick it | until the world ends |
| Plunger | Remote detonation | until the world ends |
| Heart | Restores a heart | instant |
| Lucky hat | Ten seconds of invulnerability | timed |
| Frosty nut | Next three bombs freeze enemies into kickable ice blocks | 3 bombs |
| Bouncy nut | Kicked or boomeranged bombs bounce off walls | 3 bombs |
| Long throw, Curve throw | Boomerang upgrades (World 2 and 4 bosses) | whole campaign |
| Digging claws | Dig a burrow on soft ground (World 3 boss) | whole campaign |
| Opals | 100 opals unlock a bush-tucker bonus stage | whole campaign |

### Cast

- **Wally Wombat** (hero): retired demolition expert in a hard hat with headlamp. Animations: idle (blink, look around, foot tap), walk in four directions, crouch to place a bomb, startled hat-jump at nearby blasts, power-up hop, dizzy hurt, defeat (spin, hat flies off), victory dance, burrowed.
- **Pip Possum** (player 2): Wally's apprentice in a bike helmet, for co-op and battle.
- **Baron Von Croak** (villain): monocle and top hat; taunts from his airship between worlds; pilots the Toad-Mech in the finale.
- **Enemies:** Cane Toad (hops with pauses), Frill-neck (flares its frill and sprints down open lanes), Bin Chicken (pathfinds to uncovered power-ups, steals them and runs; blast it to get them back), Drop Bear (drops onto your tile after a growing shadow), Swooping Magpie (straight dives across the arena, always announced), Croc (surfaces near splashes), Emu (charges and kicks bombs), Bush Rat Gang (plants its own bombs, flees lit fuses), Toad Trooper (reads the danger map and steps out of blast lines).

### Campaign: six worlds, 48 stages plus 6 bonus stages

| World | Mechanic and enemies | Boss |
|---|---|---|
| 1 Red Centre | Sandstone, termite mounds, burrows; teaches one idea per stage | Big Daddy Bufo: tongue lashes along rows, telegraphed by his swelling throat |
| 2 Gumtree Gully | Drop bears, rolling logs, trees that shed gumnuts | The Drop Bear King: leaps between treetops |
| 3 Billabong | Floating logs carry bombs downstream, crocs, sluice gates | Old Snappy: swallows bombs and spits them back |
| 4 Snowy Mountains | Ice tiles (sliding bombs and Wally), emus, drifts that refill | The Yowie: snowballs freeze bombs until a blast thaws them |
| 5 Opal Mines | Darkness lit by Wally's headlamp (colour RAM lighting), mine carts, bush rats | The Mega Mole: tunnels under the arena |
| 6 Croak Industries | Conveyors, crushers, switch doors, teleport chutes, toad vats | Baron Von Croak in the Toad-Mech, three phases |

Each world has seven stages and a boss stage. Six secret bonus stages hide behind blasted walls or opal totals.

### Other modes (after the campaign is solid)

- **Battle:** two players plus up to two computer wombats, eight arenas, hazards on or off, sudden-death squeeze.
- **Co-op:** Wally and Pip through the campaign; a downed partner becomes a floating hard hat the other touches to revive.
- **Survival:** endless waves on a shrinking arena, hi-score table on disk.
- **Demolition puzzles:** thirty single-screen puzzles with a fixed number of bombs.

### Sound and presentation

- Speaker on PIO port B bit 6. The two-voice engine from TENNIS II / HULLBREACH plays in each frame's idle time. In play, music is slow, short blipped notes so it never starves the game; the title, interludes and fanfares use the full engine. Music and effects switch off separately.
- Music: title, six world themes, boss, bonus, victory and world-clear fanfares, ending. Effects: bomb place, fuse fizz, explosions that deepen as a chain grows, crumble, power-up sparkle, boomerang whoosh, enemy calls, hurt, warning.
- Title: big KABOOMERANG lettering from about 300 PCG characters, Wally lighting a fuse along the letters, attract mode replaying recorded play, hi-score table.
- Illustrated interludes between worlds (the Baron's airship, Wally's ute crossing the map, the next boss). Credits close with **ViBED by BPM**.

## 2. Hardware plan

Native Z80 at 3.375 MHz. The engine starts from the one already proven in MICROBEE AUSTRALIAN OPEN TENNIS and HULLBREACH.

| Area | Decision | Status |
|---|---|---|
| Display | 40 × 25 cells of 8 × 8 at half dot clock (320 × 200). 1,000 cells, so two pages fit in the 2K screen, attribute and colour RAM | **Not yet tried.** No earlier game used a 40-column mode, and how the Premium Plus switches it on isn't documented in the sources found so far. The first test disk tries it. |
| Fallback display | 64 × 16 cells of 8 × 16 (512 × 256), as in BILBIES!, AUSOPEN and HULLBREACH | proven on hardware |
| Arena | 19 × 11 tiles of 2 × 2 cells (17 × 9 inside the border); 2 HUD rows above, a message row below | chosen |
| Colour | Colour RAM at F800h via port 08h bit 6; paper high nibble, ink low; 1 red, 2 green, 4 blue, 8 dark grey, 9–15 bright | proven |
| PCG | 16 banks × 128 glyphs; port 1Ch bit 7 enables, attribute RAM picks the bank | proven (8 × 16 glyphs; 8 × 8 use is part of the first test) |
| Expanded RAM | 32 blocks × 32K through port 50h, same MEMV macro as earlier games | proven |
| Page flipping | R12/R13 written only in vertical blanking (the 6545 re-reads the start address on every line of the first character row); a sprite-glyph pool bank per page | proven at 64 × 16 |
| Input | Keyboard by 6545 light-pen scan; joystick on PIO A | keyboard proven |
| Disk | DS80, boots to A>, boot tracks from The Lantern Deep; `KABOOM` runs the loader; SAVE.DAT with A/B copies per slot | boot proven; saving in the model only |

### Rendering

1. **Restore** the hidden page's sprite cells from two frames ago.
2. **Composite** every cell a sprite touches into a private glyph from that page's pool: copy the background glyph, AND the mask, OR the pre-shifted frame. The cell takes the sprite's ink (the colour band of the sprite row it falls in) and keeps its paper; floor speckle is dropped under sprites.
3. **Write** codes, banks and colours into the hidden page.
4. **Flip** in vertical blanking.

Grid movement is axis-locked, so a sprite walking sideways stays cell-aligned vertically and covers at most 3 × 2 cells. Two-band sprites (Wally's yellow hat over grey fur) therefore always line up with cell rows.

**Shared animated glyphs:** every bomb's pulse, water ripple, conveyor stripe and lamp flicker is a small set of glyphs rewritten once a frame, so all instances animate for the cost of one. Flames use resident shapes; most of their flicker is colour RAM.

**Bosses** are built from background-layer glyphs rewritten each frame (6 × 6 cells, moving parts) so they don't use sprite cells.

### PCG budget (2,048 glyphs)

| Banks | Glyphs | Use |
|---|---|---|
| 0 | 128 | font, HUD icons, message boxes |
| 1–7 | 896 | the current world's scenery, flame shapes, crumble frames, power-ups |
| 8–9 | 256 | boss art |
| 10–13 | 512 | sprite pools (per page) |
| 14–15 | 256 | shared animated glyphs |

### Memory

| Contents | Approx. size |
|---|---|
| Program and current stage (block 0, 8000h up) | 40K |
| World art packs | 6 × 28K |
| Pre-shifted sprite frames with masks (4 shifts) | 120K |
| Boss art and animation | 6 × 20K |
| Title, interludes, ending | 96K |
| Music, effects, attract recordings | 48K |
| Stage maps and scripts | 24K |

Everything fits in the 1MB together. Each world is unpacked during its interlude; the disk is touched only between worlds and for saving.

### Frame budget

About 67,500 T-states per 50 Hz field. A composited cell costs roughly 650–750 T-states, so a 6-cell sprite is about 4,200. HULLBREACH, on the same engine, holds 25 fps exploring and about 22 fps in its busiest fight. The target is a steady **25 fps** with 2-pixel horizontal steps; the worst case (two players, eight enemies, the boomerang, particles and a long chain) gets benchmarked before content is built.

## 3. Build plan

1. **Hardware test disk** (next): 40-column mode attempts with labelled screens; 8 × 8 PCG glyphs and banks; the colour chart; page flipping at 40 × 25; keyboard and joystick; vertical blank timing. Run in colour and on the amber monitor, then lock the display mode.
2. **Graphics proof:** the mockup's arena on the Z80 with composited, page-flipped sprites.
3. **Core gameplay:** movement with buffering, bombs, chains, crumbling, power-ups, boomerang, burrows, three enemies.
4. **Benchmark** the worst case with music; fix the update rate.
5. **World 1 complete:** seven stages, Big Daddy Bufo, music, title screen.
6. **Worlds 2–6**, one at a time.
7. **Modes and presentation:** battle, co-op, survival, puzzles, attract mode, ending, saves, polish.
