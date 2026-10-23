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

## Building the Android APK

You need Godot 4.7.2 with its export templates, the Android SDK (`C:\Android\Sdk`) and JDK 17.
The SDK, JDK and debug key are set once in Godot's editor settings (Editor Settings, Export,
Android), not in the repo. Nothing secret is stored in the project.

```bash
bash tools/build/android-debug.sh    # build/woodlogic-debug.apk, the game
bash tools/build/android-timing.sh   # build/woodlogic-timing.apk, the phone timing
```

Each script imports, exports, then prints the APK size, its package, version and permissions,
and fails if the APK asks for any permission. The game asks for none.

**Turn on USB debugging on the phone.** Settings, About phone, tap "Build number" seven times.
Then Settings, System, Developer options, turn on "USB debugging". Plug the phone in and accept
the "Allow USB debugging" question. `adb devices` (in `C:\Android\Sdk\platform-tools`) should list it.

**Install the game:**

```bash
C:/Android/Sdk/platform-tools/adb.exe install -r build/woodlogic-debug.apk
```

**Install the timing build** (it installs beside the game as "WoodLogic timing"):

```bash
C:/Android/Sdk/platform-tools/adb.exe install -r build/woodlogic-timing.apk
```

Open "WoodLogic timing" and wait for "Done". Then take a screenshot of the screen, or read the
saved table:

```bash
C:/Android/Sdk/platform-tools/adb.exe shell run-as io.github.bartbasi.woodlogic.timing cat files/timing.txt
```

## Releasing

The first public release is version 1.0.0 (code 1). The full steps, the Play Console checklist and
the privacy policy address are in [docs/release.md](docs/release.md). In short:

```bash
bash tools/build/android-release.sh      # build/woodlogic.aab (Google Play) and build/woodlogic.apk (GitHub)
bash tools/build/make_store_graphics.sh  # build/store/: icon, feature graphic and phone screenshots
```

The release script stops with a message until the release key exists. The key lives outside the
repo, is made only when Bart says so, and must be backed up (docs/release.md, section 1). The
script refuses a build that is debuggable, asks for any permission, or ships tests, tools or docs.
The store text is in [docs/store/listing.md](docs/store/listing.md), and the privacy policy in
[docs/store/privacy-policy.md](docs/store/privacy-policy.md).
