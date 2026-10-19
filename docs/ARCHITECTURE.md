# WoodLogic architecture

The contract every area builds against. The rules themselves are in docs/GDD.md (rule ids R1
to R38, B1 to B13, G1 to G7, S1 to S9); screens, sizes and words are in docs/UX.md; the look
and motion timings are in docs/DESIGN.md. Where UX.md and DESIGN.md give different numbers,
UX.md wins for sizes and layout and DESIGN.md wins for motion and color. If you need something
here changed, ask the lead. Status: Phase 2.

## 1. Areas and how they depend on each other

```
src/logic/   pure rules, solver, generator, seeds, level catalog   (level-engine-dev)
src/render/  drawing: planks, screws, boxes, tray, board, icons     (graphic-designer)
src/level/   the level scene: input, animation, timer, helpers      (gameplay-dev)
src/ui/      every other screen, the app flow, links, Godot Theme   (ui-dev)
src/save/    progress, settings and stats on the phone              (ui-dev)
src/audio/   synthesized sound and music, the Audio autoload        (audio-dev)
src/app/     the main scene, which hands over to the app flow       (lead)
data/        blueprints, tutorial levels, tuning numbers            (game-designer)
```

- **logic** depends on nothing but the engine's core types and `WorkerThreadPool` (no Node,
  no scene tree, no physics, no rendering, no autoloads, no files outside `res://data/` and
  `res://src/logic/`). Everything else may depend on it.
- **render** depends on nothing in the game except its own `Looks` and `Palette` and plain
  values passed in. It never reads the logic model or an autoload.
- **level** depends on logic, render and the Audio autoload. It gets everything else (helper
  counts, the star bank, settings) from the app flow through section 6.
- **ui** depends on everything except level internals; it talks to the level scene only
  through section 6.
- No area reaches into another's private members (names starting with `_`).

## 2. Units, coordinates and precision

- **Grid units (gu)** are the logic's units: integers in data, 1 gu = 4 design units (du). The
  board core is 86 x 90 gu (344 x 360 du), origin top left, x right, y down.
- **Angles** are degrees, positive clockwise on screen (from +x toward +y), as in GDD R16, in
  the range (-180, 180].
- The 0.25 and 0.75 margins around R16's cutoff (below) hold for authored blueprints and
  tutorial levels too, since they can be shown as authored; the blueprint validator checks
  them.
- **Design units (du)** are layout units: the base viewport is 360 x 640 du (CLAUDE.md).
- The level scene draws the core at `4 * b` du per gu, where b is UX's board scale (1.0 to
  2.0, UX 3.2.1a). Hit testing converts the touch point back to gu and tests there, so touch
  targets scale with the board.
- **Precision, so every phone agrees.**
  - The logic computes in GDScript `float` (64 bit) and `int`. `Vector2` and
    `PackedVector2Array` are 32 bit, so they appear only at the API edge for the view, never
    inside a rule.
  - Every vertex the logic uses (flattened arcs and turned outlines alike) is rounded to
    1/1024 gu as soon as it is made.
  - Centroids, distances and covering are computed from rounded vertices using only + - * /
    and `sqrt` (which IEEE 754 makes exact to the last bit on every phone).
  - A rest pose is built from the pivot-to-centroid unit vector (a rotation by its cosine and
    sine taken as ratios), never from `sin`, `cos` or `atan2`. `atan2` is used only to report
    the angle to the view.
  - Every threshold a rule or a generator check compares against has a margin: B10 and B11
    for covering, and R16's 0.5 gu "doesn't turn" cutoff, which the generator only accepts
    with r below 0.25 or above 0.75.

## 3. Data formats

All JSON, UTF-8, no comments. Godot parses every JSON number as a float, so a reader that
wants an integer checks the value is whole and in range. Every reader validates types and
ranges: a data file that fails is an error (and a test failure); a save file that fails means
defaults. No reader ever decodes objects (`str_to_var`, `bytes_to_var` with objects, or
`load()` on user files).

Folders are read by listing them, keeping names that end in `.json` (in an exported build,
also `.json.remap` with the suffix removed), sorted by name.

### 3.1 Blueprints: `data/blueprints/<id>.json`

