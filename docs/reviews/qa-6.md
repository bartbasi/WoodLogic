# QA report 6: the Phase 6 full review

Reviewer: qa-tester. Build: HEAD 53011c0 ("Phase 5: a smaller tray by level and generator
version 6"), clean working tree, generator version 6. I read PROMPT.md section 18 and the GDD
(sections 0 to 12), UX (3.2.2, 3.4, 3.6, 3.13, 4) and ARCHITECTURE (10, 11); nothing from PROMPT.md
is copied here. I wrote only in `tests/bots/` and this file and committed nothing.

## 1. Summary

**After the fix round (section 9): every finding below is fixed or accepted (H4 deep replays accepted by Bart, 22 October 2026). Open: the H5 note only. Counts below are as found at HEAD 53011c0.**

- **Full suite at HEAD: 586 passed, 0 failed; after the fix round: 629 passed, 0 failed.** (`bash tools/test.sh`.) My first full run found 4 failures: two were
  my new tests tripping the repo scan for network words (they spelled the words out), and two were
  other suites failing because one of my new tests left the symbols and sound switches off for them
  (shared engine state). Both were my tests' fault and are fixed (finding list below has no entry
  for them); a test that changes engine-wide state now puts it back in `QaFlowCase.cleanup`.
- **GDD 12 acceptance list: 40 items. 37 pass, 1 cannot be checked headless for lack of a human
  model (20), 1 needs a person (29), 1 is the fun checklist, which is part person and part test
  (31).** Section 3.
- **Definition of done (PROMPT 18): every item that can be checked here passes**, with two notes
  (H1, H2 in ASSETS.md) and one miss against the generation budget (H4). The phone items are
  steps for Bart (section 7). Section 4.
- **Levels 1 to 1000: all solved with a complete search, made twice identically, 1330 of 1330
  levels (with 30 Dailies and 100 Relaxed per band), first tap fits a box on all.** Fallback rate
  4 percent past level 100; worst time 2.8 s on this PC. Section 4.
- **No Critical and no High finding.** 2 Medium (H3, H4), 6 Low (G1, G2, G3, G4 carried; H1, H2
  new), 1 note (H5, release files not written yet).
- The new hunts found one real defect: pressing the Home tab on the title throws a script error
  (H3). A 1000 level session shows nothing growing, and a 1000 move fuzz of the whole app found
  nothing else.

| Severity | Count | Findings |
|-|-|-|
| Critical | 0 | |
| High | 0 | |
| Medium | 2 | H3 the Home tab on the title throws a script error; H4 a replay or Previous level made on demand takes up to 2.6 s |
| Low | 6 | G1 gift paid by a replay (docs disagree); G2 three notes push Replay off the clear screen; G3 badges do not count up to the gift; G4 a Relaxed hard level the novice wins; H1 ASSETS.md says five image files, there are twelve more in docs/; H2 `looks.gd` missing from ASSETS.md |
| Note | 1 | H5 docs/store/privacy-policy.md and docs/release.md do not exist yet (Phase 7) |

## 2. What I ran

```
bash tools/test.sh
godot --headless --path . -s res://tools/levels/levels.gd -- --from=1 --to=1000 --daily=2026-10-23 --days=30 --relaxed=100 --no-png --repeat --out=build/qa6/levels
godot --headless --path . -s res://tests/bots/acceptance.gd -- --per-tier=100 --g7=9-300 --random-games=2 --peaks=9-400
godot --headless --path . -s res://tests/bots/long_session.gd -- --levels=1000 --every=50
Godot_v4.7.2-stable_win64.exe --path . -s res://tests/bots/qa_windowed.gd       # 10 window sizes, windowed
```

