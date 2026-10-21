# QA report 4: the Phase 4 acceptance walk

Reviewer: qa-tester. Build: the working tree on 21 October 2026 (afternoon), on top of commit
0a0b49f, generator version 5. The tree kept changing while I walked it (finding F2 was fixed by
ui-dev and gameplay-dev halfway through; the pause rule for helper sheets changed), so each
result below was checked against the tree as it stood when I wrote it down. Everything I wrote
is in `tests/bots/` and this file. No game code was touched and nothing was committed.

## 1. Summary

- Full suite: **475 passed, 0 failed** (`bash tools/test.sh`, about 3 minutes; it prints an `OPEN FINDING` line for each open reproduction, 8 today). My 61 new tests are in it
  and run in about 80 game seconds of the runner's budget (see finding F9).
- GDD 12 acceptance list: **38 items, 33 pass, 1 fails for Hard and Expert (20), 1 passes with defects on the
  screens it touches (27), 2 not checkable here (29, 31 in part), 1 passes with findings (26)**.
  Table in section 4.
- **No Critical finding.** Open findings: **3 High (F1, F6, F7), 1 Medium (F5), 2 Low (F4, F8)**,
  plus 2 notes about the test runner (F9, F10). F2 (Medium) was fixed while I worked and stays in
  the suite as a regression test; F3 (Low) was accepted by the lead (see below).
  worked and stays in the suite as a regression test.
- The rules and the generator are clean. Over about 11,000 bot games on version 5 (tutorials,
  levels 9 to 200, 60 Dailies, 120 Relaxed, 1000 levels at 100 per tier) the session checks found
  **no rule violation**: events, free screws, R7 covering worked out again from the outlines,
  R10, R12, I1, R16 (the centroid of a hanging plank lies straight below its pivot) and undo all
  agree with the engine, and every bot result agrees with the solver.
- The problems are all in the look and layout of the new screens: the level's HUD and planks are
  drawn over the clear, out of room and stuck sheets (F1, F6) and the star bank hides under the
  pause button on every phone taller than 360 x 640 (F7). Fixing them needs a screenshot at
  360 x 800, 412 x 915 and 360 x 922, which no test in the repo takes today.

| Severity | Count | Findings |
|-|-|-|
| Critical | 0 | |
| High | 3 | F1 sheets under the level's drawing, F6 stuck sheet below the screen, F7 star bank under Pause |
| Medium | 1 (+1 fixed) | F5 About notes clipped; F2 looks changes while paused (fixed) |
| Low | 2 (+1 accepted) | F4 save fields unlinked, F8 a clock set ahead locks the streak; F3 clock moved back pays that day's stars (accepted) |
| Notes | 2 | F9 the runner's time budget is global and nearly spent, F10 first run after a new class needs a second import |

## 2. What I ran

```
bash tools/test.sh                      # everything
bash tools/test.sh qa4                  # my Phase 4 suites (61 tests)
bash tools/test.sh bots                 # all bot suites (Phase 2 and 4)
godot --headless --path . -s res://tests/bots/report.gd -- --levels=0 --generated=9-200 --dailies=60 --relaxed=40 --random-runs=20 --by=tier --out=build/qa4
godot --headless --path . -s res://tests/bots/acceptance.gd -- --per-tier=100 --g7=9-300 --random-games=2
Godot_v4.7.2-stable_win64.exe --path . -s res://tests/bots/qa_windowed.gd          # windowed, 10 window sizes
Godot_v4.7.2-stable_win64.exe --path . -s res://tests/bots/qa_windowed.gd -- --only=base --animated
```

- `report.gd` is the Phase 2 bot report with two new options: `--dailies=N` and `--relaxed=N`
  (Daily from 2026-10-21 on, and Relaxed streams of each band), plus a `kind` grouping.
- `acceptance.gd` is new. It makes 100 generated levels per tier (tiers 1 to 8 from the Relaxed
  streams, 9 and 10 from numbered levels) and checks G1 to G7, G9a, the readability caps, the
  48 du gap along the solution and R10 and I1 under the random bot, and prints the fallback
  rate, novice survival, last tray use and generation time per tier.
- `qa_windowed.gd` drives the real app in a window by script: title, map, level, pause, settings,
  about, info, stats, "Back to level", the clear screen, a Relaxed loss and a numbered loss, at
  240 x 427, 320 x 568, 360 x 640, 360 x 922, 412 x 915, 533 x 640, 1200 x 1920 and 1280 x 720,
  and again at 360 x 640 and 240 x 427 with coffee hidden. 120 pictures in `build/qa4/shots/`
  (gitignored), and an audit that every visible button is at least 48 by 48 units and on screen
  (836 buttons: none too small; the only ones off screen are inside scrolling About pages and
  the stuck sheet, F6). It points `Save.dir` at `user://qa_windowed/` first and replaces
  `Links.opener`, so no real save is touched and no link opens.
