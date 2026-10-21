# Phase 1 look directions

Three directions for Hard Stop 1, built as real Godot scenes in `src/directions/`. All three
show the same hand-placed board (7 planks in 3 layers, 17 screws in 5 colors, one covered screw
showing through, one plank hanging from its last screw at its rest angle), the same box row and
tray, the same level clear and the same title, so you compare looks and not layouts. Layouts
follow docs/UX.md (the 360 x 800 tall table: board core 344 x 360, 28 unit screw heads, free
screws at least 48 apart; the closest free pair on this board is 51 apart).

Screenshots are 1080 x 2400 (a 20:9 phone), made by `bash tools/art/capture_directions.sh`:

| | Board | Boxes and screws | Level clear | Title |
|-|-|-|-|-|
| A. Workshop | [board](workshop-board.png) | [boxes](workshop-boxes.png) | [clear](workshop-clear.png) | [title](workshop-title.png) |
| B. Nordic | [board](nordic-board.png) | [boxes](nordic-boxes.png) | [clear](nordic-clear.png) | [title](nordic-title.png) |
| C. Toybox | [board](toybox-board.png) | [boxes](toybox-boxes.png) | [clear](toybox-clear.png) | [title](toybox-title.png) |

The "boxes" shot is a sheet: the real box row and tray at the top, then all nine proposed screw
colors with their symbols at large size, an open box and a preview box at twice size, and a
free screw beside a covered one.

The scenes themselves (src/directions/) were removed at the end of Phase 4, once Bart had chosen
Workshop and the real renderers in src/render/ replaced them; these screenshots are the record.

## What all three share

- **Wood.** One CanvasItem shader (`shared/wood.gdshader`) draws each plank on one quad from a
  signed distance shape (bar, plate, L, disc, ring, triangle), so edges stay smooth with no
  MSAA. In one pass it draws the plank's soft shadow on everything behind it (longer for front
  layers), the visible edge that shows its thickness (darker toward the back, with plies for
  plywood), a bevel lit from the upper left, a thin line of light on the lit rim, and the grain.
  Holes are real holes: you see the board through an empty one.
- **Grain.** Flat sawn rings: the face cuts the growth rings at a depth that wanders along the
  plank, which draws the arches of a real board. Warp, figure, long fibers and pores come from
  one 256 x 256 noise texture made at startup with the engine's FastNoiseLite. Each plank gets
  its own seed, ring center, grain angle and a small tone shift, so no two look alike.
- **Screws.** Metal heads (`shared/screw.gdshader`): a bare metal rim with brushed marks, a
  colored domed cap, a soft contact shadow, and the drive recess cut in the shape of the color's
  symbol. The bar color has a slot, the cross color a cross head, the square color a square
  drive, the star color a star drive, and so on. So **the symbol is never hidden by a separate
  slot or cross**, because it is the slot (this answers the UX note in 7.4). The recess and the
  rim marks turn with the screw, so the light on the recess walls moves as it turns. On dark
  caps the recess shows bright bare metal, on light caps it is dark, so the symbol reads on every
  color. With symbols switched off, every head gets a plain cross.
- **Covered screws** (docs/UX.md 3.2.2): drawn flat at about 45 percent, with a dashed ring and
  no shadow, keeping color and symbol.
- **Empty box wells and tray slots** use a neutral hollow, never the box color, so an empty well
  can't be mistaken for a screw.
- Text is Godot's default font (bold is the same font emboldened in code), always on a plaque.

## Proposed screw colors and symbols

Nine colors, the same in every direction. Picked with a scratch script that simulates
protanopia, deuteranopia and tritanopia (Machado 2009) and measures OKLab distance between every
pair. The closest pairs are given very different symbols. The full check script, which also
tests every pair on every wood theme, comes in Phase 4.