New in `tests/bots/` this round: `test_qa6_update.gd` (a Phase 4 save loaded into this build, with
the fixture files in `tests/bots/fixtures/phase4/`, which the Phase 4 build's own `Save` wrote),
`test_qa6_edges.gd`, `test_qa6_defs.gd` (the definition of done), `test_qa6_fuzz.gd`,
`test_qa6_findings.gd`, `long_session.gd`. The code reviewer's nit is fixed: `qa_windowed5.gd` now
sets `Links.opener = Callable()` before it quits.

## 3. The GDD 12 acceptance list at HEAD

Pass, fail or cannot check headless, with the evidence. "Session" is `BotSession` in `tests/bots/`:
after every action it works out the rules again from outside (R7 from the outlines, R10, R12, R13
and R18 to R24, the events and their order, R16, undo) and compares with the engine.

| # | Item | Result | Evidence |
|-|-|-|-|
| 1 | R7 to R9 covering, E1, ring hole, same layer | Pass | tests/logic; the session's own R7 check after every action of the bot games (below), no mismatch |
| 2 | R10 on generated levels | Pass | `acceptance.gd` at HEAD: 1000 generated levels (100 a tier), 2000 random games with R10 checked in every state |
| 3 | R12 destination order, E7, leftmost slot after a gap | Pass | tests/logic; the session predicts every screw's destination at every state |
| 4 | R13 order, plank drop plus box close | Pass | `test_r13_one_tap_drops_a_plank_and_closes_a_box_in_order`; the session compares whole event lists |
| 5 | R16 rest angles, disc at its center | Pass | tests/logic; the session checks every hanging plank's centroid is straight below its pivot |
| 6 | R17 a fallen plank never covers | Pass | tests/logic; fallen planks are left out of the session's covering test and agree |
| 7 | R18 to R21, E4, E5, queue that runs out | Pass | tests/logic; the session's own box and queue model matches |
| 8 | I1 after every tap of 1000 generated levels (random bot) | Pass | `acceptance.gd`: 1000 levels, 2 games each, I1 checked after every action |
| 9 | R22 and R23, E6, win before loss | Pass | tests/logic; the session recomputes the status |
| 10 | R25 refused tap changes nothing and does not start the clock | Pass | tests/logic and tests/level; `test_refused_taps_leave_the_state_alone`; the fuzz and chaos suites |
| 11 | R26 to R29 undo | Pass | tests/logic; tap, undo, tap on 14 levels; undo all the way back; now also at the loss moment on 3 slot trays (`test_qa6_edges.gd`) |
| 12 | R30 and R31 | Pass | tests/logic; the chaos bot; Extra slot at a loss on 3 slot trays |
| 13 | R34 Retry identical, resets clock, tray uses, Extra slot | Pass | `test_acc_13_retry_gives_an_identical_level...` (4 slots, 5 with Extra, 4 after Retry) |
| 13a | R36 killed app restarts the level; new install opens level 1 | Pass | `test_acc_13a...`; a write killed before its rename (a `.tmp` left behind) leaves the old save in charge; closing during level generation |
| 13b | R37 the sheet shows exactly the owned usable helpers | Pass | `test_acc_13b...` (6 cases, 3 slot trays) |
| 13c | R38 buy only on a tap, never in Relaxed | Pass | `test_acc_13c...` for each of the three helpers at price minus one and at the price; one message, not two (qa-5) |
| 13d | R35a map: cleared replays, next plays, locked plays nothing | Pass | `test_a_locked_map_node...`; level 250,000 |
| 13e | R36a Pause, Settings, menus, Back to level unchanged | Pass | `test_acc_13e...` on the real scene; symbols and looks changed while paused now reach the board |
| 14 | Blueprints pass B1 to B13, id is the file name | Pass | `test_b1_to_b13...`; `test_acc_14...` (43 files) |
| 15 | Tutorials valid, solvable, no reachable loss, fewest 0 | Pass | tests/logic; the random bot won every run on all 8 |
| 15a | tuning.json matches the GDD | Pass | `test_acc_15a...` (tier table 6.1), `test_acc_21...` (sawtooth, 6.8 JSON), `test_acc_19...` (prices, gifts), `test_qa5_acceptance.gd` (tray and least peak) |
| 16 | S2 and S6 Fast at par, clock waits, stops in pause and dialogs | Pass | tests/logic, tests/level; buy dialog stops the clock; menus do not count |
| 17 | S3 Clean lost by one tray use or any helper | Pass | tests/logic; `test_acc_16_17...` |
| 18 | S5 replays add only the difference | Pass | `test_acc_18...` |
| 19 | Prices 3, 5, 8; 2 free on levels 8, 15, 25 once only | Pass | `test_acc_19...` (data and GDD text), the helper sheets on each level |
| 20 | Bot data per band matches section 5 within a factor of 1.5 | Cannot check here | the economy needs a model of how a person earns stars and buys; the bots give ceilings and floors (qa-5 section 5), not stars per level. Phase 4's bands passed for Easy and Medium and failed for Hard and Expert (qa-4); the Phase 5 estimates of 6.8 are unmeasured. Not a defect |
| 21 | tier(N) for 9 to 30 and 100 to 110 | Pass | `test_acc_21...` against the GDD's list and a formula worked out in the test |
| 22 | 100 generated levels per tier pass G1 to G7, G9a on 7 and 8, with the report | Pass | `acceptance.gd`: every check passed except the Relaxed G4 case (G4); fallback 0 to 4 percent a tier |
| 22a | G8, `suits_tier`, at least 8 boards before the skips and 6 after | Pass | `test_acc_22a...` |
| 22b | Tray per tier and level, G10, the skip lists | Pass | `test_qa5_acceptance.gd`; `acceptance.gd` over numbered levels 9 to 400 (the true least peak) |
| 22c | Gifts at 50 and 100 once, prices | Pass, with G1 and G3 | `test_qa5_flow.gd`; a gift after a reset is the gift again, not doubled (`test_qa6_edges.gd`) |
| 23 | Novice wins every tier 1 to 3 level, loses every tier 7 to 10 level | Pass, with G4 | 100 levels a tier; the only exceptions are two Relaxed hard levels (52, 92) |
| 24 | No level over 36 screws, 8 colors, 5 layers, 24 free at start | Pass | `acceptance.gd` (also 16 planks, 3 planks deep) |
| 25 | Free screws 48 du apart on the solution path | Pass | `acceptance.gd`, 1000 levels |
| 26 | Daily tier 6, same twice, after level 8, streak rules | Pass | `test_acc_26...` (3 slots, slack +1, month, year and leap day ends, the clock moved back, the same day twice); F3 accepted, F8 designed |
| 27 | Relaxed ranges, no stars, free Undo, stuck sheet | Pass | `test_acc_27...` (5 slots); five Undos on the real scene; the stuck sheet fits the screen |
| 28 | Each unlock at its milestone, survives a restart | Pass | `test_acc_28...` |
| 29 | Level 1 in under 30 s by a new player, no text | Cannot check here | needs a new player; level 1 is 3 screws, par 30 s, the hand points at all three |
| 30 | Breather after each hard level from 21; 9 to 20 climb | Pass | `test_acc_30...` |
| 31 | The fun checklist | Partly | the items a test can check pass (qa-4 section 4, unchanged); look, feel and fairness need a person |

## 4. The definition of done (PROMPT section 18)

| Item | Result | Evidence |
|-|-|-|
| Debug and release builds install and run on the phone at 60 fps | Cannot check here | Steps in section 7. The PC is not a phone. Debug and release presets exist, ask for no permissions, `version/code=1` |
| Play follows the approved GDD | Pass | section 3 |
| Every level shown has been solved; levels 1 to 1000 generate within budget | Pass, with H4 | below |
| Logic and view agree after every tap | Pass | `test_the_picture_agrees_with_the_rules_after_every_tap_on_generated_levels` (15 levels from 9 to 199, 330 taps, compared after each tap and settled); tests/level; the chaos suite with animations on; the 1000 level session |
| Stars, helpers, themes, Daily, Relaxed, Stats work and survive closing and updating | Pass | `test_qa6_update.gd`: a Phase 4 save written by the Phase 4 build (level 45, 7 stars spent, helpers, walnut and brass, a 5 day streak, Relaxed positions, sound and symbols off, a saved level from generator 5) loads with nothing lost and no `.bad` file; the app starts, keeps symbols off and the looks, refuses the old saved level, plays level 46 (3 slots, the shrink line once), writes the save back with the old fields intact, survives closing, and the Daily streak goes 5 to 6; stats and themes survive a restart |
| Effects and music synthesized in code, both toggles persist | Pass | tests/audio; `test_the_sound_and_music_switches_reach_the_audio_system_and_survive_a_restart`; every sound named in ASSETS.md |
| Colorblind symbols on by default; contrast and colorblind scripts pass | Pass | `test_colorblind_symbols_are_on_by_default_everywhere` (fresh Save, level 1 screws, the Settings switch reads On); `tests/render/test_colors.gd` (three simulations, every pair of screw colors, symbols big enough, text contrast) is green in the full run |
| About shows feedback, source, coffee with its statement, privacy, License, Credits | Pass | `test_about_shows_everything_the_definition_of_done_lists`: the buttons, the fixed Supporting and Privacy sentences equal CLAUDE.md's word for word, the attribution line, the NOTICE and GPL on the License page, Godot on Credits; coffee hidden removes the block and uses the store wording |
| The release export requests no permissions; no network code | Pass | `test_no_network_code_and_no_android_permission_anywhere` (export presets: no `permissions/*=true`, no custom permissions; no network or process classes in src, tools or tests; only `links.gd` hands an address to the phone) and tests/app |
| docs/ASSETS.md shows everything is made in code | Pass, with H1 and H2 | `test_docs_assets_names_every_shader_render_and_audio_file_and_every_sound` and `test_every_file_in_the_repo_is_code_or_text_except_the_five_icon_pngs`: every shader, every `src/render` and `src/audio` script except `looks.gd` (H2) and every sound is named; no image, audio, font or model file outside the five icons (the docs folder aside, H1) |
| QA, security and code reviews show no open Critical or High | QA: yes | no Critical or High here; the other two reviews are not mine |

**Levels 1 to 1000** (`build/qa6/levels/report.md`): 1330 levels made (1 to 1000, 30 Dailies, 100
Relaxed per band), **all solved with a complete search, none differed when made twice, the first tap
fits a box on all**, 0 problems. Per range of numbered levels, on this PC (a phone is several times
slower; the Fold5 timing build of Phase 4 measured about the same as this PC):

| Levels | Made | Fell back | Generation ms: median | 95th | worst |
|-|-|-|-|-|-|
| 1 to 8 (stored) | 8 | 0 | 1 | 2 | 2 |
| 9 to 20 | 12 | 0 | 10 | 50 | 59 |
| 21 to 49 | 29 | 0 | 43 | 351 | 575 |
| 50 to 99 | 50 | 2 (4%) | 244 | 1063 | 2017 |
| 100 to 199 | 100 | 3 (3%) | 242 | 1556 | 2573 |
| 200 to 499 | 300 | 12 (4%) | 253 | 1692 | 2812 |
| 500 to 1000 | 501 | 25 (5%) | 249 | 1560 | 2753 |

The medians (under 300 ms) meet the budget. The tails do not (H4). The report's tier table has the
rest: fallbacks by tier (tier 9: 6 percent, 10: 3, 7: 7 of 30), tray and least peak by tier, the
true least peak, W (wrong taps the tray can take) of 0 on every level from 100 on.

## 5. New edge-case hunts

| Hunt | What I did | Result |
|-|-|-|
| The shrunken tray with Undo and Extra slot at the loss | 3 slot levels from 25 to 150, random play to a loss, then Extra slot (4th slot, loss cleared, EXTENDED then RESUMED, not twice), Undo (keeps the 4th slot, R27), play on to a second loss (Extra spent, Undo still works), Retry (3 slots, nothing used); every rule checked by the session | Pass, 0 violations |
| The gifts with a reset | gift at 49, reset from Settings, the same walk again | Pass: the second gift is 2 Undos and 1 Extra slot again, not 4 and 2; the record starts over |
| The clock moving backwards for the Daily | qa-4 tests re-run at HEAD (month, year, leap day, skipped day, earlier date) | Pass; earlier dates pay their own stars once (F3, accepted) and never move the streak; a clock set far ahead locks the streak until its date (F8, as the GDD words it) |
| The app killed mid-flight | the flow freed while a deep level is being made, then a new start; a write that died before its rename (`.tmp` files beside a good save); focus lost mid-level, then a restart; a 700 move fuzz | Pass: the old save is read, no problem is reported for the leftover file, the next save goes on from it |
| A very long session | `long_session.gd`: the real flow and level scene, a quick player solving levels 1 to 1000 by the solver's line with a pause and a tour of every menu every 100 levels | Pass in 797 s (0.8 s a level, slowest 3.0 s at level 326): engine nodes 126 early, 120 late; objects 3678 and 3674; orphans 0; resources 91; static memory 49.7 MB then 50.0 MB; the save file grows 62 bytes a level (63 KB at level 1000), as the records do |
| Rotation, fold and unfold | the windowed run at 240 x 427, 320 x 568, 360 x 640, 360 x 922 (folded), 412 x 915, 533 x 640 (unfolded), 1200 x 1920 and 1280 x 720 (landscape), coffee shown and hidden; resizes in the middle of a move in the chaos and fuzz suites | Pass: no button under 48 units, none off screen except the scrolling About pages, the level, Pause, clear and Out of room screens fit every size, the landscape layout puts the boxes and tray beside the board. The project locks portrait (`orientation=1`), so on the phone the app should not rotate: step 6 in section 7 |
| A fuzz of the whole app | 1200 random actions on the real scene (presses on whatever buttons show, Back, focus out and in, starting levels, Daily, Relaxed, resizes, taps), the flow checked after each | One defect: the Home tab on the title (H3). With that press left out, nothing else |

## 6. Findings

### H3. Medium: pressing the Home tab on the title throws a script error

- **Steps:** open the app on any save past level 8 (the title shows) and tap the "Home" tab in the
  dock. (Or `bash tools/test.sh` after making a test press it: the runner fails on the logged error.)
- **Expected:** UX 1.6: "Tapping the active tab scrolls that screen's body back to the top and
  does nothing else."
- **Found:** `SCRIPT ERROR: Invalid assignment of property or key 'scroll_vertical' with value of
  type 'int' on a base object of type 'previously freed'` at `src/ui/menu_screen.gd:112`
  (`scroll_to_top`). On the title the screen's `scroll` node is a freed object, so
  `_on_tab` (line 105) assigns to it. The tap does nothing visible, but it logs an error every
  time and a debug build would stop in the debugger. The fuzz found it within 100 moves.
- **Fix hint:** `TitleScreen` should override `scroll_to_top` (nothing to scroll) or guard
  `is_instance_valid(scroll)`.
- **Evidence:** `test_h3_...` in `tests/bots/test_qa6_findings.gd` checks the cause (the freed
  node) without pressing the tab, because a logged error fails any test. `STRICT := true` there
  makes it fail until fixed.

### H4. Medium: a level made on demand can take 2.6 s

- **Steps:** with a save past level 300, tap a cleared level on the map (replay), or lose and tap
  Previous level, or open the Daily or the first Relaxed level of a band. The "One moment" screen
  shows while the level is made.
- **Expected:** PROMPT's budget is 300 ms to make and solve one level on a mid-range phone, and
  UX 3.6 says a replay starts "at once".
- **Found:** this PC: level 326 2.5 s, 730 2.6 s, 144 2.4 s, 316 1.7 s; over the whole report the
  95th percentile is 1.5 to 1.7 s from level 50 on and the worst 2.8 s (3.3 s on tier 10 in the
  100 per tier run). The medians (240 to 250 ms) are inside the budget. The Fold5 timing build in
  Phase 4 measured the same range (tier 8: 95th percentile 1.4 s). A normal player never waits,
  because level N + 1 is made while N is played; a replay, Previous level, the Daily and Relaxed are
  made when asked for.
- **Ideas for the designer and engine developer:** raise the prefetch to the replay candidates
  (the nodes next to the player's level), prefetch the Daily and each Relaxed band while the title
  shows (the title already asks for the Daily and Relaxed), or store known-good levels for the
  hardest tiers so the on demand path has a bound.
- **Evidence:** `test_h4_...` in `tests/bots/test_qa6_findings.gd` (prints the times);
  `build/qa6/levels/report.md`.

### H1. Low: ASSETS.md says five image files; docs/ holds twelve more

`docs/ASSETS.md` says the five icon PNGs "are the only image files in the repo". `docs/design/`
holds 12 more PNGs (`nordic-*.png`, `toybox-*.png` and the workshop screenshots of the Hard Stop 1
mock-ups). They are screenshots of our own mock-ups, they are kept out of the build (the export
presets exclude `docs/*`, and `docs/.gdignore` keeps them out of the import), and nothing in the
game loads them. The sentence should say "in the game" or the pictures should be said to be
documentation. `test_every_file_in_the_repo_is_code_or_text_except_the_five_icon_pngs`.

### H2. Low: `src/render/looks.gd` is not in ASSETS.md

Every other shader and `src/render` and `src/audio` script is named. `looks.gd`, which defines the
woods and metals (oak, walnut, maple, cherry, ebony; steel, brass, copper, black), is not, so the
themes are the one visual the assets list does not explain. `test_docs_assets_names_every_...`.

### Carried from qa-5 (re-rated)

- **G1, Low** (unchanged): a due gift is paid by a replay clear (the code follows UX 3.13.4; GDD 5
  says "never on a replay"), and the GDD says "with the helper sheet" where UX and the code show a
  plaque. A document fix.
- **G2, Low** (unchanged): a save that is due two unlock notes and the gift shows three notes and
  pushes Next and Replay off a 360 x 640 clear screen. Rare (an older or edited save).
- **G3, Low** (unchanged): the helper badges do not count up to the gift on the next level (UX
  3.13.4); they show the new count at once.
- **G4, Low** (down from Medium): two of 100 tier 8 Relaxed levels (hard 52 and 92) are ones the
  novice wins as played, because the generator measures the novice on the tier's 3 slots while a
  Relaxed level has 5. Relaxed cannot be lost and is meant to be calm, so no player is hurt and
  nothing the GDD promises to a player is broken; the stored `novice_won` and `novice_taps` just do
  not describe the level shown.

### H5. Note: the release files are not written yet

`docs/store/` holds only `.gitkeep`: there is no `docs/store/privacy-policy.md` (CLAUDE.md requires
it, published with GitHub Pages) and no `docs/release.md`; README has no "Releasing" section.
Both presets carry `version/code=1`, `version/name=""` and empty `min_sdk` and `target_sdk`, so
Google Play's current target level and a rising version code are for Phase 7. None of it is in the
PROMPT 18 list, so this is a note.

## 7. Phone checks for Bart

I cannot run these. Each says what to do and what a pass looks like. The ones marked (lead) are the
lead's to do with the build and the tools.

1. **60 fps (lead or Bart).** Install the debug APK (`adb install -r build/woodlogic-debug.apk`),
   play level 40 or later (a tier 6 or 7 board with many planks) for two minutes, then run
   `adb shell dumpsys gfxinfo io.github.bartbasi.woodlogic framestats` (reset first with
   `adb shell dumpsys gfxinfo io.github.bartbasi.woodlogic reset`, play, then dump). Pass: the
   "Janky frames" share is under 5 percent and the 90th percentile frame time is under 16.7 ms. Also
   watch by eye during a plank falling, a box closing with a cascade, and the clear screen's
   shavings. Do it once on a 3 slot level and once on level 12 as the tray closes.
2. **An update over the previous build keeps progress (Bart).**
   a. Install the Phase 4 build (or keep the one on the phone) and play to a state you can read:
   the level number, the star bank, the helpers you own, a theme you chose, the Daily streak,
   Relaxed positions, sound and symbols switches.
   b. Install this build over it with `adb install -r` (same package, same debug signing key, so
   nothing is uninstalled; do not uninstall first). A build signed with another key will refuse to
   install over it and asking to uninstall would erase the save.
   c. Open it. Pass: the title shows your star bank; Map shows your levels with their stars; Stats
   shows the same numbers; the helpers, the theme, the streak, the Relaxed positions and the
   switches are as they were. Press Play: the level is your next one and is made new (it may differ
   from what the old build would have shown), with 3 slots from level 21, and the shrink line
   ("The tray is smaller now. Every slot counts.") shows once, at the first level that has a smaller
   tray. If you were past level 50, the first clear shows the level 50 gift, once.
   d. Force-stop the app and open it again: the same state. Then install the same APK a second time
   (`-r` again): the same state.
   e. Check `version/code`: it is 1 in both presets, so a store update needs a higher number first.
3. **The back button and gesture (Bart).** On the title: Back leaves the app. In a level: Back
   opens Pause; Back again resumes. In Pause: Back resumes. In Settings opened from Pause: Back
   returns to Pause; "Back to level" returns straight to the level. On the clear screen and Out of
   room: Back goes to the title. Map, Stats, Info, Settings and About: Back goes to where you came
   from. License and Credits: Back goes to About. The reset dialog: Back closes it and erases
   nothing. With the Screwdriver on: Back leaves the mode, not the level. Try both the three button
   bar and the gesture (and, on Android 14 or later, the back preview animation: the game should
   not leave while you are in a level).
4. **Pause on app switch (Bart).** In a level with the clock running: press Home, wait ten seconds,
   come back. Pass: the Pause screen is showing, the board is covered, the timer did not run. Then
   Resume. Repeat with the recent apps switcher, with the screen off and on, with the notification
   shade pulled down, and with an incoming call or alarm. Repeat during "One moment" (a level being
   made), on the clear screen and on Out of room (they should stay as they are). Tap the coffee cup
   in the top bar: Pause shows first, the browser opens, coming back shows Pause on the same level.
5. **Kill and restart (Bart).** Swipe the app away in the middle of a level, open it: the title
   shows (or, on a brand new install, level 1); Play starts the same level from the beginning. Do it
   once just after clearing a level (stars and the next level kept) and once during the clear
   animation.
6. **Rotation, fold and unfold (Bart).** Turn the phone sideways in a level and in a menu: the app
   stays upright (it is locked to portrait). Fold and unfold the Fold5 in the middle of a level, in
   Pause and on the map: the layout changes size (360 x 922 folded, 533 x 640 unfolded) with the
   board, tray and boxes intact and the level not restarted. Try the split screen and a different
   Display size and Font size in Android settings: nothing should be cut off.
7. **Permissions and network (lead).** `aapt dump permissions build/woodlogic-debug.apk` (and the
   release build) should list no `uses-permission`. Settings, Apps, WoodLogic, Permissions should
   say "No permissions requested". Airplane mode makes no difference to anything.
8. **Sound (Bart).** With the ringer on silent and the media volume up, sound plays (the game uses
   media audio); switching Sound off in Settings silences effects at once; Music off stops the loop
   and the setting is still off after closing the app. Plug in headphones mid level: nothing
   changes. Take a call: audio stops and returns.
9. **The Daily and the date (Bart).** Solve the Daily; set the phone's date one day later: a new
   Daily, the streak goes up. Set it back to today: nothing is lost, today's Daily is solved, the
   streak does not go down. Set the clock a month ahead and back (the streak will not count until
   the real date passes it: this is by design, F8).
10. **A long session (Bart).** Play for 20 minutes across levels 12 to 30 and some Relaxed. Pass:
    no slowdown, no heat that makes it hard to hold, the app is still in memory when you return
    (`adb shell dumpsys meminfo io.github.bartbasi.woodlogic` before and after: Total PSS should not
    climb by more than a few tens of MB; on this PC a 1000 level session stayed flat at 50 MB).
11. **A deep replay (Bart).** On the map, scroll to a cleared level past 100 and tap it: note how
    long "One moment" shows (H4). Compare with Next from a level you just cleared (instant).
12. **First launch (Bart).** Clear the app's data and open it: level 1 starts at once with the hand
    pointing at the first screw, no title, no coffee cup, no timer. The first clear is level 1
    with three stars; at level 4 the cup and the timer appear.

## 8. Files

New: `tests/bots/test_qa6_update.gd`, `test_qa6_edges.gd`, `test_qa6_defs.gd`, `test_qa6_fuzz.gd`,
`test_qa6_findings.gd`, `test_qa6_fixes.gd` (fix round), `long_session.gd`, `fixtures/phase4/` (three files written by the Phase 4
build). Changed: `qa_flow_case.gd` (restores the looks and audio switches after each test; a faster
way to start with a deep save), `qa_windowed.gd` (loses the Out of room step until it is lost),
`qa_windowed5.gd` (the code reviewer's nit).
## 9. Fix round (after the lead's Phase 6 fixes, uncommitted tree on top of 53011c0)

Sections 1 to 8 describe HEAD 53011c0 as I found it. This section is the same build after the fix
round (generator version 7, `GenerationStop`, the new prefetcher, the clear screen and menu
changes). **Every finding is now fixed or accepted; none is open except the H5 note.**

| Finding | Was | Now | Evidence |
|-|-|-|-|
| H3 Home tab on the title | Medium | **Fixed** | `scroll_to_top` does nothing on a screen with no scroll area. `test_h3_the_active_tab_scrolls_to_the_top_and_does_nothing_else` presses the active tab on the title (Home), the map, Stats, Info, Settings and About; the screen stays as it was and no error is logged (the runner fails on one). The fuzz no longer skips Home and its three seeds (1200 moves) are clean |
| H4 made ahead (Previous level, Next, the Daily, the next Relaxed level) | Medium | **Fixed** | `test_h4_levels_made_ahead_start_at_once`: on a save at level 800, after 14 s, Previous level (800), Next (802), the Daily and the next level of each Relaxed band all start in the same frame (Previous level 5 ms), with no "One moment" |
| H4 a deep replay | Medium | **Accepted by Bart, 22 October 2026** | `test_h4_a_deep_replay_still_waits_and_that_was_accepted` prints the wait: level 326 107 ms, 730 1352 ms, 144 150 ms, 316 57 ms on this PC (they were 1.7 to 2.6 s before; the levels differ now under generator 7). The test only checks the level starts. It prints no OPEN FINDING |
| G1 gift paid by a replay | Low | **Fixed (documents agree)** | GDD 5 and 22c now say the gift is paid on the next numbered clear, a replay included, and UX 3.13.4 says never repeated. `test_g1_...` now asserts that: a replay of level 30 on a save past 50 pays the gift once, a second replay pays nothing |
| G2 three notes push Replay off | Low | **Fixed** | the notes scroll in one plaque; `test_g2_...` (strict) finds Replay and Next on the screen at 360 x 640 with the gift and two unlock notes due |
| G3 badges do not count up | Low | **Fixed** | `test_g3_...` (strict) sees the Undo badge show more than one value on level 50 |
| G4 Relaxed hard novice | Low | **Fixed** | generator version 7 makes Relaxed its own pools, measured at 5 slots. `test_g4_...` (strict) is clean for Relaxed hard 1 to 6, 52 and 92. New `test_qa6_fixes.gd`, below |
| H1 twelve PNGs in docs/ | Low | **Fixed (one nit)** | ASSETS.md now says the screenshots in docs/design/ are documentation, left out of the exports. The icon row still says the five icons "are the only image files in the repo"; it reads true for the game, so a nit |
| H2 `looks.gd` not in ASSETS.md | Low | **Fixed** | row "Wood and metal themes" added; `test_docs_assets_names_every_...` (now strict) passes |
| H5 release files | Note | Still open, Phase 7 | `docs/store/` holds only `.gitkeep`; no `docs/release.md` |

**Open findings after the fix round: Critical 0, High 0, Medium 0, Low 0, Note 1 (H5).** The
three findings suites (`test_qa5_findings.gd`, `test_qa6_findings.gd`, and the H1 and H2 checks in
`test_qa6_defs.gd`) now run with `STRICT := true` where a finding was fixed, so a return fails the
suite. The full run prints no "OPEN FINDING" line; the one line that mentions a finding is the deep
replay timing, which says "accepted".

### New checks

- **Relaxed levels as played** (`test_relaxed_levels_hold_the_novice_and_g9a_rules_as_they_are_played`):
  82 levels (easy 1 to 20, medium 1 to 20, hard 1 to 40, plus hard 52 and 92), each solved again as
  played with Relaxed's 5 slots. Every one has 5 slots; the novice bot, a fresh solve and the stored
  solve agree about whether the novice wins; tier 1 to 3 levels are won and tier 7 and 8 levels are
  lost by the novice; G9a holds as played on all 42 tier 7 and 8 levels (2 of the 82 were fallbacks
  and held too). 39 of the 82 are won by the novice (the easy and part of the medium levels), as the
  tiers say.
- **The Relaxed pools** (`test_the_relaxed_pools_are_made_and_measured_with_five_slots`): every tier
  that needs a pool has at least 3 stored levels (files `relaxed-03` to `relaxed-08`), each stored
  with 5 slots, with the novice result its tier needs and G9a where it applies; three per tier are
  solved again and agree.
- **Quitting during a long generation** (`test_stopping_a_prefetch_in_the_middle_of_a_tier_10_generation_returns_fast`,
  `test_quitting_the_app_while_a_tier_10_level_is_being_made_returns_within_a_second`): six tier 10
  levels asked for urgently, stopped 250 ms later while still being made (6 of 6 were still being
  made): the slowest `shutdown()` took 22 ms, and no stopped level is handed out. The app quit while
  tier 10 levels were being made (three of them) returned each time inside the 1 s limit.

### Numbers after the fix round (generator version 7)

- **Levels 1 to 1000** (same command as section 2, `--out=build/qa6/levels7`): 1330 of 1330 solved
  with a complete search, 0 differed when made twice, first tap fits a box on all, 0 problems, 880 s.
  Generation: median 116 ms, 95th percentile 1474 ms, worst 2407 ms (was 2812 ms).

| Levels | Made | Fell back | Generation ms: median | 95th | worst |
|-|-|-|-|-|-|
| 1 to 8 | 8 | 0 | 1 | 2 | 2 |
| 9 to 11 | 3 | 0 | 10 | 27 | 27 |
| 12 to 15 | 4 | 0 | 6 | 13 | 13 |
| 16 to 20 | 5 | 0 | 26 | 174 | 174 |
| 21 to 49 | 29 | 0 | 34 | 130 | 263 |
| 50 to 99 | 50 | 2 (4%) | 302 | 936 | 1555 |
| 100 on | 901 | 45 (5%) | 223 | 1640 | 2407 |

  Relaxed hard (100 levels): the novice loses all 100, G9a holds on all 100, 3 fell back (3%),
  worst 1065 ms. Medium and easy: 0 fell back.
- **Acceptance run** (`acceptance.gd`, 100 a tier, numbered 9 to 400): "Every check passed". The
  old exception (Relaxed hard 52 and 92, G4) is gone. Fallback 0 to 5% a tier; true least peak equals
  the schedule on 100 and up (W is 0 there), 84% on 50 to 99, 76% on 21 to 49, unchanged.
- **A long session** (`long_session.gd --levels=300 --every=25`, 189 s): nothing grew (orphans 0,
  resources 93, engine nodes 151 early and 166 late, static memory 50.2 to 53.8 MB, a 300 level run
  being shorter than the 1000 level one of section 5, which stayed flat). A new line prints when the
  script ends: "4 ObjectDB instances were leaked at exit", all `AudioStreamWAV` and
  `AudioStreamPlaybackWAV`, which is a sound still playing when a headless script ends the engine. It
  did not show at HEAD and shows at 120 levels or more here. It cannot hurt a player (the process
  ends), so I rate it a note for the audio developer, not a finding.
- **The full suite** (`bash tools/test.sh`): 629 passed, 0 failed, no "OPEN FINDING" line and no failing test (the deep replay timing line says "accepted"). The 629 include the 4 new tests in `test_qa6_fixes.gd` and the rewritten findings suites.

### Phone checks that change

Step 11 of section 7 is now "note the wait on a deep replay; it was accepted". Add one check to
step 2: after installing over the previous build, open the app, wait about 15 s on the title, then
tap a cleared level on the map or Previous level from a lost level: Previous level should start with
no "One moment".
