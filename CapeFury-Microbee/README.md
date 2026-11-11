# CAPE FURY

A one-on-one fighting game for the Microbee Premium Plus, in the style of Street Fighter II. The light at Cape Fury has gone out for the night: fight your way from the wreck beach to the lantern room and beat the Keeper.

VIBED BY BPM 2026

**Status: design stage.** There is no playable build yet. See [DESIGN.md](DESIGN.md) for the full pitch, the first playable build and the hardware test plan.

## Hardware

Microbee Premium Plus, native Z80 at 3.375 MHz, 32K PCG RAM. Keyboard, with a joystick for a second player. Colour or amber monochrome, chosen at startup. Will ship as `FURY.DS8`, booted from the SD card.

## The plan in short

- Side view, single-screen arena, best of three rounds, health bars and a round timer.
- Directions and two buttons. Standing, crouching and jumping each change what the buttons do. Signature moves are both buttons together.
- First playable: Wren Hallett (fast, close-range) against Harrow Tate (slow, long reach, floor shockwave) on The Jetty, versus the CPU.
- Full game: eight fighters, a boss, seven arenas and a seven-bout single-player climb with unlimited continues.
- Four test programs (KEYTEST, LAGTEST, DRAWTEST, LOADTEST) run on the real machine before the game code is written. KEYTEST decides the default keys and whether two players can share the keyboard.
