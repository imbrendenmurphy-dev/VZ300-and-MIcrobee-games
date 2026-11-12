# VZ-DECK

A boot-time game launcher and music player for the Dick Smith **VZ300 / VZ200** with the
**BennVenn SD loader + 128K**. VIBED BY BPM 2026. Version 0.9.

Switch the VZ on and VZ-DECK comes up instead of BASIC. It shows the folders and files on
the SD card, so games that need DAT files can live in folders of their own, and it runs any
`.VZ` file you pick. It also plays music through the VZ's 1-bit speaker: MIDI and MOD files
are built in, and PT3, PSG, S3M, XM and VGM files play through plug-in players.

```
VZ-DECK 0.9    VIBED BY BPM 2026
/GAMES/                    5/ 12
■ ..            <DIR> 06-11-26
■ ARCADE        <DIR> 06-11-26
■ ROBOGEDN VZ   22920 06-11-26
■ ROBOGEDN DAT  98304 06-11-26
■ TITLE    MOD  41300 02-03-94
...
ROBOGEDDON 2085  M/C AT 8000
RET:OPEN B:BASIC C:CLI O:OUTPUT
```

## What goes on the SD card

Copy these from `release/` to the **root** of the card:

| File | What it is |
|---|---|
| `VZDOS.VZ` | Ben Grimmett's VZDOS 2.32 with one jump redirected, so it loads `SHELL.VZ` at power-on. **Not in the GitHub copy**: make it from your own card's VZDOS 2.31/2.32 with `src/patchdos.py` |
| `SHELL.VZ` | VZ-DECK itself: the browser and the MIDI/MOD player |
| `PLAYPT3.VZ` | Plug-in player for PT3 (ProTracker 3 / Vortex Tracker) music |
| `PLAYPSG.VZ` | Plug-in player for PSG (AY register dump) music |
| `PLAYS3M.VZ` | Plug-in player for S3M (Scream Tracker 3) music |
| `PLAYXM.VZ` | Plug-in player for XM (FastTracker 2) music |
| `PLAYVGM.VZ` | Plug-in player for VGM music for the SN76489 chip (Master System, Game Gear, BBC Micro, ColecoVision...) |

Keep a copy of your original `VZDOS.VZ`. If anything goes wrong, delete the patched one
from the card and the loader's built-in BIOS takes over again.

`DEMO.PT3`, `DEMO.PSG`, `DEMO.S3M`, `DEMO.XM` and `DEMO.VGM` are small test tunes made for checking the players.

## Power-on

| Hold | Gets you |
|---|---|
| nothing | VZ-DECK |
| **B** | plain BASIC |
| **SPACE** | the DOS command line |

## The browser

| Key | |
|---|---|
| up / down arrows (`.` and SPACE, with or without CTRL), joystick 1 | move (holds repeat) |
| left / right arrows (`M` and `,`), joystick left / right | page up / page down |
| RETURN or fire | open a folder, run a `.VZ`, play music |
| **B** | BASIC |
| **C** | DOS command line |
| **O** | choose the sound output (plays a test beep) |

- Folders come first, then files in name order, with size and date. Long-name entries,
  deleted files and hidden system folders are left out.
- Icon colours: yellow folder, red `.VZ`, cyan `.DAT`, magenta music.
- The bottom line shows the highlighted `.VZ` file's own name, type and load address.
- Coming back out of a folder puts the cursor on the folder you left.
- Up to 250 entries per folder.
- BASIC programs load and drop to `READY`; type `RUN`.

There's no reset button on a VZ, so after a game, switch off and on to get back to VZ-DECK.
A game of your own can return to VZ-DECK at any time with:

```
        XOR A
        OUT (37h),A     ; switch the card back to its built-in BIOS
        JP 0            ; restart: the BIOS reloads the DOS and VZ-DECK
```

## Music

| Type | Player | Notes |
|---|---|---|
| `.MID` | built in | Any size. Up to about 24K loads whole; bigger files play straight off the card with a short pause on each card read |
| `.MOD` | built in | 15- and 31-instrument modules. Only the note data is read, so the samples don't count against memory |
| `.PT3` | `PLAYPT3.VZ` | ProTracker 3 / Vortex Tracker II, up to about 17K |
| `.PSG` | `PLAYPSG.VZ` | AY register dumps, any size. Many PC tools convert YM, VTX, AY and other chip tunes to PSG |
| `.S3M` | `PLAYS3M.VZ` | Scream Tracker 3, up to 32 channels. Patterns are read from the card as they come up (up to 8K each) |
| `.XM` | `PLAYXM.VZ` | FastTracker 2, up to 32 channels heard (more are read past). Patterns are read from the card as they come up (up to 12K each) |
| `.VGM` | `PLAYVGM.VZ` | SN76489 music, streamed from the card. Other chips in the file are skipped. Compressed `.VGZ` files must be unzipped on a PC first (rename the result to `.VGM`) |

