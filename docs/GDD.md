# WoodLogic game design document

Owner: game-designer. Status: Approved by Bart at Hard Stop 1, 19 October 2026. Phase 2 updates:
the library of 40 blueprints (section 10), the tutorial files (section 8), data/tuning.json
(section 9.4), rule B13 (section 9.2), and wider layer ranges and new covering targets for the
tiers (section 6.1). Approved by Bart at Hard Stop 2, 19 October 2026 (section 0). Phase 3
updates: the cover rule G8 and the soft step G9 (section 6.4), and covering added to eight
blueprints plus three new ones, 43 in all (section 10). Each change says why.

Board sizes come from docs/UX.md (section 3.2.1). The layout counts are the brief's defaults
and are unchanged. The data formats in section 9 are the ones docs/ARCHITECTURE.md section 3
points to.

## 0. One-page summary

**Core loop.** You see a wooden picture (a house, a boat, a windmill, or an abstract pattern)
made of planks in up to five layers, held to a back board by colored screws. You tap a free
screw. It spins out and flies to an open box of its color, or to the tray if no box of its
color has room. Three screws close a box and the next box slides in, pulling any matching
screws out of the tray. A plank on one screw swings to hang straight below it, and with no
screws it falls away. Clear every screw to win. If the tray is full and no free screw fits an
open box, you are out of room. Retry is free and gives the same level.

**Key numbers (no change to the brief's defaults).**

| Thing | Value | Why, in one line |
|-|-|-|
| Open boxes / slots per box / previewed boxes / tray slots | 2 / 3 / 2 / 5 | the brief's defaults; enough room for planning, tight enough to matter; UX's layout fits them exactly |
| Board | 344 x 360 design units, same on every phone | level N must be identical for everyone (UX 3.2.1) |
| Screw head / touch target | 28 units across / 48 unit circle | UX numbers; every pair of screws is at least 48 apart, so targets never overlap in any state |
| Screws per level | 9 to 36 | at most 7 screws fit across the board; 36 keeps a hard level readable |
| Colors per level | 2 to 8 | |
| Layers | 1 to 5 | |
| Tutorial levels | 8 | one idea each, the brief's list |
| Difficulty stops climbing | level 151 | after that it cycles through the five hardest tiers |

**Stars.** Cleared (always), Fast (within par time: 10 seconds plus 3.0 to 4.5 seconds per
screw by difficulty), Clean (tray used no more than tray par, no helpers). Tray par is the
solver's fewest tray uses plus slack: +2 on levels 9 to 30, +1 on 31 to 100 and on the daily,
0 after that.

**Helpers and economy.** Undo 4 stars, Extra slot 6, Screwdriver 8. Two free of each when it
first appears (Undo on level 8, Extra slot on 15, Screwdriver on 25). A player who plays
reasonably well earns about 19 to 25 stars per ten levels, which buys a helper every 2 to 3
levels. A careless player earns about 15, a helper every 3 to 4 levels.

**Difficulty.** Ten tiers, from 9 screws in 2 or 3 colors on 1 or 2 layers up to 36 screws in
8 colors on 4 or 5 layers. Each level's tier is a base for its level range plus a five step
sawtooth: breather, three climbing steps, then a hard level on every fifth level (10, 15, 20,
...). The base rises from level 9 to level 151 and then stays put. The daily is tier 6 for
everyone. Relaxed offers easy (tiers 1 to 3), medium (4 to 6) and hard (7 and 8).

**Themes.** Unlocked by playing, never by stars: walnut at level 10, brass screws at 25, maple
at 50, cherry at 100, ebony at 150, copper screws at a 3 day daily streak, black screws at 7.

**Decided by Bart at Hard Stop 1.** The look is the Workshop direction.

1. Undo costs the Clean star: Clean means no helpers of any kind (S3, R32).
2. Daily and Relaxed open once level 8 is cleared (section 7).
3. Out of room offers the helpers the player owns (Undo, Extra slot, and Screwdriver), never a
   purchase (R37).
4. A helper the player has none of offers "Get and use" for stars, only when the player taps
   it (section 5).
5. The queue beyond the two previewed boxes stays hidden, and tray par uses the full queue.
   Revisit at Gate 1.
6. Difficulty stops climbing at level 151. Tune at Gate 2.
7. Every pair of screws is at least 48 units apart, center to center, in every state including
   rest poses (B5).
8. The timer starts at the first action, including a helper (S6).
9. Relaxed shows only the free Undo; Extra slot and Screwdriver are hidden (R33).
10. The small speed and clean markers beside the timer stay. Check at Gate 1 that they do not
    feel like pressure (S9). (The Gate 1 build shows no timer or stars, so this check moves to
    Gate 2.)
11. Pause covers the board (S6).
12. Quitting mid level brings the player back to the same level, restarted from the beginning
    (R36). A brand new player skips the title and opens into level 1.
13. Prices 4, 6 and 8 stars, as proposed.

**Decided by Bart at Hard Stop 2** (19 October 2026, approving all the recommendations).

1. The wider layer ranges per tier stay (section 6.1).
2. Covered at start is reported per level, not required (section 6.1).
3. The tutorial plank moves in levels 3, 5 and 6 stay (section 8).
4. The rename to Falling blocks (`falling-blocks`) stands.
5. The cover rule: a tier that needs k tray uses only takes blueprints with at least 2k + 1
   screws covered at the start (G8, section 6.4).
6. The softer step into Hard on tiers 7 to 10 (G9, section 6.4.1): the novice survives at
   least ceil(screws / 3) taps, and the fewest tray use solution does not put all its tray uses
   in the first third. After measuring I propose a change, waiting for Bart: require the
   survival part on tiers 7 and 8 only, and report (not require) the tray use position, because
   as approved 73 to 98 percent of hard levels would fall back to stored ones (6.4.1).
7. More variety: covering for eight blueprints and three new round ones, so every tier from 7 to
   10 has at least 8 boards (section 10.1).

## 1. Board, units and geometry

### 1.1 Units and the grid

- All lengths are design units (du). On phones one du is at least one dp.
- **The board core** is 344 du wide and 360 du tall (UX 3.2.1). Levels use only the core.
  Extra back board on tall phones is for falling planks and drawing only.
- **The board grid.** Blueprints use integer coordinates on a grid of **4 du per grid unit**.
  The core is **86 x 90 grid units**. The origin is the core's top left corner, x grows to the
  right and y grows down.
- **Screw centers** sit in x 6 to 80 and y 6 to 84 (24 du in from each edge, inside UX's inset
  rectangle of 22 du).
- **Screw head** radius 3.5 units (14 du, so 28 du across). **Touch target** a circle of radius
  6 units (24 du).

### 1.2 Planks

Each plank has a **layer** (0 is the front, 4 the back), a **shape**, and one or more
**holes**. Each hole holds exactly one screw, and that screw holds only that plank. Shapes:

| Shape | Fields | Outline |
|-|-|-|
| bar | `path` (2 or more points), `width` (at least 10) | every point within width/2 of the polyline; a straight bar has round ends, a 3 point path makes an L |
| poly | `points` (3 or more, either winding, no self crossing) | the polygon; plates, triangles, trapezoids |
| disc | `center`, `radius` | the circle |
| ring | `center`, `radius`, `inner` (band at least 10) | the band between the two circles; whatever is inside the inner circle is not covered |

- **Signed distance** d(p, plank) is the distance from point p to the plank's outline,
  negative inside the plank.
- **Centroid** is the area centroid of the outline with uniform density. Holes are ignored.
- The logic may turn arcs into polygons, with an outline error under 0.05 units. The renderer
  draws the same outline the logic uses; bevels and edges are drawn inside it.

### 1.3 How many screws fit (the arithmetic)

- Screw centers span 74 units across (x 6 to 80) and 78 down (y 6 to 84), that is 296 by 312
  du.
- At the 48 du spacing (12 units): across, 6 gaps of 12 make 72 of the 74 units, so **7 screws
  fit across** (7 targets of 48 du take 336 du of the 344 du core). Down, y 6 to 78 gives
  **7 rows** (an 8th row would need y 90). A square lattice holds **49 screws**; a staggered one
  about 52.
- Caps: **36 screws per level** (73 percent of the lattice, so planks keep room to overlap and
  read as shapes) and **at most 24 free at the start** (UX's readability estimate).
- A 28 du head on 48 du spacing leaves at least 20 du of wood or board between any two heads.

## 2. The rules, as the logic model runs them

Each rule has an id so a unit test can name it.

### 2.1 State

- **R1.** A level is: planks (shape, layer, holes), each screw's color, the box queue (an
  ordered list of colors, one entry per box), the tray size (5), and par numbers.
- **R2.** The state is: which screws are on the board; for each plank whether it is fixed (two
  or more screws), hanging (one screw, with its rest pose) or fallen (none); the two open box
  positions (left 0, right 1), each empty or holding a box (color and screws in it, 0 to 3);
  the index of the next box in the queue; the tray slots (each empty or one screw); the tray
  use count; the helpers used this attempt; whether Extra slot was used this attempt.
- **R3.** Each color's screw count is three times its number of boxes in the queue. So the
  total number of screws is three times the number of boxes.

### 2.2 Level start

- **R4.** Box position 0 gets queue entry 0 and position 1 gets entry 1. If the queue has only
  one box, position 1 stays empty. The preview shows entries 2 and 3 (or fewer).
- **R5.** The tray is empty, the tray use count is 0, all planks are fixed or hanging at their
  authored pose. (Blueprints only put a one screw plank where it already hangs at rest, rule
  B9, so nothing moves at the start.)
- **R6.** At the start at least one free screw fits an open box (generator rule G5), so the
  first tap never has to go to the tray.

### 2.3 Covered and free

- **R7.** A screw on plank P is **covered** when some plank Q still on the board, in a layer
  strictly in front of P's (a smaller number), has d(screw center, Q's current outline) below
  3.5 units, the head radius. Otherwise it is **free**.
