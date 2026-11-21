# VZonPC

An emulator for the Dick Smith **VZ200** and **VZ300** (VTech Laser 210/310) for Windows, with a version for
Linux and macOS (see [Linux and macOS](#linux-and-macos)).

- **Machines:** VZ200 (8K, 3.58 MHz) or VZ300 (18K, 3.55 MHz).
- **Memory:** no expansion, the 16K RAM pack, or the **BennVenn SD loader with 128K**.
- **Cartridges:** the **disk drive** (DD20 controller, two drives, `.dsk` images), the **RTTY terminal pack**, the
  **RS-232 interface** (to a telnet host or COM port) and **WordPro** (in the disk controller's slot).
- **Tape:** WAV, FLAC or MP3 audio into the cassette socket, and `CSAVE` to a WAV.
- **Printer and light pen:** `LPRINT`, `LLIST` and `COPY` go to a text file; the mouse is the light pen.
- **SD card:** a folder on the PC stands in for the card.
- **Graphics:** the standard MC6847, the **Australian super hi-res mod**, or the **German hi-res mod**. Both mods give 6K of video RAM and 256×192.
- **Display:** 1:1 pixels, scaled ×2–×5, any window size, or fullscreen.
- **Input:** USB joysticks and gamepads, or the keyboard.
- **Sound:** the speaker, through the PC's sound card.
- **Testing:** `vzemu.exe`, a headless runner for scripted tests, screenshots and WAV capture.

It builds with the C# compiler that comes with Windows. There is nothing to install.

## Files

| | |
|---|---|
| `VZonPC.exe` | the emulator window |
| `vzemu.exe` | headless test runner (same emulation core) |
| `VZonPC-SDL.exe`, `vzonpc.sh`, `vzemu.sh`, `play-2018ad.sh` | the Linux and macOS version, and its launch scripts |
| `build.bat` | rebuilds all three from `src\` |
| `SD\` | the default SD card folder (mount any folder from the File menu) |
| `roms\` | put a VZ BASIC ROM here (optional, see below) |
| `tools\zasm.py`, `tools\mkvz.py` | Z80 assembler and `.VZ` wrapper (Python 3) |
| `vzonpc.ini` | settings, written on exit |

## The ROM

VZ BASIC is copyright VTech, so it isn't included. Without it the emulator runs a small
built-in stub, and **machine-code `.VZ` programs run fine**. All your games work this way.
BASIC programs, and programs that call ROM routines, need the real ROM in `roms\` under
one of these names:

| Machine | File |
|---|---|
| VZ300 | `vz300.rom` or `vtechv20.u12` (16K) |
| VZ200 | `vz200.rom` (16K), or `vtechv20.u09` + `vtechv20.u10` (8K each) |
| Disk drive cartridge | `vzdos.rom` (8K, DOS BASIC V1.2) |
| RTTY cartridge | `vzrtty.ic3` (4K) |
| RS-232 cartridge | `rs232_v15.ic2` or `rs232_v16.ic2` (2K) |
| WordPro cartridge | `wordpro.u3`, `wordpro.u4`, `wordpro.u5` (4K each), with `vzdos.rom` |

The two are BASIC V2.0, so either machine falls back to the other's ROM. These are the
MAME `vz200` / `laser310` ROM files. With a ROM, the emulator boots to `READY` and BASIC
programs are loaded and `RUN` for you.

## Booting VZDOS and VZ-DECK

This works like the real loader. With the **BennVenn** selected, a **ROM** in `roms\` and a **`VZDOS.VZ`** found,
switching on (F4, or starting VZonPC) goes through these steps:

1. The VZ ROM finds the loader's BIOS at `$4000` and runs it.
2. The BIOS loads `VZDOS.VZ` into the 128K's DOS RAM and runs it. It looks for `VZDOS.VZ` in the root of
   the SD card folder first, then in `roms\`.
3. VZDOS talks to the SD card over SPI (port `$39`), exactly as on the real machine. The mounted folder is presented to it as a
   FAT32 card, with subfolders, 8.3 names and file dates.
4. A patched VZDOS that boots VZ-DECK (`SHELL.VZ` in the root of the card) comes up in VZ-DECK. Hold **B** for BASIC
   and **SPACE** for the DOS command line, as on the real machine.

Games run from VZ-DECK load their files through the real DOS. Programs that do `OUT (37h),0 : JP 0` reboot into the
BIOS, which reloads VZDOS, as the real loader does. Mounting a different folder while VZDOS is running restarts the
machine, like swapping the card.

- Without a `VZDOS.VZ`, or with **Machine → Boot VZDOS.VZ at power-on** turned off, the machine boots to plain BASIC.
- **F2**, **F3** and drag-and-drop still load programs the quick way: straight into memory, with the emulator's
  own built-in DOS reading files from the folder. That also works for a game in its own release folder,
  outside the card.
- **Saving goes to the PC folder.** Changes VZDOS makes to the card are written back to the PC folder about half a
  second after the DOS stops writing, and again at power-off and when you close VZonPC. That covers BASIC `SAVE "NAME"`,
  overwriting, new folders, renames and deletes. Saved files get their 8.3 name (`SAVE "TEST"` → `TEST.VZ`). Files
  with long PC names keep them. A file the DOS deletes goes to the Windows **Recycle Bin**, so nothing is lost by mistake.
  Turn it off under **Machine → Save SD card changes to the PC folder**: saves then last until the next power cycle.

## Using it

- **F2** opens the SD card browser. Pick a `.VZ` and it loads the way the BennVenn menu loads it.
- You can also drop a `.VZ` on the window to run it, or drop a folder to mount it as the SD card.
- When a program is loaded with F2, F3 or a drop (not through VZDOS), games that read files through the DOS calls (`$5F00` open, `$5F03`/`$5F09`
  read sector) get them from the SD folder. They are also looked for in the folder the `.VZ` came from,
  so a game can be run from its own release folder.

| Key | |
|---|---|
| F1 | help |
| F2 | SD card browser |
| F3 | load any `.VZ` file |
| F4 / Shift+F4 | power cycle / reset the CPU |
| F5 | reload the last program |
| F6 | pause |
| F7 | paste the clipboard as typing (for BASIC listings) |
| F8 | mute |
| F9 | warp speed |
| F10 | visualiser (sidebars in fullscreen, its own window otherwise) |
| F11 or Alt+Enter, or double-click | fullscreen |
| F12 | screenshot, saved to `screenshots\` |

**VZ keyboard:** letters, digits, SPACE, RETURN, SHIFT, CTRL, `, . - ;`, and `'` for the VZ's `:` key.
The `=` key types `=`. Backspace is RUBOUT, Insert is INSERT, and Esc is BREAK.

**Joysticks:** the first USB joystick or gamepad is VZ joystick 1 and the second is joystick 2.
Buttons 1 and 3 are fire, and 2 and 4 are the second ("arm") fire. Sticks and D-pads both work.
Plugging a stick in while the emulator runs is picked up. On the keyboard, the arrow keys and
**Right Ctrl** are joystick 1. Under **Input** the arrows can be switched to the VZ cursor keys.

**View:** 1:1 pixels, ×2 to ×5, or resize the window freely. *Whole-pixel scaling only* keeps the
pixels sharp. Turn it off to fill the window, keeping the aspect ratio. The view also has a border
on/off option, a monochrome TV option and *Show VRAM snow*, which marks CPU video RAM accesses during
the picture the way the real machine shows them.

**Machine:** VZ200 / VZ300, the memory expansion, the graphics mod and the joystick interface.
Changing any of these power-cycles the machine and reloads the current program.

## Tape input

**File → Play tape (audio file)...** plays a WAV, FLAC or MP3 into the VZ's cassette socket, exactly as a tape
recorder would. Type `CLOAD` or `CRUN` first, as on the real machine. The ROM's own loader reads it, and so do
fast loaders that time the signal themselves. The status bar shows the tape position.

- The input is modelled as the VZ's inverting comparator, with its threshold just above zero, so silence reads the
  same as no tape. Fast loaders depend on that to finish a block. **Tape: invert the signal** flips it if a
  recording was made the other way round.
- With a stereo file, the left channel goes to the VZ, and the right channel plays through your speakers.
  **Tape: use the right channel** swaps them.
- Ogg files can't be opened: Windows only decodes Ogg for Store apps. Convert them to WAV first.

**2018 A.D. by Five Finger Punch** (Edison 2018) runs this way, from its original CD audio. Its left channel is a
ROM-speed boot, then 25 speedloaded parts at about 4,000 bits per second. Its right channel is the music. Set up a
VZ200 with no memory expansion, type `CRUN`, then play the audio (`combined.ogg` from scene.org, converted to WAV).
From the command line:
`VZonPC.exe --no-settings --machine vz200 --exp none --type "CRUN\r" --tape 2018AD_combined.wav`

## Saving to tape

**File → Record to tape (CSAVE to a WAV file)...** starts the tape recorder. Type `CSAVE "NAME"` and press RETURN,
and when `READY` comes back, **File → Stop recording** writes the WAV (44.1 kHz, trimmed to the recording). The
status bar shows `REC` while it runs. The recording loads back with **Play tape** and `CLOAD`, on a VZ200 or a
VZ300, and it should load on a real VZ the same way.

- `CSAVE` writes `$26` and `$20` to the latch: bits 1 and 2 drive the cassette output together. Their polarity
  matches the tape input, which loads real VZ tapes (2018 A.D.'s CD audio) without inverting.
- A level held for more than 5 ms fades to silence, as it would through a real recorder's AC-coupled input.

## Disk drive (DD20)

**Machine → Cartridge → Disk drive controller** plugs in the VZ disk controller (the DD20 / X-7304 interface) with
two 5.25" drives. It needs the controller's 8K **DOS BASIC V1.2** ROM as `roms\vzdos.rom`. It works with no memory
expansion or the 16K pack. At power-on the ROM signs on as `DOS BASIC V1.2`, and the usual DOS commands work:
`DIR`, `SAVE "NAME"`, `LOAD "NAME"`, `RUN "NAME"`, `BSAVE`, `BLOAD`, `BRUN`, `ERA`, `REN`, `INIT`, `DRIVE 2` and the rest.

- **File → Disk drive 1 / 2** inserts a disk image (`.dsk`, `.dvz`), makes a new blank disk, or ejects. Dropping a
  `.dsk` on the window puts it in drive 1 (and plugs in the controller if needed). `--disk FILE` and `--disk2 FILE`
  do the same from the command line. The disks in the drives are remembered between runs.
- **Writes go back to the file**, a second after the DOS stops writing, and on eject and exit. A read-only file is a
  write-protected disk. Images are written in the 155-bytes-per-sector layout MAME uses (99,200 bytes). Any VZ
  image that has the sector marks can be read, including VZEM's 99,184-byte ones.
- **It is emulated at the flux level, as MAME does it.** The VZ's DOS does all the encoding in software: it steps the
  head through four stepper phases, polls a flip-flop that toggles on every flux transition, and reads bits from a
  shift register at its own timing. The disk turns at 85 RPM, each bit cell is 32.4 µs, and a 1 has a second
  transition 7.9 µs in. Tracks hold the real transition positions, so reads, writes and `INIT` (which reformats
  every track) all run the real DOS code at the real speed. MAME patches two bytes of this ROM to make it work. VZonPC
  doesn't need to: the Z80 timing is exact enough for the original.
- The status bar shows the drive and track while the motor runs, and the visualiser's bottom-right panel shows the
  head on the 40 tracks, the 16 sectors in their interleaved order and where the head is over the spinning disk.

## RTTY terminal pack (K-6318)

**Machine → Cartridge → RTTY terminal pack** plugs in Dick Smith's 1984 RTTY interface (designed by VK2IDL and Rex
Callaghan, published in ETI, November and December 1984). It needs its 4K ROM as `roms\vzrtty.ic3`. At power-on
the ROM shows its title, asks for your callsign, and then offers receive, transmit and message buffers
(**SHIFT X** for the menu). It does 45, 50, 75 and 110 baud Baudot.

- **Receiving:** **File → RTTY: receive from an audio file...** plays a recording into the cartridge's
  demodulator. It takes WAV, FLAC or MP3 of standard amateur AFSK RTTY: mark 2125 Hz and space 2295 Hz
  (170 Hz shift). It could be recorded off air, from a WebSDR, or made with fldigi. `--rtty FILE` does the same
  from the command line.
- **Transmitting:** while the ROM keys the transmitter, its tones play through your speakers, so they can be
  decoded by fldigi on another machine.
- **The cartridge's registers** are memory-mapped:
  - reading `$5000`–`$57FF` gives the received bit in bit 7;
  - writing `$5800`–`$5FFF` sets the transmitted bit in bit 7;
  - writing `$6000`–`$67FF` sets the relay (push-to-talk) in bit 7.

  The polarity comes from the ROM itself: 1 means mark on both lines, and `$FF` keys the transmitter. MAME maps the
  same registers, but stubs the signals out.
- The visualiser's bottom-right panel scopes the last second of the receive and transmit lines, with dots where the
  ROM samples the received bit.

## RS-232 interface (K-6317)

**Machine → Cartridge → RS-232 interface** plugs in Dick Smith's serial cartridge. It needs its 2K ROM as
`roms\rs232_v15.ic2` (or `rs232_v16.ic2`). At power-on the ROM shows its terminal menu: **0** enters the terminal
(**SHIFT X** leaves it), and **1**–**6** set full or half duplex, echo to the printer, 7 or 8 data bits, 1 or 2 stop
bits, parity, and adding LF to CR.

- **File → RS-232 → Connect to a host (telnet) or COM port...** links the VZ to a telnet host (`host:port`, such as
  a BBS) or to a real serial port on the PC (`COM1`...). `--serial host:port` does the same from the command line.
- **Send a text file...** types a file into the VZ's receive line, and **Loopback** makes the VZ receive what it sends.
- **It runs at 300 baud, bit by bit.** The ROM does the serial timing itself, so a software UART here turns its
  transmit line back into bytes and turns incoming bytes into a receive waveform at the same speed. The ROM keeps
  its settings as characters in its menu text in RAM (`$8031` data bits, `$8049` stop bits, `$8061` parity), and
  the UART reads them from there, so the menu settings apply. Sending `U` and timing its bits shows the speed: one
  bit lasts 11,494 T-states, which is 300 baud nominal (309 on a VZ300).
- The registers are as in MAME: reading `$5000`–`$57FF` gives the received bit in bit 7 (1 = mark), and writing
  `$5800`–`$5FFF` sets the transmitted bit in bit 7, inverted (0 sends mark). The ROM's own code confirms both.
- The visualiser's bottom-right panel shows the link, the counts and the session: sent text in amber and received
  text in cyan.

## WordPro cartridge

**Machine → Cartridge → Disk drive controller + WordPro** fits DSE's word processor cartridge for the VZ300 in the
disk drive controller's own cartridge slot, as it was used, so the drives are there too. It needs its three 4K
EPROMs as `roms\wordpro.u3`, `wordpro.u4` and `wordpro.u5`, and the controller's `vzdos.rom`. The EPROMs sit at
`$D000`, `$E000` and `$F000`, and the first 2K of U3 also appears at `$6000`, where BASIC finds the cartridge's
signature (its 74LS138 decodes A12, A13 and A15 with A14 high; the schematic is on vz200.org). The DOS ROM stays at
`$4000`–`$5FFF`. It uses the space above `$D000`, so it runs with no memory expansion.

At power-on WordPro shows its command menu: **E** edit, **P** print, **C** clear, **D** disk and **T** tape.
**BREAK** (Esc, or CTRL and `-`) goes back to the menu from the editor. **P**, then **M**, prints the text in memory
as formatted pages on the printer (below).

- **Disk commands** (**D**): initiate a disk, directory, save, load, merge and kill. WordPro formats and files disks
  its own way: its directory names are in screen codes, and it counts free tracks. Tested here: initiate a disk,
  save, list, clear the text and load it back, and the same after saving the `.dsk` and starting a fresh machine.
- **WordPro writes its own sector checksum,** one more in the high byte than the sum of the bytes, and reads it
  back the same way. The disk images keep every sector's checksum exactly as written, so WordPro files survive
  being saved to a `.dsk` and loaded again. (The DOS would report these sectors as bad, but only WordPro reads
  them.) It also leaves an erased gap straight after each sector's checksum, which the flux decoder handles.

## Printer

The printer interface (DSE X-7320) is plugged in by default (**Machine → Printer interface**). BASIC's `LPRINT`,
`LLIST` and `COPY` (the screen dump), and WordPro's printing, go to `printer\printout.txt` next to `VZonPC.exe`.
**File → Open the printout** shows it. Each run's printing is added at the end, after a dated line. The bytes exactly
as sent, control codes included, go to `printer\printout.prn`. The printer is always ready.

- **Ports:** reading any port from `$00` to `$0F` gives BUSY in bit 0 (0 = ready). Writing an even port sets the
  data latch, and writing an odd port strobes the byte to the printer. BASIC uses `$0E` and `$0D` (as MAME has it),
  and WordPro uses `$00` and `$01`, so the interface can only decode the lowest address bit. VZEM also takes data on
  both `$0E` and `$00`.
- Programs that drive the latch's outputs directly, such as the robot control program on vz200.org (`OUT 14,64`),
  see the value in the visualiser's printer panel.

## Light pen

**Machine → Light pen** plugs in the VTech light pen interface (ports `$40`–`$4F`). The mouse is the pen: point at
the screen, and **hold the left button** to press the pen against it. The cursor becomes a cross while it's on.

- **Bit 6** reads 0 while the pen is pressed, and **bit 7** drops to 0 when the pen sees the beam go past.
- **It is timed to the beam.** The pen sees light for about 13 µs after the beam draws a bright pixel under its tip
  (green, yellow, buff, cyan, orange and text count, but blue, red, magenta and the dark text background don't). The
  pixel is the one the beam is drawing at that T-state, so a program can change the screen during the frame and
  find the pen with it.
- This was worked out from the light pen driver's own source code (`LPEN.VZ` on vz200.org). It finds the row by
  timing the beam down a screen of bright blocks. It finds the column by switching to MODE(1) at the pen's row,
  part-way down the frame, and lighting halves of a line until the pen sees one. Assembled unchanged and run here,
  it reports the pen to within one pixel across the whole screen (X = column ÷ 2 + 1, Y = line ÷ 3). MAME only
  documents the ports.
- The light pen disk on vz200.org (`Ligthpen.dsk`) is damaged: sector 12 of tracks 1 to 5 is bad, and its pen
  routine (`LPEN 2.0`) starts in one of them. The other programs load, but they need that routine.

## Linux and macOS

`VZonPC-SDL.exe` is the same emulator with a cross-platform front end on SDL2. It runs on Linux and macOS
under modern .NET (8 or later) or Mono, and on Windows too, given `SDL2.dll`. The emulation, the visualiser,
tapes, disks, cartridges, the printer and the light pen are all the same code as the Windows version.

**On Fedora:**

```
sudo dnf install dotnet-runtime-8.0 SDL2 ffmpeg-free zenity
./vzonpc.sh                      # or: ./vzonpc.sh GAME.VZ, ./vzonpc.sh --machine vz200 --cart disk ...
./play-2018ad.sh                 # 2018 A.D. from its CD audio (2018AD_combined.wav or combined.ogg)
./vzemu.sh script.txt            # the headless test runner
```

Debian and Ubuntu: `sudo apt install dotnet-runtime-8.0 libsdl2-2.0-0 ffmpeg zenity`. macOS: `brew install dotnet sdl2 ffmpeg`.
The scripts use `dotnet` if it's there and Mono otherwise. If they aren't executable after unzipping, run
`chmod +x *.sh`.

- **There are no menus.** F1 shows the keys. The F keys do what they do on Windows (F2 load, F4 power cycle,
  F10 visualiser, F11 fullscreen, F12 screenshot...), and Alt with a letter does the menu jobs: **Alt+M** VZ200/VZ300,
  **Alt+X** memory, **Alt+C** cartridge, **Alt+G** graphics mod, **Alt+T** play a tape, **Alt+R** record, **Alt+D**/**Alt+F**
  disks, **Alt+L** light pen, **Alt+N** printer, **Alt+1**–**5** window size. The command-line options and `vzonpc.ini`
  are the same as on Windows.
- **Drag and drop** a `.VZ`, a tape, a `.dsk` or a folder onto the window.
- **File dialogs** use zenity or kdialog when one is installed.
- **Messages** show along the bottom of the window in the 6847's own letters; the title bar shows the machine and status.
- **Tapes:** WAV directly; MP3, FLAC and Ogg through ffmpeg.
- **SD card deletes** go to the desktop's trash.
- **Game controllers** use SDL's mappings: A or X fires, B or Y is the second fire.
- **RS-232** to a telnet host works everywhere. A real serial port (`/dev/ttyUSB0`) needs Mono, or a .NET with the
  System.IO.Ports package.

`build.bat` builds `VZonPC-SDL.exe` along with the others. It's an ordinary .NET Framework 4 program with no
Windows Forms; `VZonPC-SDL.runtimeconfig.json` lets modern .NET run it, and `VZonPC-SDL.exe.config` tells Mono where SDL2 is.
Tested so far on Windows under .NET Framework 4.8 and .NET 8, not yet on Linux or macOS.

## The visualiser (F10)

**F10** (or **View → Visualiser**) shows live panels of what the machine is doing. In fullscreen they fill
the sides of the screen: on a 1920×1080 screen the picture stays at ×4 and each side gets a 320-pixel column.
In a window they open in their own window, which you can move to another monitor. Closing that window
or pressing F10 again turns the visualiser off. It's remembered between runs.

**Left: the Z80**
- **Registers**: all registers and flags. Values that changed since the last frame are amber.
- **Code**: a live disassembly. It follows a randomly sampled PC from the time the CPU was busy, so it
  shows the code doing the work rather than the vsync wait loop. The real PC is marked `>`. Recently run
  lines are bright. Routine names come from the game's `.sym` file (zasm `--sym`), found next to the
  `.VZ` or in `..uild` or `..\out`. Without one, CALL destinations are named `SUB_xxxx`.
- **Hot spots**: the top routines by CPU time over the last second.
- **Frame budget**: how each 50 Hz field was spent. *Busy* is green, *ISR* (the interrupt handler) is magenta,
  *DOS* (SD loading) is orange, and *Wait* is blue. Wait is time in a loop that comes back to the same
  address without writing anything, such as a vsync poll, a key wait, `DJNZ $` or `HALT`. A 6-second
  history graph sits underneath.
- **6847 beam, line by line**: every picture line at one pixel per T-state, coloured by the mode the latch held at
  that moment. The 16 T-states of border on each side are dim, and the 128 T-states the 6847 is drawing are bright.
  White marks a mode or colour-set change part-way along a line. Kefrens flicks show as a white column, and a split
  screen as a change of colour. On the right is the row the 6847's own address counter showed on each line. It climbs
  in steps (every 12 lines in text, every 3 in 128×64), and goes flat and amber where a mid-line flip held the row,
  which is what makes Kefrens bars and FLD work.
- **Opcodes**: a 16×16 heatmap of the first opcode byte over the last second, plus the most-used instructions.
- **Stack**: SP over time, the lowest SP this second, and the return addresses on the stack with the CALL each came from.

**Right: the machine**
- **Memory map**: all 64K, one pixel per byte. Reads glow green, writes glow red and instruction fetches
  glow blue, and all of them fade over about half a second. The faint texture underneath is the memory's
  contents. PC (white) and SP (amber) are marked, and the regions are labelled.
- **Beam and CPU**: one whole field as 228 T-states × 312 lines (two lines per row). It shows what the CPU was
  doing at every moment, overlaid with video RAM writes (white) and reads (cyan), speaker clicks (red),
  port OUT/IN, and keyboard reads. The picture area (lines 118–309, T-states 58–185), field sync, and a strip showing
  the 6847 mode on each line are drawn alongside. A tick beside the strip marks a line whose mode changed part-way
  along: white, or amber where it held the row. This shows where in the frame a game draws, and whether it races the beam.
- **MC6847**: the mode, AG, CSS, GM, the latch, the hi-res mod's port and page, and video RAM accesses per frame.
  It also counts snow (CPU accesses while the 6847 is fetching, so side-border accesses don't count), lines with a
  mid-line mode change, and line holds.
- **Speaker**: a scope of the whole field and a 0–6 kHz spectrum with the peak frequency.
- **Keyboard and joysticks**: the 8×6 matrix with pressed keys lit and the rows the game scans flashing,
  plus both joystick ports.
- **I/O ports**: all 256 ports flash on IN (green) and OUT (red), with the most recent ones and their values.
- **BennVenn SD**: the port `$37` mapping, an SD activity light, and a log of files opened and sectors read. With the
  disk drive or RTTY cartridge plugged in, this panel shows that instead (see above).

The visualiser costs about 1.5 ms of CPU per frame, so everything still runs at full speed.

## Hardware details

- **Timing.** Each field is 312 lines × 228 T-states. INT and field sync (`$6800` bit 7 low) are held for the
  first 56 lines, and the picture starts 62 lines after that (line 118). The interrupt is level-triggered as on the
  real VZ.
- **The 6847 is timed to the pixel.** Every latch and video RAM write is logged with the T-state it happens at
  (within the instruction: the last write about 2 T-states before the instruction ends, earlier writes 3 T-states
  apart). Each line is drawn once it has finished, two pixels per T-state, with the picture from T-state 58 to 185
  of the line and 16 T-states of border each side. A mode or colour-set change part-way along a line shows at the
  right pixel, and each byte is read from video RAM when the 6847 fetches it.
- **The 6847's address counter is modelled.** It moves to the next 32-byte row after 12 lines (text) or 3 lines
  (128×64), carrying on from wherever it is when the mode changes. A mode flip (text ↔ graphics) during a line resets
  the line count, so the same row is shown again on the next line. This "line hold" is what Kefrens bars and FLD rely on.
- **The top and bottom borders** keep the mode from the last picture line, not the live latch.
- **Where these numbers come from:** photos of the VZ300 Megademo 1.4 on a real VZ300, and 2018 A.D. by Five Finger
  Punch (https://github.com/vilcans/2018AD), whose Kefrens was tuned on a real Laser 200.
  - The megademo's RASTER screen shows the hold, the border colours, and where its 3-T-state mode flick lands.
  - Its finale Kefrens starts holding on line 121 and shows VRAM row 1 on the TV, so the picture starts by line 118.
  - `test\kef2018\` is a cycle-exact port of 2018 A.D.'s Kefrens. It shows row 0 only if the picture starts on
    line 118 or later. It runs correctly with no adjustment, with the flick hidden in the blanking.
  - Together these fix the picture start at line 118, and put its left edge between T-states 53 and 65.

  The hi-res mods are still drawn a whole line at a time.
- **The keyboard** is the real matrix (rows on A0–A7, bit 5 is the first key in the manual).
- **The joysticks** are on ports `$20`–`$2F`: bit 0 = joystick 1, bit 1 = its arm button, bit 2 = joystick 2,
  bit 3 = its arm button. The values are active low: 1 up, 2 down, 4 left, 8 right, 16 fire.
- **The BennVenn SD loader** follows MAME's `sdloader.cpp`. Port `$37` bit 0 selects the DOS ROM or DOS RAM at
  `$4000`–`$67FF`, bit 1 picks which 10K bank appears there, and bit 2 picks which 18K bank appears at `$B800`–`$FFFF`.
  Port `$3A` bit 0 sets VZ300 mode (expansion RAM only from `$B800`). The DOS itself is emulated at a
  high level, through the three calls the games use. A loaded game starts with mapping 1 and VZ300 mode set.
  When the real VZDOS boots (see above), those traps are off and the SD card is emulated at the SPI byte level on
  port `$39` (CMD0/8/55/41/58/17/24, SDHC block addressing), the same model VZ-DECK's own test harness uses.
  A sector read takes 44,000 T-states, the speed measured on real hardware.
- **The 16K RAM pack** sits at `$9000`–`$CFFF` on the VZ200 and `$B800`–`$F7FF` on the VZ300.
- **The Australian super hi-res mod (SHRG).** Video RAM is 8K and `OUT 32` is written as `---MMMPP`.
  MMM is the 6847 GM2..GM0 mode (0 = 64×64 4-colour … 2 = normal 128×64 … 7 = 256×192 mono). PP is the 2K page seen at `$7000`.
  AG is still `$6800` bit 3. Power-on is `OUT 32,8` (normal mode, page 0). For 256×192, set the latch to `MODE(1)` and
  write `OUT 32,28+page` (pages 0–2, 64 rows each).
- **The German hi-res mod** follows MAME's *Laser 310 (SHRG)* driver. `$6800` bit 1 drives GM0 and GM2 (GM1 is tied
  high), so the latch value `$0A` gives 256×192. The 2K page is chosen with `OUT ($D0),page`. **This is not verified.**
  The German mod articles couldn't be read when this was written. If your German-mod software uses a different
  port, tell Claude and it is a one-line change in `VzMachine.Out`.
- `SD\HIRES.VZ` (source in `tools\hires_test.asm`) draws a 256×192 grid. It drives both mods at once, so you can
  check either one.

## For Claude Code sessions: testing VZ programs

Use `vzemu.exe` instead of writing a new harness. It is script-compatible with the per-game `vzemu` harnesses
used for Crownfall, Override, Bix 2 and the others.

```
C:\Users\Owner\Documents\VZonPC\vzemu.exe script.txt      run a script
vzemu.exe -e "vz GAME.VZ; frames 300; screen s.png 2"     inline commands, separated by ;
vzemu.exe GAME.VZ [frames] [out.png]                       quick look: load, run, screenshot at 2x
```

Paths in a script are relative to the current directory. Screenshots are PNG, 256×192 × scale; add
`border` after the scale to include the border (320×240). Exit code 2 means a crash check fired.

**Configuration** (before the first run command; the defaults are VZ300 + BennVenn, standard graphics, no ROM):

| | |
|---|---|
| `machine vz200` or `vz300` | |
| `exp none` / `16k` / `bennvenn` | |
| `gfx none` / `aus` / `ger` | |
| `rom auto` / `rom DIR` / `rom none` | `auto` uses `VZonPC\roms`. With a ROM, the BennVenn and a `VZDOS.VZ`, power-on boots the real VZDOS (and VZ-DECK) from the `sd` folder |
| `joyif off` | remove the joystick interface |
| `sd DIR` | the SD card folder for DOS file reads |
| `sym FILE` | symbols as `ADDR NAME` (hex), the zasm `--sym` output, so addresses can be names |
| `quiet` | no DOS logging |

**Running and input**

| | |
|---|---|
| `vz FILE` | load a `.VZ` (machine code starts at once; BASIC is typed `RUN`) |
| `frames N`, `seconds N` | |
| `until ADDR [maxframes]` | run until PC = ADDR |
| `untilmem ADDR VAL [maxframes]` | run until a memory byte equals VAL |
| `down KEY`, `up KEY`, `tap KEY [frames]` | KEY = A-Z 0-9 SPACE RETURN SHIFT CTRL , . - ; : or J1UP J1DOWN J1LEFT J1RIGHT J1FIRE J1ARM, J2... |
| `joy N HEX` | set a raw joystick port byte: N = 0 joystick 1, 1 its arm, 2 joystick 2, 3 its arm; e.g. `joy 0 EF` = fire |
| `type TEXT` | type text (`\r` = RETURN) |
| `rand FRAMES [seed] [KEY,KEY,...]` | random-input soak |
| `reset`, `poke A V`, `out PORT V` | |
| `tape FILE [left\|right\|mix] [invert]` | play a WAV/FLAC/MP3 into the cassette input from now |
| `tapestop`, `tapeinvert [on\|off]`, `tapepos` | stop, flip the polarity, print the tape position |
| `cart disk\|rtty\|rs232\|wordpro\|none` | plug in a cartridge (before the first run command; needs `rom auto` for the BASIC ROM) |
| `disk N FILE`, `disk N blank`, `diskeject N` | put an image (or a fresh formatted disk) in drive 1 or 2; eject saves it |
| `diskdir [N]`, `diskstat`, `disksave N FILE` | list the directory, show the head and counters, write the image out |
| `disktrack N TRACK FILE` | write a track's raw bit cells (`0`, `1`, and `\|` for an erased gap) to FILE; `DISKDEBUG=1` logs each write |
| `rttyrx FILE`, `rttyloop [off]`, `rttyinvert rx\|tx`, `rttystat` | receive AFSK audio, loop TX into RX, flip polarity, show state |
| `rttytx FILE` … `rttytxend` | record the transmitted tones to a WAV |
| `taperec FILE` … `taperecend` | record the cassette output (`CSAVE`) to a WAV |
| `printer FILE`, `printer off`, `printstat` | print to FILE (text) and FILE.prn (raw bytes); show the last lines |
| `lpen X Y`, `lpen hover X Y`, `lpen up`, `lpen off`, `lpenstat` | the light pen pressed (or not) at picture pixel X,Y (0–255, 0–191) |
| `serial connect HOST:PORT\|COMn`, `serial send TEXT`, `serial file FILE` | RS-232: link it, or queue bytes for the VZ to receive (`\r`, `\n`) |
| `serial loop [off]`, `serial capture FILE`, `serial baud N`, `serialstat` | loopback, save what the VZ sends, set the speed, show the session |
| `bin FILE ADDR` | copy a raw binary into memory without running it |

**Inspection**

| | |
|---|---|
| `screen FILE [scale] [border]` | |
| `shots PREFIX COUNT [every]` | |
| `text` | the text screen as ASCII |
| `regs` | |
| `mode` | latch, AG/CSS/GM, mapper |
| `peek A [n]`, `peekw A`, `in PORT` | |
| `dump FILE` | 64K as the CPU sees it |
| `dumpvram FILE` | |
| `wav FILE` … `wavend` | speaker audio, 44.1 kHz |
| `snow`, `snowreset` | video RAM accesses during the picture |
| `tmark ADDR` + `tstats` | fields per frame, measured by writes to ADDR |
| `prof 1` … `profsave FILE` | T-states per symbol |
| `minsp`, `stack LO HI` | lowest SP in a range |
| `dos` | DOS call count |
| `vis on` | start the visualiser trace (put it before `vz` so the whole run is recorded) |
| `vis FILE [panels]` | save the visualiser as PNG: 1920×1080 with the screen in the middle, or just the two 320×1080 panels |
| `crash` | writes `crash.txt` (the last 4096 PCs) and stops when execution leaves sane memory |
| `romtrap` | stop on a jump into ROM |
| `watch LO [HI]` | log writes to a range, with the line and T-state (`watch $6800 $6FFF` shows every latch write) |
| `linelog LINE` / `linelog off` | each frame, log that line's latch changes by T-state and the 6847 row it shows |
| `print TEXT`, `quit` | |

**Environment:** `RANDRAM=seed` randomises RAM at power-on. `DOSSCRIBBLE=1` trashes memory below the DOS stack
on each DOS call, the way the real DOS does.

To build test programs, assemble with `py tools\zasm.py src.asm -o out.bin --sym out.sym`, then wrap it with
`py tools\mkvz.py out.bin GAME.VZ 0x8000`.

The GUI can also check itself: `VZonPC.exe GAME.VZ --quit-after 8 --shot win.png [--scale 2] [--gfx aus] [--fullscreen]`
runs the real window for 8 seconds (add `--vis` for the visualiser; its window is saved as `win_vis.png`), captures it from the screen and exits without touching the settings.
Other options: `--sd DIR`, `--machine`, `--exp`, `--type "RUN\r"`, `--tape FILE` (starts once the typing has finished), `--cart disk|rtty|rs232|wordpro|none`, `--disk FILE`, `--disk2 FILE`, `--rtty FILE`, `--serial HOST:PORT`, `--lpen`, `--border 0|1`, `--integer 0|1`, `--no-settings`.

## Source

`src\Z80.cs` (CPU), `src\Z80Dis.cs` (disassembler), `src\Trace.cs` + `src\Vis.cs` (visualiser), `src\Machine.cs` (memory map, BennVenn, 6847 video, speaker, DOS, loader),
`src\Floppy.cs` (disk drive), `src\Rtty.cs` (RTTY cartridge), `src\Rs232.cs` (RS-232 cartridge), `src\Peripherals.cs` (printer, light pen, cassette recorder), `src\Tape.cs` + `src\MfAudio.cs` (tape input), `src\Headless.cs` (`vzemu`), `src\MainForm.cs` / `src\WinIO.cs` / `src\SdBrowser.cs` (the window, waveOut audio,
winmm joysticks, GDI display). Run `build.bat` after changes. C# 5 only: no string interpolation or `?.`.

## Not emulated (yet)

- The BennVenn's own flash BIOS and its built-in DOS. A small stand-in loads `VZDOS.VZ` instead, so without a
  `VZDOS.VZ` the loader goes straight to BASIC.
- Two cartridges at once, other than WordPro in the disk controller's slot.
- The printer's graphics: `COPY` of a graphics screen sends bit-image codes, which are kept in `printout.prn` but
  not drawn.
- The RS-232 link to a real COM port is written but hasn't been tried with serial hardware.