Exactly GDD 9.1, checked by rules B1 to B13 (a test in tests/logic runs the validator on every
file). Adding, removing or changing a blueprint changes which level a number gives, so after
the first release it needs a new `GENERATOR_VERSION` (section 5).

### 3.2 Tutorial levels: `data/tutorial/tutorial-<n>.json`

Exactly GDD 9.3 (`id` "tutorial-n", `kind` "tutorial", with `colors`, `queue`, `tray_par`,
`par_time`, `line`, `hint`). n is 1 to 8. Numbered level n is tutorial level n while that file
exists.

### 3.3 Tuning: `data/tuning.json`

The designer's numbers, so tuning never needs a code change. The logic and the app flow read
them through `Tuning`; nobody hardcodes them.

```json
{
  "format": 1,
  "tray_size": 5, "open_boxes": 2, "box_slots": 3, "preview": 2,
  "tutorial_levels": 8,
  "tiers": [{"tier": 1, "group": "easy", "screws": [9, 12], "colors": [2, 3], "layers": [1, 2],
             "tray_uses": [0, 0], "novice": "win", "covered_pct": [0, 20]}],
  "sawtooth": {"steps": [-2, -1, 0, 1, 2], "bases": [[9, 2], [21, 3], [36, 4], [56, 5], [81, 6], [111, 7], [151, 8]]},
  "tray_par_slack": [[9, 2], [31, 1], [101, 0]],
  "par_time": {"base_s": 10, "per_screw_s": {"easy": 3.0, "medium": 3.5, "hard": 4.0, "expert": 4.5}, "round_to_s": 5},
  "daily": {"tier": 6, "tray_par_slack": 1, "group": "medium"},
  "relaxed": {"easy": [1, 3], "medium": [4, 6], "hard": [7, 8]},
  "helpers": {"undo": {"price": 4, "first_level": 8, "free": 2},
              "extra_slot": {"price": 6, "first_level": 15, "free": 2},
              "screwdriver": {"price": 8, "first_level": 25, "free": 2}},
  "unlocks": [{"what": "wood", "id": "walnut", "level": 10}, {"what": "metal", "id": "copper", "best_streak": 3}],
  "modes_open_after_level": 8,
  "recent_blueprints_excluded": 5
}
```

The example is abridged; the real file lists all ten tiers and every unlock from the GDD. The
numbers the generator reads count toward `GENERATOR_VERSION`.

### 3.4 Saves: `user://progress.json` and `user://settings.json`

Owned and written by src/save. Written safely (a temporary file, then rename) whenever
something worth keeping changes: a level result, a helper spent, bought or given, an unlock,
a setting, and on pause or focus loss. Read with type and range checks; a missing or broken
file means defaults, and a broken file is kept once as `<name>.bad`.

`progress.json`:

| Field | Type | Meaning |
|-|-|-|
| `format` | int | save format, starts at 1; an older format is migrated on load, never dropped |
| `next_level` | int | the level Play continues at (at least 1); Play always goes here, even after quitting a replay |
| `highest_cleared` | int | the highest numbered level cleared (0 at first) |
| `star_bank` | int | stars to spend |
| `stars_earned` | int | every star ever earned, for Stats ("total stars"); spending never lowers it |
| `levels` | object | key = level number as a string; value `{"stars": 0..3, "best_ms": int, "gen": int}` (`gen` is the generator version it was last cleared on) |
| `helpers` | object | `{"undo": int, "extra_slot": int, "screwdriver": int}` owned counts |
| `helpers_met` | array of strings | helpers whose first-time explanation was shown and free gift given |
| `daily` | object | `{"last_date": "YYYY-MM-DD" or "", "streak": int, "best_streak": int, "solved": int, "days": {"YYYY-MM-DD": {"stars": 0..3, "best_ms": int}}}` |
| `relaxed` | object | `{"next": {"easy": int, "medium": int, "hard": int}, "last_band": "easy" or "medium" or "hard" or ""}`; `next` is the stream index of the next relaxed level per band, moved on when a relaxed level is cleared |
| `stats` | object | `{"cleared": int (numbered levels cleared at least once, so replays do not add), "three_star": int, "helpers_used": int, "time": {"easy": {"n": int, "total_ms": int, "best_ms": int}, "medium": ..., "hard": ..., "expert": ...}}`; every win of a numbered level (first clear or replay) or a daily counts in `time`; tutorial and relaxed levels do not |
| `unlocked` | object | `{"wood": ["oak", ...], "metal": ["steel", ...]}` |

