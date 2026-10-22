# QA report 5: Phase 5, the tray by level, route B

Reviewer: qa-tester. Build: the working tree on 22 October 2026, on top of commit f627812,
generator version 6 (tray 5, 4 and 3 by level, G10, the new sawtooth, prices 3, 5 and 8, gifts
at levels 50 and 100, the shrink line). Specs read: GDD sections 0, 5, 6.3, 6.4, 6.6, 6.8 and 12
(items 19, 21, 22a, 22b, 22c, 30), UX 3.2.2, 3.4, 3.13.4 and 3.14. Everything I wrote is in
`tests/bots/` and this file; no game code was touched and nothing was committed.

## 1. Summary

- **Full suite: 567 passed, 0 failed** (`bash tools/test.sh`; it prints an `OPEN FINDING` line for each open reproduction, 4 today). It was 529 passed, 8 failed before my
  fixes; the 8 were my own tests written to the old numbers, and none was a game bug.
- **The new difficulty works as designed.** On 100 generated levels per tier plus every
  numbered level from 9 to 400, every check passed except one (G4 on Relaxed, below). The tray is
  5, 4 and 3 where it should be, G10 holds on all of them, nothing falls back more than 4 percent
  (the gate is 10), and the true least peak equals the schedule's on 84 to 100 percent of levels.
- **Is it hard but fair, or a wall?** It depends on how far ahead the player thinks (section 5).
  For a player who plans, levels 21 to 99 are fair and levels 100 and up are hard. For a player
  who only reacts to what is in front of them, levels 50 and up are a wall: a one move ahead bot
  wins 5 percent of first tries at 50 to 99 and gives up on 54 percent of those levels. A bot that
  learns the level a little more on each retry wins at 50 to 99 in a median of 5 to 7 tries and at
  100 and up in 7 to 11. The skill curve in section 5 says how good the play has to be.
- **Findings:** no Critical or High. 1 Medium (G4), 3 Low (G1, G2, G3), 1 note (G5). The Phase 4
  reproductions (F1, F4, F5, F6, F7) no longer print an open finding: they are fixed.

| Severity | Count | Findings |
|-|-|-|
| Critical | 0 | |
| High | 0 | |
| Medium | 1 | G4 a Relaxed hard level can be one the novice wins as it is played |
| Low | 3 | G1 a due gift is paid by a replay (docs disagree), G2 three notes push Replay off the clear screen, G3 the badge does not count up to the gift |
| Note | 1 | G5 two wordings for "not enough stars", one of them unreachable |

## 2. The 8 failing tests, and what I changed

I read each test's spec item and rewrote it from the GDD, not just the numbers. In every case the
code agreed with the GDD and UX; the tests were stale.

| Test | Spec item | What it expected | What I did |
|-|-|-|-|
| `test_acc_21` | 21, tier(N), GDD 6.3 | the old sawtooth (breather four tiers down, climb to level 151) | Now checks levels 9 to 30 against the GDD's own list (parsed from 6.3) and against a formula worked out in the test from the new bases and steps, levels 9 to 20 one tier after another, 21 to 49 as 5, 5, 5, 6, 6, 50 to 99 as 7, 7, 7, 8, 8, 100 to 110 as 9, 9, 9, 10, 10, the cycle to level 99999, and that the data file holds the steps and bases the GDD prints in 6.8 |
| `test_acc_30` | 30, breathers | a breather four tiers below every hard level | Now: from level 21 the level after each fifth is one tier lower with the same tray and the same least peak; levels 9 to 20 never step down |
| `test_acc_22a` | 22a, G8 | `suits_tier` equals section 10's column | `suits_tier` now includes the Phase 5 skip lists, so the column is checked on a copy of each tier row without its skips (section 10 describes the boards as authored), at least 8 boards per tier 7 to 10 before the skips and 6 after, the skip lists of 6.8 (tier 7: skyline; tier 8: bookshelf, catface, ferris-wheel, ship-wheel), that the skip list is the only difference, and the boards per range (12, 12, 7, 13, 11, 8) |
| `test_acc_19` | 19 and 22c, prices | 4, 6, 8 | Now 3, 5, 8 from the data and from the GDD's text, the arrival levels 8, 15, 25 with 2 free, and the gifts: levels 50 and 100, 2 Undos and 1 Extra slot each, no Screwdriver, as the GDD prints them |
| `test_acc_13` (Retry) | 13, R34 | a 6 slot tray after Extra slot, 5 after Retry | Level 15 has 4 slots: 5 with Extra slot, 4 after Retry |
| `test_acc_13c` (too few) | 13c, R38 | "Not enough stars. 4 needed." with a bank of 3 | The bank must be one short of the price (2, 4 and 7 stars): see the judgment below |
| `test_acc_13c` (exact price) | 13c | a bank of 4, spends to 0 | Each helper, with a bank of exactly its price (3, 5, 8): dialog, Back, Not now, Get and use spends exactly the price. The Screwdriver is taken from the save when a screw is removed, not when the mode starts |
| `test_acc_13b` | 13b, R37 | "owns nothing" case offered nothing | The test played level 60 and sometimes won it, which now pays the level 50 gift, so the player did own helpers. The levels are now 25 to 45 (3 slot trays, no gift), what is owned is read from the save, and every case checks the 3 slot tray |

