# Code review, Phase 6: the whole codebase at 53011c0

By the code-reviewer, saved by the lead on 22 October 2026.

**Counts: Critical 0, High 0, Medium 3, Low 9.**

There are no Critical or High findings. The three Medium findings are all about when levels get
made in the background. The rest are Low cleanups.

This was a whole-codebase read. Every area named in the brief was covered:
- src/ui/app_flow.gd and the contract and lifecycle parts of src/level/level_scene.gd in full,
  and a sweep of the rest of src/level.
- src/save and src/logic as a whole, building on the earlier per-phase passes.
- src/render, src/audio and src/app through their hot paths.
- tests/run_tests.gd, tests/test_case.gd, tools/, export_presets.cfg and project.godot.

## The rules (all hold)

- **License header:** present and exact on every tracked .gd, .gdshader, .gdshaderinc and .sh
  file (after the `#!` line in shell scripts). There are no .py files.
- **Copyright line:** every one reads exactly "Copyright 2026 Play, Inc." with no other form
  anywhere.
- **No network code:** no HTTPRequest, HTTPClient, StreamPeer, WebSocket, PacketPeer, TCP or UDP
  server, ENet, OS.execute or create_process.
- **Links:** OS.shell_open appears only in src/ui/links.gd.
- **No main-thread waits in src:** OS.delay_* appears only in tests.
- **Static typing:** enforced by the project setting (untyped_declaration = error).
- **Plain writing:** no em dashes or double hyphens in comments. The only double hyphens are
  command-line arguments.
- **No debug leftovers:** no print, breakpoint, TODO or FIXME in src (timing.gd's prints are its
  purpose).

## Determinism (holds)

- **Nothing that decides a level reads the clock.** `Time` is used only for the report-only `ms`
  fields.
- **Every random number generator is seeded** from `Seeds` or a fixed value (generator.gd:212,
  numbered_schedule, the trap measure). No `hash()` and no unseeded `randi` or `randf`.
- **Dictionary order:** the only key walk whose order matters, generator.gd:1090, runs over keys
  our own code inserted in a fixed order.
- **The view agrees with the logic:** the snapshot and quick-play tests compare the scene with
  PlayState after every tap.
- **Saves are atomic:** writes go to a temp file, the write result is checked, then the temp is
  renamed over the real file.

## Medium

**M1. Boot prefetches fill the slow lane, and asking again with "urgent" can't move a queued
job ahead.**
- **Where:** src/ui/app_flow.gd:104-109 and src/logic/level_prefetcher.gd:40-49.
- **What happens:**
  - At boot (once Daily and Relaxed are open) the flow queues four low-priority jobs: today's
    Daily (tier 6) and the next Relaxed level of each band. The hard band runs at `HARD_BUDGET`
    3, about 1.3 s worst on this PC and several times that on a phone.
  - WorkerThreadPool runs low-priority jobs on only about 30 percent of its threads, so 2 on an
    8-core phone.
  - `request()` returns early for a key that is already queued, so a later urgent request (the
    player taps Relaxed Hard, or Daily) stays low priority behind the others.
  - Level N + 1, requested at low priority when N starts, also waits behind all four.
- **Failure:** a returning player taps Play right after launch and clears a quick level in 10 s.
  Next shows "One moment" for several seconds, because N + 1 hasn't started yet. Tapping Relaxed
  Hard at the title just after launch waits for the whole queue.
- **Fix, any of:**
  - Ask for the Daily and Relaxed levels only once the Play level and N + 1 are in hand.
  - Or ask for them when the Relaxed setup or Daily is opened.
  - Or make `request(..., urgent=true)` re-add a key that hasn't started yet at high priority.

**M2. Quitting waits for every level still being made.**
- **Where:** src/ui/app_flow.gd:1030 (`quit()`) and :81 (`_exit_tree`), calling
  `LevelPrefetcher.shutdown()` (level_prefetcher.gd:81-87).
- **What happens:** WorkerThreadPool jobs can't be cancelled, and `shutdown()` waits for all of
  them on the main thread.
- **Failure:** Back on the title soon after launch (with the M1 jobs, or a tier 7 or 8 level
  still running) leaves the game frozen on screen for as long as the longest job takes, several
  seconds on a phone, before it closes.
- **Fix:** a static abort flag that `Generator.make` checks between attempts. Set it in `quit()`
  and `_exit_tree` before `shutdown()`, and throw the results away. This is safe for determinism:
  a stopped job never hands out a level.

**M3. Relaxed "Another" always waits, because the next Relaxed level is never made ahead.**
- **Where:** src/ui/app_flow.gd:418 (`play_relaxed(_current.band)`) and :586-593 (`_begin`
  prefetches the next level for numbered levels only).
- **What happens:** only the first Relaxed level of each band is asked for (at boot). After a
  Relaxed clear, `record_relaxed` moves the band on, and the next index is made only when
  "Another" is tapped.
- **Failure:** every "Another" in the hard band shows "One moment" for seconds on a phone (tiers 7
  and 8 at HARD_BUDGET 3).
- **Fix:** in `_begin`, for a Relaxed level, request `relaxed_next(band) + 1` at low priority, as
  numbered levels do for N + 1. Use `_ahead_key` or a second key.

## Low

**L1. Buying a helper is two separate saves.**
- **Where:** src/ui/app_flow.gd:741-742: `Save.spend_stars(price)`, then
  `Save.add_helper(helper, 1)`, each a full write.
- **Failure:** if the app is killed between them, the stars are gone and no helper was added.
  The window is milliseconds, but the save layer has an atomic pattern for exactly this
  (`grant_gift`).
