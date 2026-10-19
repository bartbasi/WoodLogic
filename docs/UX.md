# WoodLogic UX

Owner: ux-designer. Status: updated after Hard Stop 1 (the GDD is approved and Bart chose the
Workshop look, docs/design/directions.md).
Anything that depends on a number the game designer owns is tagged `[C:name]` (a layout count)
or `[GDD]` (a value that comes from docs/GDD.md, now filled in). When those change, search
this file for the tag.

Writing rules for every string in this file: plain words, no em dashes, no double hyphens,
English only. Text in `{braces}` is filled in by the game. Strings are shown in quotes and are
word for word.

## 0. Contents

1. Global rules (units, layout classes, safe areas, type, components)
2. Counts that drive the layout
3. Screens (title, level, pause, level clear, out of room, levels list, stats, settings, about,
   license, credits, relaxed setup, helper explanations and the helper buy dialog)
4. Flows and the Android back button
5. The first-time experience and tutorial lines
6. Feedback for every input
7. Accessibility
8. What this file needs from the other roles
9. Review checklist
10. Decided by Bart
11. Open questions for Bart

## 1. Global rules

### 1.1 Units and layout classes

- Everything is in design units. The base viewport is 360 x 640. Stretch mode is
  `canvas_items`, aspect `expand`. The viewport grows taller on tall phones and wider on tablets,
  and the scale stays the same in the other direction.
- On a phone 360 dp wide or wider, one unit is at least one dp. A 48 unit target is at least
  48 dp.
- **Content rect.** All layouts below are given in content coordinates: x from the left edge of
  the content rect, y from its top edge. The content rect is the viewport minus the safe-area
  insets (section 1.2). On the level screen it is the whole rect (the board scales into it,
  section 3.2.1a). On every other screen it is no wider than 480 units, centered when the
  viewport is wider.
  Backgrounds, wood and shadows are full bleed, behind the insets. Controls and text stay
  inside the content rect.
- The budget numbers assume a top inset of 24 units and a bottom inset of 16, so the content
  rect of a 360 x 640 screen is **360 x 600**. If the real insets are larger, flexible gaps
  absorb up to 12 units; past that, the top bar shrinks from 44 to 40 and the pause button keeps
  its 48 unit target by growing into the gap. The board never shrinks.
- **Bottom half** means y 300 and below in a 600 tall content rect (the lower half of the
  content rect on any height). Every primary button lives there.

| Class | Viewport (units) | Where it appears | What changes |
|-|-|-|-|
| Base | 360 x 640 | small and older phones, 16:9 | the reference layout |
| Tall | 360 x 641 to 360 x 840 | 18:9, 19.5:9, 20:9, 21:9 phones | extra height, see section 3.2 and each screen's "Tall" note |
| Wide | 361 x 640 to 480 x 640 (aspect up to 3:4) | tablets in portrait | level screen: stacked, the board view scales up and the bars shrink to make room (3.2.1a). Other screens: column up to 480, buttons at most 320 wide |
| Beyond | aspect wider than 3:4, or wider than 480 units | unfolded foldables, near square windows | level screen: stacked or split, whichever gives the larger board (3.2.1a). Other screens: column fixed at 480, centered, the sides show only the background |

A tablet shows everything at a larger physical size because the height sets the scale there.
The level screen uses that extra room (section 3.2.1a); other screens do not need to.
Nothing is laid out for landscape; the game is portrait only, and a near square or wide window
(an unfolded foldable) is treated as the Beyond class.

### 1.2 Safe areas

- Read the safe area from the display (`DisplayServer.get_display_safe_area()`) and convert it
  to viewport units. Re-read it when the window changes.
- Controls and text stay inside the safe rect plus a margin of 12 units on each side.
- Primary buttons keep at least 8 units above the bottom safe edge, so a gesture bar swipe
  does not hit them.

### 1.3 Type

The font is Godot's default. All text sits on a plaque (a solid or near solid panel, never
bare wood or the textured board), so contrast does not depend on the wood theme.

| Style | Size (units) | Weight | Used for |
|-|-|-|-|
| Display | 32 | bold | title screen name, nothing else |
| Heading | 24 | bold | screen titles, sheet headings |
| Button primary | 22 | bold | Play, Next, Retry, Resume |
| Button | 18 | bold | all other buttons and row labels |
| Tutorial line | 18 | bold | the line under the board |
| Body | 16 | regular | sentences, dialog text, About |
| Small | 14 | regular | row notes, legal text, stat captions |
| Caption | 13 | regular | the smallest allowed: helper names, star captions, coffee chip |

No text is smaller than 13 units. Numbers use the font's tabular digits if it has them, so the
timer does not jitter.

### 1.4 Shared components

Sizes are minimums. Look comes from docs/DESIGN.md.

- **Button.** Height at least 48. Primary 72 tall (title Play, Next) or 64 tall (Retry,
  Resume). Width 296 when full width (a 360 wide screen with 32 side margin) or 144 when two
  share a row with an 8 gap. Four kinds: primary (filled, strong), secondary (filled, calm),
  quiet (outline or text, used for Back and Coffee), danger (used only for "Erase everything").
  States: normal, pressed (down: scale 0.96, darker, within one frame), disabled (dimmed and
  its reason is visible as text or an icon), focused (a visible outline of at least 3 units for
  keyboards and gamepads). A button acts on release. A finger that slides off the button
  cancels it.
- **Back button.** Every screen opened from the title ends with a quiet full width Back button
  at the bottom (336 x 48, 8 above the bottom edge of the content rect). The title bar of those
  screens has no back arrow, because the top is out of thumb reach.
- **Toggle row.** The whole row is the target (full width x 56). It shows a label, an optional
  note, a switch 56 x 32 and the words "On" or "Off" beside the switch, so state is never only
  color or position.
- **Sheet.** A panel that slides up from the bottom edge (250 ms, ease out). The board stays
  visible and dimmed above it. Used for out of room and for helper explanations.
- **Dialog.** A centered panel 304 wide for a short question, with buttons stacked in the
  bottom half of the panel. The background dims by 55 percent. Used for reset and for buying a
  helper.
- **Toast.** A one line plaque 24 units above the bottom edge, shown 2 seconds, never blocks a
  tap. Only one at a time; a new one replaces the old.
- **Plaque.** The solid panel behind any text. Contrast rules in section 7.2.
- **Star icon.** A five point star: filled means earned, outline only means not earned. The two
  differ in shape, not only color.

### 1.5 Motion rules

- Every button press answers in the same frame it is pressed.
- Screen changes are a 150 ms fade or a 250 ms slide. Never faster than that, never a flash.
- No looping motion faster than one cycle per second. No brightness jump over a large area.
  Nothing flashes (section 7.5).

## 2. Counts that drive the layout

Defaults from the brief. The game designer may change them in the GDD. If one changes, the
layouts tagged with it must be redone by the ux-designer; do not just stretch them.

| Tag | Meaning | Default | Layout that depends on it |
|-|-|-|-|
| `[C:open]` | open boxes at once | 2 | boxes row (3.2.2), box width, the out of room rule |
| `[C:slots]` | slots per box | 3 | open box width 92 (3 wells of 24 + gaps), lid closes on slot 3, preview box |
| `[C:prev]` | boxes previewed in the queue | 2 | preview boxes 62 wide each, boxes row total width |
| `[C:tray]` | tray slots | 5 | tray width 260; with Extra slot 310; wording of the tray warning ("one free slot") |

Width check for the boxes row (usable width 336 = 360 minus 12 each side):
`open * 92 + (open - 1) * 8 + 12 + prev * 62 + (prev - 1) * 8`. With the defaults that is
`2*92 + 8 + 12 + 2*62 + 8 = 336`. It fits exactly. Any change that makes it larger than 336
needs a new layout (smaller wells down to 20 units, or two rows). Ask the ux-designer.

Tray width check: `slots * 44 + (slots - 1) * 6 + 16` must be at most 336. Five slots: 260.
Six (with Extra slot): 310. Seven would need 40 unit slots: `7*40 + 6*5 + 16 = 326`.

## 3. Screens

### 3.1 Title

Purpose: get into a level in one tap, reach everything else in two.

**Base layout (content 360 x 600):**

| Item | Rect (x, y, w, h) | Notes |
|-|-|-|
| Star bank chip | 12, 0, 96, 48 | star icon and the bank total, e.g. "128". Quiet. |
| Buy me a coffee chip | 208, 0, 140, 48 | see below; top right, out of thumb reach and away from the buttons |
| WoodLogic name | 0, 56, 360, 120 | Display text on a plaque or carved into a plank, graphic designer's call |
| Decorative board | 24, 176, 312, 120 | a few planks and screws, purely decoration, not tappable |
| **Play** | 32, 312, 296, 72 | primary. Label "Play". Note line under the label: "Level {n}". |
| Daily | 32, 392, 144, 56 | secondary. Label "Daily". Note: "Today's puzzle", "Done today", or "Opens after level 8" while locked. |
| Relaxed | 184, 392, 144, 56 | secondary. Label "Relaxed". Note: "No clock", or "Opens after level 8" while locked. |
| Levels | 32, 456, 144, 52 | secondary. Label "Levels". |
| Stats | 184, 456, 144, 52 | secondary. Label "Stats". |
| Settings | 32, 516, 144, 52 | secondary. Label "Settings". |
| About | 184, 516, 144, 52 | secondary. Label "About". |

