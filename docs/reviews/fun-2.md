# Fun review 2: the step into Hard, measured

Reviewer: game-designer. Material: build/bots/hs2-run.txt (the Hard Stop 2 bot report), and a
scratch copy of the generator (build/scratch/soft.gd, soft2.gd, not shipped) run on numbered
levels 151 to 350 with the Phase 3 library: 40 levels each of tiers 7, 8, 9 and 10. The rule
itself is in GDD 6.4.1 (G9); this file keeps the evidence.

**SEND BACK** the hard tiers as generated today: the step from tier 6 to tier 7 is a cliff, and
the pressure sits in the first few taps. The fixes are G9 (written) and the engine work below.

## Ranked fixes

### 1. The novice is out by tap 7 on most hard levels (checklist 5, fair failure; 9, the curve)

Evidence: Hard Stop 2, novice win rate 76 percent on tier 6 and 0 on tiers 7 to 10; random bot
57 percent on tier 6, 7 on tier 7. On the Phase 3 library, of 148 hard levels the novice's last
tap is tap 6 on 49 and tap 7 on 38 (88 by tap 7), while the levels have 27 to 36 screws.

Fix: G9a, the novice survives at least ceil(screws / 3) taps (9 to 12), required on tiers 7 and
8. With a doubled attempt budget the fallback rate is 13 percent on tier 7 and 10 on tier 8; the
novice then survives 13 to 15 taps on average and still loses every level; the trap measure goes
from 0.90 to 0.88.

### 2. The approved "late tray use" clause can't be a requirement (G9b)

Evidence: the solver's solution has its last tray use by tap 7 on 133 of 148 hard levels.
Requiring one after the first third made 73, 88, 98 and 98 percent of tiers 7 to 10 fall back
to stored levels. The solver keeps the first fewest tray use solution its search reaches, and
its search order puts tray uses early, so the clause measures the search as much as the level.

Fix: report the last tray use's position in tools/levels and the bot report; don't turn levels
down for it. Waiting for Bart.

### 3. Expert can't meet G9a with today's colorings (tiers 9 and 10)

Evidence, fallbacks with G9a at n / 3: 73 and 58 percent at today's budget, 60 and 43 percent
with a double budget. With ceil(n / 4) instead: 48 and 50 percent, 40 and 25 with the double
budget. Tiers 9 and 10 need 3 or more tray uses and a novice loss, and the deep opening that
gives those is what kills the novice early.

Fix now: G9a reported, not required, on tiers 9 and 10 (waiting for Bart). Fix later, for
level-engine-dev: a coloring that puts the forced tray uses after the first boxes. I tried one
("deep second wave": screws free at the start for boxes 1 and 2, deep screws for boxes 3 and 4).
Every level it made survived n / 3, but it fell back 35, 18, 75 and 60 percent of the time on its
own, and mixing it with the deep opening did not help on Expert. A better one is needed before
G9a can be required there.

### 4. Generation time on tiers 7 and 8 (checklist: fast retry, waiting)

Evidence: with G9a the attempts per level go from about 10 to about 36 on tiers 7 and 8 (double
budget: 24 variations, 120 attempts, 2.4 million states). On this PC a tier 7 level took a median
141 ms before G9 (build/levels-p3/report.md), so expect roughly three times that, and several
times more on a phone. The prefetcher asks for level N + 1 when N starts, so this should stay
hidden, but it should be in the Phase 3 phone timing.

### 5. Variety on the hard tiers is fixed (checklist 11)

Evidence: levels 159, 169 and 179 used one stored bookshelf level at Hard Stop 2. With the Phase 3
library (GDD 10.1) they are lattice, Ferris wheel and tiles, and levels 151 to 200 fall back on 4
of 40 hard levels (build/levels-p3/report.md). Tiers 7 to 10 have 8, 10, 8 and 8 boards.

## Note after generator version 4

level-engine-dev's numbers over levels 9 to 400 with the double budget are in GDD 6.4.1: tier 8
still falls back 19 percent of the time, mostly on skyline (tier 7) and bookshelf (tiers 8 to
10). My recommendation there: ship Gate 1 as it is and retune those two boards in Phase 4,
rather than keeping them off tiers 7 and 8.