`settings.json`: `{"format": 1, "sound": bool, "music": bool, "symbols": bool, "wood": string,
"metal": string}`, defaults true, true, true, "oak", "steel". A chosen wood or metal that is
not unlocked (after a progress reset) reads as the default.

- **Updates never cost progress.** Records are keyed by level number and never deleted or
  recomputed when the generator changes. A replay of an old level uses the current generator;
  its stars only ever add (S5).
- Mid-level state is never saved (Bart, Hard Stop 1): coming back restarts the same level.
- `Save` reads its files only when the app flow calls `Save.load_all()` at boot, never in
  `_ready`, so the test runner can point it elsewhere first.

## 4. The logic model (src/logic/)

Plain classes (`RefCounted`), statically typed, with `class_name`. Names below are the
contract; private helpers are the engine developer's choice.

### 4.1 Level data

- `LevelData`: one level. **Read-only once built**: GDScript can't enforce it, so nothing
  outside the code that builds it ever writes to its fields or arrays. That makes it safe to
  hand from a worker thread to the main thread.
  - `planks: Array[PlankData]`, `screw_colors: PackedInt32Array` (palette index per screw),
    `queue: PackedInt32Array` (one color per box, in order), `tray_size: int`,
    `tray_par: int` (the slack already added), `par_time_s: int`, `line: String`,
    `hint: PackedInt32Array` (screw ids).
  - `kind: int` (`BLUEPRINT` for a bare blueprint with no colors yet, `TUTORIAL`, `NUMBERED`,
    `DAILY`, `RELAXED`), `number: int` (the level number, the date as yyyymmdd, or the relaxed
    stream index), `band: String` (relaxed only), `tier: int`, `group: String`,
    `blueprint_id: String`, `generator_version: int`. A blueprint also has `id`, `name` and
    `blueprint_kind`. `geometry` is its `BoardGeometry`, built once.
  - `static func from_json(text: String) -> LevelData` (null and an error on bad data),
    `static func parse(text: String, errors: PackedStringArray) -> LevelData` (the same, but
    quiet: problems go in `errors`, nothing is logged), `from_dict`, `to_dict() -> Dictionary`,
    and `with_colors(...)`, which returns a new level on the same planks with colors and a
    queue. Small read helpers: `screw_center`, `screw_plank`, `layer_count`, `color_count`,
    `screw_count`, `has_colors`.
- `PlankData`: `layer: int`, `shape: int` (`BAR`, `POLY`, `DISC`, `RING`), the shape's fields
  in gu, `screws: PackedInt32Array` (screw ids, one per hole, in hole order),
  `holes: PackedVector2Array` (gu, for the view), `outline() -> PackedVector2Array` (the
  authored outline in gu, the same polygon the logic and the renderer use; arcs flattened as
  GDD 1.2 says; for a ring, `inner_outline()` is the hole).
- **Screw ids** are 0 to n-1 in file order: plank 0's holes, then plank 1's, and so on.
- `Geom` (outlines, signed distance, centroids, all in float64 and rounded to 1/1024 gu) and
  `BoardGeometry` (every possible pose of every plank and what it covers, as bit masks,
  worked out once per board).

### 4.2 Play state

`PlayState`: the rules. One per attempt; used on one thread only.

```
static func start(level: LevelData) -> PlayState
func tap(screw: int) -> TapResult              # R11 to R25
func use_screwdriver(screw: int) -> TapResult  # R31
func use_extra_slot() -> TapResult             # R30
func undo() -> TapResult                       # R26 to R29
func status() -> int                           # PLAYING, WON, LOST
func is_on_board(screw: int) -> bool
func is_free(screw: int) -> bool
func cover_plank(screw: int) -> int            # frontmost plank covering it, or -1
func destination(screw: int) -> Vector2i       # (BOX, position) or (TRAY, slot) or (NONE, -1); works for covered screws too
func plank_state(plank: int) -> int            # FIXED, HANGING, FALLEN
func plank_pose(plank: int) -> Vector3         # pivot x, pivot y (gu), angle (degrees)
func plank_outline(plank: int) -> PackedVector2Array   # current pose, gu
func open_box(position: int) -> Vector2i       # (color or -1, screws in it 0..3)
func box_screws(position: int) -> PackedInt32Array   # the screw in each filled well, in order
func preview() -> PackedInt32Array             # the next colors in the queue, up to `preview`
func tray() -> PackedInt32Array                # per slot: screw id or -1 (5 or 6 slots)
func tray_uses() -> int
func helpers_used() -> PackedStringArray       # helpers used this attempt, each name once
func extra_slot_used() -> bool
func can_undo() -> bool
func snapshot() -> Dictionary                  # the rule state undo restores, for tests
func level() -> LevelData
```