**Judgment on 13c: one message, not two.** When the bank cannot pay, the level scene shows its own
note ("Not enough stars. 3 needed.", `_helper_button` in `level_scene.gd`) and does not ask the
app flow to buy, so the player sees exactly one message. The app flow's own toast ("Undo costs 3
stars. You have 2.") only shows if the scene asks to buy with a bank it believes is bigger than the
saved one, which a real tap never does; in that case it is the only message. Both are tested
(`test_acc_13c_one_star_short_gives_one_message_and_spends_nothing`). The two wordings differ, so
this is note G5, not a double message.

## 3. New acceptance tests

| Item | Test | What it checks |
|-|-|-|
| 22b | `test_qa5_acceptance.gd` | the data (tray 5, 5, 4, 4, 3, 3, 3, 3, 3, 3 and least peak 0, 0, 0, 1, 1, 1, 2, 2, 3, 3 by tier, Relaxed 5, the six rows of the GDD 6.8 table); 27 numbered levels from 9 to 150, three Dailies and nine Relaxed levels: the tray each carries and PlayState's tray, and G10 by search (no solution with one slot fewer than the least peak when it is 2 or more, searched to the end); tutorial levels 5; the tray never grows with the level; the stored fallbacks carry their tier's tray |
| 22b | `acceptance.gd` (script) | every numbered level from 9 to 400: tray, G10, and the TRUE least peak found by searching with fewer and fewer slots (section 4) |
| 22c | `test_qa5_flow.gd` | the real gifts: the note on the clear of level 49 (not 50), 2 Undos and 1 Extra slot added, recorded, Next still one tap, nothing on level 50 or on a replay of 49, survives a restart; level 100 after 50 was given; a save already past 50 gets its gift on the next clear and once only; a save past both gets one note with the sum; no gift for the Daily or Relaxed; a progress reset clears the gift flags and the shrink line flag; edited gift and flag values in a save are cleaned. The kill between grant and clear is covered by `tests/ui/test_flow_tray.gd` (`test_a_kill_between_the_grant_and_the_plaque_gives_it_once`), so I did not repeat it |
| shrink line | `test_qa5_flow.gd`, real level scene | shows once, word for word, on level 12 when Next arrives from 11 (4 slots, the tray closing runs, the clock does not start), never again on 13; from the title the line shows with no closing; not on Retry, a replay (from the map, or by Next from a replay), the Daily or Relaxed; a save that first meets a smaller tray late (level 30) gets the line once; 21 has no line |
| tray closing | `test_qa5_flow.gd`, real level scene | runs only on arrival by Next (11 to 12, 20 to 21), never from the title, the map, Retry, a replay, the Daily or Relaxed |
| UX 3.2.2 | `test_qa5_flow.gd` | the tray frame is 160, 210, 260 and 310 wide with the slot left edges UX gives, 52 tall; the boxes, board, helper bar and top bar do not move between a 5, 4 and 3 slot level; Extra slot adds one slot and Retry takes it back |
| UX 3.14 | `test_qa5_flow.gd` | the Info lines for the tray, the prices and the gifts are the UX's words, and the app shows them |
| bots | `test_qa5_retry.gd` | the new retrying bots (below) and every Phase 2 bot with its rule checks on levels with 5, 4 and 3 slots and with Extra slot (the checks found no violation) |