- **R8.** Planks in the same layer never cover each other, even when a swing makes them
  overlap. Planks never collide.
- **R9.** Covering is recomputed after every change to the board, at the moment of the tap.
- **R10.** While any screw is on the board, at least one is free. (The frontmost plank still on
  the board has no plank in front of it.)

### 2.4 A tap

- **R11.** Only a free screw can be tapped. A tap on a covered screw changes nothing in the
  state (the view wiggles the frontmost covering plank).
- **R12. Destination.** For a screw of color c: among the open boxes of color c with fewer than
  3 screws, the one holding the most screws; on a tie, the left one. If there is none, the
  leftmost empty tray slot. If there is none of either, the tap is **refused** (R25).
- **R13. Order of resolution.** One tap resolves completely, in this order, before the next
  tap is looked at:
  1. Pick the destination (R12). If refused, stop; nothing changes.
  2. Take the screw off the board. Update its plank (R14 to R17).
  3. Recompute covering (R9).
  4. Put the screw in its destination. If it went to the tray, add 1 to the tray use count.
  5. If a box now holds 3 screws, close it and run the queue (R18 to R21).
  6. Check for a win (R22), then for a loss (R23).
- **R14.** Taps are resolved in the order they arrive, each against the state left by the one
  before. Animations never delay or reorder the logic.

### 2.5 Planks swing and fall

- **R15. Fixed.** A plank with two or more screws does not move.
- **R16. Swing.** When a plank goes down to one screw, it turns about that screw's center (the
  pivot) to its **rest pose**: the pose in which its centroid lies straight below the pivot.
  The turn is applied to the plank's authored outline. Let r be the distance from pivot to
  centroid. If r is under 0.5 units, the plank does not turn. Angles are measured in degrees,
  positive turning clockwise on screen (from +x toward +y). The logic only knows the final
  pose; the view animates a damped swing toward it.
- **R17. Fall.** When a plank loses its last screw it leaves the board at once. It covers
  nothing from then on.
- A plank swings at most once per attempt (fixed, then hanging, then fallen), except that Undo
  can put it back.
- For determinism, the engine rounds every turned vertex to a fixed precision (suggested 1/1024
  of a unit), and blueprints keep every screw at least 0.25 units away from the covering
  threshold in every possible rest pose (rule B11), so no phone can disagree.

### 2.6 Boxes and the queue

- **R18.** When a box holds 3 screws it closes and leaves its position.
- **R19.** The next box in the queue (if any) takes that same position. If the queue is used
  up, the position stays empty.
- **R20. Auto jump.** Then the tray is scanned from the left slot to the right. Each screw of
  the new box's color moves into the box, until the box holds 3 or the scan ends. Tray slots
  that empty stay empty; the other tray screws do not shift.
- **R21.** If the auto jump fills the new box, it closes too and R19 and R20 run again for that
  position. This repeats until a box arrives that is not full or the queue is used up. Only the
  position that just changed takes jumps.
- **Invariant I1.** After every tap, no tray screw matches an open box with room. (A screw only
  goes to the tray when no box of its color has room, and every new box takes its jumps at
  once.)

### 2.7 Win and loss

- **R22. Win.** The level is won when no screw is left on the board and the tray is empty.
  This is checked before loss.
- **R23. Loss.** The level is lost when every tray slot is full and no free screw on the board
  has a destination (R12). Covered screws do not count.
- **R24.** A loss is checked after every tap and every helper use. Nothing else ends a level.
  Time never does.
- **R25. Refused tap.** A tap on a free screw that has no destination (tray full, no open box
  of its color with room, but some other free screw does fit) is refused: the state does not
  change, it is not a tray use, and it does not start the timer. The view says why (UX: a
  short turn back and the full tray nudging).

### 2.8 Undo

- **R26.** Undo takes back the last action (a tap or a Screwdriver removal). It restores
  everything that action changed: the screw back in its hole, its plank's pose (a fallen plank
  returns, a hanging plank returns to its earlier pose), the boxes, the queue position, the
  tray contents and the tray use count.
- **R27.** Undo does not restore: the clock, helper counts (the Undo is spent; an undone
  Screwdriver is not refunded), or the Extra slot (the tray keeps its sixth slot).
- **R28.** Undo can be used again and again, one Undo each, back to the start of the attempt.
  With nothing to take back, the button does nothing and nothing is spent.
- **R29.** Undo is allowed after a loss (from the out of room sheet, R37). The loss is cleared
  and play continues. It is not available after a win.

### 2.9 Helpers

- **R30. Extra slot.** Adds a sixth tray slot on the right for the rest of this attempt. At
  most once per attempt (the button then reads "Used"). It may be used at any time while
  playing. Retry gives back the normal five slots.
- **R31. Screwdriver.** Removes any one screw on the board, free or covered, and sends it to
  its destination exactly as a tap would (R12, R13). It counts as an action for Undo. If that
  screw has no destination the removal is refused and the Screwdriver is not spent.
- **R32.** Using any helper in an attempt rules out the Clean star for that attempt.
- **R33.** Helpers work the same in numbered levels, replays and the daily. Relaxed shows only
  Undo, free and unlimited; Extra slot and Screwdriver are hidden there (section 6.6).
- **R37. Out of room.** At a loss the sheet offers each helper the player owns and can use:
  Undo (count 1 or more; R29), Extra slot (count 1 or more and not yet used this attempt; the
  sixth slot opens, so the tray is no longer full and play continues), and Screwdriver (count
  1 or more and at least one screw on the board, covered or not, fits an open box; the player
  then picks the screw as in R31). A helper the player owns none of is not shown on the sheet,
  and the sheet never offers a purchase. Using one clears the loss, counts as a helper for R32,
  and restarts the clock from where it stopped.
- **R38. Buying.** Tapping a helper button at count 0 during play, when the bank can pay, asks
  "Get and use" for its price (UX 3.13.3). It happens only on the player's tap, never as a
  prompt, never on the out of room sheet, never in Relaxed.

### 2.10 Retry, previous level, quitting mid level

- **R34.** Retry restarts the same level from R4: same planks, colors and queue. The clock,
  tray uses, helpers used and Extra slot all reset. Helpers spent stay spent.
- **R35.** Previous level loads level N minus 1 as a replay.
- **R36.** If the player quits mid level or the app is closed, the next Play opens the same
  level restarted from the beginning (R4), with a fresh clock. Helpers spent in the abandoned
  attempt stay spent. A brand new player skips the title and opens straight into level 1.

### 2.11 Worked examples (seeds for unit tests)

These use the shipped blueprints in data/blueprints/.

- **E1, covering (house).** The wall (layer 1) screw at (14, 40) starts covered: it lies inside
  the roof triangle (layer 0), 2 units above the roof's lower edge, so d = -2. The wall screw
  at (14, 82) is free: the nearest front plank is far away.
- **E2, swing of 180 degrees (house chimney).** The chimney is a bar from (68, 6) to (68, 20),
  width 10, screws at (68, 8) and (68, 20), centroid (68, 13). Take (68, 8) first: it hangs on
  (68, 20) with the centroid above the pivot, so it turns 180 degrees and its path becomes
  (68, 34) to (68, 20). Take (68, 20) first instead: it hangs on (68, 8), the centroid is
  already straight below, and the angle is 0.
- **E3, a swing that covers (windmill gallery).** The gallery bar (layer 0) runs from (28, 62)
  to (58, 62), width 10, screws at (30, 62) and (56, 62), centroid (43, 62). Take (56, 62): it
  hangs on (30, 62) and turns +90 degrees, so its path becomes (30, 60) to (30, 90). The tower
  screw (29, 84) on layer 3 was free (d = 17) and is now covered (d = -4).
- **E4, tray order and auto jump.** Open boxes A (0 screws) and B (2 screws), next in queue C.
  Tray holds [C, -, C, -, -]. Tap a B screw: B fills and closes, C slides into position 1, the
  tray C screws at slots 0 and 2 jump in (C now holds 2), and the tray is empty.
- **E5, cascade.** Same as E4 but the tray holds three C screws and the queue after C is D.
  C fills from the tray, closes, and D slides into position 1 in the same tap.
- **E6, loss.** Tray full with [D, D, E, E, F], open boxes A (1) and B (0), and the only free
  screws are colors D, E and F: lost. If one free screw were A or B, play would continue, and
  tapping a free D would be refused (R25).
- **E7, fullest box first.** Open boxes are both color A, holding 0 and 2. An A screw goes to
  the right one and closes it.

## 3. Counts and every "designer decides" item

| Item | Decision | Reason |
|-|-|-|
| Open boxes | 2 | two live colors make every tap a small choice; three would make early levels trivial, and one would make the tray the whole story |
| Slots per box | 3 | each color's count is a multiple of 3, and a box closes often (a small win every three right taps) |
| Previewed boxes | 2 | enough to plan two closes ahead; UX's row fits exactly 2. Boxes after those stay hidden, and tray par is computed on the full queue; Retry gives the same level, so a second try is fully informed. Revisit at Gate 1. |
| Tray slots | 5 | the brief's default; with 2 open boxes a careless player fills it on mid levels but a thoughtful one rarely does. If Gate 1 says hard levels are too soft, the first lever is coloring and queue order, the second is a 4 slot tray. |
| Tutorial levels | 8 | one per idea in the brief's list; UX already wrote a line for each |
| Tray par slack | +2 levels 9 to 30, +1 levels 31 to 100 and the daily, 0 from 101; tutorial levels set their own | new players learn the tray before we ask for neat solves; later the Clean star means best play |
| Par time | 10 s plus 3.0 s per screw (Easy tiers), 3.5 (Medium), 4.0 (Hard), 4.5 (Expert), rounded up to 5 s | harder levels need more thinking per tap; a mid level of 24 screws gets 1:35. Tuned from playtests and bots at Gate 2. |
| Timer start | the first action (tap or helper), not when the board appears | reading the board is free; looking first is the skill we want to reward |
| Daily band | tier 6, tray slack +1, Medium par time | "medium hard": a good puzzle for most players, and the same for everyone |
| Relaxed bands | easy tiers 1 to 3, medium 4 to 6, hard 7 to 8 | Relaxed is for unwinding, so it stops below Expert |
| Where difficulty stops climbing | level 151 | about four hours of play; after that variety comes from blueprints. Tune at Gate 2. |
| Extra slot per attempt | once | keeps the tray at 5 or 6 slots (UX layout) and keeps it a rescue, not a habit |
| Two open boxes of one color | allowed; the fuller box fills first | simple and kind; the generator avoids it at the start (G6) |
| Tray gaps | stay where they are | the tray never rearranges itself, so the player's memory of it holds |

