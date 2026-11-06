# vzemu - headless VZ300 emulator

Build: `gcc -O2 -o vzemu vzemu.c`

    vzemu file.vz [options]
      -f N              run N fields (default 200; 50 fields = 1 s)
      -s 10,50,100      screenshot at end of these fields -> <prefix>_NNNN.ppm (512x192)
      -p prefix         screenshot prefix (default "shot")
      -m                monochrome luminance render
      -w out.wav        write speaker audio (44.1 kHz 16-bit mono)
      -i script         input script: lines "FIELD KEY ..."; held from FIELD until the next line;
                        "FIELD" alone releases all. '#' comments.
                        Keys: A-Z 0-9 SPACE RETURN SHIFT CTRL COMMA PERIOD MINUS SEMI COLON
                        J1UP J1DOWN J1LEFT J1RIGHT J1FIRE J1ARM J2UP J2DOWN J2LEFT J2RIGHT J2FIRE
      -t N              trace the first N instructions
      -b ADDR           report the first time PC = ADDR (hex); can repeat
      -d START:LEN:file dump memory at exit (hex START and LEN); can repeat

The summary at exit shows: fields and T-states, snow (VRAM accesses during lines 94-285:
total, max per field, fields with snow), how many fields had an interrupt accepted, busy
T-states per field (min/avg/max out of 71136), speaker transitions, the first execution
in the ROM area 0000-3FFF (with the RST/IM1 0038 vector), final registers, and a HANG
line if the CPU ends halted with interrupts disabled.

Machine: PAL 3,546,894 Hz, 312 x 228 T per field. The IRQ is held during lines 0-55 and
accepted at most once per field. The latch at 6800 bit 7 reads 0 during field sync.
BennVenn SRAM is at 4000-67FF, banked by OUT (37h). There is no ROM (it reads FFh).
Each display row is captured from VRAM when the beam reaches it, so tearing shows in screenshots.

Tests (in tests/):
    python3 tests/check_alu.py ./vzemu /tmp/alu.bin   # exhaustive 8-bit ALU/rotate/BIT/DAA flags + random 16-bit
    python3 tests/check_timing.py ./vzemu             # T-states for every opcode, all prefixes, both branch outcomes
    python3 tests/run_func.py                         # assembled programs (uses ../tools/z80asm.py)

Debugging aids: `-W lo:hi` logs every write to that address range with the PC and IX. With
`VZ_WTRAIL=pc` set, a write made at that PC also prints the last 8192 executed PCs, each with
its IX value. That trail found `play_song` clobbering IX while the object loop was running.