## 4. The numbers on version 6

`acceptance.gd`, seed 7, 100 levels per tier (tiers 1 to 8 from the Relaxed streams, 9 and 10 from
numbered levels), plus the numbered levels 9 to 400:

| Tier | Fallback | Screws | Fewest tray | Novice wins | Novice taps (median) / needed | Last tray use (median) | Random wins | Generation ms (median / p95 / max) |
|-|-|-|-|-|-|-|-|-|
| 1 | 0% | 9-12 | 0-0 | 100% | 9 / - | 0 | 100% | 4 / 26 / 33 |
| 2 | 0% | 12-15 | 0-0 | 100% | 15 / - | 0 | 100% | 5 / 12 / 13 |
| 3 | 0% | 15-18 | 0-0 | 100% | 18 / - | 0 | 99% | 6 / 8 / 9 |
| 4 | 0% | 18-21 | 1-2 | 81% | 18 / - | 4 | 73% | 17 / 75 / 196 |
| 5 | 0% | 21-24 | 1-2 | 84% | 21 / - | 4 | 59% | 21 / 200 / 335 |
| 6 | 0% | 24-27 | 1-3 | 68% | 24 / - | 4 | 53% | 56 / 226 / 462 |
| 7 | 2% | 27-30 | 2-3 | 0% | 12 / 9 | 5 | 11% | 91 / 577 / 1156 |
| 8 | 2% | 30-33 | 2-3 | 2% | 13 / 11 | 4 | 7% | 161 / 812 / 1203 |
| 9 | 4% | 33-36 | 3-4 | 0% | 5 / - | 5 | 0% | 272 / 1412 / 2085 |
| 10 | 1% | 33-36 | 3-4 | 0% | 4 / - | 5 | 0% | 162 / 1563 / 2673 |

- Fallback rates are 0 to 4 percent on every tier (the gate is 10; the designer's scratch
  measurement had predicted 6 to 12 percent on tiers 7 and 8). Generation takes up to 2.7 s on this
  PC on tier 10 (p95 about 1.5 s on tiers 9 and 10), so a Daily or a Previous level made on demand
  will take noticeably longer on a phone.
- The novice's G9a survival on tiers 7 and 8 (12 and 13 taps against 10 and 11 needed) holds.
- Every check passed except **G4 on two Relaxed hard levels** (finding G4).

The true least peak: for each numbered level the fewest tray slots any solution needs, by
complete searches with fewer and fewer slots (a level that needs no tray at all shows 1, the
smallest tray the game has). "Wrong moves forgiven" is the tray minus that peak.

| Levels | n | Tray | Schedule peak | True peak equals it | Wrong moves forgiven (tray minus true peak): min / mean / max |
|-|-|-|-|-|-|
| 9 to 11 | 3 | 5 | 0 | (searched from 1) | 4 / 4.00 / 4 |
| 12 to 15 | 4 | 4 | 0 | (searched from 1) | 3 / 3.00 / 3 |
| 16 to 20 | 5 | 4 | 1 | 100% | 3 / 3.00 / 3 |
| 21 to 49 | 29 | 3 | 1 | 86% | 1 / 1.86 / 2 |
| 50 to 99 | 50 | 3 | 2 | 84% | 0 / 0.84 / 1 |
| 100 to 400 | 301 | 3 | 3 | 100% | 0 / 0.00 / 0 |

