# BIX THE BILBY — THE STAR DIGGER
### 2026 — ViBED by BPM
An original scrolling platformer and mascot for the Dick Smith VZ300
(BennVenn SD loader + 128K). Mode 1, 128×64, four colours (colour set 0).

**Build v0.10.3 — five worlds × three stages (15 levels), five bosses, slopes, time attack, high scores.**

Each world now runs: **X-1** (outward), **X-2 "The Way Back"** (the same land
mirrored, running home westward from the far end — built by the loader at
load time, so it costs no extra map storage), **X-3** the boss.

| Level | |
|---|---|
| 1-1 Gumleaf Gully | dusk eucalyptus forest (colour set 0) |
| 1-2 King Cane | boss arena: the giant cane toad |
| 2-1 Crystal Caverns | glowing caves (colour set 1), dig-through earth wall, minecart logs over an underground river |
| 2-2 The Geode Golem | boss: you can only hurt him by bursting up from below |
| 3-1 Clockwork Works | factory (colour set 0, green glow): conveyor belts, live floors, crusher pistons, slag pits, a scrap mountain to dig through |
| 3-2 Rust-o-Tron | boss: hovers dropping hot bolts, lands to cool off with its hatch open |
| 4-1 Skyward Isles | floating islands over the void (colour set 1, bright sky): updraft columns, drifting clouds, bouncy clouds, thunder spikes, beanstalk climb, Wattle Wings double jump |
| 4-2 Thunderhawk | boss: swoops down at Bix and crashes, dazed, into the ground |
| 5-1 Molten Peaks | night volcano (colour set 0): lava rivers with popping lava blobs, rockfall gully, heat vents over a lava lake, ash mountain to dig through, geysers |
| 5-2 The Magma Dragon | final boss: hops and shakes the crater like King Cane, then takes to the air like Rust-o-Tron; eight hits |
| Ending | star-shower credits, then back to the title |

New in v0.2: witchetty grubs / rock worms that pop out of the ground, cave bats,
stalactites that drop and shatter, glow frogs and crystal beetles; a CONTINUE
countdown on game over; a demo that plays if the title is left alone; the
title's Bix only redraws when his pose changes (no flicker).

---

## Load and play
Copy `BIX.VZ` to the SD card and load it like your other .VZ games
(machine code, loads at $8000–$D650, starts at $8000). It never calls the DOS
and never touches $FA00–$FFFF.

| Action | Keys | Joystick 1 |
|---|---|---|
| Run left / right | O / P (or Z / X) | left / right |
| Jump (hold for higher) | SPACE or M | fire (or up) |
| Music on/off (in game) | S | |
| Menus | O/P or Q/A to choose, SPACE to pick, A to go back | |
| Dig into the ground | A (while standing on earth) | down |
| Tunnel underground | O P Q A | all directions |
| Burst out | hold SPACE underground | fire |

Joystick is auto-detected on port $2C at boot.

---

## King Cane (World 1 boss)
A 24×20 giant cane toad. He sits and swells, then leaps at Bix; every landing
sends a **shockwave through the ground** that hurts Bix if he's standing on it —
so be in the air, or underground. Hit him by stomping his head, or **dig under
him and burst out**. Six hits; below half health he also spits flies.

## The Geode Golem (World 2 boss)
A 24×20 rock giant with a crystal back. He stomps slowly after Bix and
pounds the floor, shaking crystal shards loose from the ceiling (and sending
a shockwave through the ground). Landing on his back hurts — the only way to
damage him is to **tunnel underneath and burst out**. Five hits; at low
health he walks faster and brings down more shards.

## Rust-o-Tron (World 3 boss)
A flying factory robot. It cruises along the top of the arena dropping hot
bolts, then drops to the floor (shaking it) to cool down with its hatch
open — only then can Bix stomp it or burst up into it. Six hits; angrier
means more bolts and shorter rests.

## Wattle Wings
In the Skyward Isles the bonus-block power-up is a pair of wings: for 10
seconds Bix gets a second jump in mid-air, and flying through an updraft
recharges it.

## Modes
* **Story** — all 15 levels, lives, continues, then the high-score table
  (top five, three-letter initials; kept until power-off).
* **Time Attack** — pick any of the ten non-boss stages; a clock replaces
  the score, lives are unlimited (you respawn at the checkpoint and the
  clock keeps running), and your best time per stage is remembered.
* Leave the title alone and it alternates the high-score table and a demo.

