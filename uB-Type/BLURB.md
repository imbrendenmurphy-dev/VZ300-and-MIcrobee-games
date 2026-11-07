# μB-TYPE
### for the Microbee Premium Plus. ViBED by BPM, 2026

**The VZ300's own R-Type-style blaster has landed on the Microbee, at four times the resolution in both directions.**

μB-TYPE is the Premium Plus conversion of **VZ-TYPE**, BPM's original horizontally scrolling shoot-'em-up for the Dick Smith VZ300. The game underneath is VZ-TYPE's own: the same stages, enemy waves, bosses, weapons and hit boxes, thinned for the Microbee (fewer ordinary enemies, one faster bullet at a time from each turret, at most five enemy bullets at once, and kamikaze darts that don't always aim true) to keep it flowing and fair on a keyboard. The VZ's chunky 128×64 playfield has been redrawn from scratch at the Microbee's full 512×256, in character graphics.

You pilot a lone fighter through eight stages of biomechanical trouble:

1. **Outer Hull**: riveted plating and gun emplacements
2. **The Hive**: pulsing organic walls and a brood mother
3. **Rock Belt**: boulder-strewn caverns where an armoured serpent coils through the rocks
4. **Crystal Vein**: glittering mineral seams and a crystal colossus
5. **Dreadnought**: one long fly-past of a giant enemy warship, its decks, turrets and reactor nodes
6. **Gut Caverns**: a horned maw waiting in the tunnels
7. **Deep Field**: open space and a plated leviathan
8. **The Core**: the shelled overmind at the heart of it all

Hold fire to charge a beam that ploughs through whole formations. Shoot down carriers for lettered capsules:
- **S**, **L** and **C** arm your pod with spread, lance or crossfire. The pod is a detachable orb that fires with you, and you can launch it ahead or call it back as a shield.
- **+** speeds the ship up.
- **H** brings a pair of helper satellites.

Your ship is a slim swept dart with a cockpit window set into a low fairing, whose glint slides along as it banks. Its engine flame grows as you speed up.

It all comes wrapped in:
- a striped μB-TYPE logo with a travelling glint, a starfield and a scroller
- a ship flying across the title screen, past a planet
- Hall of Fame, How to Play and Power-ups pages
- an attract mode that flies the real game on a different stage each time
- stage intros, game over, name entry and a congratulations screen after stage 8
- VZ-TYPE's two-voice beeper music and its full set of sound effects
- a 70s "future" typeface throughout, with the double-width stroke on the lower left of each character
- a trainer mode (press **T** on the title)
- a separate set of graphics for **monochrome monitors**: pick colour or mono when the game starts

## Specifications

| | |
|---|---|
| **Machine** | Microbee Premium Plus with 1MB of RAM. Z80 at 3.375 MHz |
| **Display** | 64×16 programmable characters of 8×16 pixels: 512×256, exactly 4× the VZ300's 128×64 each way. Colour, or a monochrome mode with its own glyph sets |
| **Scrolling** | Smooth and tear-free: one VZ pixel (4 Microbee pixels) per game frame, using the 6545's start address over two screen pages and pre-shifted terrain characters |
| **Frame rate** | Capped at 25 frames per second, like the VZ original. Every stage plays at or near the VZ's speed; the bosses run at about 16–19 |
| **Disk** | `UBTYPE.DS8`, an 800K DS80 image that boots straight to the CP/M `A>` prompt (no Microbee shell). 23 files, 588K used |
| **Loading** | Type `UBTYPE`. The loader fills about 20 of the machine's 32K memory blocks, which takes about 40 seconds in the emulator |
| **Memory map** | Game code from $8000. Sprites, glyph mirrors and work tables in a 32K work block below it. Each stage carries 64K of its own: 32K of character graphics and 32K of tables, sprites and boss art. The front end, title graphics and shared graphics live in their own blocks |
| **Sound** | Speaker beeper: VZ-TYPE's effect engine and two-voice music player, retimed for the Microbee so every note and effect keeps its VZ pitch |
| **Controls** | Q A O P or cursor keys, SPACE to fire and charge, M or Z for the pod, H to pause. A joystick on the parallel port also works |
| **Source** | About 10,000 lines of Z80 assembly, plus about 4,000 lines of Python tools that draw the art and build the disk |

## The conversion challenges

**Four times the pixels, and no bitmap.** The VZ300 has a simple bitmap screen. The Premium Plus draws everything from programmable characters (PCG). At 512×256 there's no pixel buffer to draw sprites into. Every 8×16 cell a sprite touches has to become a freshly built character on every frame: the background is copied out, the sprite is masked in, and the result goes into a spare character slot. The sprites are four times the VZ's size in each direction, so a busy screen can need a hundred of these cells a frame. Two pools of 256 spare characters, one per screen page, keep the frame being built separate from the one on show.

**Smooth scrolling on a character screen.** Character displays normally scroll a whole character (8 pixels) at a time, which looks jerky. μB-TYPE scrolls 4 pixels a frame, exactly one VZ pixel, to match the original's speed. Each terrain column exists twice in character memory: once as drawn and once shifted by 4 pixels. The 6545's start address moves through a two-page ring, so a new column only has to be added at the edge. The flip to the finished page happens in the vertical blank, so the playfield never tears.

**Keeping the game identical.** The movement, enemy patterns, collisions and scoring are VZ-TYPE's own code, ported, and the stage data is the VZ's. A test harness ran the original in a VZ300 model alongside μB-TYPE, fed both the same inputs and random seed, and compared the game state after every frame. With the Microbee's thinning switched off, every frame matched, apart from a few frames when a life restarts. Those differ because of how the harness lines the two machines up, not because of the game.

**Making it fast enough.** The first working build ran the heaviest boss scenes at under 10 frames per second against the VZ's 20. A long optimisation pass, and then thinning the enemies and bullets, brought the slowest scenes up to about 16–19. The optimisation added:
- self-modifying sprite routines
- a fast path for sprite cells over open space
- an overlay that pops sprite data off the stack two lines at a time
- a cache that keeps boss parts' characters while the scenery stands still
- a one-pass colour write
- ready-made glyphs for enemy bullets over open space

All of this kept the full-resolution art. Lighter scenes now run at the VZ's speed. The busiest still slow down evenly, without losing smoothness or tearing.

**Sound at a different clock.** The VZ's effects are timed by the length of its idle loop. The Microbee's loop was written to take 180 T-states, the same 53.3 µs at 3.375 MHz, so every effect plays at the VZ's pitch. The music player keeps the VZ's 122 T-state loop structure with new pitch tables, so even its quirks survive.

**Banking and booting.** Everything is spread across the Premium Plus's 32K memory blocks. The front end is an overlay that is copied in over the stage buffers whenever it's needed. A small CP/M loader finds CP/M's own block and checks the machine has the blocks the game needs. It reads each file into place, switches CP/M out and starts the game. There's no shell and no extra setup: the disk boots to `A>` and you type one word.

**Monochrome monitors.** A monochrome monitor lights every set pixel whatever its colour, so colour alone can't separate the scenery from the background. Each stage carries a second set of terrain, band and boss characters, with outlines and patterned shading, so the game still reads on a green, amber or white screen.

## Testing

So far μB-TYPE has been tested only in an emulator: a Premium Plus model written for the project, which boots the real Microbee boot ROM. It hasn't yet run on real hardware. The full test results are in `VERIFICATION.md`.

---
*Directed and playtested by BPM. Code, graphics and music by Claude (Anthropic). Converted from VZ-TYPE for the Dick Smith VZ300.*
