# Evidence and current tradeoffs

Evidence means emulator implementation or execution unless explicitly stated.
No real Microbee has been tested in this project.

Primary implementation references:

- [MAME video implementation](https://github.com/mamedev/mame/blob/master/src/mame/ausnz/mbee_v.cpp)
- [uBee512 memory implementation](https://github.com/snakebyte69/uBee512/blob/main/src/memmap.c)
- [uBee512 mouse interface](https://github.com/snakebyte69/uBee512/blob/main/src/mouse.c)
- [uBee512 documentation](https://github.com/snakebyte69/uBee512/blob/main/doc/README)
- This repository's LanternDeep/src/DESIGN.md, loader.asm, disk.asm and ppmodel.py.

The earlier local uBee512 source in Documents/Codex was also inspected. Its
p1024k model declares a 3.375 MHz CPU, 1024K RAM and 16 PCG banks. The 1MB
decode is a 32K lower window: ((port50 & E0h)>>3)|(port50&3), xor 2 when
ROMs are disabled. The upper 32K is fixed. Port50 bit3 hides video; bit4
moves the video window. The native loader probes distinct RAM banks before
loading, retaining the repository's existing method.

PCG has 16 banks, 128 glyphs per bank, 16 bytes per glyph. 32K therefore
provides 2048 glyph slots, regardless of shorter CRTC cell height. Screen
codes 80h-FFh select PCG; attribute low nibble selects its bank. Colour RAM
selects two RGBI colours per cell. This is not a packed colour framebuffer.

Current experiment uses 64 x 32 cells, 8 x 6 pixels each, with 312 total
scanlines and 80-column horizontal dot timing. It maps a 2 x 2 block of
original logical pixels onto each cell through 256 precomputed patterns.
Where a block has more than two colours, patterns approximate the extras.
Two more PCG banks carry monochrome-specific patterns. Only changed cells
are written. This mode has passed the supplied model, not a monitor test.

The compatibility renderer is rejected as the final architecture: measured
unchanged presentation alone costs 285894 T-states (4.235 50Hz frames);
one four-logical-pixel scroll costs 660900 (9.791 frames). A forced redraw
costs 1089304 (16.138 frames). It cannot preserve the intended 12.5Hz game
pace or provide smooth per-pixel scrolling. These numbers precede the final
small key/settings changes; rerun tools/measure.py for the current build.

The next renderer needs shared terrain glyphs and shifted pattern families,
dirty destructible terrain cells, and a bounded composite-sprite cache.
CRTC start address can supply coarse character scrolling; fine phases must
be generated in PCG and must be measured. More RAM only helps caching and
precomputation; it does not increase video bandwidth. Do not promise 50Hz
scrolling from a PCG capacity calculation alone.

Current home block 1 holds original terrain at 4000h, the logical screen at
7000h and original variables at 7800h. Block9 stores compressed designs at
4000h; block8 stores the PCG conversion tables. Code at 8000h stays fixed
while those banks are read. Original collision and composition buffers
overlap F000h, so video is hidden during simulation and the stack moves
below 8000h during output. Most of the 1MB is not exploited yet.

Keyboard uses CRTC light-pen scanning. Joystick uses PIO A active-low bits
0-3 and bit7 fire, following the repository driver. Both need real interface
verification. The Microbee mouse is not a joystick or generic serial poll:
uBee512 describes a 1200-baud Microsoft three-byte packet through an interface
on serial-port DTR/CTS, exposed as PIO B bit3 clock and bit2 inverted data.
Servicing each bit requires ~2812-T-state responsiveness or an interrupt
driver. The current long rendering loops cannot safely poll it. Mouse is
not implemented; integrate and test an interrupt driver with the new renderer.

Disk geometry is 80 cylinders x 2 heads x 10 sectors x 512 bytes, raw DS8
size 819200. The builder retains the first four track-sides of the owner's
compatible CP/M disk, uses the existing 3:1 skew and 4K allocation units,
and includes CCP.SYS. It creates a fresh directory with no Shell. Actual
ROM/BDOS execution in ppmodel reaches A> and loads the native program.
uBee512 and real floppy/SD-emulation compatibility remain unverified.
