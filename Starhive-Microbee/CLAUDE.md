# STARHIVE — Microbee Premium Plus vertical shoot-'em-up

STARHIVE is an original vertically scrolling shoot-'em-up for the **Microbee Premium Plus**: Z80 at 3.375 MHz, 1 MB banked RAM, 32K PCG RAM, 6545 CRTC, DS80 disk. It has five levels, a boss for each, and smooth line-by-line scrolling. The current version is **0.6**. See `README.md` for the version history and `docs/STARHIVE_README.TXT` for the player's README that goes on the disk.

## Working with the owner (BPM)

- **Who the owner is:** a retro collector who plays the games. He is not a programmer, although he knows a little BASIC and Z80. Explain results in plain terms: what changed, how it plays, and fps.
- **Credits:** the game credits read **"VIBED BY BPM 2026"** (already on the title screen and in the docs). Never write "code by Claude" or similar.
- **Testing:** he tests on his real Premium Plus. Everything else is checked only in the emulator model in `tools/emu`, so always say so when reporting.
- **Delivery:** after every change, rebuild the disk, update both READMEs (bump the version), and push to GitHub. The repo is `imbrendenmurphy-dev/VZ300-and-MIcrobee-games`, folder `Starhive-Microbee/`. He also keeps a copy at `C:\Users\Owner\Documents\Codex\Starhive-Microbee-Claude\`, holding `STARHIVE.DS8`, `STARHIVE_README.TXT` and `Starhive-source.zip`.
- **Commit messages:** a short first line with the version and the gist, then a short bullet list.
- **His monitor rejects any change to the frame timing.** The 6545 setup is fixed at 312 lines a frame, so never change R4, R5 or R9 at run time.

## Requirements

- Python 3.10+ with `numpy` and `Pillow`.
- `gcc` for the emulator, which compiles itself on first use. On Windows this means MinGW-w64 gcc on the PATH, which builds `tools/emu/libmbee.dll`.
- No outside assembler: `tools/zasm.py` is this project's own Z80 assembler. It is sjasm-like and supports `REPT`, `ALIGN`, `ASSERT` and local `.labels`.

## Build

```
python tools/build_all.py          # everything; the levels take ~10 s
python tools/build_all.py --quick  # reuse the level data already in build/
```

The build writes into `build/`, which is generated and not committed. `build/STARHIVE.DS8` is the disk: boot it, then type `STARHIVE` at `A>`.

The build runs these steps in order:

1. `mksin.py` → `sin.inc`
2. `mkmusic.py` → `music.inc`
3. `mkwaves.py` → `waves.inc` (wave scripts and the boss table)
4. `mklevels.py` → the level files, `game.inc`, `boot.inc` and `game_files.inc/.txt`
5. `mk_starhive_disk.py` assembles `src/starhive.asm` (which saves `STARHIVE.BIN`) and `src/loader_game.asm` (the CP/M loader `STARHIVE.COM`), then writes the disk with `build_disk.py`. The disk's boot tracks and `CCP.SYS` come from `resources/`.

To assemble the game alone, run this from `src/`:

```
python ../tools/zasm.py starhive.asm --sym=../build/starhive.sym --lst=../build/starhive.lst
```

## Testing and measuring (all in the emulator)

| Tool | What it does |
|---|---|
| `python tools/bench.py [levels]` | Plays each level 30 s (weaving, firing, invulnerable). Prints fps, fields per frame, work per frame (median, 90%, max in thousands of T-states) and the time by routine. The budget is 135k T for 25 fps (2 fields) and 202k for 16.7 fps (3 fields). Gameplay differs run to run, so differences of ±1–2 fps are noise. |
| `python tools/shot.py LEVEL out.png [secs] [--mono]` | Saves two frames as the beam draws them. |
| `python tools/sprchk.py LEVEL CALLS` | Checks every `spr_draw` call against a Python model: glyphs, bucket entries and colours. It must report `bad 0`. Run it after any sprite change. |
| `python tools/sprcost.py LEVEL CALLS` | T-states per `spr_draw` call, fitted per sprite, per black cell and per scenery cell. This is the fair way to compare sprite code, because it measures the same calls. |
| `tools/starhive_run.py` | The API: `pp = boot()`, `pp.run_frames(n)` (one frame = one 50 Hz field), `pp.keys = {'SPACE', 'LEFT', …}`, `peek`, `peekw`, `poke`, `pp.S[symbol]`, `run_until(addr)`, `watch(addr, 1)` + `events()`, `profile(True)` + `prof()` (T-states by PC; map them to source with `build/starhive.lst`), `pp.pcg` and `pp.blocks`. |

To jump to a level in a test: `poke(level, n-1)`, `poke(state, 3)`, `poke(stimer, 1)`, then run about 560 frames to get through the level-clear screen.

## Hardware rules learned the hard way

- **Display mode:** 40×24 characters of 8×11, from the mode table `$35,$28,$2C,$34, 27,4,24,26, $48,10,$20,10`. The frame is always 312 lines (28×11+4).
- **40-column clock:** `ld a,1 / in a,(09h)`.
- **Interrupts:** they are off all the time (`di`). The code uses SP as a data pointer (`pop`-driven merges, the unrolled scenery pass), so never enable interrupts.
- **`vschk` must run at least every ~10k T-states.** It counts vertical-blank edges by polling bit 5 of the 6545 status, and the blanking is only ~10.4k T long. A longer gap misses a field, and that frame then takes an extra field. `vsq` is a cheaper version that clobbers AF and HL. When adding a long routine, put a `vschk` call inside it.
- **Video window:** port `1Ch` (`P_LV`) selects what F000/F800 show. `LV_SCREEN|bank` gives screen RAM at F000 and PCG bank n at F800. `LV_ATTR` gives attribute RAM at F000. Colour RAM appears at F800 via port 08 (`COL_ON`). Restore `LV_SCREEN` when done.
- **Code space:** the code must end before `COLT` at `$B000` (enforced by `ASSERT`). It ends at about `$AD3C`, so roughly 700 bytes are free. Boot-only data sits at `$C000` in `boot.inc` and is overwritten by `SEGS` after start-up.
- **Self-modifying code is everywhere.** Many labels like `.ns`, `.dst`, `.pb`, `.cv`, `.fd`, `bg_get.mo` and `.mm` are instruction operands patched elsewhere: by `frame_begin`, `set_mono` and `ovl_merge`. Grep for `label+1` before moving or reusing one.

## Architecture

### Memory

- **Upper 32K (block 0):**

  | Range | Contents |
  |---|---|
  | `$8000–AD3C` | code |
  | `$B000` | `COLT`, the colour of slot s at phase k (`+256k+s`) |
  | `$BB00` | `MFLG`, merge flags (slot s: phases 0–7 at `+s`, phases 8–10 at `+128+s`) |
  | `$BC00` | `rowt`: display row of a playfield line + 16 (`$BD00` = the line within the row; copied from boot data) |
  | `$C000–DFFF` | `SEGS`: per map row (row & 31), the counts, jump addresses (`+54h`) and cell lists for the scenery pass |
  | `$E000` | HUD buffers |
  | `$E0A0` | `ROWBUF` |
  | `$E200` | variables |
  | `$EB00` | `sr_bg` |
  | `$EC00` | `ringt`, the ring offset of each row this frame |
  | `$ED04` | `bk_s`, the bucket pointers |
  | `$EFF0` | stack |
  | `$F000` | video window |

- **Lower 32K:** a banked block. During drawing it holds the level's WORK block (`LnSPR.BNK`):

  | Range | Contents |
  |---|---|
  | `0000` | bucket set 0 |
  | `0B00` | bucket set 1 |
  | `1600` | sprite library (up to `6000`) |
  | `6000` | `COV`: the frame number that last covered each ring cell |
  | `6800` | `SHK` shadow: what each scenery cell should show |
  | `7000` | `SHC` shadow (the char also gives the pair slot) |
  | `7800` | `SHA` shadow: `STAR_BANK`=11 means black space |

  Other blocks hold the level's rows and pair data (see `tools/mklevels.py`), loaded by the loader into blocks 8–23.

### PCG banks

| Bank | Contents |
|---|---|
| 0–10 | Scenery "pair" glyphs at fine-scroll phase k: the bottom k lines of the cell above plus the top 11−k of this one, 128 slots each |
| 11 | Font, far stars (`F0–FF`), black (`80h`) |
| 12 and 14 | Sprite pools (double-buffered; `pgbank` is the one being composed) |
| 13 | Bullet glyphs (pre-drawn at 4 even shifts × 11 line offsets) |
| 15 | Shot glyphs (likewise) |

### Scrolling

- **Coarse scroll:** moves the 6545 start address back 40 per step, on a 2K ring.
- **Fine scroll:** software. Every scenery cell's attribute is set to phase k each frame, in the unrolled scenery pass in `rows_commit`, which jumps into `REPT 40` blocks by count. Pairs are loaded into slots ahead of time by an offline schedule (`load_one`).
- **Far stars:** 16 glyphs rotated at half speed.

### Main loop (`starhive.asm` `main`)

1. **Pace:** 2 fields a frame, or 3 after two overruns within `OV_WIN` frames, for `OV_CALM` frames. A frame finishing just inside the blanking commits at once (`blank_now`), unless it is a coarse-step frame.
2. **Commit:** start address, HUD, new top row, stars, `rows_commit` (put-backs, scenery pass, new sprite cells, row by row ahead of the beam), then flip the pool page.
3. **Advance:** scroll by the fields elapsed; on a step, expand and build the new row.
4. **`game_tick`.**
5. **`frame_begin` → `draw_game` → `finish_frame`.**

### Sprites (`sprite.asm`)

- **Frame data:** made by `tools/gfx.py`. The header is `wb, h, flags (bit 0: even shifts only), max cells, block size`. Each shift block then holds the per-column bounds (first line, end, colour), the (mask, gfx) lines, and strips of `h+22` (11 blank lines either side).
- **`spr_draw`:** works column by column. Each column's cells run from the row of its first line to the row of its last, so empty cells are never visited.
  - **Over black:** an 11-byte copy from the strip into the next pool slot.
  - **Over scenery:** `bg_get` fetches the pair glyph at phase k. If its set pixels are the majority (`MFLG`), it inverts the glyph and uses the ink as paper, and it drops black detail. The sprite's lines are then merged in with `pop`-driven (mask, gfx) pairs.
  - **Bookkeeping:** each cell becomes a 6-byte entry in its row's bucket (address, code, attribute, colour) and is marked in `COV`.
- **`rows_commit`:** puts back last frame's cells (skipping any `COV` says are covered again), runs the scenery pass, then writes the new cells.
- **Overlays (`ovl_draw`):** bullets and shots use the pre-drawn glyphs over black. Over scenery, `ovl_merge` composes them into a pool slot (the background via `bg_get`, the detail cleared one pixel either side).

### Game (`game.asm`)

- **States:** title 0, play 1, over 2, clear 3, name entry 4.
- **Enemies:** 12 slots of 16 bytes. Types: drone 1, dart 2, pod 3, explosion 4, boss (`QUEEN`) 5, sweep 6, spit 7.
- **On-screen limit:** waves wait while `MAXACT` (7) enemies are about, or 6 on levels 3–5.
- **Boss parameters:** from `bosstab` (`waves.inc`).
- **Difficulty:** `diff = level + 2×round`; after level 5 the game loops with `round+1`.
- **Sound:** effects play in the vertical-blank wait (`vblank_snd`). The title tune is a 2-voice phase-accumulator player.
- **Monochrome:** `set_mono` patches `fold` and the `.fd` calls.

## Performance (v0.6, emulator)

| Level | fps |
|---|---|
| 1 | about 23.5 |
| 2 | about 25 |
| 3 | about 18 |
| 4 | about 21 |
| 5 | about 18 |

- **Where the time goes on levels 3 and 5:** sprite drawing (~40k T a frame), `rows_commit` (~23k), overlays (~15k) and `bg_get` (~6k).
- **Per-cell costs:** a sprite cell costs about 800 T over black and about 2,200 T over scenery.
- **Already tried, with little gain:** column-major drawing (v0.5), per-cell micro-optimisation, caching glyphs within a frame (almost no repeats), and normalising pair polarity offline (this changed the monochrome look, so it was reverted).
- **Remaining levers:** fewer enemies at once (5 on levels 3 and 5 was offered and not yet decided), or a cheaper look for sprites over scenery.

## Obsolete files

- `src/game_v01.asm`, `src/starhive_v01.asm` and `tools/gen/` (`mk_starhive.py`, the old generator) are from v0.1.
- The test programs from the scrolling research: `scrtest`, `diag`, `softscrl`, `shiptest`, the `loader_*` files other than `loader_game`, and `release/SCRL*.DS8`, `SOFTSCRL.DS8`, `SHIPTEST.DS8`.

None of these are part of the STARHIVE build.