| Color | Hex | Symbol | Closest look-alike (simulated) |
|-|-|-|-|
| Red | #e5331e | triangle | pink under tritanopia (0.10) |
| Orange | #f5922a | square | pink under tritanopia (0.07) |
| Yellow | #f9d63a | star | white under tritanopia (0.11) |
| Green | #2f875a | circle | red under protanopia (0.11) |
| Sky | #4bc4ed | diamond | pink under deuteranopia (0.11) |
| Blue | #1e45b8 | cross | purple under protanopia (0.08) |
| Purple | #8454d9 | ring | blue under protanopia (0.08) |
| Pink | #e062a6 | bar (slot) | orange under tritanopia (0.07) |
| White | #f7f2ea | moon | yellow under tritanopia (0.11) |

The worst pair across all three simulations is 0.07 in OKLab (orange and pink for tritanopia,
the rarest of the three), and those two carry a square and a bar. Lightness is spread from blue
(darkest) to white so pairs that lose their hue still differ in brightness. I left out black: it
merges with holes, shadows and walnut. A tenth color, if the GDD wants one, would be a teal or a
lime; I'd rather keep nine.

## A. Workshop

**Mood.** An evening at the workbench. Warm lamp light from the upper left falls across
pegboard; honey oak offcuts are screwed to a dark walnut board. Cozy, tactile, a little
old-fashioned in a good way.

- **Palette.** Pegboard brown #7a5a3d into near black at the corners, walnut plaques #2c1d13,
  cream text #f7ead4, brass #d8a445 for the main action and badges.