Bottom 32 units are left empty on purpose (gesture bar room).

**Buy me a coffee chip.** Visible chip is 140 x 32 inside a 140 x 48 target. A cup icon drawn
in code (20 units) and the text "Buy me a coffee" (Caption, 13). Quiet style, low emphasis, never
animated, never in the button column. Tapping it hands the fixed address to the phone with no
confirmation; the browser opens. It never shows a badge, a counter or a reminder.

**Notes under labels:**
- Play note: "Level {n}" where n is the player's next level. A level left unfinished starts
  again from the beginning (section 4.3).
- Daily note: "Today's puzzle" until it is solved today, then "Done today". A solved daily can
  still be replayed (stars only above best, no streak change).
- **Locked Daily and Relaxed.** Both open when level 8 has been cleared `[GDD]`. Before that,
  each button keeps its place but is drawn locked: a padlock icon next to the label, a dimmed
  fill, and the note "Opens after level 8". The note and the padlock stay at full contrast
  (the note carries meaning). The button still answers a tap, so the player is told why: it
  shakes 4 units sideways twice (200 ms) with a dull knock, and the toast says "Clear level 8 to
  open Daily." or "Clear level 8 to open Relaxed." The moment level 8 is cleared, the level clear
  screen shows the unlock note "Unlocked: Daily and Relaxed" (same plaque as theme unlocks).

**Tall (up to 360 x 840):** buttons stay anchored to the bottom of the content rect. All extra
height goes to the name and decorative board: the name block grows by up to 40, the decoration
by up to 120, and the rest becomes space between them. Button sizes do not change.

**Wide (up to 480):** the button column stays 296 wide, centered. The decoration widens to 360.
The chips stay at the left and right edges of the content rect.

**First launch:** the title is skipped (section 5). It first shows after level 1 has been
cleared and the player quits to it, or on any later launch.

**Back button:** exits the app. The game is always saved already; nothing asks.

### 3.2 Level

#### 3.2.1 Vertical budget (the numbers the game designer sizes levels against)

Content coordinates, y from the top of the content rect. The content rect is the screen minus
24 top and 16 bottom inset.

**Base: 360 x 640 screen, content rect 360 x 600**

| Band | y from | y to | Height |
|-|-|-|-|
| Top bar (level, timer, star bank, pause) | 0 | 44 | 44 |
| gap | 44 | 48 | 4 |
| Boxes and preview row | 48 | 112 | 64 |
| gap | 112 | 116 | 4 |
| Tray | 116 | 168 | 52 |
| gap | 168 | 176 | 8 |
| **Board panel** | 176 | 536 | **360** |
| gap | 536 | 544 | 8 |
| Helper bar (or tutorial line) | 544 | 600 | 56 |

**Tall: 360 x 800 screen, content rect 360 x 760**

| Band | y from | y to | Height |
|-|-|-|-|
| Top bar | 0 | 48 | 48 |
| gap | 48 | 54 | 6 |
| Boxes and preview row | 54 | 130 | 76 |
| gap | 130 | 136 | 6 |
| Tray | 136 | 192 | 56 |
| gap | 192 | 204 | 12 |
| **Board panel** | 204 | 684 | **480** |
| gap | 684 | 696 | 12 |
| Helper bar (or tutorial line) | 696 | 760 | 64 |

**The board that levels are authored on is fixed.** Level N must be the same for every player,
so the playable board cannot change with the screen.

- **Board core: 344 wide x 360 tall**, at x 8 to 352. Every plank and every screw is placed in
  the core. This is the size to design blueprints against. The geometry and the rules never
  change with the screen; on large screens only the drawn scale of the whole board view changes
  (**board scale b**, section 3.2.1a). All numbers in this section are for b = 1.
- On the base screen the board panel is exactly the core (344 x 360, panel 360 x 360 with 8 side
  margins of back board).
- On a tall phone (width 360, b = 1) the panel is bigger (up to 360 x 480 at 800 and more
  above) and the core sits centered inside it (60 units of extra back board above and below at
  800). The extra back board is where falling planks drop and swinging planks may overshoot; it
  holds no screws.
  Planks may extend outside the core only as drawing (a plank hanging below its screw), never a
  screw.
- **Screw positions** stay inside the inset rectangle 300 x 316 (22 units in from each core
  edge), so a 28 unit head and its shadow stay on the board.
- **Screw head size** is 28 units across (symbol 16). **Touch target** is a circle of radius 24
  (48 across), centered on the screw.
- **Spacing rule (the game designer's stricter rule, decided by Bart):** every pair of screws
  on a board has centers at least **48 units apart**, in every state, including rest poses.
  Screws never move on the board (a plank swings but its screws do not), so this is a fact of
  the level data, checked once, and free screws' targets can never overlap. It also keeps
  ghosts of covered screws readable. At 48 spacing the inset rectangle holds at most 7 columns x
  7 rows = 49 screws (the GDD caps a level at 36 screws and 24 free at the start).
- The core could grow to 344 x 380 only by shrinking the boxes, tray and bars by 20 units in
  total, and that would crowd them. Not recommended; ask first.

**Heights between and beyond.** Let E be the screen height minus 640.
The first 40 units of E are shared by the bars and gaps in proportion to the two tables (top bar
+4, boxes +12, tray +4, helper bar +8, gaps +12). Everything after that goes to the board panel
only. So at 720 the bars have grown by 20 and the panel is 360 tall; at 800 the panel is 480;
at 840 it is 520. Round to whole units.

**Wider screens** (tablets, foldables) use the scaling rule in 3.2.1a instead of these tables.

#### 3.2.1a Scaling on large screens (decided by Bart: the board view scales up)

The board's geometry is the same for everyone (344 x 360 core, same rules, same spacing). On a
large screen the whole board view is drawn bigger, uniformly, to fill the available board panel.
Hit testing is done in core coordinates and then scaled, so touch targets scale with the board:
a free screw's target is a circle of radius 24 x b, and the spacing rule means neighbors never
overlap at any b.

**Inputs.** Wc and Hc are the content rect's width and height in units (viewport minus insets;
not capped at 480). dpu is how many dp one unit covers on this device (1.0 or more on phones;
about 1.4 to 2.2 on tablets because the height sets the scale there). Margin 8 around the board
panel.

**Two scales.**
- **b, the board scale.** Never below 1.0, never above 2.0 (a head 56 across, a target 96).
- **f, the furniture scale.** It sizes the top bar, boxes and preview, tray, helper bar, their
  gaps, their text and their targets. Floor: **f_floor = the larger of 0.7 and 1 / dpu**. The
  second term keeps every target at least 48 dp and every text at least 13 dp even when f is
  below 1. On every phone f_floor is 1.0 or close to it, so phones never shrink their bars.
  Ceiling for the stacked arrangement: 1.167 (the tall phone budget).

**Arrangement 1, stacked** (the phone arrangement: top bar, boxes, tray, board, helper bar, top
to bottom). Always available.
1. b = min( (Wc - 16) / 344, (Hc - 240 x f_floor) / 360 ), kept between 1.0 and 2.0.
2. f = (Hc - 360 x b) / 240, kept between f_floor and 1.167.
3. The board panel is Wc - 16 wide and Hc - 240 x f tall, and the scaled core (344 x b by
   360 x b) sits centered in it. Extra panel is plain back board with no screws.
4. Bars span the panel width. Their contents (boxes, tray, helper buttons) are scaled by f and
   centered; the helper buttons grow wider than 104 x f to fill the width, and are never
   taller than the bar.
For a 360 wide phone this gives b = 1 and f = 1.0 at 640 and the tall tables at 800, as before.

**Arrangement 2, split** (for near square and wider windows). The boxes, tray and helpers move
to a **rail** on the right so the board can use the full height.
1. f = f_floor. Rail width R = 360 x f. Board panel width Pw = Wc - R - 24.
2. b = min( Pw / 344, (Hc - 48 x f - 8 - 8) / 360 ), kept at 2.0 or less. Split is allowed only
   when this b is at least 1.0.
3. The top bar spans the full width at the top (44 x f tall). The board panel is on the left,
   under it, Pw wide and Hc - 48 x f - 8 tall, with the scaled core centered in it. The rail is
   on the right, same height, 8 from the edge.
4. The rail holds, top to bottom, the open boxes (one row), the preview boxes (one row), the
   tray, and the helper bar, all at scale f, centered, with the free space shared evenly
   between the four groups. The helper bar sits at the bottom of the rail, where a thumb
   rests.

**Choosing.** Work out b for both arrangements. Use split only if its b is larger than the
stacked b. Ties go to stacked.

**Overlays are not scaled.** Pause, level clear, out of room, helper sheets and dialogs keep
their size from section 3, are anchored to the bottom, and use the content column of at most
480 over a dimmed level screen.

**Worked examples** (insets 24 top and 16 bottom units on the phones and the foldable, 12 and 8
on the tablets because a unit is larger there).