- New suites in `tests/bots/`: `test_qa4_acceptance.gd` (items that read the GDD's own numbers),
  `test_qa4_flow.gd` (real level scene), `test_qa4_menus.gd`, `test_qa4_modes.gd`,
  `test_qa4_saves.gd`, `test_qa4_chaos.gd` (the real scene with animation on, hit with every
  action at once), `test_qa4_findings.gd` (reproductions, below) and the helper
  `qa_flow_case.gd`.
- `test_qa4_findings.gd` asserts what the game should do. While a finding is open the test prints
  `OPEN FINDING Fn: ...` and passes, so the suite stays green; set `STRICT := true` in that file
  and it fails until the game is fixed. After a fix the line disappears.

## 3. Bots on version 5 against Phase 2

Levels 9 to 200 as numbered levels, the perfect, novice and random bots (20 random games per
level), generated by version 5 and, for the comparison, by version 3 (Phase 2's final generator,
commit 6b3055a extracted to a scratch folder; same bots, same level numbers). Full text:
`build/qa4/bots-v5-tables.txt`, `build/qa4/bots-v3-tables.txt`; one row per level:
`build/qa4/bots-seed1-n380.csv`. In both runs: perfect bot 100 percent wins on every tier, its
tray uses equal the solver's, and no rule violation.

| Tier | Levels | Screws v3 / v5 | Fewest tray v3 / v5 | Novice wins v3 / v5 | Random wins v3 / v5 | Novice peak tray v3 / v5 | Trap v3 / v5 |
|-|-|-|-|-|-|-|-|
| 1 | 7 | 9.9 / 10.3 | 0.00 / 0.00 | 100 / 100 | 100 / 100 | 0.00 / 0.00 | 0.00 / 0.00 |
| 2 | 9 | 14.3 / 14.7 | 0.00 / 0.00 | 100 / 100 | 100 / 100 | 0.00 / 0.11 | 0.00 / 0.00 |
| 3 | 15 | 16.0 / 16.0 | 0.00 / 0.00 | 100 / 100 | 100 / 97 | 0.00 / 0.07 | 0.00 / 0.00 |
| 4 | 21 | 18.4 / 18.9 | 1.19 / 1.19 | 71 / 81 | 77 / 77 | 3.05 / 3.10 | 0.20 / 0.22 |
| 5 | 26 | 23.0 / 22.4 | 1.19 / 1.31 | 85 / 81 | 63 / 66 | 2.54 / 2.69 | 0.32 / 0.30 |
| 6 | 33 | 24.9 / 25.4 | 1.52 / 1.21 | 76 / 73 | 57 / 59 | 2.73 / 3.09 | 0.39 / 0.37 |
| 7 | 29 | 29.6 / 28.2 | 2.10 / 2.28 | 0 / 0 | 7 / 9 | 5.00 / 5.00 | 0.93 / 0.92 |
| 8 | 24 | 32.4 / 31.8 | 2.71 / 2.08 | 0 / 0 | 8 / 19 | 5.00 / 5.00 | 0.92 / 0.84 |
| 9 | 18 | 33.7 / 33.3 | 3.44 / 3.28 | 0 / 0 | 1 / 0 | 5.00 / 5.00 | 0.99 / 0.99 |
| 10 | 10 | 33.6 / 33.0 | 3.30 / 3.40 | 0 / 0 | 1 / 0 | 5.00 / 5.00 | 1.00 / 0.99 |

(Win rates in percent. The tutorials: every bot 100 percent, as before.)

What changed from version 3 to 5, in words:
- Tiers 1 to 3 and 7 to 10 are the same shape. Tiers 4 to 6 move a few points either way, as a
  different set of boards would. The novice still wins every tier 1 to 3 level and loses every
  tier 7 to 10 level (G4, item 23).
- Tier 8 is easier for the random bot (19 percent against 8) and its mean fewest tray uses fell
  from 2.71 to 2.08 (range 2 to 3 in the 100 per tier run). Worth a look by the designer: the
  step from tier 7 (9 percent random wins) to tier 8 (19) is now backwards.
- Phase 2's earlier table was on random colorings of the blueprints, where the novice won 73
  percent of Hard-size boards; with generated levels that is 0 percent, so intent in the coloring
  works, as GDD 6.5 predicted.

Daily (60 days from 2026-10-21) and Relaxed (40 per band), version 3 against 5:

| Kind | Screws | Fewest tray | Novice wins | Random wins |
|-|-|-|-|-|
| Daily, all tier 6 | 24.8 / 25.6 | 1.47 / 1.47 | 73 / 77 | 52 / 56 |
| Relaxed easy | 13.9 / 13.9 | 0.00 / 0.00 | 100 / 100 | 99 / 99 |
| Relaxed medium | 22.0 / 22.6 | 1.30 / 1.25 | 80 / 85 | 62 / 64 |
| Relaxed hard | 31.3 / 29.9 | 2.17 / 2.33 | 0 / 0 | 9 / 12 |

### 100 generated levels per tier (item 22, 23, 24, 25 and the report it asks for)

`acceptance.gd`, version 5, seed 7: **every check passed** (G1 ranges, R3, G3 solved with a
complete search, the solution replays with the fewest tray uses, G4, G5, G6, G7 over numbered
levels 9 to 300 and each Relaxed stream, G9a on tiers 7 and 8, at most 36 screws, 8 colors, 5
layers, 16 planks, 24 free and 3 planks over any screw, 48 du between free screws in every state
of the solution, and R10 and I1 over 2000 random games).

| Tier | Fallback | Screws | Colors | Layers | Most free | Fewest tray | Novice wins | Novice taps (median) / needed | Last tray use (median) | Random wins | Generation ms (median / p95 / max) |
|-|-|-|-|-|-|-|-|-|-|-|-|
| 1 | 0% | 9-12 | 2-3 | 1-2 | 12 | 0-0 | 100% | 9 / - | 0 | 100% | 4 / 25 / 27 |
| 2 | 0% | 12-15 | 3 | 2-3 | 14 | 0-0 | 100% | 15 / - | 0 | 100% | 4 / 11 / 12 |
| 3 | 0% | 15-18 | 3-4 | 3-4 | 17 | 0-0 | 100% | 18 / - | 0 | 97% | 6 / 10 / 15 |
| 4 | 0% | 18-21 | 4 | 3-4 | 17 | 1-2 | 89% | 18 / - | 3 | 77% | 17 / 55 / 88 |
| 5 | 3% | 21-24 | 4-5 | 3-5 | 22 | 1-2 | 88% | 21 / - | 4 | 74% | 22 / 109 / 181 |
| 6 | 2% | 24-27 | 5 | 3-5 | 21 | 1-3 | 70% | 24 / - | 3 | 58% | 66 / 259 / 431 |
| 7 | 9% | 27-30 | 5-6 | 4-5 | 23 | 2-3 | 0% | 12 / 10 | 5 | 15% | 82 / 383 / 595 |
| 8 | 18% | 30-33 | 6-7 | 4-5 | 24 | 2-3 | 0% | 12 / 10 | 6 | 6% | 247 / 1500 / 1721 |
| 9 | 8% | 33-36 | 7 | 4-5 | 24 | 3-4 | 0% | 6 / - | 5 | 0% | 150 / 874 / 1211 |
| 10 | 0% | 33-36 | 7-8 | 4-5 | 24 | 3-5 | 0% | 6 / - | 5 | 0% | 149 / 759 / 1031 |

Note for the designer and the engine developer: tier 8 falls back on 18 percent of its levels,
and generating a tier 8 level takes up to 1.7 s on this PC (p95 1.5 s). On a phone, several
times slower, a Next that arrives before the level made ahead is finished would wait. The app
asks for level N + 1 while N is played, so a normal player does not wait, but a Daily, a Relaxed
level or Previous level is made on demand.

### Item 20, bot data against GDD 5

The GDD's stars per level for a player who plays well (2.50, 2.25, 2.05, 1.90 by band) and for a
careless one (1.55) lie between the perfect bot (always 3.0) and the random bot on Easy and
Medium, and the novice bot is within a factor of 1.5 of the "plays well" figure there:

| Band (levels) | GDD plays well / careless | Perfect | Novice | Random |
|-|-|-|-|-|
| Easy (9 to 30; tiers 1 to 3) | 2.50 / 1.55 | 3.00 | 3.00, 3.00, 3.00 | 2.71, 2.17, 2.05 |
| Medium (31 to 100; tiers 3 to 6) | 2.25 / 1.55 | 3.00 | 3.00, 2.10, 2.15, 1.73 | 2.05, 1.56, 1.32, 1.18 |
| Hard (111 to 150; tiers 6 and 7) | 2.05 / 1.55 | 3.00 | 1.73, 0.00 | 1.18, 0.17 |
| Expert (151 on; tiers 7 to 10) | 1.90 / 1.55 | 3.00 | 0.00 | 0.00 to 0.38 |

Result: **Easy and Medium agree within a factor of 1.5. Hard and Expert do not**: the novice and
random bots cannot clear them at all (novice 0 percent, random 0 to 19 percent), so no star
rate between 1.55 and 2.05 can come from them. The economy table assumes a person who retries
and uses helpers, which bots do not model. This is the "tell the designer" case of item 20. Two
more limits: the Fast star here depends on an assumed 1.5 to 2.0 s per tap (the par is 3.0 to 4.5
s per screw, so every bot that wins is fast); and Relaxed has no stars, so its star columns are
zero by design.

## 4. The GDD 12 acceptance list

Pass, fail or not checkable here, with the evidence. "Suite" means a test in this repo; names
are given where they are not obvious. My independent check ("session") is `BotSession` in
`tests/bots/`: after every action it works out the rules again from outside (R7 from the
outlines, R10, R12, R13 and R18 to R24, the event list and its order, R16, undo) and compares.

| # | Item | Result | Evidence |
|-|-|-|-|
| 1 | R7 to R9 covering, E1, ring hole, same layer | Pass | tests/logic (E1, ring hole, R8); the session's independent R7 check after every action of about 11,000 games |
| 2 | R10 on generated levels | Pass | `acceptance.gd`: 1000 generated levels, 2000 random games, R10 checked in every state |
| 3 | R12 destination order, E7, leftmost slot after a gap | Pass | tests/logic; the session predicts every screw's destination at every state |
| 4 | R13 order, a tap that drops a plank and closes a box | Pass | `test_r13_one_tap_drops_a_plank_and_closes_a_box_in_order`; the session compares the whole event list |
| 5 | R16 rest angles E2 and E3, a disc at its center | Pass | tests/logic; the session checks every hanging plank's centroid is straight below its pivot |
| 6 | R17 a fallen plank never covers | Pass | `test_r17_a_fallen_plank_covers_nothing`; fallen planks are left out of the session's covering test and agree |
| 7 | R18 to R21, E4, E5, a queue that runs out | Pass | tests/logic; the session's own box and queue model matches in every game |
| 8 | I1 after every tap of 1000 generated levels (random bot) | Pass | `acceptance.gd`: 1000 levels, 2 games each, I1 checked after every action |
| 9 | R22 and R23, E6, win before loss | Pass | tests/logic (`test_r22_the_win_check_comes_before_the_loss_check`, `test_e6_r23`); the session recomputes the status |
| 10 | R25 refused tap changes nothing and does not start the clock | Pass | `test_e6_r25...`; `test_refused_taps_leave_the_state_alone` (the session checks state, helpers, history after each refusal); tests/level `test_the_clock_starts_at_the_first_accepted_tap_only` |
| 11 | R26 to R29 undo (box closes, plank falls, swing, cascade, loss, five in a row) | Pass | tests/logic; mine: tap, undo, tap again on 14 levels with the snapshot compared each time, undo all the way back, undo after a win refused |
| 12 | R30 and R31 | Pass | tests/logic; the chaos bot (illegal and badly timed calls, every reason code checked) |
| 13 | R34 Retry identical, resets clock, tray uses, Extra slot | Pass | `test_acc_13_retry_gives_an_identical_level...` on the real scene (level 15, Extra slot used, retry from Pause) |
| 13a | R36 killed app restarts the same level; new install opens level 1 | Pass | `test_acc_13a_a_killed_app_comes_back...` (the save holds no board state; same board, from the beginning); tests/ui `test_a_first_launch_goes_straight_to_level_1` |
| 13b | R37 the sheet shows exactly the owned, usable helpers | Pass | `test_acc_13b...`: six ownership cases on real losses; `usable_after_loss` equals the rule worked out here; the sheet never offers a purchase |
| 13c | R38 buying only on a tap, never in Relaxed | Pass | `test_acc_13c...` (3 stars: "Not enough stars. 4 needed." and nothing spent; exactly 4: dialog, Back and Not now buy nothing, Get and use spends exactly the price, clock held while it is open); tests/level `test_relaxed_shows_only_a_free_undo` |
| 13d | R35a map: cleared replays, next plays, locked plays nothing | Pass | `test_a_locked_map_node_leaves_the_paused_level_alone` (hammering locked nodes, gaps and off-map points); a 250,000 level save keeps the pool small and taps work |
| 13e | R36a Pause, Settings, other menus, Back to level: nothing changed, clock did not run | Pass | `test_acc_13e_a_paused_real_level_is_untouched_by_a_tour_of_every_menu` (the rule state, tray and picture identical after 1.5 s in menus; the recorded time leaves it out); quit or another level restarts it; F2 below was a gap here, now fixed |
| 14 | Blueprints pass B1 to B13, id is the file name | Pass | `test_b1_to_b13_every_shipped_blueprint_passes`; mine: 43 files, id equals file name, 8 tutorial files |
| 15 | Tutorials: valid, solvable, no reachable loss, fewest 0 | Pass | `test_8_tutorial_levels_are_solvable_without_the_tray_and_cannot_be_lost`; bots: perfect 0 tray uses, novice wins all 8, the random bot won 25 of 25 runs on each |
| 15a | tuning.json matches GDD 9.4 | Pass | `test_15a...`; mine reads GDD 6.1's table and compares all 10 tier rows, and the 9 to 30 list in 6.3 |
| 16 | S2 and S6 Fast at par, not at par + 1 s; clock waits, stops in pause and dialogs | Pass | stars unit tests; mine: Fast exact; the clock stopped while the buy dialog is open; 1.5 s in menus not counted |
| 17 | S3 Clean lost by one tray use or any helper | Pass | tests/logic; mine: each of the three helpers costs Clean but not Fast |
| 18 | S5 replays add only the difference | Pass | `test_acc_18...`: 1, +2, 0, 0; the bank and stars earned; spending does not lower stars earned |
| 19 | Prices 4, 6, 8; two free on levels 8, 15, 25, once | Pass | `test_acc_19...` (prices, levels, the sheet on each level, two free, no second sheet or gift on a replay) |
| 20 | Bot data matches GDD 5 within a factor of 1.5 | **Fails for Hard and Expert** | section 3: Easy and Medium agree; the bots cannot clear Hard and Expert, so the GDD's star rates there cannot be reached by them. The designer is told here |
| 21 | tier(N) for 9 to 30 and 151 to 160 | Pass | `test_acc_21...` parses the GDD's list; the cycle holds to level 99999 |
| 22 | 100 levels per tier pass G1 to G7, G9a on 7 and 8, with the report | Pass | section 3 (`acceptance.gd`) |
| 22a | `suits_tier` gives section 10's column; at least 8 boards for tiers 7 to 10 | Pass | `test_acc_22a...` parses the GDD table (43 rows) and compares every board and tier |
| 23 | Novice wins every tier 1 to 3 level and loses every tier 7 to 10 level, with the win rates | Pass | section 3: 100 levels per tier, the bot agrees with `Solver.novice_won` on every one |
| 24 | No level over 36 screws, 8 colors, 5 layers, 24 free at start | Pass | `acceptance.gd` (also 16 planks and at most 3 planks over a screw) |
| 25 | Free screws 48 du apart in every state of the solution | Pass | `acceptance.gd`, 1000 levels |
| 26 | Daily: tier 6, same for two installs, after level 8, streak rules | Pass, with F8 | `test_acc_26...`: tier 6, Medium, slack +1, same level twice and a different one the next day, golden fingerprints in tests/logic; streak over month, year and leap day ends, a skipped day, the clock moved back, the same day twice; the daily keeps the date it started on |
| 27 | Relaxed: tier per band, no stars, free unlimited Undo, stuck sheet | Pass, with F1 and F6 | `test_acc_27...`; `test_relaxed_undo_is_free_and_unlimited_on_the_real_scene` (five Undos, nothing taken from the save, each counted in the stats); the sheet itself has layout defects |
| 28 | Each unlock at its milestone and survives a restart | Pass | `test_acc_28...`: walnut 10, brass 25, maple 50, cherry 100, ebony 150, copper at a streak of 3, black at 7, named on the clear screen, still there after reload |
| 29 | Level 1 in under 30 s, no text | Not checkable here | needs a new player. Structure is right: 3 screws, par 30 s, the hand points at all three, no line of text on the level |
| 30 | A breather after every hard level, on the map | Pass | `test_acc_30...` (levels 10 to 400: the level after each fifth is at least 3 tiers down, or tier 1); the map marks every fifth level from 10 (tests/ui) |
| 31 | The fun checklist, item by item | Partly | table below |

### Fun checklist (GDD 11)

| # | Item | Result | Evidence or note |
|-|-|-|-|
| 1 | Level 1 under 30 s, no reading | Not checkable | needs a person (item 29) |
| 2 | Every tap answers within 100 ms | Pass | `tap_screw` with animation on: mean 0.4 ms, worst 2.2 ms (the picture and sound start in that call) |
| 3 | No dead taps | Pass | covered, gone and refused taps all answer (tests/level; the chaos suite) |
| 4 | Tray pressure visible, warning at one free slot | Pass | tests/level `test_a_screw_to_the_tray_clinks_dull_and_the_warning_ticks_once` |
| 5 | Fair failure | Not checkable | needs a person; the game has no randomness after the level is made, so every loss is a sequence of the player's own taps |
| 6 | Retry in under 2 s | Pass | Retry from Pause or the loss sheet is playable at once (2 ms here); the sheet slides in 0.25 s |
| 7 | A plank falling looks and sounds great | Not checkable | judgment |
| 8 | A box closing is a small win | Not checkable | judgment (sound and motion exist and are tested) |
| 9 | Breathers follow hard levels | Pass | item 30 |
| 10 | Mid game levels take 1 to 3 minutes | Not checkable | needs a person; the par for tiers 5 and 6 is 85 to 105 s |
| 11 | No two levels in a row look alike | Pass | G7 holds over numbered levels 9 to 300 and every Relaxed stream |
| 12 | Clear to next in one tap | Pass | Next is one tap and 3 ms (the level was made ahead) |
| 13 | Look first, the clock waits | Pass | tests/level and the 13e test |
| 14 | The first tap never has to go to the tray (G5) | Pass | `acceptance.gd` |
| 15 | Hard means order, not hunting | Pass | at most 24 free screws, 3 planks deep, covering never a near miss (the validator) |
| 16 | A swing that covers or uncovers a screw changes its look at the tap | Pass | tests/level (snapshot compares the drawn covered state with the rules); the chaos suite |
| 17 | An auto jump is a chain, left to right | Pass | event order checked in every game; tests/level `test_the_tray_fills_and_jumps_into_boxes_in_tray_order` |
| 18 | Every star is explained | Pass | the clear screen shows each star's target (screenshots) |
| 19 | Helpers are a choice, the bots prove it | Pass | the perfect bot wins all 1000 generated levels with no helper |
| 20 | A refused tap says why and costs nothing | Pass | tests/level; the session checks nothing changes |

Speed targets (UX 4.4) on this PC, headless, with the next level made ahead: Play to a level on
screen 28 ms, Next 3 ms, Retry 2 ms. These say nothing about a phone; the generator numbers in
section 3 are the part that scales with the phone.

## 5. Edge-case hunt

All of these have a test in `tests/bots/` unless marked. Nothing here crashed, logged an error or
lost progress, except the findings.

| Area | What I did | Result |
|-|-|-|
| Paused level through the dock | Real scene; two taps in, Back, Settings, Map, Stats, Info, About, License, Credits, Home, 1.5 s away, "Back to level" | Pass: state, tray and picture identical, time not counted |
| Quit to title, another level, reset | Restart from the beginning; map tap, Daily, Relaxed, reset drop the paused level | Pass |
| Back on every screen (UX 4.2) | Table-driven from the title and from Pause: each menu, License and Credits, Relaxed setup, clear, out of room, stuck sheet, reset dialog, Screwdriver mode, the title | Pass; nothing erased or spent by any Back |
| Coffee, shown and hidden | Every menu with the chip on and off; the level cup on levels 1 to 3, 4 and 21; Pause chip; a failing opener; cup pressed twice; `open_coffee` asked directly with coffee hidden | Pass: one chip per screen, none when hidden (not even the word), nothing handed to the phone |
| Locked map nodes | Hammered, between nodes, off the map; a paused level around them; level 250,000 | Pass: the toast names the next level, the paused level is untouched |
| Settings while paused | Sound, music, symbols from Pause; Back to level | Sound and music pass; symbols and looks did not reach the paused board (F2, fixed) |
| Reset progress | From a paused level and from the title; settings kept; a look that is no longer unlocked falls back | Pass |
| Buy with too few stars | 3 stars, exactly 4, Back, Not now, Get and use | Pass |
| Daily streak | Month end, year end, 2028 leap day, skipped day, clock back, same day twice, midnight during a daily | Pass; F8 is about the clock, F3 is accepted |
| Relaxed free Undo | Five in a row on the real scene | Pass |
| Edited saves | 20 progress files with wrong, huge, negative, string, null and unknown values; 13 damaged files (empty, truncated, NaN, deeply nested, NUL bytes); 5 settings files; 6 tampered `next_level.json`; a save from a newer build; an older one with few fields | Pass: all clamp or fall back, the app starts and every menu opens, no error logged. F4 is the one hole |
| Taps during animation, double taps, undo mid-animation | The real scene with animation on, 480 random actions on levels 9, 25 and 40: taps on any screw, the three helpers, Screwdriver mode, Pause, Resume, hold, Retry, resize, Back | Pass: the picture agrees with the rules in flight and settled, nothing logged |
| A swing that covers a screw, undo after a box closes or a plank falls | The session in every bot game | Pass |
| App killed mid level | Focus out, then no quit: the save holds no board, Play restarts the same board | Pass |
| Date changing during a daily | Level started on 31 October, won after midnight | Pass: counts for the day it began |
| Tiny and huge screens | Windowed pictures from 240 x 427 to 1200 x 1920 and 1280 x 720; button audit | Pass except F1, F5, F6, F7. No button under 48 units. The 1280 x 720 landscape layout puts boxes and tray beside the board and looks right |
| A save from an older build | Few fields | Pass |
| Double press on Next in one frame (not a test) | Two `pressed` signals in the same frame skip a level (the second press computes from the new current level) | Low, synthetic: a finger cannot do it, the clear screen is gone by the next frame |

## 6. Findings

### F1. High: the clear screen, Out of room and the stuck sheet are drawn under the level's own drawing

- **Steps:** play any level with the real scene (windowed or `qa_windowed.gd`). Win it: the clear
  screen shows with the level's top bar (Level, timer, star bank, pause button) and the helper
  row (Undo, Extra slot, Screwdriver) drawn on top of it, covering the top of the heading and
  the Replay button below Next. Lose a level: Out of room (and in Relaxed the stuck sheet) is
  drawn under the planks and the helper row; the heading, body text and Retry are cut up by
  planks and buttons.
- **Expected:** a sheet or screen over the level is drawn above everything of the level.
- **Found:** the level scene's HUD and planks use `z_index` (level scene top z is 100, the
  screens 0), and `z_index` sorts across the whole canvas, not inside the node. The flow does
  not hide the scene or give the screens a higher z or a CanvasLayer on win and loss.
