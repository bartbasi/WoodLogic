# WoodLogic

A screw puzzle in wood, for phones. Tap the screws out of a wooden contraption; each one flies
to an open box of its color, or to a small tray if none is open. A plank with no screws left
falls away, and one held by a single screw swings on it. Clear every screw to win, and don't
let the tray fill up. Levels never run out: each is generated on the phone and checked by a
solver first, so every level can be solved by thinking.

WoodLogic is free, with no ads and no tracking. It never goes online and asks for no
permissions. Every picture and sound in it is made by its own code.

Built with Godot 4.7.2 (GDScript, Mobile renderer), Android first. It is in early
development.

## Running and testing on a PC

Godot is installed at `C:\Tools\Godot`. From the project folder:

```bash
# Play
C:/Tools/Godot/Godot_v4.7.2-stable_win64.exe --path .

# Headless tests (all of them, or only those whose path or name contains some text)
bash tools/test.sh
bash tools/test.sh logic
```

## License

Copyright 2026 Play, Inc.

WoodLogic is free software: you can redistribute it and/or modify it under the terms of the
[GNU General Public License, version 3](LICENSE), with the additional terms in [NOTICE](NOTICE)
(allowed by the GPL's section 7). In short:

- **Keep the credit.** Anything built from WoodLogic, in whole or in part, must keep the line
  "Based on WoodLogic, designed and written by Bart Basi, with assistance from Claude.
  Copyright 2026 Play, Inc." in its source (the NOTICE file) and, if it has a screen, in its
  About, Credits or License screen.
- **Mark your changes.** A modified version must say it has been changed and must not pass
  itself off as the original WoodLogic or as made or endorsed by Play, Inc. or Bart Basi.
- **Use your own name and icon.** The license gives no rights to the name "WoodLogic" or its
  icon.

Every source file starts with a two-line notice pointing to LICENSE and NOTICE; please keep it.
WoodLogic is built with the [Godot Engine](https://godotengine.org) (MIT license); the game's
Credits screen shows Godot's notices and those of its third-party parts.