| Screen | Viewport | Hc | dpu | f_floor | Arrangement | b | f | Board drawn |
|-|-|-|-|-|-|-|-|-|
| Base phone | 360 x 640 | 600 | 1.0 | 1.0 | stacked | 1.00 | 1.00 | 344 x 360 |
| Tall phone | 360 x 800 | 760 | 1.0 | 1.0 | stacked | 1.00 | 1.167 | 344 x 360 in a 360 x 480 panel |
| 10 inch tablet, portrait, 10:16 (1200 x 1920 px) | 400 x 640 | 620 | 2.14 | 0.70 | stacked | 1.12 | 0.91 | 384 x 402 |
| 10 inch tablet, 3:4 | 480 x 640 | 620 | 1.6 | 0.70 | stacked | 1.26 | 0.70 | 432 x 452 in a 464 x 452 panel |
| Unfolded foldable | 840 x 720 | 680 | 1.25 | 0.80 | split | 1.54 | 0.80 | 528 x 553 in a 528 x 634 panel |

Detail for the 10 inch tablet (400 x 640): b = min(384 / 344 = 1.116, (620 - 168) / 360 =
1.256) = 1.116, so f = (620 - 402) / 240 = 0.91. The bands become top bar 40, boxes 58, tray
47, helper bar 51, gaps 22. The board is 384 x 402 and fills the panel. At 2.14 dp per unit, a
0.91 target is 48 x 0.91 x 2.14 = 93 dp, far above 48 dp. For the 3:4 tablet the bars fall to
f = 0.70 to give the board 1.26, and the 464 wide panel leaves 16 units of back board each side
of the board.

Detail for the unfolded foldable, 840 x 720 (Wc 840, Hc 680, 1.25 dp per unit, so f = 0.80):
- Stacked would give b = min(824 / 344 = 2.40, (680 - 192) / 360 = 1.36) = 1.36, a board 466 x
  488 in the middle of a very wide screen.
- Split gives R = 288, Pw = 528, b = min(528 / 344 = 1.54, (680 - 38 - 16) / 360 = 1.74) = 1.54.
  That is larger, so split is used.
- Layout: top bar 840 x 35. Under it on the left, the board panel 528 x 634 with the core drawn
  528 x 553, 40 units of back board above and below. On the right, the rail 288 x 634 holding
  the open boxes (each 74 x 45), the preview boxes (50 x 35), the tray (5 slots of 35) and
  the helper bar (buttons 83 x 45) spaced evenly down it. A screw head is 43 across and its
  target 74 across. Every rail button is 38 units tall or more, which is 48 dp.
- Under the current stretch settings the engine would report this window shape as 747 x 640
  (the height sets the scale). The same rule gives split with b = 1.36 there, and the same
  proportions.

The graphic designer draws a plain wooden back panel behind the rail and the bars so the split
arrangement looks like one workbench, and the same panel continues behind the top bar.

#### 3.2.2 Bands

**Top bar** (height 44; 48 on tall)

| Item | Rect (x, y, w, h) at base | Notes |
|-|-|-|
| Level label | 12, 0, 96, 44 | Heading size 20 bold: "Level {n}". For the daily: "Daily". For relaxed: "Relaxed". |
| Timer and pips | 112, 0, 108, 44 | timer "m:ss" (Body 16) and two small pips, see below. Hidden in Relaxed. |
| Star bank | 224, 0, 76, 44 | star icon and the total, e.g. "128". Hidden in Relaxed. |
| Pause button | 308, 0, 48, 44 | target is 48 x 48 (grows 4 into the gap below). Pause icon (two bars). Label for screen readers: "Pause". |

- **Timer** counts up from the first **action** of the attempt, not from when the level
  appears (decided by Bart, GDD S6). An action is a tap that is accepted or a helper use
  (including Get and use). A refused tap (section 6.1) is not an action, and neither is a tap on
  a covered screw. The timer stops while the game is paused, while a helper sheet or the buy
  dialog is open, at the clear and at the loss. It shows "0:00" until the first action and caps
  at "59:59". Retry resets it.
- **Pips.** Two tiny 14 unit icons beside the timer tell the player which bonus stars are still
  possible: a stopwatch pip (speed, filled while the time is under par, outline once past par)
  and a tray pip (clean, filled until the tray is used more than par times or a helper is used,
  then outline). They change shape (filled to outline) in silence, quietly. They are
  information, not alarms. They stay (decided by Bart) and are checked at Gate 1.
- Using Undo, or any helper, turns the clean pip to an outline at once. That is the visible
  cost of a helper (decided by Bart, GDD R32): Undo costs the Clean star.
- The timer, pips and star bank appear from level 4 `[GDD S9]`. Levels 1 to 3 show only the
  level label and the pause button, so those levels are just the board. Stars are still
  awarded on levels 1 to 3 and shown on the clear screen.

**Boxes and preview row** (64 tall at base, 76 tall at 800)

