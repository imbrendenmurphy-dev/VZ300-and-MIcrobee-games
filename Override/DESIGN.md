# OVERRIDE - design notes

An original top-down "droid transfer" action game for the Dick Smith VZ300 with the
BennVenn SD loader and 128K. You are a LINK PROBE (unit 000) loose on a derelict fleet
whose service droids have been taken over by a rogue ship mind. Shoot droids, or link
into them and take them over through a short circuit duel, then use their bodies to
clear every deck of every ship.

## Display
Mode 1, 128x64, colour set 0 (green, yellow, blue, red).
- Rows 0-9: HUD (score, deck, host droid, energy bar), rows 10-63: the deck view
  (128 x 54 = 16 x 9 tiles of 8 x 6 pixels).
- Tiles are 8 px wide (2 bytes) by 6 rows, close to square on a 4:3 TV.
- Droids are 13 x 8 sprites: a dome and a band carrying the droid's three-digit
  number in a 3x5 font. The player's host is yellow with blue digits; hostile droids
  are red with yellow digits.

## Engine (game mode: mapping 7, IM 2 field interrupt)
- **4-phase ring buffer** in low bank 3 ($4000-$5FFF): the deck around the camera is
  kept pre-rendered at all four pixel phases, 64 rows x 32 byte columns each. Moving
  the camera only renders the new byte column or pixel row (all four phases), so
  scrolling is pixel smooth in all eight directions.
- Each frame the visible window (54 rows) is copied from the right phase into the
  back buffer (40-byte rows with 4 guard bytes each side so sprites need no
  horizontal clipping), then sprites and the HUD are drawn.
- The field interrupt copies the back buffer to video RAM with an unrolled stack
  copy (12.75 T a byte), starting at field sync and outrunning the beam.
- One-voice effects ride along: one speaker sample about every 610 T in the
  interrupt copy, the window copy and the idle wait. IY is the phase accumulator
  and is never used by game code.
- Target 25 frames a second (two fields a frame).

## Front end (FE mode: interrupts off)
Title, attract pages, transfer duel, lift, console, cards, game over, high scores,
ending. Music is the three-voice pulse player from Dracula's Castle II (pulse voices
with decaying width, noise channel for drums), playing in each frame's idle time.
Screens change video RAM a few rows at a time (dirty rows), so the music hardly
stops.

## Memory (mapping 7 = low bank 3 + upper bank 1)
| Range | Contents |
|---|---|
| $4000-$5FFF low bank 3 | ring buffer, 4 phases x 2K |
| $6000-$67FF low bank 3 | pre-shifted droid sprites for this deck (8 slots x 256) |
| $7000-$77FF | video RAM |
| $7800-$7BFF | left alone (ROM/DOS system area) |
| $7C00-$7D7F | IM 2 table + vector |
| $7D80-$7FFF | stack |
| $8000-$AFFF | main code (OVERRIDE.VZ) |
| $B000-$B7FF | variables, object tables, SD bounce buffer |
| upper 1 $B800-$C1FF | back buffer, 64 rows x 40 bytes |
| upper 1 $C200-$C9FF | current deck map, 64 x 32 tiles |
| upper 1 $CA00-... | front-end code, screen copy code, tiles, font, music (OVCOM.DAT) |
| upper 0 $B800-$EFFF | ship data (OVSHIPn.DAT), title picture, text (storage only) |
| upper 0 $F000-$FFFF | DOS stack, sector buffer, DOS RAM (never touched) |