- **Evidence:** `build/qa4/shots/base-360x640-10-clear-animated.png`, `...-11-stuck.png`,
  `...-12-out-of-room.png` (and the other sizes). `test_qa4_findings.gd`, F1 (it compares the
  highest drawn z of the level with the screen's). With a real mouse over the window (windowed
  run, `Input.warp_mouse` and a synthetic click) a click on Retry's center does retry, so
  touches reach the sheet: this is the picture, not the input.
- **Why High and not Critical:** the buttons still work, but the loss screen is where a
  player decides to retry, and the Replay button is hidden. It breaks "fast retry" and
  "every star explained" visually.

### F6. High: the Relaxed stuck sheet's buttons hang below the screen

- **Steps:** Relaxed, lose a level (or `test_f6` in `test_qa4_findings.gd`). At 360 x 640 and
  360 x 922 (and every size in the windowed run) Retry and Title end at y 657 of 640, y 939 of
  922: 17 units below the screen, so a third of each 48 unit button is off screen (more with a
  gesture bar).
- **Expected:** every button of a sheet fully on screen above the safe area.
- **Evidence:** `build/qa4/shots/tall-360x922-11-stuck.png`; the audit lines in
  `build/qa4/windowed-run.txt`. The numbered Out of room sheet does not have this.