- **Box layout, settled for the Workshop look** (from docs/design/workshop-boxes.png). Wells on
  top, the color and symbol painted across the front, the lid leaning back above. There is no
  lid strip carrying the symbol. Open boxes `[C:open]`: two boxes, each body 92 x 56, at x 12
  to 104 and x 112 to 204, y 6 to 62 inside the 64 tall row.
  - **Lid:** a thin strip (3 units, in the box's color, drawn y 2 to 6) leaning back above the
    body. Decoration, and it swings forward over the wells when the box closes.
  - **Wells** `[C:slots]`: three hollows of 24 units (x offsets 6, 34, 62 inside the body),
    their centers **20 units below the top of the body** (so y 8 to 32). Empty wells are a
    neutral dark hollow, never the box color, so an empty well cannot be mistaken for a screw. A
    filled well shows the screw drawn 24 across with its symbol.
  - **Front band:** a painted band 80 x 18 at x offset 6, y offset 36 to 54 of the body, in the
    box's color, with its symbol centered. The symbol is 14 units tall with strokes of at least
    2 units, drawn black or white, whichever contrasts more with the band (at least 3 to 1, aim
    for 4.5 to 1).
  - **Usability check:** a 14 unit symbol on the box is a little smaller than the 16 unit drive
    on a screw. That is fine here, because the band is large and its color and the screws
    already sitting in the wells say the same thing. Do not make the band thinner than 18.
  - When symbols are off the symbol is not drawn; the band's color and the box shape stay.
- A small chevron (8 wide) at x 206 to 214 separates open boxes from the queue.
- Preview boxes `[C:prev]`: two closed trays, each 62 x 44, at x 216 to 278 and x 286 to 348,
  vertically centered in the row. Each has a painted lid in the box's color with its symbol at
  20 units, black or white by contrast. They carry no wells. The first preview is the next to
  slide in.
- On tall screens the row height grows to 76 by adding space around the boxes. Their widths do
  not change, because the row is already full.

**Tray** (52 tall at base, 56 at 800)

- Five slots `[C:tray]`, each 44 x 44 with 6 between, in a frame 260 x 52 centered (x 50 to
  310). The frame is the brushed steel parts tray with riveted ends. Each slot is a neutral
  hollow of 38 units; a screw in it is drawn 32 units across with its symbol.
- Filling order: leftmost free slot first.
- With Extra slot used, a sixth slot grows in on the right and the frame becomes 310 wide
  (x 25 to 335).
- **Warning at one free slot `[C:tray]`:** when exactly one slot is free, the frame turns a warm
  warning tone and a small triangle with an exclamation mark is drawn inside the free slot
  (a symbol, so it is not only color). One soft tick sound plays once as the state is entered.
  There is no looping animation. If a screw leaves the tray (a box opens and takes it) and two
  slots are free again, the warning clears without sound.
- **Full tray:** all slots filled. If any free screw can still go to an open box, play
  continues. The tray frame holds the warning tone with a closed-lid icon in the frame corner.
  A tap on a free screw that has nowhere to go is refused (section 6.1, rule R25).

**Board panel.** The board art and screws. Free screws look raised with a rim and a shadow.
Covered screws show faintly through the wood: drawn flat, about 45 percent opacity, with a
dashed ring and no shadow, so free and covered differ by opacity, shading, outline style and
shadow, never by color alone. Covered screws keep their color and symbol so the player sees
what is under what.

**Helper bar** (56 tall at base, 64 at 800)

- Three buttons, each 104 x 56, with 12 between, filling 336 of width. Each shows an icon (28),
  the helper name below it (Caption 13) and a count badge (24 unit circle with the number, Body
  16 bold) at the top right corner. Names: "Undo", "Extra slot", "Screwdriver".
- A helper that has not been introduced yet is not shown. The bar then shows the tutorial line
  of that level, if there is one, in a 336 x 48 plaque (Tutorial line style, centered, up to
  two lines at 16 if needed).
- **Owned (count 1 or more):** a tap uses one.
  - Undo: takes back the last action (a tap or a Screwdriver removal) at once. It can be used
    again and again back to the start of the try, each use spending one Undo `[GDD R26 to
    R28]`. With nothing to take back it does nothing, spends nothing, and shows the toast
    "Nothing to undo."
  - Extra slot: adds one tray slot for the rest of this try, once per try `[GDD R30]`. After it
    is used the button shows "Used" in place of the count and is disabled. Retry gives back the
    normal five slots.
  - Screwdriver: enters a mode. A banner replaces the helper bar: "Tap any screw to remove it."
    with a Cancel button (96 x 48 at the right). The next tap on any screw, covered or free,
    removes it. Cancel, the system back button, or tapping the pause button leaves the mode and
    keeps the helper. If the chosen screw has nowhere to go (no open box of its color with room
    and a full tray) the removal is refused and the Screwdriver is not spent: the screw shakes
    back (as in 6.1), the mode stays, and the toast says "That screw has nowhere to go."

- **Not owned (count 0):** the badge shows the price instead, with a small star icon (for
  example "4" and a star for Undo, "6" for Extra slot, "8" for Screwdriver `[GDD]`). A tap opens the buy dialog (3.13.3) if the bank can pay. If it
  cannot, the button looks dimmed and a tap shows the toast "Not enough stars. {price} needed."
- **Relaxed (decided by Bart):** the bar shows only the free Undo, centered, with no count. Its
  badge reads "Free" and it never runs out. Extra slot and Screwdriver are hidden, and the buy
  dialog never appears.

#### 3.2.3 States of the level screen

- **Playing.** Everything above.
- **Hand hint.** Tutorial levels may show a pointing hand (section 5).
- **Helper intro.** A sheet over the lower board with the first-time explanation (3.13).
- **Screwdriver mode.** Banner described above. Free and covered screws all show their symbol
  bright, so the player can pick any.
- **Paused.** The pause screen (3.3).
- **Cleared.** The clear screen (3.4) takes over.
- **Out of room.** The sheet from 3.5 slides up.

**Back button:** opens Pause. In Screwdriver mode it leaves the mode first. In the helper intro
it closes the intro. In a dialog it closes the dialog.

### 3.3 Pause

Purpose: stop the clock, change sound, leave. Reached from the pause button, the Android back
button, or automatically when the app loses focus.

- The board is covered by the pause panel, not only dimmed, so thinking time during a pause does
  not help the speed star. The timer is stopped.
- Full screen panel, content rect 360 x 600:

| Item | Rect (x, y, w, h) | Label |
|-|-|-|
| Heading | 0, 96, 360, 36 | "Paused" |
| Level line | 0, 140, 360, 24 | "Level {n}" (or "Daily" or "Relaxed, {Easy, Medium or Hard}") |
| **Resume** | 32, 300, 296, 72 | "Resume" (primary) |
| Retry | 32, 380, 296, 52 | "Retry" |
| Sound | 32, 440, 144, 52 | "Sound: On" or "Sound: Off", with a speaker icon (crossed out when off) |
| Music | 184, 440, 144, 52 | "Music: On" or "Music: Off", with a note icon (crossed out when off) |
| Quit to title | 32, 500, 296, 52 | "Quit to title" |

- Sound and Music toggle at once on tap and the label changes in the same frame.
- Retry restarts the same level at once with no question (Retry is always free). The timer
  resets, the tray goes back to its start size, and helpers already spent stay spent `[GDD
  R34]`.
- Quit to title shows the title. The level is not kept: Play starts it again from the beginning
  (section 4.3).
- **Tall:** the heading and level line stay at the same distance from the top; the buttons stay
  anchored to the bottom.
- **Back button:** same as Resume.

### 3.4 Level clear

Purpose: celebrate fast, then get out of the way. Next is one tap.

**Timeline (all within 1.6 seconds, none of it blocks input):**

| Time from the last screw landing | Event |
|-|-|
| 0 ms | the box closes; the board is empty or its last planks fall |
| 250 ms | the heading drops in (150 ms), chime begins |
| 350 ms | star 1 pops (200 ms, ease out with a small overshoot), rising chime note |
| 650 ms | star 2 pops, or its outline settles if not earned |
| 950 ms | star 3 pops, or its outline settles if not earned |
| 1600 ms | particles finish; everything is at rest |

Next and Replay fade in from 350 ms and are tappable from **500 ms**, before the stars finish.

A tap on Next during the celebration skips the rest and loads the next level. The result is
already saved at the moment of the clear, so it can never be lost by skipping.

**Layout (content 360 x 600):**

| Item | Rect (x, y, w, h) | Text |
|-|-|-|
| Heading | 0, 56, 360, 36 | "Level {n} cleared" |
| Star row | 48, 120, 264, 72 | three stars 72 across with 24 between |
| Star captions | 30, 200, 300, 72 | three columns of 100: label (Button 18) then detail (Caption 13) |
| Summary line | 32, 284, 296, 28 | "+{k} stars" or "No new stars this time" (Heading 20) |
| Unlock note (when any) | 32, 322, 296, 48 | "Unlocked: {name} wood" or "Unlocked: {name} metal" |
| **Next** | 32, 460, 296, 72 | "Next" with a right arrow, note "Level {n+1}" (primary) |
| Replay | 32, 540, 296, 48 | "Replay" (secondary) |

Captions per star (label then detail; the target is always shown, whether earned or not, so the
player learns what to aim for):

| Star | Label | Detail |
|-|-|-|
| 1 | "Cleared" | "Every screw is out" |
| 2 | "Fast" | "Under {par_time}" (for example "Under 1:20") and, when earned, the player's time below it: "Yours {time}" |
| 3 | "Clean" | "Tray {par} times or fewer, no helpers" for par 2 or more; "Tray once or never, no helpers" for par 1; "No tray, no helpers" for par 0 |

- Earned stars are filled and warm; not earned stars are outline only with a faint inner mark,
  so the difference is shape and not only color.
- "+{k} stars" counts only stars above the player's best for this level. For one star: "+1 star".
  A replay with no gain: "No new stars this time".
- The star bank in the corner is not on this screen; the summary line is the confirmation.
- Unlock note shows only when this clear passes a theme milestone `[GDD]`. It is a plaque, not a
  dialog, and does not need a tap.
- **Daily clear:** heading "Daily puzzle solved". The summary line is followed by "Streak: {n}
  days" (or "Streak: 1 day"). The big button reads "Done" and goes to the title. Replay stays.
- **Relaxed clear:** no stars, no timing. Heading "Nicely done". The big button reads "Another"
  (a new relaxed level at the same difficulty). The second button reads "Done" and goes to the
  title.
- **Tall:** the heading, stars and captions move down in proportion (heading at 15 percent of the
  height, stars at 22 percent). Buttons stay anchored to the bottom.
- **Back button:** goes to the title. The clear is already saved.

### 3.5 Out of room (the loss)

Purpose: say plainly what happened, and get back to playing in under two seconds.

**When it appears.** The losing tap's screw lands in the tray (about 400 ms). The tray slots
shake 6 units sideways for 250 ms and the soft falling tone plays. A beat of 300 ms lets the
player see the full tray. Then the sheet slides up (250 ms). So the sheet is up about 0.9 seconds
after the tap, Retry works from the first frame of the slide, and the level restarts within 400
ms of the Retry tap (the level data is kept in memory, so there is never a wait to generate).

**Layout (content 360 x 600).** The sheet has two heights. With at least one helper owned it is
360 x 300 at y 300; with none owned it is 360 x 244 at y 356. Rects are inside the sheet.

| Item | Rect inside the sheet (x, y, w, h) | Text |
|-|-|-|
| Heading | 32, 16, 296, 32 | "The tray is full" |
| Body | 32, 48, 296, 44 | "Every slot is taken, and no free screw fits an open box." |
| **Retry** | 32, 100, 296, 64 | "Retry" (primary) |
| Helper row (only when at least one helper can be offered) | 32, 172, 296, 56 | 1 to 3 buttons, see below |
| Bottom button | 32, 236, 296, 48 (or 32, 172, 296, 48 with no helper row) | "Previous level" (or "Title", see below), quiet |

- **Decided by Bart, GDD R37:** the sheet offers each helper the player owns **and can use**,
  and never offers to buy one. A helper with count 0 is not shown, and neither is one that
  cannot be used right now (not dimmed, not greyed: simply absent). Nothing on this sheet
  costs stars.
- **Which buttons appear**, in this fixed order left to right:
  1. "Undo ({n})" when the Undo count is 1 or more.
  2. "Extra slot ({n})" when its count is 1 or more and it has not been used in this try.
  3. "Screwdriver ({n})" when its count is 1 or more and at least one screw on the board,
     covered or not, fits an open box (GDD R37). The engine reports this from the state.
- **Layout for 0 to 3 buttons** (the row is 296 wide and 56 tall, 8 between buttons, always
  filling the full width so the row never looks lopsided):

| Buttons | Sheet | Row contents |
|-|-|-|
| 0 | 360 x 244 at y 356, no helper row | Retry at y 100, bottom button at y 172 |
| 1 | 360 x 300 at y 300 | one button 296 x 56, laid out as a row: icon (28), name (Button 18), count badge at the right |
| 2 | 360 x 300 at y 300 | two buttons 144 x 56 each, icon above name, count badge at the top right corner |
| 3 | 360 x 300 at y 300 | three buttons 93 x 56 each (296 minus 16, divided by 3), icon above name (Caption 13, "Screwdriver" fits), count badge at the top right corner |

  Retry is always the biggest button and sits first, above the row, so it is the first thing
  the thumb finds. All helper buttons are at least 48 tall and at least 93 wide, so every target
  meets the 48 unit rule.
- **What each button does.** It uses one helper, closes the sheet, and play continues. The clock
  restarts from where it stopped (GDD R37).
  - Undo takes back the last action `[GDD R29]`.
  - Extra slot adds the sixth tray slot, so the tray is no longer full.
  - Screwdriver enters the Screwdriver mode (banner on the helper bar, section 3.2.2). After a
    loss no free screw can go anywhere, so the screws it can help with are covered ones that fit
    an open box.
  Using any helper costs this try's Clean star (the clean pip turns to an outline).
- The board stays visible above the sheet, dimmed by 30 percent only, so the player can see
  how the tray filled. The tray frame stays at full brightness above the sheet. The board shows
  down to y 300 (or 356 without helpers).
- "Previous level" loads level n minus 1 and is not shown on level 1 or in the daily. In those
  cases the bottom button is "Title".
- **Relaxed stuck sheet** (relaxed levels cannot be lost): the 244 tall sheet with heading
  "Stuck for now", body "Nothing fits an open box and the tray is full. Take back a move and try
  another way." and buttons: "Undo" (primary, free, 64 tall, in the place of Retry), then
  "Retry" and "Title" side by side (144 wide each) in the place of the bottom button. No other
  helpers are offered.
- **Tall:** the sheet keeps its size and stays anchored to the bottom; the board shows more.
- **Back button:** goes to the title (the level can be continued with Play: it restarts from the
  beginning).

### 3.6 Levels list

Purpose: replay any cleared level to earn more stars.

**Layout (content 360 x 600):**

| Item | Rect | Notes |
|-|-|-|
| Header | 0, 0, 360, 56 | "Levels" (Heading) at the left, star bank at the right |
| List | 0, 56, 360, 480 | a vertical scroll area of cells |
| Back | 12, 544, 336, 48 | "Back" (quiet) |

- Cells are 56 x 56 in a grid of **5 columns** (gap 14, margin 12: 5 x 56 + 4 x 14 = 336),
  with 12 between rows. Each cell shows the level number (Button 18, centered in the upper part)
  and three small stars (12 units) along the bottom: filled or outline.
- The list runs from level 1 upward and contains only cleared levels plus the next one to play.
  The next one has a thicker border and a play triangle in place of the stars, and is the only
  cell that is not a star record.
- It opens scrolled so the next level is in the lower third of the list, close to the thumb.
  Scrolling is a vertical drag with momentum.
- Tapping a cell starts that level at once (no confirmation).
- A cell with fewer than three stars is not marked in any other way; its outline stars are the
  hint.
- **Wide:** 6 columns when the content width is 432 or more.
- **Empty state** (nothing cleared): the list shows level 1 as the next cell and the note
  "Clear a level to see it here." in Body under it.
- **Back button:** goes to the title.

### 3.7 Stats

Purpose: show the player's record. Kept on the phone only.

**Layout (content 360 x 600):** header "Stats" (Heading) at y 0 to 56, a vertical scroll area at
y 56 to 536, Back at y 544.

Rows are 48 tall plaques: label on the left (Body 16), value on the right (Button 18, bold).

| Group | Label | Value |
|-|-|-|
| Levels | "Levels cleared" | number |
| | "Highest level" | number |
| | "Total stars" | number (stars earned in all) |
| | "Three-star levels" | number |
| Daily puzzle | "Current streak" | "{n} days" or "1 day" or "0 days" |
| | "Best streak" | "{n} days" |
| | "Daily puzzles solved" | number |
| Helpers | "Helpers used" | number |
| Times | group heading "Times by difficulty" | |
| | column headings "Band", "Best", "Average" | |
| | one row per band: "Easy", "Medium", "Hard", "Expert" `[GDD 6.7]` | best and average as "m:ss", or "None yet" |

- Group headings are Button 18 on a slim plaque.
- The daily counts in "Medium". Tutorial levels and Relaxed are not timed.
- A footer line in Small: "These numbers stay on this phone."
- Numbers of 1000 or more use a comma ("1,234").
- **Empty state:** zero values show as "0", times as "None yet", and a line at the top reads
  "Play a few levels and your numbers show up here."
- **Back button:** goes to the title.

### 3.8 Settings

Purpose: sound, music, symbols, themes, reset. Nothing else.

**Layout (content 360 x 600):** header "Settings" y 0 to 56, a scroll area y 56 to 536, Back at
y 544. Rows (heights are minimum, 8 between):

| Row | Height | Contents |
|-|-|-|
| Sound | 56 | toggle row, label "Sound", note "Taps, clinks and wood knocks" |
| Music | 56 | toggle row, label "Music", note "Quiet background tones" |
| Colorblind symbols | 64 | toggle row, label "Colorblind symbols", note "A shape on every screw and box" |
| Wood | 104 | label "Wood"; five swatches 48 x 48 with 8 between (272 wide); a caption line under them |
| Metal | 104 | label "Metal"; up to five swatches as above; a caption line |
| Reset progress | 56 | danger styled row, label "Reset progress", note "Erase levels, stars, helpers and stats" |

- Defaults: Sound On, Music On, Colorblind symbols **On**. Toggles apply in the same frame and
  are saved at once.
- **Pickers.** Each swatch is a 48 x 48 target that shows the wood grain or the screw metal as a
  small sample. The selected one has a thick outline and a check mark (two signals). A locked
  one is dimmed and shows a padlock icon. The caption line under the strip names the swatch
  last touched:
  - Selected and free: "{name}" (for example "Oak").
  - Locked by level: "{name}. Clear level {n} to unlock." Locked by streak: "{name}. Reach a {n}
    day daily streak to unlock." The numbers are the GDD's (section 7): Walnut 10, Maple 50,
    Cherry 100, Ebony 150 (levels), Brass 25 (level), Copper 3 and Black 7 (best daily streak,
    so a broken streak never takes anything away). Oak and Steel are open from the start.
  - Tapping a locked swatch only shows the caption; it does not change the theme.
  - Wood names: "Oak", "Walnut", "Maple", "Cherry", "Ebony". Metal names: "Steel", "Brass",
    "Copper", "Black". (The Workshop direction proposes nine screw colors, but metals are the
    four finishes above.)
- **Reset progress** opens a dialog:
  - Heading: "Erase everything?"
  - Body: "This erases your levels, stars, helpers, streaks and stats on this phone. It cannot be
    undone. Your settings stay as they are."
  - Buttons, stacked, in the bottom half of the dialog: "Keep my progress" (primary, 304 wide
    minus margins, listed first and focused) and below it, 16 units apart, "Erase everything"
    (danger).
  - After erasing: a toast "Progress erased." The next Play starts level 1 and skips the title
    like a first launch.
  - Back button inside the dialog: same as "Keep my progress".
- **Tall:** the scroll area grows; no row changes size.
- **Back button:** goes to the title.

### 3.9 About

Purpose: what this is, who made it, the links, the fixed statements, License and Credits.

**Layout (content 360 x 600):** header "About" y 0 to 56, a scroll area y 56 to 536, Back at
y 544. Contents in order, 12 between blocks:

1. **What it is.** Block with the name "WoodLogic" (Heading), "Version {version}" (Small), and
   this text (Body):
   "WoodLogic is a free screw puzzle. It was made by Play, Inc. and designed by Bart Basi."
2. **Send feedback** (row button 336 x 64). Label "Send feedback". Note: "Opens a draft in your
   email app. You can edit it first."
3. **Source code** (row button 336 x 64). Label "Source code". Note: "Opens
   github.com/bartbasi/WoodLogic in your browser."
4. **Supporting WoodLogic.** Heading "Supporting WoodLogic" (Button 18), then this fixed text
   (Body):
   "WoodLogic is free, with no ads and no tracking, and it always will be. If you'd like to
   support more games like it, you can buy me a coffee. Never expected, always appreciated."
   Below it the button "Buy me a coffee" (336 x 56, secondary, cup icon drawn in code), with the
   note "Opens a web page in your browser."
5. **Privacy.** Heading "Privacy", then this fixed text (Body):
   "WoodLogic collects nothing: no ads, no tracking, no internet. The Buy me a coffee button
   only opens a web page in your phone's browser, and the game itself sends nothing."
6. **License** (row button 336 x 56), label "License", opens 3.10.
7. **Credits** (row button 336 x 56), label "Credits", opens 3.11.
8. **Attribution** (Small, centered, the fixed line):
   "Based on WoodLogic, designed and written by Bart Basi, with assistance from Claude.
   Copyright 2026 Play, Inc."

- **The email draft.** Opens `mailto:bartbasi@gmail.com` with:
  - Subject: "WoodLogic feedback"
  - Body: a blank area for the player's message, then a last line:
    "Sent from WoodLogic {version} on {phone model}, {OS name and version}. You can edit or
    delete this line."
  The draft is shown by the phone's email app; the player can change any part.
- **If a link cannot open:** a toast. For email: "No email app found. You can write to
  bartbasi@gmail.com." For web pages: "No browser found on this phone."
- Links open only the three fixed addresses; nothing the player types is ever passed to them.
- **Wide:** the column stays at most 480.
- **Back button:** goes to the title.

### 3.10 License page

Reached from About. Header "License" (Heading) y 0 to 56, a scroll area y 56 to 536, Back
(returns to About) at y 544. Text is Small (14) on a plaque, with line spacing 1.4, in this order:

1. The attribution line (Body, the fixed line).
2. "WoodLogic is free software. You can use it, study it, share it and change it under the GNU
   General Public License version 3, with a few added terms. The added terms ask you to keep the
   line above, to mark changed versions as changed, and not to present them as the original or
   as made or endorsed by Play, Inc. or Bart Basi. They give no rights to the name WoodLogic or
   its icon."
3. Heading "Additional terms", then the text of the NOTICE file, unchanged.
4. Heading "GNU General Public License, version 3", then the text of the LICENSE file,
   unchanged.

The text of items 3 and 4 comes from the files shipped with the game so it can never drift
from the repository. **Back button:** returns to About.

### 3.11 Credits page

Reached from About. Header "Credits", scroll area, Back (returns to About). Order:

1. "WoodLogic is made with the Godot Engine, a free and open source game engine." (Body)
2. "Every picture and sound in WoodLogic is made by the game's own code." (Body)
3. Heading "Godot Engine".
4. The engine's own license text and its list of third-party parts and their notices, as the
   engine provides them at run time (the engine's license text, copyright information and
   donor list functions, as the platform allows). This is the engine's wording and is shown
   unchanged. It includes the notice for Godot's default font.
5. The attribution line from 3.9 (Small).

**Back button:** returns to About.

### 3.12 Relaxed setup

Purpose: pick a difficulty and be playing in one tap.

**Layout (content 360 x 600):**

| Item | Rect (x, y, w, h) | Text |
|-|-|-|
| Heading | 0, 56, 360, 36 | "Relaxed" |
| Body | 32, 100, 296, 72 | "No clock, no stars, and you can't lose. Undo is free." |
| **Easy** | 32, 300, 296, 72 | "Easy" and note "Fewer screws, plenty of room" |
| **Medium** | 32, 380, 296, 72 | "Medium" and note "A good puzzle" |
| **Hard** | 32, 460, 296, 72 | "Hard" and note "Tight spots and long plans" |
| Back | 12, 544, 336, 48 | "Back" |

- A tap on a difficulty starts a relaxed level of that difficulty at once. The last difficulty
  played shows the word "Last" in a small tag at the top right of its button (a tag, not only a
  color).
- Relaxed earns no stars and does not move the main level count.
- **Back button:** goes to the title.

### 3.13 Helper explanations and the buy dialog

#### 3.13.1 First-time explanation

Appears the first time a helper is available, at the levels the GDD sets: **Undo on level 8,
Extra slot on level 15, Screwdriver on level 25** (two free of each, price 4, 6 and 8 stars). It
is a sheet shown when that level appears, before the player's first tap. The timer has not
started and stays stopped while the sheet is open.
The helper bar is visible below the sheet with the new helper's button outlined by a steady ring
(no pulsing) and a down arrow from the sheet to it.

**Layout (content 360 x 600; sheet 360 x 264, y 280 to 544, directly above the helper bar):**

| Item | Rect inside the sheet | Text |
|-|-|-|
| Illustration | 32, 16, 72, 72 | a small animation drawn in code, one loop of about 2 seconds, no flashing |
| Heading | 116, 16, 212, 32 | the helper name (Heading 24) |
| Body | 32, 96, 296, 66 | the explanation (Body 16, up to three lines) |
| Cost note | 32, 166, 296, 20 | "Using a helper means no Clean star on that try." (Small 14) |
| **Got it** | 32, 192, 296, 56 | "Got it" (primary) |

The three explanations:

| Helper | Heading | Body | Illustration |
|-|-|-|-|
| Undo | "Undo" | "Takes back your last tap. Here are 2 to get you started." | a screw flies out of a box back onto its plank |
| Extra slot | "Extra slot" | "Adds one more tray slot for the rest of this try. Here are 2 to get you started." | the tray grows one slot on the right |
| Screwdriver | "Screwdriver" | "Removes any one screw, even a covered one. Here are 2 to get you started." | a screwdriver lifts a screw out from under a plank |

- "Got it" closes the sheet; the helper's count badge counts up from 0 to 2 (one tick each,
  200 ms apart), then play starts. The sheet never appears again for that helper.
