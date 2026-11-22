# Real MZ-700 test sheet

Everything so far has been checked only in the simulator and in the MZ-700 Emulator for Win32.
This sheet covers the first run on the real machine. Load each file the way you normally load an
MZT through UniCMT. A phone photo of each screen listed below is all that's needed.

## Files to put on the UniCMT stick

| File (in `release/`) | What it is |
|---|---|
| `MZRAY.MZT` | the speed benchmark (small, quick to load) |
| `DROPBEAR.MZT` | the game, packed: it unpacks itself in about half a second after loading |
| `DROPBEAR_FULL.MZT` | the same game unpacked, about 2.5 times longer to load. Only needed if `DROPBEAR.MZT` doesn't start. |

## Test 1: the benchmark (`MZRAY.MZT`)

1. Load and run it. It runs four timed tests by itself, about 15 to 25 seconds in all.
2. **Photo A:** the results screen (four lines of fields and fps).
3. On the results screen, press **1**, **2**, **3** or **4**. The view should change mode each time.
4. Try the **cursor keys**: up and down should walk, left and right should turn.
5. Press **B**: the benchmark should start again.
6. Note any key that does nothing or does the wrong thing.

For comparison, the Win32 emulator gave 76 / 85 / 125 / 134 fields.

## Test 2: the game (`DROPBEAR.MZT`)

1. **Time the load** with a stopwatch, from starting the tape until the title appears.
2. **Photo B:** the title screen, with "DROPBEAR" in big red letters.
3. **Listen to the title music.** It's slow and ominous (a heartbeat, then rising notes, then a
   sad trombone). Say whether it sounds too high, too low, or about right. For comparison, you can
   play `sounds/title_music.wav` on the PC: it's what the simulator expects.
4. Leave it alone for about 30 seconds: a monster gallery should follow, then a self-playing demo.
   **Photo C:** one gallery card.
5. Press **SPACE** to reach the intro page, then SPACE again to play.
6. Try each key:
   - **W** forward, **S** back, **A** turn left, **D** turn right, **Q** and **E** step sideways
   - the **cursor keys** should also walk and turn
   - **SPACE** fires (you should hear a "wucka-thump")
   - hold **M** in the first area for the map
   - **1**, **2**, **3** and **4** change the render mode
7. **Photo D:** the starting view in mode 1, with the FPS number in the bottom-left corner.
   Then **Photo E:** the same view in mode 3.
8. Shoot a bear (two shots). It should burst into pieces with a squelch.

## What to send back

- Photos A to E
- the load time for `DROPBEAR.MZT`
- whether the music pitch sounded right
- any keys that didn't work
- anything that looked broken (stray colours, flicker, a frozen screen)

If `DROPBEAR.MZT` loads but the screen stays blank or garbled, try `DROPBEAR_FULL.MZT` and say
whether that one works.