- The logic never waits, animates or sleeps. Every call resolves completely (R13, R14).
- **Which calls work when.** `PLAYING`: all of them. `LOST`: `undo`, `use_extra_slot` and
  `use_screwdriver` work (R29, R37); `tap` returns `NOT_PLAYING`. `WON`: every action returns
  `NOT_PLAYING`. Every successful action runs the win and loss checks (R22 to R24), so an
  action that starts at `LOST` ends with either `RESUMED` or a fresh `LOST` event, never
  neither (a Screwdriver or an Undo can leave the board still lost).
- `helpers_used()` records "undo" only when an undo actually took something back,
  "extra_slot" and "screwdriver" when they succeeded. Extra slot can't be undone (R27).
- `plank_pose()`: for `FIXED`, pivot (0, 0) and angle 0 (the authored pose). For `HANGING`,
  the pivot screw's center and the rest angle (a plank that turns half way round reports 180).
  For `FALLEN`, the pose it had when it fell.
- `cover_plank()` picks the frontmost layer; within one layer, the lowest plank index.
- `snapshot()` holds everything an undo restores, including the tray's length, and leaves
  out helpers used and the Extra slot flag, which undo never takes back (R27). So a tap then
  an undo gives back an equal snapshot.
- Relaxed uses the same `PlayState`. "Can't be lost" is the screens' job: on `LOST` they offer
  the free Undo instead of the out of room sheet.

### 4.3 Tap results and events

`TapResult`: `ok: bool`, `reason: int`, `events: Array[LogicEvent]`.

| `reason` | When |
|-|-|
| `NONE` | it worked |
| `GONE` | the screw is no longer on the board (a double tap), or the id is out of range |
| `COVERED` | the screw is covered (the view wiggles `cover_plank(screw)`) |
| `REFUSED` | no destination (R25, or a Screwdriver with nowhere to go, R31) |
| `NOTHING_TO_UNDO` | undo with an empty history (nothing is spent) |
| `ALREADY_USED` | Extra slot a second time this attempt |
| `NOT_PLAYING` | not allowed in this status (above) |

`LogicEvent` fields: `kind: int`, `screw: int`, `plank: int`, `position: int`, `slot: int`,
`well: int`, `color: int`, `angle: float`, `screws: PackedInt32Array`.