- A full progress reset shows the explanations again.
- On the base screen the sheet (y 280 to 544) covers the lower part of the board panel. That is
  fine because the player dismisses it before play begins, and the timer has not started.
- **Back button:** same as "Got it".

#### 3.13.2 Level that introduces a helper

Only level 8 (Undo) is a tutorial level with a line: "Tapped the wrong one? Try Undo." The
sheet carries the explanation, and they never both appear at once: the line shows after "Got it"
is tapped. Levels 15 and 25 have no tutorial line; the sheet alone introduces Extra slot and
Screwdriver.

#### 3.13.3 Buy dialog (from a helper button at count 0)

Shown when the player taps a helper they do not own and the bank can pay.

- Decided by Bart: a tap on a helper at count 0 offers "Get and use" for stars, and it happens
  only on the player's own tap. The game never opens this dialog by itself.
- Heading: "Get {name}?" (for example "Get Undo?")
- Body: "{name} costs {price} stars. You have {bank}. Spend {price} and use it now?"
- Buttons: "Get and use" (primary) and "Not now" (secondary). Both 296 wide, 8 apart, in the
  bottom half of the dialog.
- "Get and use" spends the stars, adds one helper and uses it at once. Screwdriver then enters
  its mode; if the player cancels the mode, the helper stays owned.
