# WoodLogic architecture

The contract every area builds against. The rules themselves are in docs/GDD.md (rule ids R1
to R38, B1 to B13, G1 to G7, S1 to S9); screens, sizes and words are in docs/UX.md; the look
and motion timings are in docs/DESIGN.md. Where UX.md and DESIGN.md give different numbers,
UX.md wins for sizes and layout and DESIGN.md wins for motion and color. If you need something
here changed, ask the lead. Status: Phase 3 (section 10 says what Phase 3 builds).

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

### 3.5 Stored levels: `src/logic/fallback/tier-<NN>.json`

A stored level is `LevelData.to_dict()`: the tutorial format of GDD 9.3 (planks with
`colors`, `queue`, `tray_par`, `par_time`, `line`, `hint`) with `kind` "numbered", "daily" or
"relaxed", plus `number`, `tier`, `group`, `blueprint`, `generator` (the version that made
it) and `band`. A fallback file is `{"format": 1, "tier": t, "levels": [{"level": {...},
"solve": {...}}, ...]}`, one level per line, where `solve` is the stored `SolveResult`
(including `novice_taps` and `last_tray_use`). The test suite solves every stored level again
and replays its solution.

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
  an undo gives back an equal snapshot, unless the Extra slot opened in between: then the
  tray keeps its sixth slot, and a loss in the earlier snapshot may now be cleared.
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