G10 only guarantees the true peak is at least the schedule's. The rest are one higher, which is
one wrong move fewer: 14 percent of levels 21 to 49 forgive one wrong move instead of two, and 16
percent of levels 50 to 99 forgive none instead of one. That is within the designer's "up to" wording
and I do not count it as a defect.

## 5. The retrying bots: how hard are levels 9 to 200

`retry_report.gd`, seed 1, numbered levels 9 to 200 as generated (192 levels), 10 people per
level and profile. The command is
`godot --headless --path . -s res://tests/bots/retry_report.gd -- --from=9 --to=200 --persons=10 --samples=10 --out=build/qa5`
(about 3 minutes); the full output is `build/qa5/retry-report.txt` and one row per level is in
`build/qa5/retry-seed1-9-200.csv`. Nobody uses a helper.

There is no single "retrying bot", because the answer depends on how a person plays. I used four,
from least to most informed:

- **Greedy novice** (GDD 6.4): deterministic, so it wins on the first try or never.
- **The thinker**: thinks one move ahead (a screw that completes a box first, then one that fits a
  box, then a tray screw whose box is in the preview), breaks ties at random, so every try
  differs, and retries after a loss. This is "think 1 move ahead".
- **The learner**: starts as the thinker and, after each loss, sees the best move on 5 (or 10)
  percent more of the taps: a person who learns the level by losing at it.
- **The planner**: knows a good line and slips (about 2 wrong taps in a first try, a random free
  screw instead of the planned one), then plays plan guided, and slips 20 percent less after each
  loss. This is "a person who makes some wrong taps, loses, and retries".

**Tries to win** (cap 30; a person who has not won by then is counted as "gave up"):

| Levels | Novice wins first try | Novice never wins | Thinker: first try | median | p90 | gave up | Learner +5% a try: median | p90 | Learner +10%: median | p90 | Planner (2 slips): first try | median | p90 |
|-|-|-|-|-|-|-|-|-|-|-|-|-|-|
| 9 to 20 | 92% | 8% | 92% | 1 | 1 | 0% | 1 | 1 | 1 | 1 | 100% | 1 | 1 |
| 21 to 49 | 62% | 38% | 41% | 2 | 14 | 8% | 2 | 5 | 2 | 4 | 97% | 1 | 1 |
| 50 to 99 | 0% | 100% | 5% | 30 | 30 | 54% | 7 | 14 | 5 | 9 | 83% | 1 | 2 |
| 100 to 200 | 0% | 100% | 0% | 30 | 30 | 94% | 11 | 15 | 7 | 10 | 76% | 1 | 2 |

**The skill curve**: the share of first tries won by a person who sees the planned move on that
share of taps and otherwise plays like the thinker, no slips.

| Levels | 0% | 25% | 50% | 75% | 90% | 100% |
|-|-|-|-|-|-|-|
| 9 to 20 | 93% | 98% | 99% | 100% | 100% | 100% |
| 21 to 49 | 42% | 71% | 84% | 94% | 99% | 100% |
| 50 to 99 | 6% | 21% | 45% | 78% | 93% | 100% |
| 100 to 200 | 0% | 4% | 20% | 56% | 83% | 100% |

**What a level forgives**: the share of tries won with exactly k wrong taps (a free screw sent to
the tray needlessly, at a random moment, the rest planned):

| Levels | k=1 | k=2 | k=3 | k=4 | levels where k=1 always wins | k=2 always wins | k=3 always wins |
|-|-|-|-|-|-|-|-|
| 9 to 20 | 100% | 100% | 100% | 100% | 100% | 100% | 100% |
| 21 to 49 | 99% | 97% | 96% | 91% | 93% | 83% | 69% |
| 50 to 99 | 93% | 84% | 70% | 62% | 68% | 42% | 12% |
| 100 to 200 | 84% | 71% | 61% | 51% | 25% | 4% | 1% |