## Level clock and attract (v0.9)
* **Story levels have a generous clock** — 400 seconds (300 on boss
  levels), shown in the HUD in place of nothing (top row, after the level
  number; hidden on boss levels). A soft tick plays in the last 30 seconds;
  at zero Bix loses a life and the clock resets.
* **Time bonus:** on the level-clear screen every second left is tallied
  into the score (10 points per second).
* **Left alone, the machine goes back to the attract sequence:** an idle
  game times out life by life, the CONTINUE countdown runs out, and it
  returns to the title / high scores / demo. The STORY/TIME ATTACK menu,
  the Time Attack stage menu and high-score name entry also give up after
  about 20 seconds with no input. In Time Attack the clock stops the run at
  about 10 minutes.

## Billabong logs (v0.10.3)
The first log's run was long enough to carry it off the right of the screen
for several seconds while Bix waited on the bank, so it looked as if there
were no logs.  Both runs are shorter (and different lengths, so the logs
drift in and out of step), the camera looks a little further ahead, and
moving platforms are always allowed to appear, even on screen.

## Map corruption fix (v0.10.2)
A sprite more than 16 px off the left edge of the screen could wrap round
in the sprite drawer and be drawn past the end of the back buffer, straight
into the first ~30 columns of the level map.  In X-1 that's the start (already
behind you); in "The Way Back" it's the end, which is where the broken
platforms and stray columns showed up.  Such sprites are now skipped.

## Three-voice title music (v0.10)
The title tune, the jingles and the ending now use a three-voice player
(lead, plus the bass on two voices for weight; v0.10.1 dropped the echo,
lowered the title three semitones, slowed it slightly and stopped the
pulses narrowing so far, which made them reedy) with drums (a
falling-pitch kick, noise snare and hat).  Each note starts with a wide
pulse that narrows as it plays, so notes swell and fade instead of
cutting off - an idea taken from the Cybernoid title player.  In-game
music is unchanged (it rides along with the screen copy for free).
The high-score table between title tunes now shows for about half as long.

## Spawning fix (v0.9.1)
Enemies now only appear from just off either edge of the screen. Before, an
enemy whose spawn point was on screen could pop in out of nowhere (when a
slot freed up, or an enemy that had wandered off came back to its start
point), and magpies started 30 px from their spawn point. After a respawn or
a rescue the enemies in view appear with the redrawn scene.

## Slopes
45° ramps now appear in every world (little hills with a ramp up and a ramp
down). Bix walks up and down them smoothly; the side-collision probe was
raised so he steps over small lips.

## The mascot: Bix
A golden bilby — the VZ is an Australian machine, so its mascot is an Australian
animal nobody else has claimed. At 8×10 pixels the silhouette is all **ears**:
two tall red-lined ears, a long red-tipped snout, a striped tail. Instantly
readable even at native size.

**Signature ability — Burrowing.** Bix dives into any soft red earth and
tunnels freely in eight directions, leaving a visible tunnel behind him.
Underground he is safe from enemies and collects **buried stars**. Holding
jump tunnels straight up and **bursts** him out of the ground with a launch
higher than a normal jump, defeating anything above. The ability shapes the
level design: walls you dig *under*, thorn fields with secret tunnels beneath,
buried treasure marked by little lanterns, ledges only reachable by a burst.

Personality: idle blinks, an ear twitch, and if you leave him alone he starts
sniffing and pawing at the ground. Squash on landing, skid pose with ears
flung forward, ears streaming back when jumping and blown up when falling,
a cheer pose at the goal. Musical motif: G–B–D–G ("dig-dig-dig-POP"), heard in
every tune.

---

## World 1-1: Gumleaf Gully (288 tiles = 2,304 px, 12 tiles tall)
Eucalyptus forest at dusk: dithered distant ranges, moon, clouds, gum trees,
billabong. Sections: first steps + first dig spot → log steps and bonus
blocks → the brick wall (dig under it or bounce over on the mushroom) →
checkpoint → the billabong with moving logs → drop-bear forest → thorn field
over a secret tunnel with a hidden 1-UP chamber → checkpoint → the climb
(vertical platform, high route) → the gully run → goal burrow.

Enemies: bull ants (patrol, turn at ledges), swooping magpies, drop-bears
(fall from the canopy when you pass under, then chase), cane toads (hop
towards you). Stomp them, burst into them, or use the Wattle Glow shield.
Items: stars (100 = extra life), buried stars, Wattle Glow (10 s shield with
sparkle trail, from the bonus block), 1-UP. Termite blocks break from below.

---

## Engine (measured in the test harness, 3.5469 MHz, 312-line fields)
**Locked 25 fps with genuine single-pixel horizontal scrolling plus vertical
camera**, ~12k T-states/frame to spare.

