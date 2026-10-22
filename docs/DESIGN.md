# WoodLogic design: Workshop

Owner: graphic-designer. Status: Phase 1, after Hard Stop 1. Bart chose the Workshop direction,
symbols as the drive recess, the nine screw colors below, and one wood per board set by the wood
theme. Layout lives in docs/UX.md and is never repeated here; this file says how things look and
move. The Phase 1 mock-ups are in `src/directions/workshop/` and `src/directions/shared/`, with
screenshots in docs/design/ (`workshop-*.png`) and the comparison in docs/design/directions.md.

All lengths are design units (docs/UX.md 1.1). Colors are sRGB hex. "Upper left" means screen
space, y down.

## 1. The mood

An evening at the workbench: warm lamp light from the upper left across pegboard, honey oak
pieces screwed to a dark board, polished steel screws, brass plates for the controls. Tactile,
warm, a little old-fashioned. The risk is that it is dark, so daylight readability on a phone is
checked at every playtest gate; if it is too dark, the background and plaques lift a step (the
`lift` tokens in section 2) without changing anything else.

## 2. Color tokens

Text pairs are WCAG contrast against the plaque they sit on (the plaque is 94 percent opaque, so
it is measured as blended over the pegboard). Every text pair must stay at 4.5:1 or more and
every meaningful non-text mark at 3:1 or more (docs/UX.md 7.2); the Phase 4 check script tests
all of them.

| Token | Value | Used for | Contrast |
|-|-|-|-|
| `bg.pegboard` | #7a5a3d, falling to about 45 percent at the corners | the wall behind everything | |
| `bg.hole` | #1e120a | pegboard holes | |
| `board.walnut` | #6f4a30 to #47291a, edge #3a2215 | back board on the oak, maple, cherry and birch themes | |
| `plaque` | #2c1d13 at 94 percent | every panel that holds text | |
| `plaque.border` | #d8a445 at 55 percent, 1 unit | plaque outline | |
| `text` | #f7ead4 (cream) | all text on plaques | 13.3 |
| `text.dim` | #e8d6b8 | notes, captions, details | 11.1 |
| `text.gold` | #f3c766 | the "+{k} stars" summary | 9.9 |
| `primary` | #d8a445 (brass), lip #8a6420 | Play, Next, Retry, Resume | |
| `primary.text` | #2a1708 | label on brass | 7.6 |
| `secondary` | #4b3121 (walnut block), lip #24160d | all other buttons, helper buttons | |
| `secondary.text` | #f7ead4 | label on walnut block | 10.0 |
| `quiet.line` | #d8a445 at 60 percent, 2 units | Back, coffee chip outline | |
| `danger` | #8e2a1c, lip #4f160e | "Erase everything" only | 7.1 with `text` |
| `badge` / `badge.text` | #d8a445 / #2a1708 | helper count badges | 7.6 |
| `star.earned` | #e9b23e face, #9a6c1c rim, #f7d77e facets | earned stars | |
| `star.missed` | outline #d9b46a at 90 percent, 3 units | stars not earned | 8.1 (non-text) |
| `warn` | #e9a23b | tray warning tone, warning triangle fill | |
| `warn.mark` | #2a1708 | the "!" and the triangle's outline | 7.9 on `warn`, 6.8 on the steel tray |
| `focus` | #f7ead4, 3 units | keyboard and gamepad focus ring | 5.3 on the pegboard |
| `veil` | #140d08 at 62 percent | behind the level clear card | |
| `shadow` | #1a0d05 | every cast shadow | |
| `lift` (only if daylight needs it) | pegboard #8a6a4a, plaque #3a281b | brighter variant | recheck all pairs |

Brass against the pegboard is 4.2:1, so a brass button never needs an outline to be found.

## 3. Screws

### 3.1 The head

A screw head is 28 across on the board (22 in a box well, 28 in the tray). Drawn by
the screw shader (Phase 1: `src/directions/shared/screw.gdshader`) on one small quad:

- a soft contact shadow, offset down and right by 0.14 and 0.26 of the radius, blur 0.22 of the
  radius, `shadow` at 55 percent;
- a bare metal rim, the outer 20 percent of the radius, in the metal finish (section 6), with
  brushed marks that turn with the screw;