### F7. High: the star bank is hidden under the pause button on phones taller than 360 x 640

- **Steps:** play level 4 or later on a 360 x 720, 360 x 800, 412 x 915 or 360 x 922 screen.
- **Expected:** cup, level label, timer, star bank and pause side by side.
- **Found:** the top bar items are laid out at `f` times their base width, while the bar stays
  360 wide. On a tall screen `f` is above 1 and the star bank's rectangle (up to x 302 f)
  reaches into the pause target (from x end minus 52 f): 53 units overlap. The star icon shows
  beside the button and the number is covered. At exactly 360 x 640 it fits.
- **Evidence:** `build/qa4/shots/tall-360x922-3-level.png`, `phone-412x915-3-level.png`;
  `test_f7` in `test_qa4_findings.gd` (rectangles from the HUD's own `top_items()` and targets,
  five sizes overlap, 360 x 640 does not). 412 x 915 is among the most common phone sizes.

### F5. Medium: the notes under "Send feedback" and "Source code" are cut off

- **Steps:** open About on any phone.
- **Expected:** "Opens a draft in your email app. You can edit it first." and "Opens
  github.com/bartbasi/WoodLogic in your browser." readable.
- **Found:** the note label does not wrap, is wider than its 328 unit button (353 and 379 units)
  and runs off both edges: "...You can edit it fir". The sentence that says the player can edit
  the draft is the one that is lost.