- The timer stays stopped while the dialog is open. Using the helper after "Get and use" is the
  attempt's first action if nothing came before it, so it starts the timer.
- Never shown in Relaxed. Never shown outside the level screen. Never shown on the out of room
  sheet (3.5).
- **Back button:** same as "Not now".

## 4. Flows and the Android back button

### 4.1 Flow map

```
First launch or after reset (no level ever cleared)
    -> Level 1 (title skipped) -> Level clear -> Next -> Level 2 ...

Launch (later)
    -> Title
        Play     -> Level {n} (starts from the beginning)
        Daily    -> Level (daily)            (locked until level 8 is cleared: toast only)
        Relaxed  -> Relaxed setup -> Level (relaxed)   (locked until level 8 is cleared)
        Levels   -> Levels list -> Level {n} (replay)
        Stats    -> Stats
        Settings -> Settings -> (dialog: reset)
        About    -> About -> License | Credits
        Coffee   -> phone browser (the game keeps running underneath)

Level
    -> Pause -> Resume | Retry | Sound | Music | Quit to title
    -> Level clear -> Next | Replay (Done | Another for daily and relaxed)
    -> Out of room -> Retry | Previous level | Title | Undo
    -> Helper sheet (first time) -> Got it
    -> Buy dialog -> Get and use | Not now
```

### 4.2 Android back button on every screen

The back button and the back gesture do the same thing.

| Screen | Back does |
|-|-|
| Title | Exits the app. Everything is already saved. |
| Level (playing) | Opens Pause. |
| Level (screwdriver mode) | Leaves the mode, keeps the helper. |
| Level (helper intro sheet) | Closes it, same as "Got it". |
| Level (buy dialog) | Closes it, same as "Not now". |
| Pause | Resumes. |
| Level clear | Goes to the title. |
| Out of room | Goes to the title. |
| Relaxed stuck sheet | Goes to the title. |
| Levels list | Goes to the title. |
| Stats | Goes to the title. |
| Settings | Goes to the title. |
| Settings reset dialog | Closes it, nothing erased. |
| About | Goes to the title. |
| License | Goes back to About. |
| Credits | Goes back to About. |
| Relaxed setup | Goes to the title. |

Back never erases or spends anything. A level left unfinished starts again from its beginning.

### 4.3 Lifecycle

- The app losing focus or going to the background while a level is on the screen opens Pause (the
  clock stops). Returning shows Pause; the player taps Resume.
- Progress and settings are written when the app is paused or loses focus, and at every level
  clear. The save holds only the player's current level number (and the rest of the progress),
  not the state of a board.
- **Decided by Bart:** quitting to the title, or the app being closed or killed in the middle of
  a level, brings the player back to the same level, started again from the beginning. The exact
  board is not kept. Retry is still free.
- Date change during a daily: the daily keeps the date it started on; solving it counts for
  that date.

### 4.4 Speed targets

- **Next from level clear:** one tap. The next level is generated while the player plays, so
  Next starts the level immediately: the old board slides out left (200 ms) while the new one
  slides in (250 ms), playable from the first frame of the slide.
- **Retry after a loss:** under two seconds from the losing tap (section 3.5). Retry itself is
  one tap, and the level is playable 400 ms after it.
- **Retry from pause:** one tap, playable in 400 ms.
- **Cold start to playing** on a returning player: title is up in the time it takes to draw it;
  Play to the first tappable screw in under one second (the level is generated in the
  background while the title is showing).

## 5. The first-time experience

**Goal:** level 1 cleared in under 30 seconds, with no reading.

### 5.1 First launch

1. The app opens straight into level 1. No title, no menu, no text.
2. The board fades in over 400 ms. Level 1 is the GDD's: one bar with three screws of one color
   and one box, so three taps finish it (GDD section 8).
3. After 500 ms a **hand** (a pointing hand drawn in code) glides to the first screw to tap and
   makes a small press, over a cycle of about 1.2 seconds, repeating until the player taps it.
   After the player taps a screw, the hand glides to the next screw in the tutorial data's
   `hint` list (GDD 9.3; for level 1 the left, right, then middle screw, so the bar never swings).
4. The player taps. The screw spins out (ratchet, pop), flies into the box (clink). Three taps and
   the box closes (lid sound, slide away), then the clear screen: the stars pop and Next waits.