**Reading it.**
- **Levels 9 to 20** forgive everything: even the thinker wins 92 percent of first tries. This is
  the intended gentle ramp (Bart's "up to 5 wrong moves").
- **Levels 21 to 49** are fair. The thinker wins 41 percent first time (median 2 tries); a person
  who sees the best move half the time wins 84 percent; the planner with 2 slips wins 97 percent.
  Two wrong taps are forgiven 97 percent of the time, three still 96 percent: the "only 2 wrong
  moves" of the schedule is a ceiling on the tightest moment, not a cap on how many needless taps
  a level absorbs (GDD 6.8 says so).
- **Levels 50 to 99** are hard, and a wall for a player who only reacts. The thinker wins 5
  percent of first tries and gives up on 54 percent of the levels. A learner needs a median of 5 to
  7 tries (p90 9 to 14). Someone who sees the best move on three taps of four wins 78 percent first
  time. One wrong tap is still forgiven 93 percent of the time and two 84 percent.
- **Levels 100 to 200** are very hard: the thinker gives up on 94 percent, a learner needs 7 to 11
  tries (p90 10 to 15), and a person must see the best move on about 9 taps of 10 to win 83 percent
  first time. Yet one random wrong tap is still forgiven 84 percent of the time and two 71 percent,
  so "no wrong move" from level 100 is not literally true for a player who plans: the true least
  peak equals the tray on all 301 levels, but the tray holds the screws at the tightest moment
  only.
- **Bart's complaint** (level 40, "I can pull the wrong screw more than once and still solve it")
  is still true for a player who plans: at 21 to 49 two or three deliberate wrong taps are
  absorbed 96 to 97 percent of the time. What changed is the player who does not plan: a one move
  ahead player now loses more than half of the levels 21 to 49 and nearly all from level 50.
- **A way to read it for the designer.** If the target is "a player who thinks one move ahead
  struggles from about level 21 and must plan from level 50", the data says the game does that. If
  the target is "even a planner can only afford one slip at 50 and none at 100", it does not: the
  planner's first try success with two slips is 83 and 76 percent. The wave coloring in GDD 6.8
  (a second peak after halfway) is the experiment aimed at exactly that.

**How far to trust the bots.** The planner follows the solver's best line, so it is a ceiling for
a human who has found the solution; the thinker is a floor for a human who reacts. Real players
sit between, and a real player who re-plans after a slip is stronger than the planner (which only
re-orders its old plan). The learner's "5 or 10 percent more of the taps per loss" is a guess at
how fast a person learns a level; the result moves with it (median 5 against 7 tries at 50 to 99),
which is why both rates are shown. The star economy (GDD 6.8's helper estimates) is not measured
here, because it needs a model of how many stars a person earns, which these bots do not give.

## 6. Findings

### G4. Medium: a Relaxed hard level can be one the novice wins as it is played

- **Steps:** `LevelCatalog.get_level(LevelData.RELAXED, 52, "hard")` (also 92). Play it with
  `NoviceBot` (or run `acceptance.gd`).
- **Expected:** GDD 6.4 G4: on tiers 7 to 10 the novice must lose; 6.6: Relaxed "applies G1 to G10".
- **Found:** the novice bot wins both (tier 8). The stored solve says `novice_won` false. The
  generator measures the novice on the tier's tray (3 slots) but a Relaxed level is played with 5,
  and a fresh solve of the level as played says the novice wins. So the stored `novice_won`,
  `novice_taps` and the other solve measures describe a 3 slot level that is not the one shown.
  `fewest_tray_uses` and the solution stay valid on 5 slots, so every level is still solved.
- **Impact:** Relaxed cannot be lost (free Undo), so no player is hurt; it is a measurement that
  does not match the level (2 of 100 tier 8 levels in my sample, 0 of 100 on tier 7).
- **Evidence:** `test_g4_a_relaxed_hard_level_...` in `tests/bots/test_qa5_findings.gd`;
  `acceptance.gd` reports it under "G4".

### G1. Low: a due gift is paid by a replay, and the documents disagree about the gift

- **Steps:** a save that has cleared 60 levels and never got its level 50 gift. Replay level 30
  from the map and win it.
- **Found:** the gift for level 50 is paid on that replay clear.
- **Documents:** GDD 5 says each gift is "never on a replay"; UX 3.13.4 says a player already
  past 50 gets it "on their next numbered level clear", which includes a replay. The code follows
  the UX. Separately, GDD 5, 6.8 and 12 item 22c say the gift is "shown with the first time helper
  sheet", while UX 3.13.4 and the code show a plaque on the clear screen (so Next stays one tap).
  The designer should make the GDD say what UX and the code do.
- **Evidence:** `test_g1_...` in `test_qa5_findings.gd`; 22c is checked as the UX says it.

### G2. Low: three notes on the clear screen push Replay (and Next) off a 360 x 640 screen

- **Steps:** a save that never received its unlock notes (an older build) and has cleared level 48.
  Win level 49: "Unlocked: Walnut wood", "Unlocked: Brass metal" and the level 50 gift show
  together; Next ends at y 626 and Replay at y 682 of 640.
- **Expected:** UX 3.4 has room for two notes (the unlock and the gift).
- **Impact:** only a save that is due two unlocks and the gift at once; one unlock and the gift fit.
  `build/qa5/shots/base-6-clear49-gift.png` shows it (the tall screen is fine).
- **Evidence:** `test_g2_...` in `test_qa5_findings.gd`.

### G3. Low: the helper badges do not count up to the gift

- **Steps:** win level 49 with no helpers (the gift pays 2 Undos and 1 Extra slot), press Next.
- **Expected:** UX 3.13.4: "the helper bar's count badges for Undo and Extra slot count up from
  the old number to the new one when the next level shows (one soft tick per step, 200 ms apart,
  once)".
- **Found:** level 50's Undo badge shows 2 from its first frame (before the gift it showed the
  price, 3 with a star). Only the first-time sheet's count up exists (`highlight_helper`).
- **Evidence:** `test_g3_...` in `test_qa5_findings.gd`.

### G5. Note: two wordings for "not enough stars"

The level says "Not enough stars. 3 needed." and the app flow says "Undo costs 3 stars. You have 2."
Only the first can be reached by a tap (section 2, judgment on 13c). The second is dead code in
practice; if it stays, the wording should match.

### Phase 4 findings now fixed

The reproductions of F1 (sheets under the level's drawing), F4 (next_level beyond progress), F5
(About notes clipped), F6 (stuck sheet below the screen) and F7 (star bank under Pause) no longer
print an open finding; F2 stays as a regression test, F3 is accepted, F8 is pinned as designed.

## 7. What I looked at on screen

`qa_windowed5.gd` (windowed, `Save.dir` guarded) took 21 pictures into `build/qa5/shots/`: level 11
(5 slots), level 12 arriving by Next (the tray closing in two frames, then the shrink line), level
21 (3 slots) from the title, the clear screen of level 49 with the gift, and a full 3 slot tray on
the Out of room sheet, at 360 x 640, 412 x 915 and 360 x 922. The 4 slot and 3 slot trays are
centered, steel, and shorter, the shrink line sits in the helper bar's place without covering the
board or tray and wraps to two lines at 16 point, and the Out of room sheet is readable (the
Phase 4 overlap is gone). The only layout problem is G2.

## 8. Files

New in `tests/bots/`: `test_qa5_acceptance.gd`, `test_qa5_flow.gd`, `test_qa5_findings.gd`,
`test_qa5_retry.gd`, `retry_player.gd`, `retry_report.gd`, `qa_windowed5.gd`. Changed:
`test_qa4_acceptance.gd`, `test_qa4_flow.gd`, `test_qa4_modes.gd` (the 8 tests), `acceptance.gd`
(Phase 5 tray and true least peak table, `--peaks`).

## 9. Ideas for later

- Measure the star economy with a person model (stars per level for the planner and the learner
  against the new prices) before changing a price.
- A wave coloring experiment, if Bart still finds the endings too easy, can be judged with the
  skill curve: it should lower the 75 to 90 percent skill columns at levels 50 and up.
- `retry_report.gd` could run on every generator version and keep its table next to the
  fallback report in `tools/levels`.