Everything is played as three square-wave voices plus drum bursts:

- **MIDI and MOD:** the highest note sounding takes the lead, the lowest takes the bass,
  and the most recently struck of the rest takes the middle voice. Drums are picked from
  the MIDI drum channel, or from MOD instrument names (kick, snare, hat...).
- **S3M:** like MOD, reduced to lead, bass and middle voices, with drums picked from
  instrument names. Speed, tempo, pattern break and jump are followed; a jump backwards
  (a song's loop point) ends the song.
- **XM:** the same as S3M: lead, bass and middle voices, drums from instrument or sample
  names, and speed, BPM, volume, pattern break and jump followed. Key-off stops a note.
- **VGM:** the SN76489's three tone channels map straight onto the three voices, with
  volume as pulse width. White noise becomes a hat or snare burst.
- **PT3 and PSG:** the three AY channels map straight onto the three voices, with volume
  as pulse width. Ornaments, samples, slides and portamento are followed. Noise becomes a
  hat or snare burst.

S3M, XM and VGM files are read from the card as they play. Files are fine up to 255 card
clusters (about 1 MB on a card with 4K clusters); past that the rest of the file reads as silence.

Keys while playing: **SPACE** (or P) pause, **RETURN** or fire stop, **V** change view.
Every player has bars, scope and piano roll views. The fourth view is a tracker view for
MOD, PT3, S3M and XM (the notes of each row as it plays), the live AY registers for PSG
and the live SN76489 registers for VGM.
The plug-ins remember the view you last chose.

### Sound output (O in the browser)

| Output | What it drives |
|---|---|
| Speaker | the VZ's own speaker (latch bits 0 and 5) |
| Cassette port | cassette out (latch bits 1 and 2, levels 4 and 6) into an amplifier |
| Speaker + cassette | both |
| Printer port | `OUT (14),A` with the speaker's bit pattern, so data bits 0 and 5 of the printer plug carry the sound. Wire amplified speakers to those pins, or between them for twice the swing |

Pitch and tempo are corrected for the printer port's slightly slower output instruction.
The choice lasts until power-off.

### Plug-in players

VZ-DECK looks in the root folder at start-up. A file called `PLAYxxx.VZ` plays files ending
in `.xxx`, so new players can be added without changing the shell. A plug-in loads at
`$A000`, finds the music file's details at `$7FC0`, and reloads `SHELL.VZ` when it's done;
see `src/plib.asm`.

## Memory

| Range | Use |
|---|---|
| `$4000–$5FFF` | VZDOS (in the card's RAM); patch stub at `$5BBA` |
| `$6000–$67FF` | VZ-DECK player code (MOD, views) |
| `$7000–$71FF` | screen |
| `$7C00–$7FBF` | VZ-DECK variables (kept while a plug-in runs) |
| `$7FC0–$7FDD` | hand-over block for plug-ins |
| `$8000–$98BD` | VZ-DECK |
| `$9A00–$F7FF` | folder list / music buffers / plug-ins at `$A000` |
| `$F800–$FFFF` | DOS buffers and stack |

## Building

`src/build.sh` builds everything with Python 3; output goes to `src/out/`. It needs no
other tools: `asm.py` is a small Z80 assembler written for this project.

```
cd src
sh build.sh
python3 patchdos.py <your VZDOS.VZ> out/VZDOS.VZ
```

`src/` also has a Z80 emulator with a simulated SD card (`z80.py`, `vz.py`) and the tests
used during development (`test*.py`, `mt*.py`, `pt3test.py`, `psgtest.py`, `outtest.py`...).
They run the real VZDOS code, so they need your own `VZDOS.VZ` in a `testfiles/` folder next
to `src/` (or set `VZDECK_FILES`). Some also use a MIDI and a MOD file from there.

## Credits

- VZDOS and the SD loader are by **Ben Grimmett (BennVenn)**. VZ-DECK is a separate program
  that runs on top of his DOS; the GitHub copy contains no part of it, only the patch tool.
- Everything else: VIBED BY BPM 2026.