- **Wood.** Oak planks (#dcae6c to #a8713a, open pores, strong rings) with a 7 unit edge and a
  deep bevel; walnut back board with a lamp falloff across it.
- **Metal.** Polished steel rims, glossy enamel caps.
- **Boxes and tray.** Little oak trays with drilled wells, the lid leaning back above, the color
  as a painted band on the front with the symbol stenciled on it. Preview boxes are closed trays
  with a painted lid. The tray is a brushed steel magnetic parts tray with riveted ends.
- **Clear.** Brass stars stamped from sheet, oak shavings curling around the card, sawdust motes
  in the light.
- **Why it feels good to touch.** Strongest depth of the three: thick edges, firm shadows and a
  bevel that catches the lamp make every plank look like it can be picked up. Brass plates with
  screw dots read as real buttons.
- **Risk.** The darkest of the three. Plaques and planks are high contrast, but it should be
  checked on a phone in daylight.

## B. Nordic

**Mood.** A quiet morning in a bright room. Pale birch plywood on a sage painted board, a linen
wall, soft window light. Calm and airy, made for thinking.

- **Palette.** Linen #ece8e1, white plaques #fbfaf7, charcoal text #2e3338, pine green #2f5d50
  for the main action, ochre stars #d9a441.
- **Wood.** Birch plywood (#efe2c9 to #d5bf98, faint grain, no pores) with a thin 5 unit edge
  that shows its plies; a sage painted ply back board (#aab7ae) whose edge shows raw birch plies.
- **Metal.** Satin steel rims, matte powder coat caps with a soft wide sheen.
- **Boxes and tray.** Birch trays lined with felt in their color, the lid slid back as a strip
  across the top with the symbol on it. The tray is a slim birch shelf with five dimples.
- **Clear.** White card, filled ochre stars, a few paper dots and strips drifting down. The
  board stays visible under a light veil.
- **Why it feels good to touch.** Soft, round, rubbery buttons with generous space; the matte
  screws look like they would feel smooth. Least dramatic depth: the shadows are soft and the
  edges thin.
- **Risk.** Lowest energy of the three. The first version had pale planks on a pale board and
  they blurred together; the sage board fixed that, but the planks still pop less than in A or C.

## C. Toybox

**Mood.** A Saturday morning on the playroom floor. Chunky lacquered beech on a navy painted
board, a bright sky with polka dots, the name spelled in painted alphabet blocks. Cheerful and
bouncy.

- **Palette.** Sky #3fa9e0 to #2a9fd6 with white dots, navy #22306e text and board, white
  plaques, sunny yellow #ffbf1f for the main action, coral #ff6b3d badges and ribbon.
- **Wood.** Beech (#f2cf98 to #d9a865) with a 10 unit edge, extra rounded corners, a pillowy
  bevel and a lacquer gloss; the navy back board shows its grain through the paint.
- **Metal.** Chrome rims, candy gloss caps with a sharp highlight.
- **Boxes and tray.** Solid painted bins in the screw color with a white edge, the lid flipped up
  behind, white cups for wells, the symbol on a white sticker. The tray is a chunky white bar
  with five cups.
- **Clear.** Glossy stars with a white sticker edge, soft rays, confetti in the screw colors.
- **Why it feels good to touch.** The thickest planks and the roundest corners, like toy blocks;
  buttons have a deep lip and look squashy. Highest contrast between planks and board.
- **Risk.** The bins are big blocks of color, so the box row is loud. Younger looking than the
  other two; it may not suit everyone.

## Rendering cost on a mid-range phone

Measured nothing on a phone yet (that waits for Phase 3). Estimates from the shaders:

- **Planks** are the cost. Each plank fragment evaluates its shape about 8 times (face, 4
  samples for the edge, the shadow, 2 for the bevel normal), each with the hole loop, and takes 5
  samples of the small noise texture: roughly 250 to 300 ALU operations. Each plank quad is
  padded for its shadow, so at 1080 x 2400 the back board and seven planks shade about 3.5 million
  fragments a frame, with blending. That is within reach of a mid-range GPU at 60 fps but not
  with much room to spare.
- **The fix is cheap and planned for Phase 4:** the board only changes when a plank moves, so
  each plank's face, edge and grain can be drawn once into a texture when the level loads (or
  the whole still board into one texture), and a frame then costs a textured quad per plank plus
  its shadow. The shader stays as the way those textures are made.
- **Screws** are small quads (about 135 x 135 pixels each) with a few symbol evaluations; even 30
  of them cost less than one plank.
- **Backgrounds** are one full screen pass each: the pegboard (one texture sample and a grid),
  the linen (two samples) and the polka dots (math only) are all light. Most of each is behind
  the back board; Phase 4 can skip drawing under it.
- **UI** is StyleBoxFlat panels and _draw calls: small and cheap. Toybox and Workshop stack two
  or three panels per button for lips and bevels, a little extra overdraw on small areas.
- **Draw calls.** Every plank and screw has its own material, so they don't batch: about 60 to
  80 draw calls for the level screen, which is fine for the Mobile renderer.
- **No Light2D.** The light direction is a fixed upper left, baked into the shaders; real 2D
  lights would cost more and add nothing here.

The three directions cost about the same. Toybox's thicker edges and Nordic's wider shadow blur
make their quads a few percent larger; none of the differences matter. Choosing a direction is
not a performance choice.

## 3D with an orthographic camera?

I don't think it would look clearly better. What 3D would add is true edge perspective and real
specular on a turning screw head, and the 2D shaders already fake both convincingly at phone
size. It would cost real shadows and MSAA in the Mobile 3D renderer, and every plank would need
a mesh built from its shape. The rules are 2D anyway. I recommend staying in 2D. One idea for
later: a falling plank could tumble in 3D for its last second, since it no longer matters to the
rules, but it isn't needed.

## Recommendation

**A. Workshop**, with two things borrowed from the others.

- It sells the name best. It looks and feels most like wood, and the depth (thick edges, firm
  shadows, lamp light) makes a plank falling off the board a real moment, which the fun
  checklist calls the best moment in the game.
- It is the most original of the three. Pegboard, brass plates and shavings belong to this game
  and to no screw puzzle I know of.
- Its world explains the themes for free. Oak, walnut, maple, cherry and ebony are just
  different timber on the same bench, and steel, brass, copper and black screws are different
  tins of screws.
- Borrow from Toybox: its rounder corners and pillowy bevel on the planks, which make them
  friendlier to touch. Borrow from Nordic: birch plywood with ply edges as an unlockable wood
  theme.
- The one thing to check is daylight brightness on your phone. If it is too dark, the
  background and plaques can lift a step without changing the mood.

If you want the widest appeal and the most energy, Toybox is the strong second choice.