- `Solver.solve(level: LevelData, max_states: int, max_tray_uses := -1) -> SolveResult`:
  `solved: bool`,
  `complete: bool` (false if it stopped at `max_states`), `fewest_tray_uses: int`,
  `solution: PackedInt32Array` (screw ids), `states: int`, `novice_won: bool` (GDD 6.4),
  `trap: float` (the engine's trap measure), `novice_taps: int` (the novice's taps before the
  loss, or n on a win), `last_tray_use: int` (the tap number, 1 to n, of the solution's last
  tray use; 0 if none), `ms: int` (report only). A level whose search
  did not complete is never shown. The search explores moves in a fixed order (by screw id),
  so a search stopped at `max_states` stops at the same point on every phone. The visited set
  is keyed on an exact packing of the rule state, not a hash number, so two states can never
  be confused. The key leaves out which tray slot and which box position holds what: tray
  counts per color follow from the key, same-colored tray screws are interchangeable, and
  R12's tie between two boxes only happens when they are identical. A rule that makes slots
  or positions matter must change the key too.
  With `max_tray_uses` set (the tier's top count), the search stops once that count is
  passed and `over_cap` is true. `Solver.explore`, `Solver.search_only` and
  `Solver.measure(level, result, with_trap := true)` (with false, only the novice is measured)
  are for tests and tools only.
- `Generator.GENERATOR_VERSION: int` (started at 1; 3 since Phase 2's review fixes; 4 since
  Phase 3's G9).
  `Generator.make(kind: int, number: int, band: String) -> GeneratedLevel`: `level`, `solve`,
  `attempts: int`, `fell_back: bool`, `gen_ms: int` (report only). It tries a fixed sequence
  of attempts derived from the seed, each solved with a fixed `max_states`, and falls back
  after a fixed number of failed attempts. The same kind, number, band and version give the
  same level on every phone and PC. Budgets are per tier: `max_states` per attempt is 20k for
  tiers 1 to 3, 30k for 4 and 5, 40k for 6, 60k for 7 and 8 and 80k for 9 and 10; a level gets
  at most 12 variations, 60 attempts and 1.2M states in all, then falls back. A tier in
  `Generator.SURVIVAL_TIERS` or `LATE_TRAY_TIERS` gets `G9_BUDGET` (2) times each, so 24, 120
  and 2.4M on tiers 7 and 8. Hard tiers color with intent:
  a planned solution that sends key screws to the tray (solvable by construction), or a deep
  opening (made safe only by the solver). Either way only a complete, solved search accepts a
  level, and it proves the fewest tray uses. A tier needing k tray uses only takes blueprints
  with at least 2k + 1 screws covered at the start (approved by Bart at Hard Stop 2). `level` is
  never null once `LevelCatalog.load_all()` has succeeded.
- **G9 (GDD 6.4.1).** G9a holds when the novice survives at least ceil(n / `SURVIVAL_DIVISOR`)
  taps (the divisor is 3); it is required on `SURVIVAL_TIERS` ([7, 8]). G9b holds when the last
  tray use p has p x `LATE_TRAY_PART` > n (the part is 3), or there is no tray use; it is
  required on `LATE_TRAY_TIERS` (empty for now). Both are reported on every tier. The novice
  plays each coloring before the search, so only colorings that pass G4 and G9a are searched;
  the rules are the same as checking after the search, only cheaper. The trap measure is made
  only for the level kept. Helpers for tests and tools: `survival_needed(screws)`,
  `survives(level, r)`, `late_tray(level, r)`, `g9_holds(tier, level, r)`, `budget_scale(tier)`;
  `GeneratedLevel` counts `short_survival` and `early_tray` in `rejections()`.
- **Blueprint choice (G7) is a pure function** of (kind, number, version): computing level N
  never needs any other level to be generated. For numbered levels it guarantees no blueprint
  repeats within 5 levels (for example a seeded deal per block of levels, arranged so the
  join between blocks doesn't repeat either, filtered by which blueprints suit the tier).
  Retries stay within the chosen blueprint (other variations of it); when they run out, the
  level falls back. Each relaxed band follows a 60-level schedule built at load: at each
  index the tier used least so far (seeded tie break), then the least-used blueprint for that
  tier not seen in the last 5, wrapping around without a repeat. The daily walks a seeded
  order of its pool along its day count. The streams don't affect each other.
- `Seeds`: `numbered(n) -> int`, `daily(year, month, day) -> int`, `relaxed(band, index) ->
  int`, each mixing in `GENERATOR_VERSION` with our own integer hash. The hash keeps every
  value in 32 bits: it multiplies only by constants below 2^31 (so a product stays below
  2^63) and masks with `& 0xFFFFFFFF` after every step, so it never overflows and never uses
  `hash()`. Randomness only through a `RandomNumberGenerator` with its `seed` set from these.
  `Seeds.date_of_day(days) -> int` gives the yyyymmdd of a day count.
- **A golden test** in tests/logic pins `LevelData.fingerprint()` (whole numbers only:
  blueprint, tier, tray par, par time, colors, queue, holes and the fields each plank's shape
  uses, exactly what `to_dict` writes; never an angle) of a
  fixed set of levels (numbered 9 to 40, a spread from 100 to 160 covering tiers 7 to 10, deep
  openings and fallbacks, three dailies and two relaxed levels per band). Any change that
  alters them fails the test until `GENERATOR_VERSION` goes up and the fingerprints are
  renewed; `tools/levels --golden` refuses to renew them at the same version.
- **Fallback levels** are known-good levels per tier, generated by the engine developer's tool
  and stored as JSON in `src/logic/fallback/tier-NN.json` (up to 8 per tier, one per line;
  level-engine-dev; format in 3.5). When a level's attempts run out the order is: the tier's
  own stored levels, then the closest attempt that was solved (preferring one that holds G9
  as its tier requires, then the most tray uses, then the novice result), then a neighboring
  tier's stored levels. Stored levels hold G9 for their tier. A stored level is picked among those whose blueprint's nearest planned use in
  the same stream is farthest away (beyond 5 either side whenever the pool allows;
  `Generator.neighbor_distances(kind, number, band)` plans blueprints only and makes no
  levels), and its colors are relabeled by a permutation seeded from the level's seed (the
  same map on screws and queue, so every rule outcome is unchanged). Two neighbors that both
  fall back can still share a blueprint. `LevelCatalog.read_fallback(dir, errors) -> bool`
  reads them quietly; a file that is broken or holds levels of another tier makes
  `load_all()` fail.
- `LevelCatalog.load_all() -> bool` reads `Tuning`, every blueprint, every tutorial level and
  the fallback levels, on the main thread at startup (the app flow's boot, and the test
  runner, which stops if it returns false or logs an error). A second call returns the
  first call's result without loading again. After that they are
  read-only, so worker threads can read them freely. Reading files goes through
  `LevelCatalog.read_text` and `json_files`, which handle exported `.remap` names.
  `LevelCatalog.get_level(kind, number, band) -> GeneratedLevel`: the tutorial file for
  numbered levels 1 to 8, otherwise the generator.
- `LevelPrefetcher` (owned by the app flow, which polls it every frame):
  - `request(kind, number, band, urgent := false) -> String` (the key) starts
    `LevelCatalog.get_level` on `WorkerThreadPool` unless that key is already done or
    running. `urgent` makes it a high priority task, for the level the player is waiting on;
    a task already running keeps its priority. Keys are strings like `"numbered:42"`,
    `"daily:20261019"`, `"relaxed:easy:7"`.
  - `poll()` (called each frame) checks `WorkerThreadPool.is_task_completed`, then calls
    `wait_for_task_completion` to collect it.
  - `is_ready(key) -> bool`, `take(key) -> GeneratedLevel` (removes it from the cache; null
    if not ready, and the app flow shows the board a moment later when it is).
  - `shutdown()` waits for every running task; the app flow calls it before quitting.
  - The app flow asks for level N+1 as soon as level N starts. At boot it asks for the Play
    level as urgent, and today's daily and the next Relaxed level of each band as normal,
    since those can't be fetched during an earlier level. It keeps the current and previous
    level's `LevelData`, so Retry and Previous don't make them again. Worst case on this PC
    is about 2 s for a numbered level (1.98 s, level 114, in the version 4 run of 1 to 350).
- `Stars.award(level: LevelData, won: bool, elapsed_ms: int, tray_uses: int, helpers_used:
  PackedStringArray) -> Vector3i` (cleared, fast, clean as 0 or 1), per GDD S1 to S8, and
  `Stars.par_time`.
- `Tuning`: `data/tuning.json`, validated, loaded by `LevelCatalog.load_all()`. Its values are
  static and written only then, at boot; after that everyone, worker threads included, only
  reads them. For the app flow it offers `TierSpec`, `tier_for_level`, `slack_for_level`,
  `par_time_for`, and the helper and unlock numbers.
- `LevelData.with_colors(colors, queue, errors, play := {})`: `play` sets the play fields
  (kind, number, band, tier, group, tray par, par time, line, hint, generator, blueprint, id,
  name) and shares the planks and geometry. Also `LevelData.from_planks`, `fingerprint`,
  `is_id`, and `PlankData.transformed` for variations (it moves the center only for discs
  and rings, the shapes that have one). The other public helpers in
  `Generator`, `LevelCatalog`, `GeneratedLevel` (report-only fields) and `LevelPrefetcher`
  (`key_for`, `is_running`) are for tests and tools.

### 4.5 tools/levels

`C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s
res://tools/levels/levels.gd -- --from=1 --to=100 [--daily=2026-10-19] [--out=build/levels]`
writes `report.md` (per level: kind, tier, blueprint, screws, colors, layers, fewest tray
uses, novice result, novice taps against the G9a need, last tray use, trap, attempts,
fallback with the blueprint it planned, generation ms, solve ms) and one small PNG per level
drawn into an `Image`, plus per tier the novice taps (median and least) and how many hold G9a,
the last tray use (median and latest) and how many hold G9b, a timing summary (median, 95th
percentile, worst) and the ten slowest levels. Other
options: `--days`, `--relaxed`, `--no-png`, `--repeat` (make every level twice and compare).
Two options write into the repo, for the engine developer only: `--fallback=K` rewrites
`src/logic/fallback/`, and `--golden` rewrites `tests/logic/golden_levels.json` (only after
`GENERATOR_VERSION` goes up). `--out` takes any path; keep it under `build/`.

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
- `TrayView.setup(slots: int)`, `set_filled(filled: PackedByteArray)` (1 for each slot that
  holds a screw, so the warning mark sits on the free slot), `set_warning(on: bool)` (one free
  slot left, a steady state, never blinking), `set_full(on: bool)`.
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
| `Save` | src/save/save.gd | ui-dev | progress and settings on the phone (below) |
| `Audio` | src/audio/audio.gd | audio-dev | one call per effect (`Audio.play("ratchet")` and so on), music, `set_sound(on)` and `set_music(on)`, which the app flow calls from the settings |

The logic and the renderers use no autoload.

`Save`'s public interface (Phase 3):

- Signals `settings_changed` and `progress_changed`. Variables `dir` (set by the test runner
  before `load_all()`), `sound`, `music`, `symbols`, `wood_id`, `metal_id`, and `problems`
  (what the last load found wrong).
- Files: `load_all()`, `save_all()`, `save_progress()`, `save_settings()` (all do nothing
  before `load_all()`), and `erase_all()` (memory and files, `.bad` and `.tmp` included).
- Progress: `next_level()`, `set_next_level(n)`, `highest_cleared()`, `star_bank()`,
  `stars_earned()`, `level_record(n)` (`{stars, best_ms, gen}` or `{}`), `progress_copy()`
  (a deep copy), and `record_win(level, elapsed_ms, stars: Vector3i) -> int` (the stars
  gained; saves at once). Stars per level only add, `best_ms` only improves, `next_level`
  moves to n + 1 only when n is at least `next_level`, and `stats` counts as 3.4 says.
- Settings: `set_sound(on)`, `set_music(on)`, `set_symbols(on)`, `set_look(wood, metal)`,
  `wood()` and `metal()` (an id that isn't unlocked reads as the default),
  `is_unlocked(kind, id)`.
- The saved next level (10.3): `write_next_level(key, level) -> bool`,
  `read_next_level(key, generator_version) -> LevelData` (null for anything it doesn't
  trust), `clear_next_level()`.

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

## 10. Phase 3: the first playable

What Phase 3 builds, so Bart can play the core loop on his phone at Playtest Gate 1 (PROMPT.md
Phase 3). Everything here builds toward the full contract above; Phase 4 adds the rest without
reworking it.

**Scope.** Numbered levels only (tutorial levels 1 to 8, then generated), with Retry and
Previous level. No stars shown, no helpers, no Daily, Relaxed, Levels list, Stats, Settings,
About, links or coffee button yet. The look is a plain placeholder.

### 10.1 Level scene (gameplay-dev)

- Section 6 in full, with these Phase 3 stubs: `set_star_bank`, `set_helpers`,
  `highlight_helper` and `use_helper` do nothing, `usable_after_loss` returns an empty list,
  and `helper_used` and `helper_buy_requested` are never emitted. No helper row. The clock
  runs (the result's `elapsed_ms`), and `LevelResult.stars` comes from `Stars.award` as usual,
  but no star is drawn.
- **Placeholder look.** Plain shapes and flat colors, drawn by private classes in
  `src/level/placeholder/` named `PlaceholderPlank`, `PlaceholderScrew`, `PlaceholderBox` and
  `PlaceholderTray`. They take section 7's `setup` arguments and offer its methods, and the
  level scene makes them in one place, so Phase 4 swaps in src/render's views there and
  nowhere else. Screws use DESIGN.md 3.2's nine colors plus a simple line symbol per color,
  so color is never the only signal (UX 7.4). Layout, sizes and the board scale follow UX 3.2
  and 3.2.1a, so the board grows on large and foldable screens.
- **Real motion.** The timings and feedback in UX 6.1 and DESIGN.md 9: the turn and flight,
  the box filling, closing and sliding away, the queue moving up, tray jumps in tray order,
  the plank swing to the logic's rest angle, and the fall (Godot physics or a tween, for looks
  only), the covered-screw wiggle and the refused-tap shake. Input is never blocked (section
  5.2).
- Section 5.3's `debug_snapshot()` and `set_instant()`, and a test in tests/level that plays
  generated levels tap by tap and checks the snapshot against `PlayState` after every tap.

### 10.2 Audio (audio-dev)

The `Audio` autoload, `src/audio/audio.gd`:

```
func play(effect: String, pitch := 1.0, volume_db := 0.0) -> void
func set_sound(on: bool) -> void
func set_music(on: bool) -> void      # Phase 3: stores the switch; music comes in Phase 4
```

Phase 3 effects, synthesized into `AudioStreamWAV` buffers by our own code (PROMPT.md 10):

| Name | When (UX 6.1) |
|-|-|
| `ratchet` | a screw starts to turn |
| `pop` | it comes free |
| `clink` | it lands in a box; tray jumps call it with a rising `pitch` |
| `clink_tray` | it lands in the tray (duller than `clink`) |
| `knock` | a plank falls (wooden) |
| `knock_dull` | a covered screw is tapped; a refused tap plays it at `pitch` 0.85; a button press at `pitch` 1.3 and `volume_db` -12 |

An unknown name logs an error. `play` adds its own small random changes in pitch and timing
(its own `RandomNumberGenerator`, never the logic's) and never clips; several effects can
sound at once. With sound off, `play` does nothing. Making all the buffers takes under 50 ms
on this PC. The rest of PROMPT.md 10's effects and the music come in Phase 4, including
`lid`, `tick` and `creak`, which the Phase 3 level scene stands in for with `knock` and
`knock_dull` at other pitches.

### 10.3 Screens, app flow and saves (ui-dev)

- `src/ui/app_flow.tscn` (root `AppFlow`) runs the app; `src/app/main.tscn` (lead) holds it.
  At boot it calls `LevelCatalog.load_all()` (a failure shows a plain "WoodLogic could not
  start" line and nothing else), `Save.load_all()`, and `Audio.set_sound` from the settings,
  then shows the first screen.
- Screens: Title (Play only, and the version), the level, Pause (Resume, Retry, Quit to
  title), Level clear (Next and Replay, no stars), and Out of room ("The tray is full",
  Retry, Previous level, Title). UX 3.1, 3.3, 3.4, 3.5 and 4.1 for layout, words and flow,
  without the parts this phase leaves out. First launch skips the title (UX 4.1).
- The Android back button and the lifecycle follow UX 4.2 and 4.3 for these screens.
- `LevelPrefetcher` as in 4.4: urgent for the level the player waits on, level N+1 as soon as
  N starts, and the current and previous `LevelData` kept for Retry and Previous level.
- **The next level is saved** (Bart, Hard Stop 2, to save time on slow phones):
  `user://next_level.json`, written through `Save` as soon as the app flow holds the level
  that `Save.next_level()` names (so quitting mid level or on Level clear both work), is the
  stored-level format of 3.5 for one level plus `"key"`. At boot, if its key is the Play
  level's and its `generator` is `GENERATOR_VERSION`, the app flow reads it with
  `LevelData.from_dict` and plays it without generating. Anything else (missing, broken, an
  error from `from_dict`, another key or version) is ignored and the level is generated as
  usual. The file only saves time: the same key and version always make the same level.
- `Save` (src/save/save.gd) writes the full `progress.json` and `settings.json` of 3.4, with
  the fields this phase doesn't use left at their defaults. It offers `var dir := "user://"`,
  which the test runner points at `user://test_<process id>/` before `load_all()`. ui-dev
  lists `Save`'s public functions in its report and the lead adds them to section 8.

### 10.4 Android build and the phone timing (platform-dev and the lead)

- `export_presets.cfg`: an "Android debug" preset for `io.github.bartbasi.woodlogic` that asks
  for no permissions, signed with the debug key only, excluding `src/directions/*`, `tests/*`,
  `tools/*`, `docs/*`, `build/*` and Markdown files. `tools/build/android-debug.sh` exports it to
  `build/woodlogic-debug.apk`; Bart installs it with `adb install -r build/woodlogic-debug.apk`.
- An "Android timing" preset, the same but named "WoodLogic timing", with the package
  `io.github.bartbasi.woodlogic.timing` (so it installs beside the game), the custom feature
  `timing`, and `tests/logic/golden_levels.json` included. With that feature, `src/app/main.gd`
  (lead) runs `src/app/timing.gd` instead of the app: it loads the catalog, checks the golden
  fingerprints (so the phone reads `res://data` from the APK and makes the same levels as the
  PC), times levels 1 to 200, ten dailies, the boot's sound building and reading a saved next
  level, and shows the table on screen and writes it to `user://timing.txt` and the log.
  `tools/build/android-timing.sh` builds it to `build/woodlogic-timing.apk`.
