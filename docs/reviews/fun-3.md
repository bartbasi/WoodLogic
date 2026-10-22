# Fun review 3: Gate 2, the middle is too easy

Reviewer: game-designer. Material: Bart's Gate 2 notes and his difficulty schedule
(docs/playtests/gate-2.md), docs/reviews/qa-4.md (generator version 5), level-engine-dev's probe
(build/levels-v5-probe/report.md: forgiveness, lookahead, peak tray load), GDD 6.1 and
data/tuning.json, and my depth estimate per board (build/scratch/depth.txt, a scratch script:
for each screw, the fewest removals before it comes free over 3000 random orders). The plan is
GDD 6.8; this file keeps the reasoning.

**SEND BACK** difficulty from level 9 on, to Bart's schedule. Everything else Bart approved.

## Why the game was soft

- **Spare tray room.** A wrong tap only sinks a level once the best line's peak tray load plus
  the wrong taps passes the 5 slots. The peak was 1 on tiers 4 to 6 (level 40 is tier 6), so
  level 40 survived 3 wrong taps anywhere, and random play won it 32 times in 32.
- **One move of lookahead was enough** on tiers 4 to 6: when the novice lost, it saw it at once.

## Bart's schedule, and why it maps onto the peak

Bart counts wrong moves: 5 at most for levels 9 to 15, 3 for 16 to 20, 2 for 21 to 49, 1 for 50 to
99 and 0 from 100. With 5 slots, W wrong moves is a peak of 5 minus W, and the probe's numbers
back that up (by peak, winnable after 1, 2 and 3 wrong taps: up to peak 2 always, peak 3: 100,
100, 79; peak 4: 100, 88, 56; peak 5: 69, 56, 0). So G10 is a peak range per level, the
sawtooth is rebuilt so each range deals only tiers that can reach it, and the ramp in 9 to 20 is
level by level without breathers, as Bart asked.

## What blocks it

- **The cover rule as it is.** G8 asks for 2k + 1 covered screws for k tray uses. A peak of p
  needs p tray uses, so levels 21 to 49 need 7 covered screws, 50 to 99 need 9, and 100 on needs
  11. Today that leaves 3 boards for levels 16 to 20, 5 for 21 to 49 (only bricks on tier 5), 3 on
  tier 7 and 4 for levels 100 on. Fixing it by redrawing means about 18 boards.
- **The count is the wrong measure.** What makes a peak is depth: the open boxes' screws must
  stay hidden for about p removals. The depth estimate disagrees with the count: dominoes has 10
  covered screws but only one that needs 2 removals; barn's 4 are each freed by one removal; the
  ladybug has 7 that need 5. So I propose a depth rule in place of the count for tiers with a
  peak, calibrated against the engine's feasibility run, and a short redraw list for the gaps that
  remain (levels 21 to 49 first, since that is where Bart is).

## Choices I made inside Bart's words

- Levels 9 to 15 allow "up to 5": 5 for 9 to 11 (peak 0 to 1), then 4 for 12 to 15 (peak 1 to 2),
  so the ramp is visible before 16.
- "At most W" also caps forgiveness: each range's peak may sit at its least value or one above.
- From level 21 the sawtooth works inside each range: the breather after a hard level is smaller,
  never looser. From 100 on that means no breather allows a wrong move; that is question 1 for
  Bart.
- G9a stays where it doesn't fight the schedule; if it does, the schedule wins.
- The earlier "novice must lose on a share of Medium levels" proposal is withdrawn: the peak does
  that work.

## Helpers

With 1 wrong move from 50 and none from 100, Undo and Extra slot become the way out of a slip.
Earnings fall to about 18.5 and 17.5 stars per ten levels there, while a player leaning on Undo
might want one a level. So I propose Undo 3 and Extra slot 5 (Screwdriver stays 8), and a gift of
two Undos and an Extra slot at levels 50 and 100, where the game gets stricter. Retry stays free
and the perfect bot needs no helper, so helpers remain a choice. A retrying bot should measure the
real figures.

## Update: route B, the tray by tier (22 October 2026)

A higher least peak alone failed on today's boards (70 to 84 percent fallbacks), so Bart chose a
smaller tray by range: 5, 4 and 3 slots with least peaks 0 to 3, giving his 5, 4, 3, 2, 1 and 0
wrong moves. With the tiers re-dealt to his ranges and five boards skipped where they can't carry
their tier (skyline on 7; bookshelf, catface, ferris-wheel and ship-wheel on 8), my check runs
fell back 0 percent on levels 9 to 49, about 12 percent on 50 to 99 (3 to 7 percent per tier with
a bigger budget) and 2 percent from 100. No board needs redrawing, and the cover rule stays.
What remains soft is the second half of a level, which forgives up to the tray size at quiet
moments; the wave coloring is the experiment for that, if Bart wants it. GDD 6.8 has it all.
