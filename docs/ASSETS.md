# Assets

Every visual and every sound in WoodLogic is made by the game's own code. Nothing comes from
an image, audio, font or model file made anywhere else. The only exceptions are what ships
inside the Godot engine, such as its default font, and the app icon PNGs, which our own script
draws (below). Each entry below names the thing, the code that makes it, and how.

The screenshots in docs/design/ are pictures of our own Phase 1 design scenes, taken with the
game's own windowed runs. They document the design choice and are not part of the game: the
exports leave docs/ out.

## Visuals

| What | Made by | How |
|---|---|---|
| Godot's default font (all text) | the engine | ships inside Godot |
| Godot's default font, heavier, for numbers on the map badges | src/render/render_fonts.gd | the engine's default font with a heavier weight set in code |
| Planks | src/render/plank_view.gd, shaders/plank_bake.gdshader, shaders/plank.gdshader, shaders/wood_grain.gdshaderinc | each plank's face is baked once, when the level loads, from the logic's own outline polygon: a signed distance gives the bevel and the round holes, and procedural grain (flat sawn rings, warp, figure, fibers, pores) colors it per wood theme. Every frame one quad draws its soft shadow, the edge that shows its thickness, and the lit face. |
| The wood noise the grain samples | src/render/wood_noise.gd | one small tiling noise texture made at startup with the engine's FastNoiseLite |
| Screws | src/render/screw_view.gd, shaders/screw.gdshader | one quad per screw: a contact shadow, a brushed metal rim, a domed enamel cap in the screw's color, and the drive recess cut in the shape of the color's symbol; the ghost look for covered screws |
| Color symbols | src/render/palette.gd | nine filled polygons at unit radius, drawn as the screws' recess, on boxes and in the queue |
| Boxes and the queue | src/render/box_view.gd, src/render/paint.gd | a small oak tray with three drilled wells, its color painted across the front with the symbol, and a thin lid, drawn with _draw panels and circles |
| The tray | src/render/tray_view.gd, src/render/paint.gd | a brushed steel parts tray with riveted ends and dished slots, warming toward amber with one slot left, drawn with _draw |
| The pegboard and back board | src/render/board_view.gd, shaders/pegboard.gdshader | one full screen pass for the perforated, lamp-lit hardboard, and the theme's back board panels baked once |
| Cached views | src/render/cached_drawing.gd, shaders/cached.gdshader | boxes, the tray, the HUD and the map nodes draw live while they change, then are captured into one texture and drawn as one rect |
| Icons (helpers, pause, stars, cup, padlock, the dock's six, and the rest) | src/render/icons.gd | lines, arcs and polygons in one color, scaled to any size |
| The level clear celebration | src/render/clear_effects.gd | a veil, three stars stamped in brass (or outlined when missed), curling wood shavings and dust motes, all drawn with _draw over 1.6 s |
| The progress map's nodes and trail | src/render/map_node_view.gd, src/render/map_trail.gd | oak discs with the number and stars (a notched edge on every fifth level, a padlock when locked); a brass inlay along a gentle curve, dotted past the next level |
| The title's decorative board | src/render/title_board.gd | a small windmill of planks and screws on the back board, using the views above in the chosen wood and metal |
| Wood and metal themes | src/render/looks.gd | the player's chosen wood and metal turned into the colors and grain settings every renderer reads; numbers only, no images |
| Screen panels, buttons and the dock | src/ui/ui_theme.gd, src/render/tokens.gd | a Godot Theme of StyleBoxFlat panels built in code from the color tokens |
| The app icon (icons/icon-192.png, icon-512.png, adaptive-background.png, adaptive-foreground.png, adaptive-monochrome.png) | tools/art/app_icon.gd | a walnut board, an oak plank and a red screw with the triangle drive, drawn in code and saved as PNGs. These five are the only image files the game ships (the screenshots in docs/design/ are documentation): they are outputs of that script, kept as files because the Android export needs icon files. Remake them with `C:/Tools/Godot/Godot_v4.7.2-stable_win64.exe --path . -s res://tools/art/app_icon.gd`. |

## Sounds

All synthesized by src/audio/synth.gd into 16 bit mono `AudioStreamWAV` buffers: the effects
at startup (22050 Hz for the bright ones, 11025 Hz for the low and dull ones), the music on a
worker thread when it is first wanted (8000 Hz). Each effect is a few damped sine tones (the
ringing parts of a struck object) plus a short noise burst for the strike, normalized to a 0.7
peak. src/audio/audio.gd plays them with small
random changes in pitch and level, and a hard limiter on the Master bus keeps stacked sounds
from clipping.

| What | Made by | How |
|---|---|---|
| `ratchet`, a screw starts to turn | src/audio/synth.gd | 5 quick clicks about 40 ms apart, each rising slightly in pitch and a little uneven in timing; each click is a short noise tick plus damped tones near 1, 2.3 and 4.1 kHz. Two variants. |
| `pop`, a screw comes free | src/audio/synth.gd | a sine gliding quickly down from about 1500 Hz to 420 Hz over 110 ms, with a bright 2.6 kHz tick and a tiny noise burst at the start |
| `clink`, a screw lands in a box | src/audio/synth.gd | a sharp noise strike over five damped tones at inharmonic ratios around 2.65 kHz, ringing 25 to 110 ms |
| `clink_tray`, a screw lands in the tray | src/audio/synth.gd | the same idea, lower (1.45 kHz) and much shorter (12 to 35 ms), over a soft 330 Hz thud, with a smoothed (duller) strike |
| `knock`, a plank falls | src/audio/synth.gd | low damped body tones at about 175 Hz with inharmonic overtones (2.35, 4.1 and 6.4 times) and a smoothed noise tick, then a fainter bounce about 110 ms later. Two variants. |
| `knock_dull`, a covered or refused tap, a button press | src/audio/synth.gd | one low thump: a 140 Hz tone decaying in about 22 ms, a quieter overtone and a heavily smoothed noise tick |
| `lid`, a box lid closes | src/audio/synth.gd | a tiny noise scrape, then a wooden slap: a body tone at about 250 Hz with overtones at 2.5 and 4.6 times, a smoothed noise tick and a faint 1.9 kHz ring |
| `tick`, a soft clock tick (the tray warning, toggles, swatches, the Screwdriver tap) | src/audio/synth.gd | two short damped tones near 1.75 kHz and 880 Hz with a faint dull noise tick |
| `creak`, a plank swings | src/audio/synth.gd | a slow, slightly wobbling saw pulse train (about 60 to 90 Hz) with a little noise, through a resonance near 650 Hz, swelling in and out over half a second |
| `chime`, a level is cleared | src/audio/synth.gd | four bell notes climbing a C major arpeggio (C5, E5, G5, C6) 110 ms apart, each a sine with a quieter octave; the last rings longer |
| `star`, one star on the clear screen | src/audio/synth.gd | a single 880 Hz bell note (a sine with overtones at 2.0 and 2.76 times) and a tiny tick; the caller raises the pitch per star |
| `lose`, a loss | src/audio/synth.gd | a warm sine with a quiet octave, gliding down about a fifth over 0.8 s and fading |
| `unlock`, a theme or swatch unlocks | src/audio/synth.gd | two high bell notes (about 1175 Hz, then 1760 Hz 70 ms later) with overtones |
| `tap`, a faint wooden tap | src/audio/synth.gd | a very short dull noise tick plus damped tones near 420 Hz and 980 Hz |
| `undo`, an Undo | src/audio/synth.gd | four soft ratchet clicks, rendered and then reversed, with a short fade in |
| `wood_pop`, the extra tray slot opens | src/audio/synth.gd | a 760 to 300 Hz downward glide over 90 ms, a 520 Hz hollow body tone and a smoothed noise tick |
| The music, a quiet ambient loop | src/audio/synth.gd | 32 s at 8000 Hz: four slow chords (C, Am, F, G, 8 s each) from sines that swell in and out, each note with a slightly detuned twin, plus 5 or 6 sparse pentatonic bell notes, wrapped round the loop end so it loops without a click. Peak 0.5, played 14 dB down, under the effects. About 0.5 MB. |