- a domed cap in the screw color, glossy enamel, lit from the upper left;
- a thin dark groove where the cap meets the rim;
- **the drive recess in the shape of the color's symbol** (Bart approved). The recess is the
  symbol: the bar color has a slot, the cross color a cross, and so on, so no slot or cross ever
  hides the symbol. The symbol fits a 16 unit circle on a 28 unit head with strokes of at least
  2 units (docs/UX.md 7.4). Its far wall catches the light and its near wall casts a shadow
  into it, and both move as the screw turns. On dark caps (blue, purple) the recess floor shows
  bright bare metal; on the others it is dark. A thin dark lip just outside the recess keeps it
  crisp on every cap.

### 3.2 Colors and symbols

| Index | Color | Hex | Symbol (recess) | Closest other color, any simulation | OKLab distance |
|-|-|-|-|-|-|
| 0 | Red | #e5331e | triangle | pink, tritanopia | 0.102 |
| 1 | Yellow | #f9d63a | star (5 points) | white, tritanopia | 0.109 |
| 2 | Sky | #4bc4ed | diamond | pink, deuteranopia | 0.111 |
| 3 | Blue | #1e45b8 | cross | purple, protanopia | 0.083 |
| 4 | Orange | #f5922a | square | pink, tritanopia | 0.072 |
| 5 | White | #f7f2ea | moon (crescent) | yellow, tritanopia | 0.109 |
| 6 | Green | #2f875a | circle (round socket) | red, protanopia | 0.106 |
| 7 | Purple | #8454d9 | ring | blue, protanopia | 0.083 |
| 8 | Pink | #e062a6 | bar (slot) | orange, tritanopia | 0.072 |

Worst pair per view across all nine (Machado 2009 simulation at full severity, distance in
OKLab): normal vision 0.160 (red and pink), protanopia 0.083 (blue and purple), deuteranopia
0.108 (blue and purple), tritanopia 0.072 (orange and pink). Every one of those pairs has
symbols of different shape families (cross and ring, square and bar). Lightness runs from blue
(darkest) to white so colors that lose their hue still differ in brightness. Black is left out
on purpose: it merges with holes, shadows and dark woods.

**Index order.** The index is what the logic, the generator and the data use, and the GDD says
tutorials use the first four colors and levels use up to eight. So the order is chosen to make
every prefix as distinct as possible: I searched every order of the nine for the best worst pair
among the first 4, then the first 5, and so on.

| Colors in use | Worst pair in this order | In the Phase 1 mock-up order |
|-|-|-|
| first 4 | 0.221 | 0.106 |
| first 5 | 0.130 | 0.106 |
| first 6 | 0.109 | 0.106 |
| first 7 | 0.106 | 0.083 |
| first 8 | 0.083 | 0.072 |
| all 9 | 0.072 | 0.072 |

The mock-ups in src/directions/ still use the old order (red, orange, yellow, green, sky, blue,
purple, pink, white); only the order changes, never a color or its symbol.

### 3.3 Symbols switched off