5. Next goes to level 2.

Estimated time for an attentive new player: about 10 to 15 seconds. The hand reappears after
8 seconds without a tap in any level that has a hand, so a player who looks away is never lost.

### 5.2 Rules for tutorial levels

- The first eight levels teach one idea each (GDD section 8, confirmed against the lines below).
- Each has at most one short line, at most 8 words where possible. The line sits in the helper
  bar position (3.2.2) in a plaque, in the Tutorial line style (18 bold). It shows from the start
  of the level and stays until the level ends. It never blocks the board.
- A tutorial line may be accompanied by the hand and by a steady ring around the relevant thing,
  never by anything flashing.
- Level 1 shows no line at all. After 8 seconds with no tap, it shows "Tap a screw." (this is
  the only text a player might ever see on level 1).
- A player can lose a tutorial level; the same loss sheet is used.
- The timer, pips and star bank stay hidden until level 4 (3.2.2).
- Each line belongs to one tutorial level. Replaying that level from the levels list shows the
  line again, which is fine.

### 5.3 Tutorial lines

These match the lines in GDD section 8 word for word (checked after Hard Stop 1). The level
numbers are the GDD's. Where the hand points is set by each level's `hint` list in the GDD
(section 8, last column); the table here only says what the line teaches.

| Level | Idea | Line |
|-|-|-|
| 1 | Tap a screw | no line (after 8 s idle: "Tap a screw.") |
| 2 | Screws go to their box | "Screws fly to the box of their color." |
| 3 | The tray | "No open box? The screw waits in the tray." |
| 4 | Covered screws | "Covered screws are stuck. Free the plank on top." |
| 5 | A plank falls | "Take out every screw and the plank falls." |
| 6 | A plank swings | "With one screw left, a plank swings." |
| 7 | The box queue | "The next boxes are shown. Plan ahead." (a steady ring around the preview, no hand) |
| 8 | The first helper (Undo) | "Tapped the wrong one? Try Undo." (after the helper sheet, with a steady ring on the Undo button, no hand) |

- The covered screw line is 8 words, the longest. Any line may wrap to two lines at 18 units in
  the 336 wide plaque.
- No tutorial line uses a number.

## 6. Feedback for every input

Rule for all of this section: the first visible response starts within one frame (about 16
ms); every response of every kind has started within **100 ms** of the touch. The sound starts
at the same moment as the first motion. Sounds come from the audio set in the brief; a button
press uses the knock sound at low volume and a higher pitch, so no extra sound is needed. Sound
is never the only signal: each row has motion, and sound adds to it.

Screws and the board act on **touch down**. Buttons act on release (with the pressed state on
touch down).

### 6.1 The board

| Input | What moves | Sound | Starts within |
|-|-|-|-|
| Tap a free screw, a box with a free slot of its color is open | the head lifts 4 units and turns; after 120 ms the screw rises and flies in a curve (about 350 ms) to the free slot, still turning; on landing the well pops (scale 1.0 to 1.15 and back in 150 ms) | ratchet, then pop as it comes free, clink on landing | 16 ms |
| Tap a free screw, no matching open box | same turn and flight, to the leftmost free tray slot; the slot pops on landing | ratchet, pop, clink (duller than the box clink) | 16 ms |
| The tray reaches one free slot `[C:tray]` | the free slot nudges (scale 1.0 to 1.08 and back in 300 ms) and the warning state shows (3.2.2) | one gentle tick, once | at landing |
| A box's last slot fills `[C:slots]` | the lid closes (200 ms); then the box slides out (300 ms) and the next one slides in (300 ms) with a small bounce; the preview boxes slide one place and a new one appears | lid sound | at landing |
| New box arrives and the tray holds matching screws | each matching tray screw jumps to the box in tray order, 120 ms apart, in an arc | a clink per screw, rising a little in pitch | at the slide in |
| A plank loses its last screw | it hangs for 80 ms, then falls off the board with a turn and goes out of sight; a soft dust puff appears where it fell | wooden knock | at the tap |
| A plank is down to one screw | it swings about that screw to its resting angle, a damped swing of about 0.7 seconds with a little overshoot | soft creak | at the tap |
| Newly freed or newly covered screws | change from covered styling to free styling (or the reverse) at the moment of the tap, not partway through the swing | none | at the tap |
| Tap a **covered** screw | the plank in front of it wiggles (plus and minus 3 degrees, two cycles, 220 ms); the covered screw's ghost ring brightens steadily for 600 ms and the covering plank's edge glows steadily for 600 ms (no pulsing) | a dull knock | 16 ms |
| Tap a free screw that has **nowhere to go** (GDD R25: the tray is full and no open box of its color has room, while some other free screw does fit) | the screw lifts 3 units, turns back about 30 degrees and settles in its hole (160 ms, it never leaves); the tray frame nudges sideways 4 units, twice (200 ms); the free screws that do fit an open box get a steady ring for 1 second (fades in and out over 150 ms each, no pulsing); the toast shows "The tray is full. Tap a screw that fits an open box." | a dull knock, lower than the covered screw knock | 16 ms |
| Tap a plank where there is no screw | the plank presses in by 2 units and returns (120 ms) | a faint tap | 16 ms |
| Tap the back board where there is nothing | a soft ring spreads from the touch (250 ms, fades) | a faint tick | 16 ms |
| Tap anywhere after the level is cleared or lost | nothing | none | |

- Hit testing: a free screw is hit by a circle of radius 24 around its center. If circles from
  two free screws could meet, the one with the nearer center wins (but the spacing rule keeps
  that from happening). If no free screw is hit, a covered screw hit by the same circle makes
  its frontmost covering plank wiggle. Otherwise the tap hits the plank or the board.
- **Taps during animations are accepted.** The logic runs on each tap at once, in tap order.
  Every screw in flight keeps flying; a new tap starts a new flight without waiting. The slot or
  tray place is decided by the logic at the tap, not when the earlier flights land. A quick
  player can tap the next screw while the last one is still flying.
- **A refused tap changes nothing.** It is not a tray use, it does not start the timer, and
  nothing is spent. The player can tap another screw at once.
- **Double taps** on the same screw: the second tap is ignored because the screw is already
  gone.
- **Tapping the pause button during a flight** pauses everything; flights finish when the
  player resumes.

### 6.2 Helpers

| Input | What moves | Sound | Starts within |
|-|-|-|-|
| Undo tap | the last action (a tap or a Screwdriver removal) reverses: the screw reverses its flight (350 ms) from its box or the tray slot back to its hole, turning backwards; a fallen plank rises back onto the board; a closed box (lid shut) reopens and slides back; a swung plank swings back to where it was | a soft reverse of the ratchet | 16 ms |
| Extra slot tap | a new tray slot grows in on the right (250 ms) and the frame widens to 310 | a small wooden pop | 16 ms |
| Screwdriver tap | a banner slides in over the helper bar (150 ms); all screws show their symbols bright | soft tick | 16 ms |
| Screwdriver then a screw with nowhere to go | the screw shakes back as in the refused tap above; the mode stays; the toast "That screw has nowhere to go." | a dull knock | 16 ms |
| Screwdriver then screw tap | the screwdriver icon touches the screw (100 ms), then the screw rises through the planks above it (it is drawn on top of everything) and flies as usual | ratchet, pop, clink | 16 ms |
| Helper button at count 0, can pay | the buy dialog fades in (150 ms) | soft tick | 16 ms |
| Helper button at count 0, cannot pay | the button shakes 4 units sideways, twice, in 200 ms; the toast shows | a dull knock | 16 ms |
| "Get and use" tap | the star bank number counts down by the price (400 ms); then the helper acts as above | per helper | 16 ms |

### 6.3 Buttons and controls

| Input | What moves | Sound | Starts within |
|-|-|-|-|
| Any button press (down) | scales to 0.96 and darkens | the low knock at low volume | 16 ms |
| Any button release on the button | the action runs; the button returns to size | none extra | at release |
| Press, slide away, release | the button returns and nothing happens | none | |
| Toggle (sound, music, symbols) | the knob slides across (120 ms) and the word On or Off changes | a tick, except when turning Sound off | 16 ms |
| Swatch tap (free) | the check mark moves to it; the board sample updates | a tick | 16 ms |
| Swatch tap (locked) | the swatch shakes 4 units, twice; the caption names the unlock | a dull knock | 16 ms |
| List scroll | follows the finger; momentum slows it | none | immediate |
| Level cell tap | the cell presses; the level slides in | knock | 16 ms |
| Link buttons | the pressed state; the phone opens the other app | none | at release |

### 6.4 Moments

| Moment | What moves | Sound |
|-|-|-|
| Level starts | the planks drop in (staggered, 300 ms total), the timer waits for the first action | a soft wood tap per plank at low volume |
| Level cleared | see 3.4; the stars pop; no flash, no strobing | short chime, rising |
| Out of room | the tray slots shake 6 units sideways for 250 ms; the sheet slides up after 300 ms | a soft falling tone |
| Pause | the screen covers in 150 ms | none |

The celebration uses color and shape from the graphic designer's direction, but nothing in it
flashes (section 7.5).

## 7. Accessibility

### 7.1 One-handed portrait