| Kind | Fields used | Meaning |
|-|-|-|
| `SCREW_TO_BOX` | screw, position, well (0..2) | a screw leaves the board for a box well |
| `SCREW_TO_TRAY` | screw, slot | a screw leaves the board for a tray slot |
| `PLANK_SWUNG` | plank, screw (pivot), angle | a plank goes down to one screw and hangs at this rest angle (sent with angle 0 when it doesn't turn, R16) |
| `PLANK_FELL` | plank | a plank loses its last screw |
| `COVER_CHANGED` | screws | these screws changed between free and covered; the view asks `is_free()` |
| `BOX_CLOSED` | position, color | a full box closes and leaves |
| `BOX_ARRIVED` | position, color | the next queue box takes the position (or `color` -1: it stays empty) |
| `TRAY_TO_BOX` | screw, slot, position, well | a tray screw jumps into the new box (R20) |
| `TRAY_EXTENDED` | slot | the Extra slot opened |
| `UNDONE` | screw, screws | an undo put `screw` back; `screws` lists every screw whose place changed, `screw` included. The view replays the move backwards for `screw` and tweens everything else to the state |
| `WON` / `LOST` / `RESUMED` | | the status changed (`RESUMED`: a loss was cleared) |

**Canonical order within one action** (logic tests assert it):

1. `SCREW_TO_BOX` or `SCREW_TO_TRAY` (the screw leaves and lands; R13 steps 2 and 4 are one
   event, because the logic has no time in between).
2. `PLANK_SWUNG` or `PLANK_FELL`, if its plank changed.
3. `COVER_CHANGED`, if any screw changed.
4. While a box is full: `BOX_CLOSED`, `BOX_ARRIVED`, then one `TRAY_TO_BOX` per jumping screw
   in tray order (R18 to R21; this repeats on a cascade).
5. `WON` or `LOST`.

An Extra slot is `TRAY_EXTENDED`, then `RESUMED` or `LOST` if it started at `LOST`. An undo is
`UNDONE`, then `RESUMED` or `LOST` likewise. A Screwdriver removal follows the tap order, with
`RESUMED` after step 4 when it cleared a loss. A failed action has `ok` false and no events.

### 4.4 Solver, generator, seeds, catalog

**Nothing that decides what a level is may depend on time.** Budgets are counts. Wall-clock
milliseconds are measured only for reports.

- `Solver.solve(level: LevelData, max_states: int) -> SolveResult`: `solved: bool`,
  `complete: bool` (false if it stopped at `max_states`), `fewest_tray_uses: int`,
  `solution: PackedInt32Array` (screw ids), `states: int`, `novice_won: bool` (GDD 6.4),
  `trap: float` (the engine's trap measure), `ms: int` (report only). A level whose search
  did not complete is never shown. The search explores moves in a fixed order (by screw id),
  so a search stopped at `max_states` stops at the same point on every phone. The visited set
  is keyed on an exact packing of the rule state, not a hash number, so two states can never
  be confused. The key leaves out which tray slot and which box position holds what: tray
  counts per color follow from the key, same-colored tray screws are interchangeable, and
  R12's tie between two boxes only happens when they are identical. A rule that makes slots
  or positions matter must change the key too.
  `Solver.explore` and `Solver.search_only` are for tests and tools only.
- `Generator.GENERATOR_VERSION: int` (starts at 1).
  `Generator.make(kind: int, number: int, band: String) -> GeneratedLevel`: `level`, `solve`,
  `attempts: int`, `fell_back: bool`, `gen_ms: int` (report only). It tries a fixed sequence
  of attempts derived from the seed, each solved with a fixed `max_states`, and falls back
  after a fixed number of failed attempts. The same kind, number, band and version give the
  same level on every phone and PC.
- **Blueprint choice (G7) is a pure function** of (kind, number, version): computing level N
  never needs any other level to be generated. For numbered levels it guarantees no blueprint
  repeats within 5 levels (for example a seeded deal per block of levels, arranged so the
  join between blocks doesn't repeat either, filtered by which blueprints suit the tier).
  Retries stay within the chosen blueprint (other variations of it); when they run out, the
  level falls back. Fallback levels are exempt from G7. Each relaxed band applies the same
  rule along its own stream index (GDD 6.6), and the daily along its day count; the streams
  don't affect each other.
- `Seeds`: `numbered(n) -> int`, `daily(year, month, day) -> int`, `relaxed(band, index) ->
  int`, each mixing in `GENERATOR_VERSION` with our own integer hash. The hash keeps every
  value in 32 bits: it multiplies only by constants below 2^31 (so a product stays below
  2^63) and masks with `& 0xFFFFFFFF` after every step, so it never overflows and never uses
  `hash()`. Randomness only through a `RandomNumberGenerator` with its `seed` set from these.
- **A golden test** in tests/logic pins a fingerprint (blueprint, colors, queue, tier) of a
  fixed set of levels (numbered 9 to 40, a few dailies and relaxed levels). Any change that
  alters them fails the test until `GENERATOR_VERSION` goes up and the fingerprints are
  renewed.
- **Fallback levels** are known-good levels per tier, generated by the engine developer's tool
  and stored as JSON in `src/logic/fallback/` (level-engine-dev).
- `LevelCatalog.load_all()` reads `Tuning`, every blueprint and every tutorial level, on the
  main thread at startup (the app flow's boot, and the test runner). After that they are
  read-only, so worker threads can read them freely.
  `LevelCatalog.get_level(kind, number, band) -> GeneratedLevel`: the tutorial file for
  numbered levels 1 to 8, otherwise the generator.
- `LevelPrefetcher` (owned by the app flow, which polls it every frame):
  - `request(kind, number, band)` starts `LevelCatalog.get_level` on `WorkerThreadPool` unless
    that key is already done or running. Keys are strings like `"numbered:42"`,
    `"daily:20261019"`, `"relaxed:easy:7"`.
  - `poll()` (called each frame) checks `WorkerThreadPool.is_task_completed`, then calls
    `wait_for_task_completion` to collect it.
  - `is_ready(key) -> bool`, `take(key) -> GeneratedLevel` (removes it from the cache; null
    if not ready, and the app flow shows the board a moment later when it is).
  - `shutdown()` waits for every running task; the app flow calls it before quitting.
  - The app flow asks for level N+1 as soon as level N starts.
- `Stars.award(level: LevelData, won: bool, elapsed_ms: int, tray_uses: int, helpers_used:
  PackedStringArray) -> Vector3i` (cleared, fast, clean as 0 or 1), per GDD S1 to S8, and
  `Stars.par_time`.
- `Tuning`: `data/tuning.json`, validated, loaded by `LevelCatalog.load_all()`. Its values are
  static and written only then, at boot; after that everyone, worker threads included, only
  reads them.

### 4.5 tools/levels

`C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s
res://tools/levels/levels.gd -- --from=1 --to=100 [--daily=2026-10-19] [--out=build/levels]`
writes `report.md` (per level: kind, tier, blueprint, screws, colors, layers, fewest tray
uses, novice result, trap, attempts, fallback, generation ms, solve ms) and one small PNG per
level drawn into an `Image`, plus a timing summary (median, 95th percentile, worst).

## 5. Rules that keep logic and view in step

1. The logic decides; the view animates. The view never computes a rule, a rest angle or a
   destination. It reads them from `PlayState` and the events.
2. Input is never blocked by animation. A tap is hit tested against the logic's current state
   (`plank_outline`, `is_on_board`, `is_free`), not against where a plank happens to be drawn
   mid swing. Animations retarget to the newest state.
3. The level scene offers `debug_snapshot() -> Dictionary` (screw id to drawn center in gu,
   plank id to drawn outline in gu, box and tray contents) and `set_instant(on: bool)` (every
   animation jumps to its end, so tests run fast). A test in tests/level plays many generated
   levels and checks after every tap that the snapshot matches `PlayState`.
4. **Generator versions.** `GENERATOR_VERSION` goes up whenever a change would alter any level
   a number gives: generator code, blueprints, the tuning numbers it reads, the palette count,
   an engine upgrade that changes `RandomNumberGenerator`. The golden test catches it. Saves
   keep records by level number, so nothing is lost.

## 6. The level scene and the screens

`src/level/level_scene.tscn` (root `LevelScene`, gameplay-dev). ui-dev's app flow creates it
and talks to it only through these.

```
func play(level: LevelData, replay: bool) -> void
func retry() -> void
func pause() -> void                                   # covers the board, stops the clock
func resume() -> void
func hold_clock(on: bool) -> void                      # stops the clock with the board still visible (the buy dialog, helper sheets, S6)
func handle_back() -> bool                             # true if it handled Back (e.g. leaving Screwdriver mode)
func set_star_bank(stars: int) -> void
func set_helpers(counts: Dictionary, shown: PackedStringArray) -> void
	# counts {"undo": n, ...}; shown = the helper buttons on screen (none before level 8;
	# only "undo" in Relaxed, where it is free and unlimited and shows no count)
func highlight_helper(helper: String) -> void          # the ring and arrow after a first-time sheet (UX 3.13.1)
func use_helper(helper: String) -> void                # after "Get and use" was bought (R38), or from Out of room
func usable_after_loss() -> PackedStringArray          # owned helpers that can clear this loss (R37)
func set_instant(on: bool) -> void                     # tests only
func debug_snapshot() -> Dictionary                    # tests only

signal won(result: LevelResult)          # after the last screw has landed (about 0.5 s after the winning tap)
signal lost(level: LevelData)            # after the last move settles; the screen shows Out of room (or Relaxed's stuck sheet)
signal pause_requested
signal helper_used(helper: String)       # a helper took effect; outside Relaxed the screen takes one from the save
signal helper_buy_requested(helper: String)  # tapped with count 0; the screen asks "Get and use"
signal first_action                      # the clock started
```

`LevelResult`: `level: LevelData`, `replay: bool`, `elapsed_ms: int` (taken at the winning
tap, S6), `tray_uses: int`, `helpers_used: PackedStringArray`, `stars: Vector3i` (from
`Stars.award`).

The app flow (src/ui) owns which screen shows; shows each helper's first-time sheet before the
level that introduces it, then calls `highlight_helper`; records results, spends and gifts in
the save; applies unlocks; owns and polls `LevelPrefetcher`; and handles the Android back
button (asking `handle_back()` first) and the lifecycle. In Relaxed, `helper_used("undo")`
counts in `stats.helpers_used` but takes nothing from the save (GDD 6.6).

## 7. Renderers and looks (src/render/)

Node2D classes the level scene and screens compose. They take plain values, draw in local du,
and never hold game state.

- `PlankView.setup(outline_gu: PackedVector2Array, inner_gu: PackedVector2Array, layer: int,
  holes_gu: PackedVector2Array, grain_seed: int)`; the parent places and rotates it.
  `wiggle()` plays the covered-tap wiggle. `bake()` draws the still plank into a texture
  (DESIGN.md performance plan); the level scene calls it for every plank while the board is
  hidden (behind the level clear screen or before the first frame), never mid play.
- `ScrewView.setup(color: int, size: int)` (`BOARD`, `WELL` or `TRAY`, sized per UX.md),
  `set_covered(covered: bool)`, `set_turn(degrees: float)` (the highlight moves as it turns),
  `set_lift(amount: float)` (0 in its hole, 1 fully out; the head and its shadow for the
  unscrew and the flight).
- `BoxView.setup(color: int, preview: bool)` (a preview box is the closed queue look),
  `set_count(n: int)`, `set_lid(open: float)` (0 closed, 1 open), `close()`.
- `TrayView.setup(slots: int)`, `set_warning(on: bool)` (one free slot left, a steady state,
  never blinking), `set_full(on: bool)`.
- `BoardView` (the back board and its shadows); icon drawing in `Icons`.
- `Palette`: `COLORS` (the nine screw colors, in DESIGN.md's order), `symbol(color: int)`
  drawing data, `color_name()`. The logic only knows color indices.
- `Looks`: `wood(id: String) -> Dictionary` and `metal(id: String) -> Dictionary` (shader
  parameters), `WOODS` and `METALS` (ids in unlock order), and `static var current: Dictionary`
  (`{"wood": id, "metal": id, "symbols": bool}`). The app flow sets `Looks.current` from the
  settings at boot and when Settings changes; screens and the level scene rebuild their views
  then. Renderers read only `Looks.current`, never `Save`.

## 8. Autoloads

Registered by the lead in project.godot:

| Name | Script | Owner | Purpose |
|-|-|-|-|
| `Save` | src/save/save.gd | ui-dev | progress and settings, `settings_changed` and `progress_changed` signals, `load_all()` |
| `Audio` | src/audio/audio.gd | audio-dev | one call per effect (`Audio.play("ratchet")` and so on), music, `set_sound(on)` and `set_music(on)`, which the app flow calls from the settings |

The logic and the renderers use no autoload.

## 9. Tests

- Suites live in `tests/<area>/test_*.gd` (CLAUDE.md). Logic tests name the GDD rule they
  check (for example `test_r20_tray_jumps_in_tray_order`).
- Tests never touch the player's real saves: the runner points `Save` at
  `user://test_<process id>/` before anything loads and deletes it after the run. Tests never
  open a link: the runner replaces the opener in `Links` and clears it before quitting (a
  lambda left in a static variable crashes the engine on quit). The runner calls
  `LevelCatalog.load_all()` once before the suites.
- `tests/app/` checks the whole repo: the license header on every source file, no network
  classes, and no `OS.shell_open` outside src/ui/links.gd.
- src/directions/ (the Hard Stop 1 mock-ups) is excluded from exports until Phase 4 removes
  it.