Every head gets the same plain cross recess (the cross color's head is unchanged), so the screw
still looks like a screw and still shows its turn. Boxes and previews show color only, with no
symbol (docs/UX.md 3.2.2). The cap colors are the same.

### 3.4 Telling a screw from its plank

Under color blindness, red and green caps come close to every brown wood (as close as 0.03 on
oak, walnut and cherry), and yellow comes close to maple. That is fine because a screw never
relies on its cap color to stand out from the wood: the bright metal rim and the dark contact
shadow outline every head. Rule for the check script: the rim and shadow together must reach
3:1 against the plank face on every wood theme; cap against wood is reported but not required.

## 4. Covered screws (the ghost)

A covered screw shows faintly through the plank in front of it (docs/UX.md 3.2.2):

- drawn right after the topmost plank that covers it, so planks further in front still hide it;
- flat: no dome, no rim, no gloss, no shadow, no turning;
- a disc of the screw color at 45 percent opacity, 92 percent of the head's radius;
- the symbol at 70 percent, in the cap color darkened 55 percent (or lightened 60 percent on
  blue and purple);
- a dashed ring at the head's radius: 12 dashes, 55 percent on, 1.6 units wide, #2a1708 at 70
  percent;
- on dark woods (ebony) the symbol ink and the dashed ring are light (the cap color lightened
  60 percent, and cream), so they still show through;
- when the covering plank leaves, the ghost becomes the real head over 150 ms (opacity and
  shading together, no flash);
- in Screwdriver mode every ghost shows its symbol at full strength (docs/UX.md 3.2.3).

## 5. Wood themes

One wood per board, set by the theme (Bart approved). Each theme sets the plank wood and the
back board; the back board changes only when the planks would otherwise blend into it. Each
plank still gets its own seed, ring center, grain angle and a tone within 3 percent, so no two
look the same. Unlock milestones come from the GDD.

| Theme | Plank face light to dark | Plank edge | Grain | Back board |
|-|-|-|-|-|
| **Oak** (default) | #dcae6c to #a8713a | #8a5a2c | strong rings, open pores (0.22), rings 0.11 per unit | walnut |
| Walnut | #8a5e3f to #5e3c26 | #4a2f1d | wavy figure, fine pores (0.12), rings 0.08 | ebonized oak #3a2a20 to #251a12 |
| Maple | #edd5a8 to #d1af7c | #b58f58 | faint rings (contrast 0.35), no pores, a little curl | walnut |
| Cherry | #c8825a to #9a5636 | #7d4429 | soft rings, fine pores (0.08), warm tone | walnut |
| Ebony | #3b312c to #221b18 | #1a1412 | tight dark stripes, almost no rings | pale maple #d9bc8c to #b9955f |
| Birch plywood (possible extra) | #efe2c9 to #d5bf98 | #e6d5b4 with 4 plies (lines #a68d68) | faint, no pores | walnut |

Notes for the check script: maple with yellow and white caps and birch with white caps are the
weakest cap and wood pairs (rule 3.4 covers them). Walnut planks on the ebonized board and ebony
planks on the maple board must keep at least 1.6:1 luminance contrast between plank face and
board so the silhouette reads; the script checks that too.

## 6. Metal finishes

The finish sets the rim, the recess floor on dark caps, and how glossy the cap is. Cap colors
never change with the finish.

| Finish | Rim light | Rim dark | Cap gloss | Notes |
|-|-|-|-|-|
| **Steel** (default) | #f4f1ea | #4c463e | 0.55, highlight power 26 | polished, neutral |
| Brass | #f6dc93 | #3d2c0b | 0.5, power 22 | warm; matches the brass controls |
| Copper | #f3b48a | #3f1a0b | 0.5, power 22 | check against orange and red caps |
| Black | #9a9aa0 | #1c1c1f | 0.35, power 14 | black oxide, satin; the recess floor on dark caps stays light grey #c8c8cc so the symbol still reads |

## 7. Light, bevels and edges

- **One light, fixed:** from the upper left, the screen space direction (-0.55, -0.83), tilted
  toward the viewer. It never moves with the camera or a plank; a rotated plank turns its
  local light so its lit side stays upper left. No Light2D.
- **Planks:** the visible edge (the thickness) is 7 units, extruded down and a little right
  along (0.3, 1.0), darker toward the back and showing end grain streaks. The face has a 4.5
  unit rounded bevel (strength 1.5): bright where it faces the light, darker where it faces
  away, with a crisp line of light on the lit rim. Corners are rounded (12 units on bars and
  plates; Bart may want them a little rounder, borrowed from Toybox, which is a one number
  change).
- **Holes** go through: an empty hole shows the board behind it, in shadow, with its far wall
  lit.
- **Back board:** 10 unit edge, 6 unit bevel, and a gentle lamp falloff across its face (35
  percent from the lit corner to the far corner).
- **Boxes and tray** use the same light. The boxes are small oak trays (the same oak as the
  theme, or a fixed oak if the theme is dark, so the box row stays readable): a lid that swings
  up and leans back when open, drilled wells that read as hollows in a neutral dark wood (never
  the box color, so an empty well can't look like a screw), and the box color painted on the
  box with its symbol stenciled in dark or light ink, whichever reads. A box in the queue is
  closed, with its painted lid and symbol on top. The tray is a brushed steel magnetic parts
  tray with riveted ends and dished slots. The UX designer is settling the box layout.

## 8. Shadows

- Every plank casts a soft shadow on everything behind it, in `shadow`, offset (5, 8) units,
  blur 6, opacity 55 percent.
- Layer 0 is the front and layer 4 the back (GDD). The offset grows by 25 percent for each layer
  nearer the front: layer 4 (5, 8), layer 3 (6.25, 10), and so on to layer 0 (10, 16). Front planks
  look higher, and a front plank's shadow falls on the planks below it.
- Each layer further back is also 3.5 percent darker (layer 4 by 14 percent), as if less light
  reached it. Planks are one wood per board, so this is what parts two overlapping planks besides
  the edge and the shadow.
- The back board casts its shadow on the pegboard: offset (4, 12), blur 16, opacity 70 percent.
- A screw's contact shadow is part of its head (section 3.1). While a screw lifts out, its shadow
  moves further down right and softens (offset up to twice, blur up to three times), so height
  reads without scaling much.
- A swinging plank keeps its shadow rules; the shadow stays down right whatever the angle.
- A falling plank's shadow fades out over its first 200 ms, as it leaves the board.

## 9. Motion

Every tap answers within 100 ms, nothing slows play, and a quick player can tap the next screw
while the last one is still flying (each flight runs on its own). The logic model decides
everything at the moment of the tap; animation only shows it. Easing names are Godot's Tween
transitions.

| Moment | What moves | Timing and easing |
|-|-|-|
| Tap on a free screw | the head dips (scale 0.94) | 60 ms, in the same frame as the tap |
| Unscrew | the screw turns one and a half times counterclockwise while rising: scale 1.0 to 1.15, shadow grows | 220 ms, sine in and out; the recess and rim marks turn, so the light on them moves |
| Flight | an arc to its box well or tray slot, 40 to 60 units high, shrinking to well size on arrival | 320 to 380 ms by distance, cubic out |
| Landing | a small settle: overshoot 6 percent and back | 80 ms, back out |
| Box fills | the lid swings down and shuts | 180 ms, quad in, a 2 unit bounce at the end |
| Box leaves | it slides out of the row | 220 ms, cubic in |
| Next box | the queue slides along and the new box opens its lid | 260 ms, back out (8 percent overshoot) |
| Tray to new box | matching tray screws hop into it in tray order | 200 ms each, starting 80 ms apart |
| Swing | the plank swings on its last screw toward the logic's rest angle as a damped swing with a little overshoot: angle = rest + (start - rest) e^(-zeta w t) cos(w_d t), with a natural frequency of 1.4 cycles per second and damping ratio zeta 0.5 (about 16 percent overshoot) | settles inside 0.9 s; covered and free styling follow the logic at once, not the animation |
| Fall | a plank with no screws left drops off the board and out of the bottom of the screen, turning a little from where its last screw was; a real physics body is allowed here | gone within 0.9 s; knock sound as it leaves the board |
| Covered tap | the topmost plank in front wiggles about its center, and the ghost rises to 70 percent | plus and minus 2.5 degrees, 3 half swings decaying over 240 ms, starting within 100 ms; ghost back over 300 ms |
| Tray warning (one free slot) | the steel frame warms toward `warn` and a warning triangle appears in the free slot | 200 ms fade in, then steady; no blinking, no pulse |
| Level clear | per docs/UX.md 3.4: veil fades in, heading drops in, stars pop one by one (scale 0 to 1.12 to 1), shavings drift and settle, sawdust motes drift slowly | all at rest by 1.6 s, always under 2 s; Next is tappable from 500 ms |
| Title windmill (TitleBoard) | once the board has faded in, the sails make one quarter turn, then rest; nothing on the board moves or redraws after that, so a title left open costs no frames | 8 s, sine in and out (at most about 17 degrees a second); `set_turning(true)` turns them once more |

**Nothing flashes** (docs/UX.md 7.5). No area changes brightness more than once a second, there
is no full screen or large area flash, every particle fades in and out over at least 120 ms, and
nothing loops faster than one cycle per 1.2 seconds. The star pop changes scale, not brightness.

## 10. Performance plan

Target: 60 fps on a mid-range Android phone with the Mobile renderer, with a frame under 13 ms so
there is room to spare. Measured on Bart's phone at Gate 2 with Godot's monitors (frame time,
draw calls); the numbers below are from this PC (Phase 4).

- **Still planks are drawn to textures once per level** (`PlankView.bake()`). The bake shader
  works from the logic's outline polygon (simplified to within 0.3 units, at most 128 points, and
  a ring's hole at most 64) in one loop that gives the signed distance and the outward direction,
  and writes two textures at the device's pixel scale (at most 3 texels a unit and 1024 a side):
  the face (grain and coverage) and the shape (bevel slope, rim line, shadow silhouette). Each
  frame a plank is then one quad with seven texture samples a pixel: shadow, four for the edge
  along the screen down direction (so a swinging plank keeps its edge at the bottom), face and
  shape, and a few dozen operations for the light. The full grain and shape work runs only in the
  bake.
- **The back board panels bake the same way**; the pegboard is one light full screen pass.
- **Screws stay live** in their shader: small quads, cheap, and they need to turn.
- **Fading with `modulate` works on every view**: the plank and screw shaders multiply by the
  node's modulate, and cached views lay down their texture premultiplied with modulate applied
  to color and alpha (checked on the Mobile renderer).
- **Boxes, the tray and map nodes are cached** (`CachedDrawing`): they draw live while they change
  and, two frames after they settle, draw once into a small texture and become one textured rect.
  Godot 4 gives every polygon, circle and panel its own draw call, so this took the box row and
  tray from about 170 draw calls to 6.
- **Measured** (a generated level with 10 planks, 15 screws, two boxes, two previews and the tray,
  at 1080 x 2400): 34 draw calls for the board, boxes and tray together, about 1.4 ms a frame on
  this PC. The level's own top bar and helper bar are on top of that; my stand-ins for them cost
  55 more, so the level scene should cache its bars too.
- **Budgets for the level screen:** at most 120 draw calls; at most 2.5 screens' worth of shaded
  fragments a frame (about 6.5 million at 1080 x 2400), each at most about 10 texture samples or
  60 operations.
- **Load time:** each plank's bake is two small render passes in one frame; the level scene bakes
  while the board is hidden (behind the clear screen or before the first frame). To be measured
  on the phone; the target is under 30 ms of GPU time for a level.
- If a phone still misses the budget, the first step down is 2 edge samples instead of 4; the
  look doesn't change at phone distance.

## 11. The renderers (built in Phase 4)

In `src/render/`, against docs/ARCHITECTURE.md sections 7 and 11.1, with tests in tests/render/.
They draw from plain values and the logic's own outline polygons (`PlankData.outline()` and
`inner_outline()`), so the picture and the rules always use the same shape. They read the look
only from `Looks.current`; a change of wood, metal or symbols is a rebuild (setup and bake again).

| Class | What it is |
|-|-|
| `Palette` | the nine colors and symbols of 3.2 in index order, symbol outlines, ink, contrast |
| `Looks` | `wood(id)`, `metal(id)`, `WOODS`, `METALS`, `current` (sections 5 and 6) |
| `Tokens` | the colors of section 2 and the type sizes of docs/UX.md 1.3, and the pairs the contrast check covers |
| `Icons` | every icon in one color: `Icons.draw(ci, name, center, size, color)`, `Icons.NAMES` |
| `PlankView` | a plank: setup from the outline, `bake()`, `wiggle()`; a plain stand-in until baked |
| `ScrewView` | a head in three sizes (28, 24, 32): `set_covered` (the ghost, 150 ms fade), `set_turn`, `set_lift` |
| `BoxView` | an open box or a preview: `set_count`, `set_lid`, `close()` (section 7's look, UX 3.2.2's layout) |
| `TrayView` | the steel tray: `set_filled`, `set_warning`, `set_full` |
| `BoardView` | the pegboard and the theme's back board panels (one, or the board panel and the rail) |
| `ClearEffects` | the level clear: veil, popping stars, shavings and motes; `play()`, `skip()`, `finished` |
| `MapNodeView`, `MapTrail` | the progress map's nodes (cleared, hard, next, locked) and the path between them |
| `TitleBoard` | the title's decorative board: a windmill of planks on the back board, baked into one texture, sails turning once then resting |
| `CachedDrawing` | the base that turns a still view into one textured rect (section 10) |
| `Paint`, `WoodNoise`, `RenderFonts` | small shared helpers |

The shaders are in `src/render/shaders/`: `plank_bake`, `plank`, `wood_grain` (included by the
bake), `screw` and `pegboard`.

Tools in tools/art/: `capture.gd` (any scene to a PNG at phone size), `app_icon.gd` (writes the
launcher, store and adaptive icon layers into icons/), and review sheets in tools/art/sheets/
(the board on a real generated level, every part, every icon). The check script is
tests/render/test_colors.gd: `bash tools/test.sh test_colors` prints its numbers.
