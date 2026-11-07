# μB-TYPE
### for the Microbee Premium Plus. VIBED BY BPM 2026

**μB-TYPE? Is it a typing tutor for the Microbee? No!** It's a horizontally scrolling shoot-'em-up.

It started life as **VZ-TYPE** on the Dick Smith VZ300. You can't even get an AI to copy R-Type, so BPM had one make him his own instead. VZ-TYPE now lands on the Premium Plus at four times the resolution in both directions, with all-new art. Underneath it's the same game: VZ-TYPE's stages, enemy waves, bosses and weapons, thinned a little to keep it flowing on a keyboard.

## The game

A lone fighter takes on eight stages of biomechanical trouble, each ending in a huge boss. Hold fire to charge a beam that ploughs through whole formations. Shoot down carriers for lettered capsules:
- **S**, **L** and **C** arm your pod with spread, lance or crossfire. The pod is a detachable orb you can launch ahead or keep as a shield.
- **+** speeds you up.
- **H** brings two helper satellites.

1. **Outer Hull**: riveted plating, gun emplacements and an armoured fortress
2. **The Hive**: pulsing organic walls and a brood mother
3. **Rock Belt**: boulder-strewn caverns where an armoured serpent coils through the rocks
4. **Crystal Vein**: glittering mineral seams and a crystal colossus
5. **Dreadnought**: one long fly-past of a giant warship, its turrets and reactor nodes, up to the bridge tower
6. **Gut Caverns**: a horned maw waiting in the tunnels
7. **Deep Field**: open space and a plated leviathan
8. **The Core**: the shelled overmind at the heart of it all

## Specifications

| | |
|---|---|
| **Machine** | Microbee Premium Plus, 1MB of RAM, Z80 at 3.375 MHz |
| **Display** | 64×16 programmable characters of 8×16: 512×256, exactly 4× the VZ300's 128×64 each way. Colour, or a monochrome mode with its own graphics |
| **Scrolling** | Smooth and tear-free: 4 pixels a frame, double-buffered with the 6545's start address |
| **Frame rate** | Up to 25 frames per second, like the VZ original |
| **Sound** | Beeper: VZ-TYPE's two-voice music and sound effects, retimed to keep the VZ's pitch |
| **Disk** | `UBTYPE.DS8` (800K DS80). Boots to the CP/M `A>` prompt; type `UBTYPE`. No shell needed |
| **Controls** | Q A O P or cursor keys, SPACE to fire and charge, M or Z for the pod, H to pause. Joystick on the parallel port |

## The conversion

- **No bitmap.** The Premium Plus draws everything from programmable characters, so every 8×16 cell a sprite touches is rebuilt as a fresh character each frame: background copied out, sprite masked in. Two pools of 256 spare characters, one per screen page, keep the frame being built apart from the one on show.
- **Smooth scrolling on a character screen.** Each terrain column is stored twice, as drawn and shifted by 4 pixels. The 6545's start address walks a two-page ring, so only one new column is added each frame, and pages flip in the vertical blank.
- **Speed.** Sprites are 16 times the VZ's area. To keep up, the drawing code uses self-modifying routines, stack-popped sprite data, a cache for boss parts, and ready-made characters for bullets. The enemy count is also trimmed.
- **Same game.** The game logic is VZ-TYPE's own, ported. With thinning switched off, a test harness matched it frame for frame against the original running on an emulated VZ300.
- **Sound.** The idle loop runs at the VZ's 53.3 µs at 3.375 MHz, so every effect keeps its pitch.
- **Banking.** Everything is spread across the Premium Plus's 32K memory blocks. A small CP/M loader fills them, switches CP/M out and starts the game.
- **Monochrome.** Each stage has a second set of graphics with outlines and patterned shading, so it reads on green, amber or white monitors.

Tested on Microbee Premium Plus hardware.

---
*VIBED BY BPM 2026*
