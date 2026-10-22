# Playtest Gate 2: the full build

Owner: game-designer. A record of Bart's notes from Playtest Gate 2, on his phone (Galaxy Z
Fold5, folded and unfolded), with the Phase 4 build, generator version 5, 22 October 2026.

## What Bart said

Everything else: "Looks good, love it everything works. Speed is good. Music and sound are good,
keep them. Coffee buttons work great. Folded and unfolded work great."

Difficulty: "Levels are far, far too easy. I'm on level 40 and even when I intentionally pull
the wrong screws more than once I can recover and solve the puzzle. By that level 2 wrong moves
and you should need to start over; there's almost no thought needed to solve this; you see
what's hidden and the planning to solve is trivial. At most I've had to think 1 move ahead; and
I can make repeated errors and still end up with a solve. It needs to get tougher, not a lot but
a little."

## The seven questions, from those notes

1. Where did you smile? The look, the sound and music, the coffee buttons, folded and unfolded.
2. Where were you bored? The levels up to 40: almost no thought needed.
3. Where were you confused? Nothing reported.
4. Did any loss feel unfair? None reported; the problem is the opposite.
5. Did anything feel slow? No: "Speed is good."
6. What did you want to do next? Harder levels that need planning.
7. Would you play again tomorrow? Not asked directly; he played to level 40.

## Ranked fix list

1. **Difficulty from level 21 to the first Hard levels is too soft** (bugs: none; fun: this).
   Evidence: Bart's words above; qa-4, where the greedy novice wins 81 to 89 percent of tiers 4
   and 5 and 70 to 73 percent of tier 6 (level 40 is tier 6), then none from tier 7. Fix: GDD 6.8,
   round 1: targets per tier, the mistake tolerance rule G10, a share of Medium levels the
   novice must lose, tier 6 needing two tray uses, then the smaller levers. Waiting for
   level-engine-dev's baseline and Bart's approval.
2. Nothing else: everything else is approved as it is.

## Bart's answer on difficulty (22 October 2026)

Put the two options (A, literal at level 40, and B, "a little"), Bart answered with his own
schedule, which replaces both:

"At level 10 to 20 we ramp up level by level the screw placement so the player learns they have
to think about which screw to remove, the puzzles need to show them that they can make up to 5
wrong moves at the most levels 9-15 and 15-20 they can make at most 3 wrong moves, above that
they can make only 2 wrong moves, at level 50 and above it's only 1 wrong move, at level 100 and
above it's only 0 wrong moves."

As read with the lead (a wrong move is a screw sent to the tray needlessly; W wrong moves means a
peak tray load of 5 minus W): levels 9 to 15 allow up to 5 (5 for 9 to 11, then 4 as the ramp
climbs), 16 to 20 allow 3, 21 to 49 allow 2, 50 to 99 allow 1, and from 100 none. GDD 6.8
has the plan; the fix list item 1 above is now that plan.

## Bart's decisions on the plan (22 October 2026)

A higher least peak alone turned out not to work on today's boards (70 to 84 percent of levels
fell back), so three routes went to Bart. He chose:

- **Route:** "Tray now, then try". The tray shrinks by level range (5 slots for levels 9 to 11,
  4 for 12 to 20, 3 from 21), with low least peaks, so the wrong moves forgiven are the tray minus
  the peak: 5, 4, 3, 2, 1 and 0 from level 100. Relaxed keeps 5 slots; the Daily has 3. A wave
  coloring is the next experiment, only if he still finds the endings too easy.
- **Helpers:** "Cheaper, with gifts": Undo 3 stars, Extra slot 5, Screwdriver 8, and 2 Undos and
  1 Extra slot on reaching level 50 and again at level 100.
- **The shrink:** "One short line" the first time the tray shrinks (level 12), shown once.

GDD 6.8 has the final schedule, the capability deal and the measured fallbacks. This replaces
the reading above where they differ.