## 4. Stars, par and the clock

- **S1. Cleared:** win the level.
- **S2. Fast:** win with elapsed time at most the par time. Helpers are allowed.
- **S3. Clean:** win with tray uses at most tray par, and no helper used in this attempt.
- **S4.** Stars are independent: Fast can come without Clean and the other way round.
- **S5.** A level's record is its best star count. Replaying adds to the star bank only the
  stars above that record (the record is the best total, not a per star memory).
- **S6. Clock.** Starts at the first action (tap or helper use) of the attempt. Stops while
  paused (the pause screen covers the board, so pausing gives no free thinking time), while a
  helper sheet or the buy dialog is open, at the win and at the loss. The win
  time is taken at the winning tap (the logic moment), not after the animation. It is compared
  in milliseconds against the par in whole seconds.
- **S7. Tray par** is the fewest tray uses the solver found plus the slack in section 3.
- **S8. Par time** is 5 x ceil((10 + k x screws) / 5) seconds with k from section 3. Examples:
  18 screws on tier 4 gives 10 + 63 = 73, so 75 s; 30 screws on tier 7 gives 130 s; 36 screws
  on tier 10 gives 172, so 175 s.
- **S9. What shows when.** The timer, the speed and clean pips and the star bank appear from
  level 4 (UX's suggestion). Levels 1 to 3 still award stars, with generous par from their data.
  The pips stay; Gate 1 checks that they do not feel like pressure.
- Relaxed has no stars, no clock and no par.

## 5. Helpers and the economy

| Helper | Price | First appears (2 free) | Why that level |
|-|-|-|-|
| Undo | 4 stars | level 8 (tutorial) | the tutorial teaches it |
| Extra slot | 6 stars | level 15 | the third hard level; the tray first gets tight here |
| Screwdriver | 8 stars | level 25 | a hard level with real covering, and the brass unlock |

- Buying happens on the level screen: a helper at count 0 shows its price, and a tap asks to
  get and use one (UX 3.13.3). Stars are never spent anywhere else.
- Using a helper also costs that attempt's Clean star, so the real price is one star more when
  the Clean star was in reach.

**Worked economy.** Assumed rates for a player who plays reasonably well (a guess to be
checked against bot data and Gate 2), with an assumed buying mix of 2 Undo : 1 Extra slot :
1 Screwdriver, so an average price of (4 + 4 + 6 + 8) / 4 = 5.5 stars.

| Levels | Base tier | Cleared | Fast | Clean | Stars per level | Per 10 levels | Undos (4) | Extra slots (6) | Screwdrivers (8) | Mixed helpers | One helper every |
|-|-|-|-|-|-|-|-|-|-|-|-|
| 9 to 30 | 2 to 3 | 1.00 | 0.80 | 0.70 | 2.50 | 25 | 6.2 | 4.2 | 3.1 | 4.5 | 2.2 levels |
| 31 to 100 | 3 to 6 | 1.00 | 0.70 | 0.55 | 2.25 | 22.5 | 5.6 | 3.8 | 2.8 | 4.1 | 2.4 levels |
| 101 to 150 | 6 to 7 | 1.00 | 0.60 | 0.45 | 2.05 | 20.5 | 5.1 | 3.4 | 2.6 | 3.7 | 2.7 levels |
| 151 on | 8 | 1.00 | 0.55 | 0.35 | 1.90 | 19 | 4.8 | 3.2 | 2.4 | 3.5 | 2.9 levels |
| careless player, any band | | 1.00 | 0.40 | 0.15 | 1.55 | 15.5 | 3.9 | 2.6 | 1.9 | 2.8 | 3.5 levels |

Arithmetic, first row: 1 + 0.8 + 0.7 = 2.5 stars per level, 25 per ten; 25 / 4 = 6.2 Undos,
25 / 6 = 4.2, 25 / 8 = 3.1; 25 / 5.5 = 4.5 helpers, so one every 10 / 4.5 = 2.2 levels.

- By the end of the tutorial a player has about 22 stars (levels 1 to 3 give 3 each, levels 4
  to 8 about 2.6 each), plus 2 free Undos.
- The daily adds about 2.1 stars a day.
- Target met: a helper every 2 to 3 levels for a good player, every 3 to 4 for a careless one.
  Nobody needs one: every level is solved without helpers, and Retry is free.
- **Tuning rule.** If bot data shows the bank growing past 60 unspent stars for a typical
  player by level 100, helpers are too cheap or unneeded and we leave prices alone (unspent
  stars are fine). If a careless bot cannot afford one helper per 5 levels, lower Undo to 3.

## 6. Difficulty

### 6.1 Tiers

| Tier | Group | Screws | Colors | Layers in use | Fewest tray uses (solver) | Novice policy (6.4) | Covered at start (reported, not a rule) |
|-|-|-|-|-|-|-|-|
| 1 | Easy | 9 to 12 | 2 to 3 | 1 to 2 | 0 | must win | 0 to 20 percent |
| 2 | Easy | 12 to 15 | 3 | 2 to 3 | 0 to 1 | must win | 0 to 30 |
| 3 | Easy | 15 to 18 | 3 to 4 | 2 to 4 | 0 to 1 | must win | 0 to 35 |
| 4 | Medium | 18 to 21 | 4 | 3 to 4 | 1 to 2 | either | 0 to 35 |
| 5 | Medium | 21 to 24 | 4 to 5 | 3 to 5 | 1 to 2 | either | 0 to 50 |
| 6 | Medium | 24 to 27 | 5 | 3 to 5 | 1 to 3 | either | 5 to 50 |
| 7 | Hard | 27 to 30 | 5 to 6 | 4 to 5 | 2 to 3 | must lose | 14 to 50 |
| 8 | Hard | 30 to 33 | 6 to 7 | 4 to 5 | 2 to 4 | must lose | 25 to 50 |
| 9 | Expert | 33 to 36 | 7 | 4 to 5 | 3 to 4 | must lose | 25 to 55 |
| 10 | Expert | 33 to 36 | 7 to 8 | 4 to 5 | 3 to 5 | must lose | 25 to 60 |

Colors never exceed screws / 3. "Tray pressure" is the fewest tray uses column together with
the novice policy column: a careless order must be able to fail from tier 7 up. The same numbers
are in data/tuning.json (section 9.4).

**Phase 2 changes, and why** (both confirmed by Bart at Hard Stop 2).

- **Layers are wider ranges.** With the Hard Stop 1 ranges (tier 2 exactly 2 layers, tiers 4 and
  5 exactly 3, tiers 7 and 8 exactly 4, tier 10 exactly 5), half of the first ten blueprints
  suited no tier at all (windmill, bridge, lighthouse, rings and lattice). Layers are a weak
  lever on their own: what makes a level hard is how many screws are covered, how deep, and the
  coloring. So each tier now takes one more layer count, and tier 10 takes 4 or 5 like tier 9.
  Tier 10 still differs from tier 9 by colors (up to 8) and tray uses (up to 5). With 5 layers
  only, tier 10 had three blueprints; with 4 or 5 it has six.
- **Covered at start is reported, not a rule.** It is not one of G1 to G9, and the generator's
  variations (a changed layer order, a dropped plank) move it a lot. tools/levels reports it per
  level so we can see the spread. The ranges match what the blueprints give as authored
  (section 10, where percentages are rounded; in Phase 2 castle and crates covered 4 of 27,
  14.8 percent, and all 43 of Phase 3 still fall inside their tiers' ranges), so a report
  outside them means the variation changed the board a lot, which is worth a look but is not a
  reason to reject the level. The cover rule G8 (section 6.4) is separate: it counts covered
  screws on the authored blueprint to decide which tiers may use it.

### 6.2 Readability caps (every tier, every level)

- At most 36 screws, 8 colors, 5 layers, 16 planks.
- At most 24 free screws at the start.
- At most 3 planks over any screw at the start.
- Every pair of screws at least 48 du apart, so free screws' 48 du targets never overlap in any
  state (section 1.3). Blueprint rules B5 to B12 keep covering easy to read.

### 6.3 The sawtooth

tier(N) = clamp(base(N) + step(N mod 5), 1, 10), for numbered levels N from 9 (1 to 8 are the
tutorial).

In data/tuning.json, `sawtooth.steps` lists the steps in the order of this table, so the step
for level N is `steps[(N - 1) mod 5]`: level 11 gets -2, level 15 gets +2. `sawtooth.bases`
lists [first level, base] pairs: base(N) is the base of the last pair whose first level is at
most N.

| N mod 5 | 1 | 2 | 3 | 4 | 0 |
|-|-|-|-|-|-|
| role | breather | climb | climb | climb | hard |
| step | -2 | -1 | 0 | +1 | +2 |

| Levels | 9 to 20 | 21 to 35 | 36 to 55 | 56 to 80 | 81 to 110 | 111 to 150 | 151 on |
|-|-|-|-|-|-|-|-|
| base | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
| tiers in a cycle | 1, 1, 2, 3, 4 | 1, 2, 3, 4, 5 | 2, 3, 4, 5, 6 | 3, 4, 5, 6, 7 | 4, 5, 6, 7, 8 | 5, 6, 7, 8, 9 | 6, 7, 8, 9, 10 |

Levels 9 to 30 in full: 9: 3, 10: 4, 11: 1, 12: 1, 13: 2, 14: 3, 15: 4, 16: 1, 17: 1, 18: 2,
19: 3, 20: 4, 21: 1, 22: 2, 23: 3, 24: 4, 25: 5, 26: 1, 27: 2, 28: 3, 29: 4, 30: 5.

Every hard level (10, 15, 20, ...) is followed by a breather four tiers lower. Theme
milestones (10, 25, 50, 100, 150) all land on hard levels, so the reward follows the effort.
From level 151 the tiers cycle 6, 7, 8, 9, 10 for good.

Mid game levels (tiers 5 to 7, 21 to 30 screws) at 3.5 seconds a screw (Medium, tiers 5 and 6)
or 4.0 (Hard, tier 7) take about 85 to 130 seconds (21 x 3.5 + 10 = 83.5, so 85; 30 x 4.0 + 10 =
130): inside the checklist's 1 to 3 minutes.

### 6.4 Generator acceptance rules

A variation is shown only if all of these hold. Otherwise the generator tries the next one.

- **G1.** Screws, colors and layers in use are inside the tier's ranges. Every color count is a
  multiple of 3.
- **G2.** The varied layout still passes every blueprint rule (B4 to B13), after mirroring,
  shifts, swapped shapes, dropped or added planks and a changed layer order.
- **G3.** The solver solved it, and its fewest tray uses is inside the tier's range.
- **G4.** The novice policy's result matches the tier (must win, either, must lose).
- **G5.** At the start at least one free screw fits an open box.
- **G6.** The queue never has the same color twice in a row, and the two starting boxes differ.
- **G7.** The blueprint was not used in the previous 5 numbered levels.
- **G8. The cover rule** (approved by Bart at Hard Stop 2). A tier whose fewest tray uses range
  starts at k (its `tray_uses` low end in data/tuning.json) only uses blueprints with at least
  2k + 1 screws covered at the start, counted on the blueprint as authored
  (`LevelCatalog.suits_tier`). Tiers with k = 0 (1 to 3) take any blueprint whose screws and
  layers fit. So tiers 4 to 6 need 3 covered, tiers 7 and 8 need 5, tiers 9 and 10 need 7. Why:
  a board with nothing covered never needs the tray, whatever its colors (every screw can be
  taken in queue order), and each forced tray use needs about two covered screws to hide the
  screws that make it. This decides which blueprints a tier may draw (G7's deal); it is not
  checked again on the varied board.
- **G9. The soft step into Hard** (tiers 7 to 10, approved by Bart at Hard Stop 2, with a
  proposed change). See section 6.4.1.

**Novice policy** (a cheap stand in for a careless player, deterministic): at every step, if
some free screw fits an open box, tap the topmost such screw (smallest y, then smallest x);
otherwise tap the topmost free screw. It never uses helpers.

**Measures the solver records** for every level (brief section 5): screws, colors, layers,
planks, fewest tray uses, the novice policy's result, and a trap measure the engine defines
(suggested: the share of random playouts that lose). Bots in tests/bots report the rest.

### 6.4.1 G9: the soft step into Hard

**Why.** In the Hard Stop 2 bot run (build/bots/hs2-run.txt) the novice won 76 percent of tier 6
levels and none on tiers 7 to 10, and the random bot fell from 57 to 7 percent. The novice lost
after about 8 taps on 30 screws: the tray was full by then, so one opening decided the whole
level and the other 20 taps carried no pressure. On the Phase 3 library the same generator gives
the same picture: of 148 hard levels (151 to 350), the novice is out by tap 7 on 88, and the
solver's solution makes its last tray use by tap 7 on 133.

**Where it applies.** Every generated level of tiers 7 to 10: numbered, Relaxed (hard band) and
the stored fallback levels. Not the daily (tier 6) or the tutorial. As proposed below, G9a is
required on tiers 7 and 8 and reported on 9 and 10, and G9b is reported only.

**G9a. Survival.** Let n be the level's screws. Play the novice policy (section 6.4) from the
start, exactly as `Solver.measure` does for `SolveResult.novice_won`. Its survival s is the
number of taps it makes before the level is lost: every tap counts, into a box or into the tray,
and the tap after which R23 holds is the last one counted. (The novice never makes a refused
tap, because it only taps a screw that has a destination, and it uses no helpers.) G4 already
requires it to lose on these tiers, so s is below n. The rule:

  **s >= ceil(n / 3)**, required on tiers 7 and 8; on tiers 9 and 10 reported, not required
  (proposed, waiting for Bart; approved was required on all four).

| Screws | 27 | 28 to 30 | 31 to 33 | 34 to 36 |
|-|-|-|-|-|
| ceil(n / 3), taps | 9 | 10 | 11 | 12 |

**G9b. Late tray use.** Number the taps of the solver's solution (`SolveResult.solution`, one tap
per screw, the order that reaches the fewest tray uses) from 1 to n. A tap is a tray use when its
screw goes to the tray (R12; the tap that R13 step 4 counts). A tray use's position is its tap
number p. The solution puts all its tray uses in the first third when every tray use has
3p <= n. Approved: such a coloring is turned down. Proposed (waiting for Bart): tools/levels and
the bot report show the last tray use's position for every level, and nothing is turned down for
it.

**When a coloring fails G9.** It is turned down like a coloring that fails G4: the generator
goes on to its next attempt (the next coloring of the same variation, then the next variation),
and the attempt counts toward the attempt and state budgets. The coloring pressure does not
change (measured: lowering it after a G9 failure made no difference). G4 and G9a are checked
first, before the search, because they need only the novice playout (one playout of at most n
taps, about 1 ms); only colorings that pass them are searched for G3. The rules for keeping a level
are the same; only the order of the walk through the colorings differs (so levels can differ,
which is part of why the golden levels changed with version 4), and it makes the hard tiers
about 3.5 times faster (searches per level on tier 7 fell from 43 to 4, on tier 8 from 40
to 6, with the same fallbacks). G9b, where it is reported, needs one replay of the solution
after the search.

**With the per-tier tray cap.** Unchanged. The search still stops past the tier's top tray use
count (`over_cap`), the fewest tray uses must still be inside the tier's range (G3), and G9 never
widens or narrows that range.

**With the fallbacks.** The stored fallback levels of tiers 7 and 8 must pass G9a (rebuild them
once G9 is in). When a level's attempts run out, the order stays: the tier's own stored levels,
then the closest solved attempt, then a neighboring tier's stored levels. When choosing the
closest attempt, one that passes G9a beats one that does not, before the existing order (most
tray uses, then the novice result the tier wants). A neighbor's stored level from tier 6 or 9
needs no G9.

**Measured, and why I propose a change.** A scratch copy of the generator with G9 added, on
levels 151 to 350 (40 levels per tier, the Phase 3 library), counting the levels that ran out of
attempts and fell back to a stored level. "Today's budget" is 12 variations, 60 attempts and
1.2 million states per level; "double" is 24, 120 and 2.4 million.

| Generator | Tier 7 | Tier 8 | Tier 9 | Tier 10 |
|-|-|-|-|-|
| as now, no G9 | 0% | 5% | 20% | 5% |
| as approved: G9a at n / 3 and G9b, today's budget | 73% | 88% | 98% | 98% |
| G9a at n / 3 only, today's budget | 25% | 28% | 73% | 58% |
| G9a at n / 3 only, double budget | 13% | 10% | 60% | 43% |
| G9a at n / 3 on tiers 7 and 8 only, double budget (proposed) | 13% | 10% | 20% | 5% |

On the accepted levels with G9a, the novice survives 13 to 15 taps on average (today 8 to 10),
and the trap measure barely moves (0.88 on tier 7 instead of 0.90), so a careless order still
loses, just not in the opening.

- **G9b measures the solver more than the level.** The solver is a breadth first search by tray
  uses that keeps the first solution it reaches, and its order of exploring puts tray uses
  early: today 133 of 148 hard solutions make their last tray use by tap 7. Requiring a late one
  turned down nearly every coloring.
- **G9a fits the step into Hard, not yet Expert.** The hard tiers color with a deep opening (the
  two open boxes need screws that only come free after several removals), which is exactly what
  fills the novice's tray by tap 6 or 7. Enough of those colorings survive n / 3 on tiers 7 and
  8, given a bigger budget. Tiers 9 and 10 also need 3 or more tray uses, and too few colorings
  manage both: even with the double budget, 43 to 60 percent of those levels would be stored
  ones, which undoes the variety work of section 10.1. The cliff Bart saw is between tiers 6 and
  7, so the rule goes there first; Expert stays sharp for now.
- **What would let the approved version work** (for level-engine-dev, a suggestion): a second
  coloring that gives the deep screws to boxes 3 and 4 (the previewed ones) and screws free at
  the start to boxes 1 and 2. In my scratch copy every level it produced passed G9a at n / 3,
  but on its own it fell back as often as the deep opening on Expert (35, 18, 75 and 60 percent
  on tiers 7 to 10 at today's budget), and mixing the two did not help there. Expert needs a
  better coloring before G9a can be required on it; then measure again.
- **Acceptance.** G9 ships when tools/levels shows at most about 10 percent fallbacks on tiers 7
  and 8 over levels 9 to 400 (13 and 10 percent in my scratch run with the double budget), and
  the generation times on the phone stay acceptable. If the engine can't get there, the numbers
  come back to me and Bart; nobody relaxes them silently.
- **Measured with generator version 4** (level-engine-dev, levels 9 to 400, double budget). Fell
  back: tier 7 12 percent (8 of 69), tier 8 19 percent (12 of 64), tier 9 14 percent, tier 10 10
  percent. A triple budget brings tier 7 to 3 percent but leaves tier 8 at 13; a quadruple adds
  nothing. Two boards cause most of it: skyline falls back 5 of 6 times on tier 7, and bookshelf
  4 of 6 on tier 8, 5 of 8 on tier 9 and 4 of 6 on tier 10 (the fallback builder found no tier 8
  bookshelf level in 160 tries). Jellyfish and ship-wheel each miss 2 on tier 8. On accepted tier
  7 and 8 levels the novice survives a median of 13 taps (at least 9 and 10). On Expert, where
  G9a is only reported, 7 of 48 tier 9 levels and 7 of 40 tier 10 levels pass it, with a median
  of 7 novice taps. Levels 358 and 368 hand out the same stored level. So the gate is not met on
  tier 8.
- **Recommendation for Bart.** Ship Gate 1 as it is: every fallback is still a solved, checked
  level, Gate 1 is about feel, and the player meets tier 7 first at level 60 and tier 8 at level
  85, past where the Gate 1 sittings reach. In Phase 4, fix the data, with the version bump that
  goes with it. I prefer retuning skyline and bookshelf (deeper or more covering, so colorings
  that let the novice survive also need 2 or more tray uses) over keeping them off tiers 7 and 8:
  skyline suits only tiers 7 and 8, so dropping it there drops it from the game and leaves tier 7
  with 7 boards, and bookshelf fails on tiers 9 and 10 too. Then measure again against this gate,
  and check that no two levels within 5 of each other hand out the same stored level.

### 6.5 Evidence so far

A scratch reference model of rules R1 to R25 (Python, outside the repo, for my checks only)
solved random colorings of three blueprints by full search: house with 5 colors, windmill with
5, bridge with 6. Fewest tray uses came out 0 to 2 and under 2 percent of reachable states were
losses. So random colors give tiers 1 to 4 at most. The higher tiers need the generator to
color with intent (early free screws in colors late in the queue) and denser blueprints. That
is the main thing to prove at Hard Stop 2.

### 6.6 Daily and Relaxed

- **Daily:** tier 6 every day, tray slack +1, par k = 3.5. Opens after level 8. Built from the
  local date and the generator version. Stars as for any level; replays add only above best.
  **Streak:** solving the daily of date D adds one if the last counted daily was D minus 1,
  otherwise the streak becomes 1. A daily counts only if its date is later than the last
  counted date, so moving the clock back gains nothing. The daily keeps the date it was started
  on (UX 4.3).
- **Relaxed:** opens after level 8. Its own seed stream. Easy picks a tier from 1 to 3, medium
  from 4 to 6, hard from 7 to 8, by seed, and applies G1 to G9. No stars, no clock. Undo is free
  and unlimited. When R23 would make the level lost, it is not lost: the stuck sheet offers a
  free Undo (UX 3.5). Relaxed does not move the level count or the stats beyond "helpers used".

### 6.7 Band names for Stats

Stats times are grouped by tier group: **Easy** (tiers 1 to 3), **Medium** (4 to 6), **Hard**
(7 and 8), **Expert** (9 and 10). The daily counts in its group (Medium). Tutorial levels and
Relaxed are not timed in Stats.

## 7. Unlocks

| What | When |
|-|-|
| Undo (2 free) | level 8 |
| Daily, Relaxed | level 8 cleared |
| Extra slot (2 free) | level 15 |
| Screwdriver (2 free) | level 25 |
| Oak wood, steel screws | from the start |
| Walnut wood | level 10 cleared |
| Brass screws | level 25 cleared |
| Maple wood | level 50 cleared |
| Cherry wood | level 100 cleared |
| Ebony wood | level 150 cleared |
| Copper screws | best daily streak 3 |
| Black screws | best daily streak 7 |

- "Level N cleared" means the highest level cleared reaches N. Streak unlocks use the best
  streak, so a broken streak never takes anything away. Unlocks are permanent; a progress
  reset clears them.
- If the graphic designer ships more themes, the next milestones are levels 200 and 300 and
  best streaks of 14 and 30.
- In data/tuning.json, `unlocks` lists the themes (oak and steel with `"level": 0`, meaning from
  the start; the rest with the level or best streak above), `helpers` gives each helper's first
  level and its 2 free, and `modes_open_after_level` is 8.

## 8. Tutorial levels

Levels 1 to 8, written by hand as data in data/tutorial/tutorial-1.json to tutorial-8.json.
Colors are shown as A, B, C, D: palette indices 0 to 3, which in DESIGN.md's order are red,
yellow, sky and blue. That is the order DESIGN.md picked so the first four are the most distinct
set (worst pair 0.221 in OKLab), and sky and blue also differ strongly in lightness and have
different symbols (diamond and cross). Levels 2 to 6 use only red, yellow and sky; blue first
appears in level 7. Coordinates are grid units (section 1.1).

Every one was solved by full search in my scratch model (every reachable state visited) and by
the engine's solver in src/logic, and both agree. None of them has a reachable losing state, so
a new player can only fail to get a star. No plank in a tutorial ever hangs across a screw of
its own layer, so a screw the player can tap is never drawn under a hanging plank. Lines are
UX's (UX 5.3), unchanged.

| Level | Idea | Line | Board | Queue | Tray par / par time | Fewest tray uses | Hand points at |
|-|-|-|-|-|-|-|-|
| 1 | Tap a screw | none (UX: "Tap a screw." after 8 s idle) | one bar (25, 45) to (61, 45), width 12, screws A A A | A | 2 / 30 s | 0 | the left, right, then middle screw, so the bar never swings and falls at the end |
| 2 | Screws go to their box | "Screws fly to the box of their color." | two upright bars at x 25 and x 61, screws at y 25, 45, 65: A B A and B A B | A B | 2 / 50 s | 0 | the first screw |
| 3 | The tray | "No open box? The screw waits in the tray." | three upright bars at x 19, 43, 67 (y 25 to 65), screws at y 25, 45, 65: A C B, C A C, B B A | A B C | 3 / 65 s | 0 | the C screw at (19, 45) (it goes to the tray, then jumps to C's box) |
| 4 | Covered screws | "Covered screws are stuck. Free the plank on top." | back bar (layer 1) at y 45 with A A B at x 19, 43, 67; front upright bar (layer 0) from (43, 21) to (43, 69), width 12, screws A and B, covering the middle back screw; a B disc at (67, 21) | A B | 2 / 50 s | 0 | the covered screw (wiggle), then the front bar's screws |
| 5 | A plank falls | "Take out every screw and the plank falls." | front plate (layer 0) 23 to 63 by 28 to 66 with three A screws; back bar (layer 1) at y 47 with C B B B C, the three B under the plate; a C disc at (13, 80) | A C B | 2 / 65 s | 0 | the plate's three screws |
| 6 | A plank swings | "With one screw left, a plank swings." | two front bars at y 24 and y 76 (x 25 to 61), screws A A and B B at the ends; behind each bar's middle a disc: B at (43, 24), A at (43, 76) | A B | 2 / 50 s | 0 | the right screw of the top bar (it swings down from (25, 24) and frees the B disc) |
| 7 | The box queue | "The next boxes are shown. Plan ahead." | four upright bars at x 13, 33, 53, 73, screws at y 25, 45, 65: C A D, B D A, A C B, D B C | A B C D | 1 / 85 s | 0 | none (a steady ring on the preview) |
| 8 | Undo | "Tapped the wrong one? Try Undo." | front uprights at x 25 (A top, B bottom) and x 61 (B top, A bottom), y 21 and 69; back bar (layer 1) at y 45 with C at x 25, 43, 61 (the outer two covered); D discs at (43, 21), (43, 69), (43, 84); an A disc at (73, 84) and a B disc at (13, 84) | A B C D | 1 / 85 s | 0 | none (the ring on Undo, after the helper sheet) |

- Par time for tutorials is 10 s plus 6 s per screw, rounded up to 5. Level 1 has 3 screws, so
  30 s, which also matches the "level 1 in under 30 seconds" check.
- Level 7's tray par of 1 is the point of the level: the Clean star asks the player to use the
  preview. Level 8 gives 2 Undos; using one costs the Clean star (decision 1).
- Hint lists name screws as [plank, hole] in file order (UX's `hint` field, section 9.3).
- **Phase 2 changes, and why.** Level 3's bars stand upright instead of lying flat: a flat bar
  left on its end screw swung down across the bars below it and was drawn over their free
  screws. An upright bar only ever hangs straight down or flips below its last screw. Level 5's
  C disc moved from just below the plate to the bottom left corner: the plate, left on its
  bottom screw, turned over and hung across the disc. Level 6's bars are shorter and further
  apart for the same reason. The ideas, lines, counts and par numbers are unchanged.
- Each file's `name` is the Idea column.

**Checks on the files** (from my scratch model, which counts states its own way; the engine's
solver counts fewer on the levels that use the tray, 512, 192, 4047 and 2295 for levels 3, 5, 7
and 8, but gives the same fewest tray uses and novice result on all eight):

| Level | Screws | Reachable states | Fewest tray uses | Losing states | First tap fits a box (G5) | Novice policy |
|-|-|-|-|-|-|-|
| 1 | 3 | 8 | 0 | 0 | yes | wins |
| 2 | 6 | 64 | 0 | 0 | yes | wins |
| 3 | 9 | 708 | 0 | 0 | yes | wins |
| 4 | 6 | 48 | 0 | 0 | yes | wins |
| 5 | 9 | 318 | 0 | 0 | yes | wins |
| 6 | 6 | 49 | 0 | 0 | yes | wins |
| 7 | 12 | 16191 | 0 | 0 | yes | wins |
| 8 | 12 | 8079 | 0 | 0 | yes | wins |

## 9. Data formats

docs/ARCHITECTURE.md section 3 points here for blueprints and tutorial levels. Plain JSON, no
comments, integers only (the tuning file has a few decimal seconds), coordinates in grid units
(4 du).

### 9.1 Blueprint

An example showing all four shapes (data/blueprints/ holds the real files):

```json
{
  "format": 1,
  "id": "example",
  "name": "Format example",
  "kind": "pattern",
  "board": [86, 90],
  "planks": [
    {"layer": 0, "shape": "poly", "points": [[3, 42], [43, 6], [83, 42]], "holes": [[43, 18], [29, 34], [57, 34]]},
    {"layer": 1, "shape": "bar", "path": [[68, 6], [68, 20]], "width": 10, "holes": [[68, 8], [68, 20]]},
    {"layer": 0, "shape": "disc", "center": [20, 58], "radius": 7, "holes": [[20, 58]]},
    {"layer": 2, "shape": "ring", "center": [29, 31], "radius": 17, "inner": 6, "holes": [[17, 31], [29, 19]]}
  ]
}
```

- `format` 1. `id` is lowercase letters, digits and hyphens, the same as the file name.
  `name` is for reports. `kind` is `silhouette` or `pattern`. `board` is always [86, 90].
- `planks` in any order; a screw is named [plank index, hole index] in file order.
- No colors: the generator assigns them.

### 9.2 Blueprint rules (the validator checks these)

- **B1.** `format` 1, `board` [86, 90].
- **B2.** 1 to 16 planks; layers start at 0 and have no gaps; at most 5 (0 to 4).
- **B3.** Every plank has at least one hole. The total is a multiple of 3, from 9 to 36.
- **B4.** Every hole is inside x 6 to 80, y 6 to 84.
- **B5.** Every pair of holes is at least 12 units (48 du) apart, center to center.
- **B6.** Every hole sits at least 4.5 units (18 du) inside its own plank (the 14 du head plus
  a 4 du rim of wood). Bars and ring bands are at least 10 wide.
- **B7.** Every plank lies inside the core (0 to 86 by 0 to 90) as authored.
- **B8.** Planks in the same layer do not overlap.
- **B9.** A plank with one hole is at rest: its centroid is within 0.5 units of straight below
  the hole (or on it).
- **B10.** Clear covering at the start: for every screw and every plank in front of it, d is at
  most 0 (the screw's center is under wood, so it is plainly covered) or at least 5.5 (a gap of
  at least 8 du between head and wood, so it is plainly free). Nothing in between.
- **B11.** Safe swings: for every plank with two or more holes and every one of its holes as
  pivot, in the rest pose (R16), every screw behind it has |d - 3.5| of at least 0.25 units.
  (Rest poses are fixed per plank and pivot, so this is a finite, static check.)
- **B12.** At most 24 screws free at the start; at most 3 planks over any screw.
- **B13.** The margin around R16's cutoff (ARCHITECTURE.md section 2): for every plank and every
  one of its holes as pivot, the distance r from the pivot to the centroid is below 0.25 or
  above 0.75 units, never in between, so no phone can disagree about whether it turns.

**Planks hanging below the core: a view rule, not a B14** (asked for in Phase 3 review; I
propose this instead, waiting for the lead and Bart). A plank on its last screw hangs straight
below it (R16), so a long plank near the bottom hangs far below the 90 gu core: in level 40 the
weave's full width bar (86 gu long) hangs from (67, 55) down to y 122. On the base phone UX
3.2.1 leaves no room for that: the board panel is exactly the core, with 8 units (2 gu) of gap
above, below and at each side before the tray, the helper bar or the screen edge. I measured the
reach of every rest pose (BoardGeometry's `hang_outline` for every screw, the furthest vertex
outside x 0 to 86, y 0 to 90):

| Allowed reach outside the core | 1 gu | 2 gu | 15 gu (the tall phone's extra back board) | 30 gu | 45 gu |
|-|-|-|-|-|-|
| Files that fail, of 43 blueprints and 8 tutorials | 49 | 49 | 47 | 35 | 27 |

Every tutorial fails, and so would almost any picture with a long plank near the bottom (bases,
hulls, branches, rails, shelves): the worst reach is 91 gu. A data rule tight enough to keep
poses on the base phone's board would mean redrawing nearly the whole library and losing most of
its long planks, and it would still not cover the fall (planks drop off the board, R17) or the
swing's overshoot, which are drawn outside the core anyway. Below the core a plank covers
nothing (there are no screws there), so this is purely a drawing question. So the rule goes to
the view:

- **V1.** The board view draws planks (resting, hanging, swinging and falling) clipped to the
  board panel of UX 3.2.1 (on the base phone exactly the core; on taller phones the panel with
  its extra back board), and the top bar, boxes, tray and helper bar are drawn above the board
  layer. A hanging plank is cut off at the panel's edge and never covers a bar or a button.
- The logic and the rules are unchanged; the validator gets no new check.

**House rules I hold my own blueprints to** (stricter than B1 to B13, not checked by the game):
a one hole plank has its centroid exactly on the vertical through its hole (or on the hole), and
a covered screw is at least 2 units (8 du) under the wood that covers it. The Phase 1 ten keep
their shallower covered screws (fish, tree, rings, sailboat and windmill), which Bart saw at
Hard Stop 1.

### 9.3 Tutorial level

A blueprint plus play data. `kind` is `tutorial`.

```json
{
  "format": 1,
  "id": "tutorial-4",
  "name": "Covered screws",
  "kind": "tutorial",
  "board": [86, 90],
  "planks": [
    {"layer": 0, "shape": "bar", "path": [[43, 21], [43, 69]], "width": 12, "holes": [[43, 21], [43, 69]], "colors": [0, 1]},
    {"layer": 1, "shape": "bar", "path": [[19, 45], [67, 45]], "width": 10, "holes": [[19, 45], [43, 45], [67, 45]], "colors": [0, 0, 1]},
    {"layer": 0, "shape": "disc", "center": [67, 21], "radius": 6, "holes": [[67, 21]], "colors": [1]}
  ],
  "queue": [0, 1],
  "tray_par": 2,
  "par_time": 50,
  "line": "Covered screws are stuck. Free the plank on top.",
  "hint": [[1, 1], [0, 0], [0, 1]]
}
```

- `colors` lists each hole's color as a palette index (0 to 7; DESIGN.md section 3.2 has the
  order), in hole order.
- `queue` lists the boxes in order by color index; each color appears (its screws / 3) times.
- `par_time` in seconds, `tray_par` in tray uses, `line` may be "" (no line), `hint` is the
  order of screws the hand points at, as [plank, hole].
- Tutorial levels pass B1 to B13 except the 9 screw minimum (level 1 has 3, levels 2, 4 and 6
  have 6).

### 9.4 Tuning: data/tuning.json

ARCHITECTURE.md section 3.3 gives the format. Every number in it is in this document, and this
document wins if they ever differ:

| Key | Section here |
|-|-|
| `tray_size`, `open_boxes`, `box_slots`, `preview`, `tutorial_levels` | 3 |
| `tiers` (screws, colors, layers, tray uses, novice policy, covered at start) | 6.1 |
| `sawtooth` | 6.3 |
| `tray_par_slack`, `par_time` | 3, 4 (S7, S8) |
| `daily`, `relaxed` | 6.6 |
| `helpers` | 5 |
| `unlocks`, `modes_open_after_level` | 7 |
| `recent_blueprints_excluded` | 6.4 (G7) |

## 10. The blueprint library

There are 43 blueprints in data/blueprints/: ten from Phase 1, thirty added in Phase 2 and three
added in Phase 3, each an original picture or pattern. "Suits tiers" means
`LevelCatalog.suits_tier` accepts the blueprint as authored: its screw count and layer count are
inside the tier's ranges (section 6.1), and it has enough covered screws for the tier's tray uses
(the cover rule, G8 in section 6.4). The generator's variations (a dropped plank) can reach a
neighboring tier too. The table is sorted by screws.

| Blueprint | Picture | Kind | Screws | Planks | Layers | Free at start | Covered at start | Suits tiers | Added |
|-|-|-|-|-|-|-|-|-|-|
| heart | Heart | silhouette | 9 | 2 | 2 | 9 | 0 (0%) | 1 | Phase 2 |
| kite | Kite | silhouette | 9 | 4 | 2 | 9 | 0 (0%) | 1 | Phase 2 |
| mug | Mug | silhouette | 9 | 4 | 2 | 9 | 0 (0%) | 1 | Phase 2 |
| mushroom | Mushroom | silhouette | 9 | 5 | 2 | 9 | 0 (0%) | 1 | Phase 2 |
| signpost | Signpost | silhouette | 9 | 4 | 2 | 8 | 1 (11%) | 1 | Phase 2 |
| flower | Flower | silhouette | 12 | 11 | 2 | 12 | 0 (0%) | 1, 2 | Phase 2 |
| target | Target | pattern | 12 | 3 | 1 | 12 | 0 (0%) | 1 | Phase 2 |
| car | Car | silhouette | 15 | 7 | 3 | 13 | 2 (13%) | 2, 3 | Phase 2 |
| fish | Fish | silhouette | 15 | 9 | 3 | 11 | 4 (27%) | 2, 3 | Phase 1 |
| house | House | silhouette | 15 | 6 | 2 | 12 | 3 (20%) | 2, 3 | Phase 1 |
| sailboat | Sailboat | silhouette | 15 | 7 | 3 | 13 | 2 (13%) | 2, 3 | Phase 1 |
| snowman | Snowman | silhouette | 15 | 9 | 3 | 14 | 1 (7%) | 2, 3 | Phase 2 |
| windmill | Windmill | silhouette | 15 | 7 | 4 | 10 | 5 (33%) | 3 | Phase 1 |
| bridge | Bridge | silhouette | 18 | 5 | 4 | 14 | 4 (22%) | 3, 4 | Phase 1 |
| lighthouse | Lighthouse | silhouette | 18 | 9 | 4 | 16 | 2 (11%) | 3 | Phase 1 |
| owl | Owl | silhouette | 18 | 7 | 4 | 13 | 5 (28%) | 3, 4 | Phase 2, covered more in Phase 3 |
| pagoda | Pagoda | silhouette | 18 | 9 | 4 | 15 | 3 (17%) | 3, 4 | Phase 2 |
| rocket | Rocket | silhouette | 18 | 15 | 3 | 17 | 1 (6%) | 3 | Phase 2 |
| tree | Tree | silhouette | 18 | 7 | 3 | 15 | 3 (17%) | 3, 4 | Phase 1 |
| balloon | Hot air balloon | silhouette | 21 | 9 | 4 | 16 | 5 (24%) | 4, 5 | Phase 2, covered more in Phase 3 |
| barn | Barn | silhouette | 21 | 10 | 4 | 17 | 4 (19%) | 4, 5 | Phase 2 |
| rings | Rings | pattern | 21 | 10 | 5 | 17 | 4 (19%) | 5 | Phase 1 |
| train | Train | silhouette | 21 | 10 | 3 | 16 | 5 (24%) | 4, 5 | Phase 2, covered more in Phase 3 |
| bricks | Brick wall | pattern | 24 | 10 | 4 | 12 | 12 (50%) | 5, 6 | Phase 1 |
| butterfly | Butterfly | silhouette | 24 | 8 | 4 | 19 | 5 (21%) | 5, 6 | Phase 2, covered more in Phase 3 |
| crane | Tower crane | silhouette | 24 | 8 | 5 | 21 | 3 (13%) | 5, 6 | Phase 2 |
| weave | Weave | pattern | 24 | 8 | 3 | 20 | 4 (17%) | 5, 6 | Phase 2 |
| castle | Castle | silhouette | 27 | 10 | 4 | 19 | 8 (30%) | 6, 7 | Phase 2, covered more in Phase 3 |
| crates | Crates | pattern | 27 | 9 | 5 | 19 | 8 (30%) | 6, 7 | Phase 2, covered more in Phase 3 |
| ladybug | Ladybug | silhouette | 27 | 11 | 4 | 17 | 10 (37%) | 6, 7 | Phase 3 |
| robot | Robot | silhouette | 27 | 16 | 4 | 20 | 7 (26%) | 6, 7 | Phase 2, covered more in Phase 3 |
| steamboat | Steamboat | silhouette | 27 | 12 | 4 | 21 | 6 (22%) | 6, 7 | Phase 2, covered more in Phase 3 |
| dominoes | Dominoes | pattern | 30 | 14 | 5 | 20 | 10 (33%) | 7, 8 | Phase 2 |
| skyline | City skyline | silhouette | 30 | 6 | 4 | 22 | 8 (27%) | 7, 8 | Phase 2 |
| ziggurat | Step temple | silhouette | 30 | 5 | 5 | 21 | 9 (30%) | 7, 8 | Phase 2 |
| bookshelf | Bookshelf | silhouette | 33 | 16 | 4 | 22 | 11 (33%) | 8, 9, 10 | Phase 2 |
| catface | Cat | silhouette | 33 | 7 | 4 | 23 | 10 (30%) | 8, 9, 10 | Phase 2 |
| falling-blocks | Falling blocks | pattern | 33 | 13 | 5 | 23 | 10 (30%) | 8, 9, 10 | Phase 2 |
| ferris-wheel | Ferris wheel | silhouette | 33 | 15 | 5 | 19 | 14 (42%) | 8, 9, 10 | Phase 3 |
| jellyfish | Jellyfish | silhouette | 33 | 11 | 5 | 24 | 9 (27%) | 8, 9, 10 | Phase 2 |
| lattice | Lattice | pattern | 33 | 7 | 4 | 24 | 9 (27%) | 8, 9, 10 | Phase 1 |
| ship-wheel | Ship's wheel and lifebuoys | silhouette | 33 | 9 | 5 | 21 | 12 (36%) | 8, 9, 10 | Phase 3 |
| tiles | Tiles | pattern | 36 | 9 | 5 | 20 | 16 (44%) | 9, 10 | Phase 2 |

**How many blueprints each tier can use, as authored** (measured with `LevelCatalog.suits_tier`,
section 10.1):

| Tier | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|-|-|-|-|-|-|-|-|-|-|-|
| Before Phase 3 (with the cover rule) | 7 | 6 | 12 | 4 | 5 | 5 | 3 | 8 | 6 | 6 |
| Now | 7 | 6 | 12 | 7 | 8 | 9 | 8 | 10 | 8 | 8 |

G7 itself needs only two boards per tier, but the more a tier has, the longer a player goes
before seeing the same board at that tier again. From level 151 tiers 6 to 10 come once every
five levels, and they now share 20 different blueprints (14 before). The daily (tier 6) has 9
boards, so a board comes back about every 9 days instead of every 6.

### 10.1 Phase 3 changes: covering for the middle and hard tiers

Why: under the cover rule (G8), a tier that needs k tray uses only takes blueprints with at least
2k + 1 screws covered at the start, so tiers 4 to 6 needed 3 covered and tiers 7 to 10 needed 5
or 7. Robot, train and balloon had none covered and butterfly and steamboat two, so those five
suited no tier at all and the owl (one covered) only tier 3; tier 7 had only 3 boards, and hard levels repeated
boards (Hard Stop 2 bot run: levels 159, 169 and 179 were the same stored bookshelf level).

What changed (pictures in build/blueprints-p3/, before and after):

| Blueprint | Screws (was) | Covered (was) | What covers what now |
|-|-|-|-|
| castle | 27 (27) | 8 (4) | pointed roofs on both towers cover the towers' top screws; the wall rises in front of the keep and covers its two lower screws |
| crates | 27 (27) | 8 (4) | the top crate is wider and covers two screws of the crates beside it; the left and right stacks reach further and cover one each |
| robot | 27 (21) | 7 (0) | a visor and a mouth plate cover the head's two screws; the arms start under the torso; the chest panel and a belt cover three torso screws; two antennae and two ears are new |
| steamboat | 27 (24) | 6 (2) | a deck rail covers the cabin's three lower screws; a wheelhouse stands behind the cabin with one screw under it; the funnels still cover the cabin's top screws |
| ladybug (new) | 27 | 10 | the shield in front of the head covers one head screw and one body screw; the wing cases cover two body screws and, with the body, the inner screws of all six legs |
| butterfly | 24 (24) | 5 (2) | the forewings overlap the hindwings and cover one screw each; the body covers the screw where the antennae meet |
| train | 21 (21) | 5 (0) | a crate on the wagon covers two wagon screws; the coupling bar covers one screw of the engine and one of the wagon; the engine covers the chimney's lower screw |
| balloon | 21 (21) | 5 (0) | the envelope covers the tops of the two ropes; the middle stripe covers two envelope screws; a small cloud covers the sun |
| owl | 18 (18) | 5 (1) | big eyes cover one body screw each; the body covers three branch screws |
| ferris-wheel (new) | 33 | 14 | the hub covers the six inner spoke screws and the rim covers the six outer ones; the base covers both feet of the stand; eight cabins ring the wheel |
| ship-wheel (new) | 33 | 12 | the hub covers the six inner spoke screws, and the three spokes cover six of the rim's twelve; four lifebuoys fill the corners |

- The three new boards are round, so the hard tiers no longer look like rows of rectangles
  (tiles, falling blocks, cat, skyline, step temple, dominoes, lattice).
- The Ferris wheel and the ship's wheel are built alike (a hub, a rim and three spokes that cross
  in the middle) but play differently: on the Ferris wheel the rim is in front and locks the outer
  spoke screws until all six rim screws are out; on the ship's wheel the spokes are in front and
  each spoke that falls frees two rim screws.
- Robot, steamboat, castle, crates and the ladybug serve tiers 6 and 7; the Ferris wheel and the
  ship's wheel serve 8 to 10. Train, balloon, owl and butterfly stay medium boards (tiers 3 to 6):
  tiers 4 and 5 needed boards as badly as tier 7 did, and those four pictures are too small to
  hold 27 screws and stay readable.
- Every picture keeps its idea and its outline; nothing is taken from any reference game.

**How I checked.**

- The engine's validator (src/logic/blueprint_validator.gd, `bash tools/test.sh validator`)
  passes all 43 blueprints and the 8 tutorials.
- My house rules hold for all eleven boards: every covered screw is at least 2 units (8 du)
  under its wood, and every one hole plank hangs exactly on the vertical through its hole.
- B11 margin: in every rest pose of the eleven boards, no screw comes within 0.44 units (1.8
  du) of the covering threshold. The closest in the whole library is still the windmill (0.32
  units).
- The counts above come from a scratch script that calls `LevelCatalog.suits_tier` for every
  blueprint and tier, before and after the change.

### 10.2 Phase 2 checks and notes (still true)

**What I checked, and how.** Every file was checked by my scratch validator (Python, outside the
repo) against B1 to B13 and my house rules (section 9.2), and drawn and looked at. B11 and B13
were checked for every plank and every hole as pivot. The engine's validator in
src/logic/blueprint_validator.gd, run headless on the same files, also passes all forty and all
eight tutorials.

- No two screws closer than 48 du anywhere in the library; the thinnest wood rim around a hole is
  18 du (B6's minimum).
- In the thirty new blueprints, every covered screw is at least 8 du under its wood and every
  one hole plank hangs exactly on the vertical through its hole. The Phase 1 ten keep their
  shallower covered screws (fish 2.8 du, tree 2.9, rings and sailboat 4.0, windmill 5.1).
- B11: in every rest pose of the new blueprints, no screw comes within 1.4 du (0.36 units) of
  the covering threshold; across the whole library the closest is 1.3 du (windmill).
- B13: the closest r to the forbidden band is 0.79 units (the car body hanging on its middle
  hole). Bars with three or more points that hang near their centroid (the kite's tail, the
  barn's Z braces) are point symmetric about their hole, so r is exactly 0 however the arcs are
  flattened.

**Changes to the Phase 1 ten.** Free screws at the start are unchanged for all ten.

- fish: the bottom fin's top edge moved up one unit, so its one hole sits on the centroid. Before,
  r was 0.667, inside B13's band.
- bricks: the four side bricks are 18 wide and centered on their holes. Before, the centroid was
  half a unit to the side of the hole: B9 allowed it, but the plank was not truly at rest.
- lattice: the middle cross bar moved to its own layer, so lattice has four layers and suits
  tiers 8 to 10. With three layers it suited no tier.

**What the engine and the tiers will find hard.**

- **Tray pressure must come from coloring.** The new dense blueprints cover 27 to 44 percent of
  their screws at the start (most of the mid ones 0 to 20). That is enough for order to matter,
  but tiers 7 to 10 ("must lose" for the novice, 2 to 5 fewest tray uses) will mostly come from
  coloring with intent: early free screws in colors late in the queue (section 6.5).
- **Search size.** Tiles (36 screws), bookshelf (33 screws on 16 planks) and the other 33 screw
  blueprints are the largest searches. They are where `max_states` will bite first.
- **A hanging plank can be drawn over a free screw of its own layer.** Same layer planks never
  cover each other (R8), but after a swing a plank can hang across another plank's screw on the
  same layer. 24 blueprints have at least one such pose (19 in Phase 2: target 12, bricks 10,
  bookshelf 8, skyline 6, sailboat 5; the Phase 3 boards add the ship's wheel 14, the Ferris
  wheel and the ladybug 10 each, and fewer in the rest); no tutorial has one. The renderer
  should draw every screw above every plank of its own layer, so the screw stays visible and
  tappable, as the rules say.
- **Hanging planks reach below the core.** Most blueprints have a pose (a long bar flipping
  under its last screw) that hangs below the bottom edge of the core. That is drawing only (UX
  3.2.1), but the board view must not clip it oddly.
- **Few planks, many holes.** Step temple has 5 planks (one with 12 holes) and the cat 7 (its
  head has 14), so those planks only swing near the end. That is fine for play, but a generator
  variation that drops such a plank removes many screws at once and leaves its tier.

## 11. Fun checklist

From the brief:

1. First minute: level 1 is cleared in under 30 seconds, with no reading.
2. Every tap answers within 100 ms, with motion and sound.
3. No dead taps: a covered screw shows what covers it.
4. Tray pressure is visible: slots fill, and there is a warning at one free slot.
5. Fair failure: every loss traces back to choices the player could see.
6. Fast retry: from a loss to playing again in under 2 seconds.
7. A plank falling is the best moment, and it looks and sounds great.
8. A box closing feels like a small win every time.
9. Breathers follow hard levels.
10. Mid game levels take 1 to 3 minutes.
11. No two levels in a row look alike.
12. From level clear to the next level in one tap.

Added by the designer:

13. Look first: nothing on the board moves and the clock waits until the first tap.
14. The first tap of a level never has to go to the tray (G5).
15. Hard means order, not hunting: at most 24 free screws, nothing more than 3 planks deep, and
    covering that is never a near miss (B10).
16. A swing that covers or uncovers a screw changes that screw's look at the tap.
17. An auto jump out of the tray reads as a chain, one screw at a time, left to right.
18. Every star is explained: the clear screen shows each star's target.
19. Helpers are a choice: no level needs one, and the bots prove it.
20. A refused tap (tray full) says why, and costs nothing.

## 12. Acceptance list for QA

Walk these on Windows (tests and bots) and on the phone. Each item names how to check it.

**Rules (unit tests in tests/logic, one or more per rule)**

1. R7 to R9: covering, including E1, a ring's inner hole not covering, and same layer planks
   not covering.
2. R10: on random generated levels, every state with screws on the board has a free screw.
3. R12: destination order, including E7 and the tray's leftmost empty slot after a gap.
4. R13: the resolution order, checked by a tap that both drops a plank and closes a box.
5. R16: rest angles for E2 (0 and 180 degrees) and E3 (+90 degrees), and no turn for a disc
   held at its center.
6. R17: a fallen plank never covers.
7. R18 to R21: E4 and E5, and a queue that runs out.
8. I1: holds after every tap of 1000 generated levels played by the random bot.
9. R22 and R23: E6, and the win check coming before the loss check.
10. R25: a refused tap changes nothing and does not start the clock.
11. R26 to R29: undo after a box closes, after a plank falls, after a swing, after a cascade,
    after a loss, and five undos in a row back to the start.
12. R30 and R31: Extra slot once per attempt; Screwdriver on a covered screw; Screwdriver
    refused and not spent when there is nowhere to go; undo after Screwdriver.
13. R34: Retry gives an identical level and resets clock, tray uses and Extra slot.
13a. R36: quitting mid level and pressing Play restarts the same level from the beginning; a
    brand new install opens straight into level 1.
13b. R37: the out of room sheet shows exactly the owned, usable helpers (Undo; Extra slot if
    not used this attempt; Screwdriver if some screw fits an open box), each clears the loss,
    and the sheet never offers a purchase.
13c. R38: a helper at count 0 asks "Get and use" only after the player taps it, and never in
    Relaxed.

**Data**

14. Every file in data/blueprints/ passes B1 to B13, and its id is its file name.
15. Every tutorial level passes B1 to B13 except the 9 screw minimum, is solvable, has no
    reachable losing state, and its fewest tray uses matches section 8 (0 for all eight).
15a. data/tuning.json loads, and every number in it matches section 9.4's sections.

**Stars and economy**

16. S2 and S6: Fast earned at exactly par, missed at par plus one second; the clock waits for
    the first action and stops in pause and dialogs.
17. S3: Clean lost by one tray use over par, and by any helper.
18. S5: a replay with more stars adds only the difference; a replay with fewer adds nothing.
19. Prices are 4, 6, 8; each helper arrives with 2 free on levels 8, 15 and 25, once only.
20. Bot data per band matches section 5 within a factor of 1.5, or the designer is told.

**Difficulty**

21. tier(N) matches section 6.3 for levels 9 to 30 and 151 to 160.
22. 100 generated levels per tier pass G1 to G7, and G9a on tiers 7 and 8. The report gives
    the fallback rate, the novice survival and the last tray use position per tier next to it.
22a. G8: `LevelCatalog.suits_tier` gives section 10's "Suits tiers" column for every
    blueprint, and every tier from 7 to 10 has at least 8 suitable blueprints.
23. The novice policy wins every tier 1 to 3 level and loses every tier 7 to 10 level (G4).
    The greedy novice bot's win rates per tier are reported next to it.
24. No level shows more than 36 screws, 8 colors, 5 layers or 24 free screws at the start.
25. On every reachable state of the solver's solution path, free screws are at least 48 du
    apart (UX 7.3 test).

**Modes and unlocks**

26. Daily is tier 6, the same for two installs on the same date and version, opens after level
    8, and the streak follows section 6.6 (consecutive days, a skipped day, the clock moved
    back).
27. Relaxed: right tier range per choice, no stars, free unlimited Undo, the stuck sheet at a
    would be loss.
28. Each unlock in section 7 appears at its milestone and survives a restart.

**Fun checks (Gate playtests and the designer's review)**

29. Level 1 cleared in under 30 seconds by a new player, no text read.
30. A hard level is followed by a breather in the level list (tiers 10 to 11, 15 to 16, ...).
31. The fun checklist in section 11, item by item, with notes.

## 13. Notes for the other roles

- **ux-designer.** Answers to your questions: helpers appear on levels 8, 15 and 25; the
  timer, pips and star bank from level 4; tutorial lines on levels 2 to 8 as in your table;
  band names Easy, Medium, Hard, Expert; unlocks in section 7; Extra slot once per attempt.
  New items for you: a refused tap needs feedback (R25), Daily and Relaxed are locked until
  level 8 (they need a short note on the title buttons), the `hint` field is in 9.3, and the out of room sheet now lists every owned, usable helper
  (R37), not only Undo.
- **level-engine-dev.** Rules R1 to R38, worked examples E1 to E7, generator rules G1 to G9,
  the novice policy, and B1 to B13 for variations. Please round turned vertices to a fixed
  precision (R17 note). Higher tiers will need coloring with intent (section 6.5). Phase 2:
  the tier layer ranges changed (6.1), covered at start is a report, not a filter, the
  sawtooth steps are indexed by (N - 1) mod 5 (6.3), and tutorials 3, 5 and 6 moved some planks
  (8). Tutorial `hint` entries are [plank, hole] in the file. Phase 3: the cover rule is written
  down as G8 and the soft step as G9 (6.4, 6.4.1); eight blueprints changed and three are new
  (10.1), so `GENERATOR_VERSION` goes to 4, the golden fingerprints are renewed, the fallback
  levels are rebuilt (tiers 7 to 10 must pass G9), and the expected table in
  tests/logic/test_validator.gd (`test_b12_shipped_blueprints_free_at_start_match_the_gdd`)
  takes its numbers from section 10's table.
- **graphic-designer.** The palette needs at least 8 screw colors usable in one level. Plank
  outlines drawn by the renderer must match the logic outline (section 1.2). Please draw every
  screw above every plank of its own layer: after a swing, a plank can hang across a free screw
  of the same layer (section 10).
- **gameplay-dev, graphic-designer and ux-designer.** View rule V1 (section 9.2): planks are
  drawn clipped to the board panel and under the bars, because a hanging plank can reach up to
  91 gu outside the core (for example level 40's weave bar, down to y 122).
- **qa-tester.** Section 12, and bot reports per tier group so section 5's table can be
  checked.
