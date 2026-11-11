# RED DUST RUMBLE

A one-on-one fighting game for the Dick Smith VZ300, in the style of Street Fighter II. Sable's Travelling Boxing Tent is in town: beat the troupe, then the Ringmaster.

VIBED BY BPM 2026

**Status: design stage.** There is no playable build yet. See [DESIGN.md](DESIGN.md) for the full pitch, the first playable build, and the hardware test plan.

## Hardware

VZ300 with a BennVenn SD loader and 128K RAM expansion. Joystick (two buttons) or keyboard.

## The plan in short

- Side view, single-screen arena, best of three rounds, health bars and a round timer.
- Stick and two buttons. Standing, crouching and jumping each change what the buttons do. Signature moves are both buttons together.
- First playable: Flick Finnegan (fast, close-range) against Dusty Marlowe (slow, long reach) in the Showground Tent, versus the CPU.
- Full game: six fighters, a boss, six arenas and a seven-fight single-player circuit.
- Four test programs (PADTEST, LAGTEST, DRAWTEST, BANKTEST) run on the real machine before the game code is written.