- Every screen works with one thumb, in portrait only.
- The bottom half (y 300 and below in content coordinates) holds every primary action:
  Play, Next, Retry, Resume, the three difficulties, Got it, Get and use, the helper bar, and
  every Back button.
- The pause button is in the top right and is the only frequently used control above the
  bottom half. It is deliberately a little away from the thumb to prevent accidental pauses,
  and the Android back button does the same job from anywhere.
- No gesture is required: no swipes, no pinch, no long press, no hold, no double tap. Scroll
  areas scroll by drag, and have every function reachable without scrolling to find a hidden
  control.

### 7.2 Contrast and text

- Text contrast is at least **4.5 to 1** against its plaque, for all text including captions and
  disabled labels' text where it carries meaning. The graphic designer's script checks every
  text and plaque pair listed here:
  primary label on primary button, secondary label on secondary button, quiet button label on
  its plaque, body on panel, caption on panel, tutorial line on its plaque, timer on top bar,
  star bank number on top bar, helper name on helper button, badge number on badge, toast text
  on toast, danger label on danger button, caption text on the picker plaque, text on the
  sheet and dialog panels, and legal text on its plaque.
- Non-text elements that carry meaning (icons, switch outlines, star outlines, the focus ring,
  the warning triangle, the padlock, the check mark) have at least **3 to 1** against what is
  behind them.
- Text sits on a plaque, never straight on wood.
- Minimum text size is 13 units (section 1.3).

### 7.3 Touch targets

- Every control has a target at least **48 x 48 units**. Where a visible control is smaller (the
  coffee chip, the pause icon, swatches) the target is still 48 by 48.
- Neighboring targets are at least 8 units apart, and a danger button is at least 16 units from
  the nearest other button.
- **A free screw's target never overlaps another free screw's.** Because every pair of screws
  is at least 48 units apart (3.2.1, decided by Bart), circles of radius 24 never meet in any
  state. A test checks it on the level data (section 8).
- Targets are the same size for left and right hands; nothing depends on handedness.

### 7.4 Color is never the only signal

| Signal | Color | Also |
|-|-|-|
| Screw color | the screw's color | a symbol on the head (on by default) |
| Box color | the box body | the same symbol on the box and on the preview |
| Free or covered | opacity differences | shading and shadow on free, dashed ring and flat on covered |
| Tray warning | warm tone | a triangle with an exclamation mark in the free slot, and a tick sound |
| Star earned | warm fill | filled shape versus outline, and caption text |
| Toggle state | switch color | the words "On" and "Off" and the knob position |
| Selected swatch | outline | check mark |
| Locked swatch | dimmed | padlock icon and caption |
| Pips | fill | filled shape versus outline |
| Danger button | red tone | the label "Erase everything" and its position below the safe choice |

- **Sound is never the only signal** either: every sound has a matching motion or change.
- **Colorblind symbols are on by default.** Each screw color has one symbol (circle, triangle,
  square, star, diamond, cross, ring, bar and so on; the graphic designer assigns them in
  docs/DESIGN.md). The symbol is the same on screws, boxes and the box preview: at least 16
  units on a 28 unit head, 14 on the front of an open box, 20 on a preview box, with strokes of
  at least 2 units. In the Workshop look the symbol is cut into the head as its drive recess, so
  no separate slot or cross can hide it, and it rotates with the screw. With symbols off every
  head gets a plain cross. Settings can turn symbols off.

### 7.5 Nothing flashes

- No element changes brightness more than three times in any one second, and in practice
  nothing changes brightness more than once a second.
- No full screen or large area flash, in celebrations, in the loss, or when a box closes.
- No strobing particles. Particle effects fade in and out over at least 120 ms.
- The tutorial hand, pulses and rings are steady or move slowly (one cycle per 1.2 seconds or
  slower).
- The tray warning is a steady state, not a blink.

### 7.6 Other

- **No time pressure.** The clock only changes the speed star. A level can never be lost to
  time.
- **No fine motor demands.** No drag is needed to play the board; the player only taps.
- **Text for screen readers.** Where the engine supports it, every control carries its visible
  label as its accessible name (for example the pause button is "Pause", the pause icon needs no
  other text). The board is not described to screen readers in v1.
- **System settings.** Android's font scale does not change canvas text in this engine setup;
  the type sizes in 1.3 are the guarantee.

## 8. What this file needs from the other roles

For the lead to pass on.

- **game-designer:** the GDD already gives the helper levels (8, 15, 25), the timer level (4),
  the tutorial lines, the band names, the unlocks, and the 48 unit spacing for every pair of
  screws, and this file now matches. Say if any count in section 2 changes.
- **level-engine-dev:** a test that every pair of screws on every generated and tutorial level
  is at least 48 units apart (screws never move, so this covers every state and rest pose). The
  tutorial `hint` list is in GDD 9.3. The logic needs to report whether a screw has a
  destination (for the refused tap, R25, and for the Screwdriver on the out of room sheet).
- **graphic-designer:** works from this file's rects (at b = 1 and f = 1; the level screen is
  drawn at any b from 1.0 to 2.0 and f from 0.7 to 1.167, and needs a back panel that works behind
  a rail as well as behind a stack). Provide the symbols, the hand, the star,
  the cup, the padlock, the warning triangle, the pause icon, and the helper icons. Contrast
  script pairs in 7.2. Covered screw styling per 3.2.2. Nothing flashes (7.5).
- **gameplay-dev:** hit testing and feedback per 6.1 and 6.2, the timer per 3.2.2, the hand and
  idle hint per section 5. The board view takes a scale b from the layout (3.2.1a); hit testing
  and the 24 unit target radius work in core coordinates and are scaled with it.
- **ui-dev:** every screen outside the level; back button table in 4.2; license and credits
  content in 3.10 and 3.11; links per 3.9; saving per 4.3. The level screen's layout rule
  (inputs Wc, Hc, dpu; outputs b, f, stacked or split) is in 3.2.1a, and needs the safe area
  and the device's dp per unit.
- **audio-dev:** sound list is the brief's; a button press reuses the knock quietly.

## 9. Review checklist (used on screenshots)

1. Level screen at 360 x 640 and 360 x 800 matches the budget tables.
2. The board core is 344 x 360 in core coordinates; no screw is outside the inset rectangle. The
   drawn board matches the b of 3.2.1a for the screenshot's size.
3. Every control is at least 48 x 48 units (at least 48 dp where f is below 1); free screws'
   targets do not overlap.
4. Text is at least 13 units and on a plaque; contrast numbers pass.
5. Primary buttons are in the bottom half; Back is at the bottom of every sub screen.
6. Symbols appear on screws, boxes and the preview by default.
7. A covered screw tap wiggles the right plank within 100 ms.
8. The tray warning shows at one free slot (with the triangle).
9. Level clear: Next is tappable at 500 ms; the celebration is under 2 seconds; no flashing.
10. Out of room: says "The tray is full"; Retry is the biggest button; Retry to playing is
    under 2 seconds.
11. Every string matches this file word for word; no em dashes, no double hyphens.
12. Back button table in 4.2 holds on every screen.
13. Safe areas: nothing under a notch or gesture bar.
14. Tablet and foldable: the board is scaled uniformly (never stretched) as in 3.2.1a, bars and
    rail are composed, other screens use a column of at most 480.
15. Level 1 clears in under 30 seconds with no reading.

## 10. Decided by Bart

1. **Quitting or being killed mid-level.** The player comes back to the same level, started
   again from the beginning. The exact board is not kept. Retry is still free. The save only
   needs the current level number. (Sections 3.3, 4.1, 4.3.)
2. **A brand new player skips the title and opens straight into level 1.** Approved. (Section 5.)
3. **The fixed board core is approved**: 344 x 360 units, the same level geometry on every
   device. On big phones, unfolded foldables and tablets the board view scales up uniformly to
   fill the board panel, and touch targets scale with it. (Section 3.2.1a.)
4. **Buying a helper from its button.** A tap on a helper with count 0 offers "Get and use" for
   stars. It happens only on the player's tap. (Sections 3.2.2, 3.13.3.)
5. **Out of room offers only helpers the player owns** (Undo, Extra slot, and Screwdriver if
   owned). It never offers to buy one. (Section 3.5.)
6. **Relaxed shows only the free Undo** and hides Extra slot and Screwdriver. (Section 3.2.2.)
7. **The speed and clean markers next to the timer stay.** They get checked at Gate 1.
   (Section 3.2.2.)
8. **Pause covers the board.** (Section 3.3.)
9. **The Buy me a coffee chip goes top right on the title screen.** (Section 3.1.)
10. **Spacing: every pair of screws is at least 48 units apart**, in every state including rest
    poses. This replaces the earlier rule of 48 for free screws and 32 for any pair. (Section
    3.2.1.)
11. **The timer starts at the first action**, including using a helper (GDD S6). (Section 3.2.2.)
12. **Undo costs the Clean star** (any helper does, GDD R32). **Daily and Relaxed open after
    level 8**, so the title shows them locked with a note before then. (Sections 3.1, 3.2.2.)
13. **Look direction: Workshop.** Box layout settled for it in 3.2.2 (wells on top, painted front
    band with the symbol, lid leaning back above).

## 11. Open questions

None for Bart at this point. The GDD (rules R36 to R38) now agrees with this file on quitting mid
level, the out of room sheet and buying helpers.