- **Fix:** a `Save.buy_helper(helper, price) -> bool` that does both in one write.

**L2. The whole progress file is written twice per helper use, on the main thread mid-level.**
- **Where:** src/ui/app_flow.gd:721-722 calls `take_helper` then `note_helper_used`, and each
  does a full write (save.gd:284-299 via `_progress_changed`, line 439).
- **Failure:** after a long season the file holds a record per level and up to 4000 days, so
  each write is a stringify plus a file write during play, which could drop a frame on Undo.
- **Fix:** one combined call, or mark the file dirty and write once at the end of the frame or
  on pause and clear.

**L3. Box views are created and freed during play.**
- **Where:** src/level/level_scene.gd:1731 (`_sync_previews`), and box arrivals make new
  BoxViews.
- **What happens:** each is a CachedDrawing that makes a SubViewport and renders a capture two
  frames later, and the closed boxes are freed. Nothing leaks, but there is steady node and
  render-target churn on every box close.
- **Fix:** recycle the box views (`reset_box` already exists).

**L4. Stale comments that contradict the current code:**
- src/level/level_scene.gd:12-13: "The looks are the placeholder views made in LevelViews until
  the real renderers are swapped in". The placeholders were deleted in Phase 4.
- src/level/level_scene.gd:1320: "Undo (Phase 4 wires the button)". It is wired.
- src/level/level_scene.gd:2146-2147: `debug_undo` says "as Phase 4's Undo button will. Tests
  only for now". The real Undo goes through `_run_helper`. Keep the test hook, but fix the
  comment.
- src/level/level_hint.gd:7: "Placeholder look".

**L5. Dead code.** src/ui/app_flow.gd:903-905, `show_title()` ("Kept for the Phase 3 callers"),
has no callers left in src or tests. Remove it.

**L6. `has_method` and `has_signal` guards hide contract breaks.**
- **Where:** src/ui/app_flow.gd:135, 450, 611, 615 and 661, and `_ensure_level_scene`'s
  conditional connects.
- **What happens:** ARCHITECTURE 6 and 12.2 require `refresh_looks`, `usable_after_loss`,
  `play_tray_closing`, `show_tray_note`, `set_coffee` and the helper and coffee signals, and the
  fake scene in tests has them. A rename on the level side would silently drop the feature
  instead of failing a test.
- **Fix:** call them directly, or assert once in `_ensure_level_scene`.

**L7. `Save.set_next_level` is for tests only but marks levels cleared.**
- **Where:** src/save/save.gd:151.
- **What happens:** it raises `highest_cleared` (which opens Daily and Relaxed and the level
  unlocks) with no level records, and nothing in src calls it (only tests/ui/test_flow.gd).
- **Fix:** mark it as tests-only in its comment, or move it into a test helper, so a future
  screen doesn't use it.

**L8. The title windmill keeps animating.**
- **Where:** src/render/title_board.gd:94 and :118.
- **What happens:** once `_turning` is on, the sails turn every frame for as long as the title
  is open, so the frame keeps rendering on the title. It's fine visually, but it costs battery
  on a screen a player may leave open.
- **Fix:** consider stopping it after one turn, or enabling
  `application/run/low_processor_mode` on menus.

**L9. Test isolation.**
- **Where:** tests/run_tests.gd resets `Links.opener` and `coffee_hidden_for_tests` per test,
  but not the Save autoload's in-memory progress or `Looks.current`.
- **What happens:** a suite that forgets `erase_all()` inherits the previous test's progress,
  and Looks carries over. Nothing fails today, but the result depends on order.
- **Fix:** call `Save.erase_all()` (the runner's temp folder) and reset `Looks.current` before
  each test.

## Checked and fine

- **App flow and level scene:**
  - A paused level kept alive behind the menus is woken by `_begin` (`resume` before `play`) and
    by `_force_unpaused`.
  - `refresh_looks` sets every view up again from the current state. A loss during Pause is kept
    and shown on Resume.
  - Helper sheets survive a focus loss. Back works per UX 4.2 on every screen.
  - Out of room helpers re-announce the loss when they don't clear it.
  - The Screwdriver works after a loss (R37) and its cancel brings the sheet back.
- **Save and the flow:**
  - Gifts are granted in one write before the clear screen, and refused once the list is full.
  - The shrink line is marked shown before it shows. The tray closing uses the real tray size.
  - `next_level` is clamped on load. A version 5 saved next level is refused cleanly.
- **Lifecycle:**
  - Pause, focus loss and close save everything and cover the board.
  - Audio suspends and resumes. Music renders on a worker thread and is waited for at quit.
  - The level clock uses `ticks_msec`, so changing the phone's clock can't affect it.
  - The Daily keeps the date it started on.
- **Bounded over a long session:**
  - LevelMarks is capped at 48, daily days at 4000 and gifts at 32.
  - The prefetch cache holds at most the abandoned and boot keys.
  - The map recycles its node pool. `_anims` and `_moves` are cleared each attempt.
- **Render and HUD hot paths:**
  - There are no per-frame allocations.
  - CachedDrawing and PlankView bakes count frames rather than awaiting. The HUD re-caches once
    a second for the timer.
  - The pegboard is one light full-screen pass. The screw shader cost was measured on the phone
    at Gate 2.
- **Export and project:**
  - Both presets ask for no permissions, and the timing preset now leaves out
    `tests/logic/fixtures`.
  - Version 0.1.0 and code 1 must go up for the release preset. That is a reminder, not a defect.

The suite was not rerun in this pass, because qa-tester was running long reports. The last full
run, at the Phase 5 tree this commit holds, was 567 passed, 0 failed.
