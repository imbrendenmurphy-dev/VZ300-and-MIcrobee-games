=====================================================================

              M I C R O B E E    M E G A D E M O    2 0 2 6

                          VIBED BY BPM 2026

        The first megademo for the Microbee Premium Plus

=====================================================================

  Six minutes of Microbee doing things it was never meant to do.

  It has no sprites, no scroll registers, no copper and no blitter,
  just a Z80, a 6545 CRTC, a 1-bit speaker and a megabyte of RAM.
  Every effect here comes from reprogramming the CRTC in the middle
  of the picture, in time with the beam, scanline by scanline, while
  a two-voice beeper soundtrack keeps playing in the gaps.

  Prepare to stress test your emulators. This demo depends on
  scanline-exact 6545 behaviour: start addresses re-read on every
  line of a character row, row counts compared all the time, and the
  CPU held whenever it touches video RAM while the screen is drawn.
  It was developed against a raster-accurate emulator and then
  tuned on a real Premium Plus. If your emulator rolls, tears or
  shows a blank screen, it is the emulator.


---------------------------------------------------------------------
 RUNNING IT
---------------------------------------------------------------------

  Machine:   Microbee Premium Plus (1 MB RAM, 32K PCG RAM)
  Disk:      MEGA.DS8 - double sided, 80 track (DS80) image.
             Write it to a real disk, or use it from an SD card or
             floppy emulator.
  Start:     Boot the disk and type  MEGA  at the  A>  prompt.
             Loading takes about 40 seconds (about 600K is loaded).
  Monitor:   Press  C  for a colour monitor or  M  for monochrome.
             The mono version draws everything as dot patterns,
             because a mono monitor shows no colour at all.
  Keys:      SPACE skips to the next part.
  Length:    about 6 minutes 10 seconds, then it returns to the
             monitor choice.

  Tested on a real Premium Plus with an amber monochrome monitor.
  The colour version has only been checked in an emulator so far.


---------------------------------------------------------------------
 THE PARTS
---------------------------------------------------------------------

   1  POWER ON      The picture tube warms up: a dot, a line, a
                    screen. Up to 222 one-line screens a frame.
   2  SELF TEST     A terminal checks the machine, then the picture
                    tears apart row by row.
   3  TITLE         A copper-bar logo screen with a smooth scroller.
   4  TWISTER       A twisting bar, 1 pixel accurate. No pixels are
                    drawn: the CRTC picks one of 30 slices for each
                    line, 222 screens per frame.
   5  PLASMA        1536 blocks of colour recomputed 25 times a
                    second, inside the scanlines, between the music
                    samples.
   6  KEFRENS BARS  Racing the beam: every line painted as it is
                    drawn.
   7  LIVE          A real-time rotozoomer, two blocks per scanline,
      ROTOZOOMER    worked out as the beam draws it. It shows five
                    textures in turn (the BPM sign, honeycomb,
                    checkers, acid smileys, tartan). Each next
                    texture is built in the background while it
                    runs.
   8  TUNNEL        |  Effects no 3.375 MHz Z80 could compute in
   9  PERSPECTIVE   |  time, so every block of every frame was
      FLOOR         |  computed in advance into the megabyte: 324
  10  SWIRL         |  pictures, 288K, streamed back at 25 frames a
  11  TWIST         |  second with colour cycling.
  12  VECTOR TORUS  A lit, dithered torus in hi-res PCG pixels. 68
                    pictures are streamed into the hidden PCG bank,
                    four bytes per scanline, with double buffering.
  13  CREDITS       A smooth vertical scroller, one pixel line at a
                    time.
  14  POWER OFF     The tube shrinks to a line, then a dot.


---------------------------------------------------------------------
 TECH SPECS
---------------------------------------------------------------------

  CPU         Z80A at 3.375 MHz. Every scanline is exactly 216
              T-states, and the demo counts them all.
  Display     6545 CRTC, 64 x 16 characters of 8 x 16 PCG glyphs
              (512 x 256 pixels). The kernel reprograms the CRTC up
              to every scanline, from a "line program" rebuilt every
              frame (two buffers, swapped in the vertical blanking).
  Tricks      - one-line frames (R9 = 0) to give each scanline its
                own start address (twister, copper bars, tube)
              - variable-height frames for fine vertical scrolling
                (credits, title)
              - extra rows that are never displayed, for a stable
                blanking edge mid-frame (plasma, rotozoomer, torus)
              - video RAM writes in a single burst per scanline,
                re-synchronised to the CRTC after the picture
  Sound       Two-voice 1-bit beeper music (a 25% pulse lead and a
              square-wave bass, plus drums), played inside every
              scanline: two samples per line, 15.6 kHz.
              About 6 minutes of music in 185 patterns (5.1K).
  Effects     Live: plasma, Kefrens bars, rotozoomer, twister,
              scrollers.
              Precomputed: tunnel, floor, swirl, twist, torus.
  Colour/mono Every part has a colour version and a monochrome
              version.


---------------------------------------------------------------------
 MEMORY USED
---------------------------------------------------------------------

  Main RAM (1024K, 32 blocks of 32K):

    Program, music and tables     23.7K   (8000h-DC8Dh)
    Variables, two line programs,
      scratch and stack           about 5K   (DC8Dh-EFFFh)
    Loaded from disk              600K   (19 blocks: graphics,
                                          screens, tiles and text
                                          140K, tunnel 96K, floor,
                                          swirl and twist 192K,
                                          torus 128K, rotozoomer's
                                          first texture 32K)
    Built while it runs           160K   (4 rotozoomer textures of
                                          32K, and 32K of rotated
                                          colour ramps for the
                                          plasma)
    ----------------------------------------------------------------
    In use                        about 790K of the 1024K
    (plus a 32K staging block while it loads)

  PCG RAM (32K, 16 banks of 2K):
    3 banks permanent: the font and two "line 0 pattern" banks
    (every 8-pixel pattern, used for one-line screens)
    up to 5 banks reloaded for each part: the logo, the plasma's
    and rotozoomer's dot glyphs, and the torus's two picture
    buffers

  Screen, attribute and colour RAM: all 2K of each, reloaded for
  each part while the music plays.

  Disk: 628K of the DS80 disk's 784K.


---------------------------------------------------------------------
 THANKS AND GREETINGS
---------------------------------------------------------------------

  To the Microbee community, to Applied Technology who built the
  Bee, to everyone keeping a Bee alive, to the emulator writers and
  archivists, and to the demoscene, then and now.


                          VIBED BY BPM 2026

=====================================================================
