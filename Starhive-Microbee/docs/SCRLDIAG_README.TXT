STARHIVE - SCROLL DIAGNOSTIC          VIBED BY BPM 2026

Type SCRLDIAG at the A> prompt. The screen fills with a grid of
numbered, coloured rows. The big digit at the left of every row is
the test you are running. Press 1 to 8 to change test.

Please watch each test for about 10 seconds and note what you see:

 1  STEADY     Nothing should move. Is the picture rock steady?
 2  SLOW R5    Once a second the whole grid should move DOWN ONE
               THIN LINE, ten times, then jump back up. Do you see
               the tiny one-line steps, or nothing, or big jumps?
 3  FAST R5    The grid creeps down and snaps back, about 5 times a
               second. Does the picture stay steady on the monitor
               (no rolling, no shaking)?
 4  COARSE     Once a second the grid should move down ONE ROW
               (the row numbers count up). Is that clean?
 5  SMOOTH 50  A proper smooth scroll: does it glide downwards
               smoothly, or jerk / jump?
 6  SMOOTH 25  The same, slightly coarser. Smooth or jerky?
 7  LATE       As 5 with the registers written mid-picture.
               Smooth or jerky?
 8  DELAYED    As 5 with the start address written a frame later.
               Smooth, or worse than 5?

A one-line answer per test (for example "2: tiny steps, 3: steady,
5: jerky every second, 7: smooth") tells me exactly how your 6545
behaves, and which way to build the scroll.

Reset to leave.
