# Original contract

Baseline: OneDrive source archive and binary, selected by the owner.

24 levels, six each Mild/Tricky/Tough/Wild. Level dimensions up to 512 x 80
logical pixels. Viewport 128 x 44 plus panel. Forty 16-byte creature records.
Simulation target 12.5 ticks/s; graphics/input loop 25 Hz.

Eight skills: climber, floater, bomber, blocker, builder, basher, miner,
digger. Skills have per-level finite supplies. Climb and float persist as
flags; bombs use 63 ticks before the oh-no sequence. Builders place 12
bricks. Bash/mine/dig respect steel rectangles. Walkers turn at level edges;
the source constants specify step-up/down 2, fatal falls 24, float opening 4.
The manual's step-down wording differs; game.asm is the authority.

Collision is a 512 x 80 one-bit mask independent of the four-colour scenery
plane. Non-solid scenery stamps do not alter collision. Water is a bounded
hazard region. Save quota, release count/rate, level time and skills are in
each generated level header. Completion uses saved count against quota;
progress unlocks levels. There is no original disk save.

Original controls: QAOP/joystick cursor, Space/M/fire assign or activate a
panel button, X/Z cycle skills, 1-8 direct skills, comma/period release rate,
H pause, NN nuke, Ctrl-Q abandon. Cursor edges scroll; minimap click jumps.
Trainer and attract scripts are part of the front end. Reuse game.asm and
level geometry before changing presentation, to avoid changing puzzle rules.

See original `Bilbies/NOTES.txt` for all quotas, skills, timings, animation
counts and level names. Do not infer new implementation correctness from
that manual's historical emulator test claims.