- **Evidence:** `build/qa4/shots/phone-412x915-7-about.png`; `test_f5` (every label inside a
  button against the button's width, on all menus and Pause at 360 x 640). `UiButton`'s `_note`
  has no `autowrap_mode`.

### F2. Medium, fixed during the walk: symbols and looks changed while paused did not reach the paused board

- **Steps (before the fix):** pause level 4, Settings, switch symbols off, Back to level.
- **Found then:** 6 of 6 screws kept their symbols until the next level; the symbols setting is
  the color-blind aid, so turning it on mid level showed nothing.
- **Now:** `AppFlow._apply_looks` calls the scene's `refresh_looks()`. The test
  `test_settings_changed_while_paused_show_when_the_player_goes_back_to_the_level` stays as a
  regression test.

### F3. Low, accepted by the lead: moving the clock back pays stars for a Daily that was never played

- **Steps:** solve the Daily of 10 November (3 stars). Set the clock to 9 November, solve that
  day's Daily: the bank grows by 3 more.
- **Found:** each date has its own stars, so any unsolved date in the past or future pays once.
  GDD 6.6 says moving the clock back "gains nothing"; that is true for the streak (the date must
  be later than the last counted one) and for the solved count, not for the stars.
- **Decision:** accepted. The game is offline, stars only buy helpers, and the streak is
  protected. `test_f3_accepted_...` in `test_qa4_findings.gd` no longer prints an open finding;
  it now pins that an earlier date pays its own stars once, never counts for the streak, the
  best streak, the solved count or the last counted date, and that earlier days cannot be added
  to build a streak backwards.

### F8. Low: a clock set far ahead once locks the streak until the real date catches up

- **Steps:** set the clock a year ahead, solve the Daily, set the clock back. `last_date` is now
  a year ahead, so no Daily counts for the streak until then (`test_a_clock_set_far_ahead_locks_
  the_streak_until_that_date` pins it).
- **Expected:** GDD 6.6 asks for exactly this rule ("later than the last counted date"), so it
  is as designed; the cost is a player with a wrong clock. Noted so the designer can decide
  whether to ignore dates more than a few days ahead of the last counted day.

### F4. Low: nothing ties `next_level` to the levels cleared in a save

- **Steps:** a progress file with `highest_cleared` 0 and `next_level` 500 starts level 500 on
  first launch. Every other field is clamped and checked; this pair is not.
- **Impact:** a hand-edited file can skip the game. Local only, nothing leaves the phone, so Low.
  A level that comes from `next_level.json` is checked for format and generator version but not
  for solvability (there is no solver at boot), which is the same kind of local-only gap.
- **Evidence:** `test_f4`.

### F9. Note: the test runner's time budget is one global 1800 game seconds, counted in frames

`tests/run_tests.gd` stops the whole run after 1800 game seconds, and `--fixed-fps 60` makes a
game second 60 frames however fast the frames are. A loop that waits for a worker thread by
spinning frames runs tens of thousands of frames a second (an idle frame takes microseconds), so
one wait of a second of real time costs several game minutes. My first version of the new tests,
which used the existing `FlowCase.until`, pushed the full run over the limit ("TIMED OUT after
1800 s" in `test_qa4_modes`); by my count the suites that run before mine (app, audio and the
Phase 2 bot tests) had already used about 1000 game seconds. My helper `QaFlowCase.until` sleeps
10 ms between frames, and my suites now use about 80 game seconds in all. Suggestion for the
lead: raise `TIME_LIMIT` (done: it is now 3600 game seconds), or make `FlowCase.until` sleep, because the next suite that waits for
a generated level will hit the same wall.

### F10. Note: the first full run after a new `class_name` file can fail to load a suite

My first `bash tools/test.sh` after the working tree gained `src/render/title_board.gd` failed
`render/test_views.gd` with "Identifier TitleBoard not declared" (a parse error, "could not load
the suite"); `bash tools/test.sh render` passed straight after. The import step in the script
did not register the new class on the first pass. A second import fixes it. Low, but a trap for
anyone running tests right after pulling.

## 7. What is not covered, and ideas for later

- Not checkable here: items 29 and part of 31 need a person; so do the feel of motion and sound
  and a phone's own timing. The phone-side items (gesture bar, notch, the real back button) need
  the APK on a device; the windowed pictures only approximate them.
- The windowed script draws pictures but no test compares them. A screenshot test of the clear,
  out of room and stuck sheets and the top bar at 360 x 800 would have caught F1, F6 and F7;
  that needs a window, so it belongs in a script run before each phase gate, not in `test.sh`.
- A bot that retries and buys helpers would let the star economy (item 20) be measured for Hard
  and Expert.
- `acceptance.gd` could join `tools/levels` as the per-tier gate report, since it is the
  per-tier table the GDD asks for.