* **4-phase ring buffer.** The playfield is kept pre-rendered four times, once
  per 2-bit pixel phase (96 rows × 34 bytes × 4 = 13 KB at $B000). Scrolling
  never shifts bitmaps: when the camera crosses a byte boundary one new column
  is rendered into all four phases (~25k T, table lookups); fine scroll just
  picks which phase to copy. Vertical scrolling is free (start row).
* **Back buffer + interrupt copy.** Each frame the visible window (two LDI
  runs per row to handle the ring wrap) is copied into a 40-byte-wide back
  buffer with 4 guard bytes each side, so sprites need no horizontal clipping.
  The IM2 field interrupt copies the finished buffer to VRAM rows 8–63,
  starting at field sync and outrunning the beam — tear-free, flicker-free.
* **No wasted sync time.** On fields with nothing to copy the ISR returns
  without re-enabling interrupts; the main loop re-enables them once sync has
  ended, so the 56 sync lines aren't burned in a wait loop.
* **Sprites** are pre-shifted (4 phases × both facings) in SRAM, colour 0
  transparent via a 256-byte mask table. ~1.8k T per 8×10 sprite.
* **Sound woven into the renderer.** Both copy loops output one speaker sample
  per row from a 16-bit phase accumulator (~4.7 kHz), so music and effects run
  during gameplay at almost no cost. Title and jingles use a full-CPU
  two-channel interleaved player (~26 kHz).
* Tile patches (stars, blocks, tunnels) re-render only the affected 8 rows in
  the ring. Map changes are undo-logged so a new game restores the level.

Per-frame budget (2 fields = 141.8k T): VRAM copy 37k, ring→buffer 37k,
column render ≤25k (only on byte crossings), sprites/particles ~15k, game
logic ~15k.

### BennVenn memory (v0.7, per MAME's sdloader.cpp and tests on real hardware)
Port $37 is three switches, not a bank number: bit0 = DOS RAM/ROM at
$4000-$67FF, bit1 = which of two 10K RAM banks appears there, bit2 = which of
two 18K RAM banks appears at $B800-$FFFF.
* **1** (home): shift tables, pre-shifted sprites, work area.
* **3**: the level archive (all maps, tilesets, songs, sprite sheets, LZ-packed).
* **5** (upper $B800-$FFFF swapped): the packed menus overlay and any archive
  overflow, ~11K still free. Because that range is also the playfield, it is
  only switched in between levels, by resident code below $B800, passing data
  through a 128-byte buffer at $AF10.
At boot both are filled from the load image and verified; a failure shows
"128K SRAM BANK TEST FAILED: 3" or ": 5".

### Memory map
| Range | Use |
|---|---|
| $4000–$45FF | shift tables (SRAM, built at boot) |
| $4600–$46FF | sprite mask table |
| $4700–$5FFF | pre-shifted sprites (built per world at load) |
| $6000–$67FF | entity pool, particles, spawn states, star list, spawn list, boss frames |
| $7800–$7FFF | variables + stack |
| $8000–$ADFF | code + resident data |
| $AE00–$AFFF | IM2 table (I=$AE) + vector |
| $B000–$E2FF | ring buffer (staged bank data at boot; overlay + loader scratch between levels) |
| $E300–$EBBF | back buffer |
| $EC00–$F98B | level map |

Uses the SRAM at $4000–$67FF as the DOS leaves it (mapping 1), the same way
your Cybernoid build does — so it overwrites the DOS and can't return to it.

---

## Building
`./build.sh` → `build/BIX.VZ`. Needs Python 3 + Pillow and sjasmplus.
`tools/art.py` (all pixel art), `tools/level1.py` (level built from stamps),
`tools/music.py` (tunes), `tools/build_assets.py` (pre-shifting, packing,
level preview PNG). `tools/vzemu.c` is the small test harness (VZ timing,
field-sync INT, keyboard matrix, profiler).

## Status / next steps
* Tested only in my harness (it emulates the port $37 banks) — **not yet on
  a real VZ300**, and the sound is unheard. If an older build loads but this
  one doesn't, tell me which; if you see the BANK TEST message, the digit.
* The .VZ now loads up to $EF09 (the staging area runs into the level-map
  space, which is free at boot). If v0.6 fails to load but v0.5 works, this
  is the first suspect.
* Space: banks 3 and 5 are now essentially full (assets are packed first-fit
  across both); ~370 bytes of resident code left. Saving high scores/records
  to SD would need the DOS calls, which this build deliberately avoids.
