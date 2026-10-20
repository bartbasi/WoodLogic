# Assets

Every visual and every sound in WoodLogic is made by the game's own code. Nothing comes from
an image, audio, font or model file. The only exception is what ships inside the Godot engine,
such as its default font. Each entry below names the thing, the code that makes it, and how.

## Visuals

| What | Made by | How |
|---|---|---|
| Godot's default font (all text) | the engine | ships inside Godot |

## Sounds

All synthesized at startup by src/audio/synth.gd into 16 bit, 22050 Hz mono `AudioStreamWAV`
buffers. Each is a few damped sine tones (the ringing parts of a struck object) plus a short
noise burst for the strike, normalized to a 0.7 peak. src/audio/audio.gd plays them with small
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
