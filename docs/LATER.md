# Later

Ideas beyond the v1 brief, kept for Bart to decide on. Nothing here gets built without his
go-ahead.

## From Phase 1 (19 October 2026)

Screens and accessibility (ux-designer):

- A text size setting, a reduced motion setting and a high contrast mode.
- A left-handed mirror for the pause button.
- A way to reread the helper explanations, for example from Pause.
- Levels list: a jump to level field and a filter for levels under three stars.
- A screen reader description of the board.
- A "peek at the board" handle on the Out of room sheet.
- A hint button for stuck players.

Play (game-designer):

- Show the rest of the box queue as small colored dots after the two previewed boxes.
- If hard levels feel too soft at Gate 1, try a 4 slot tray as a second lever, after smarter coloring.

Look (graphic-designer):

- Birch plywood and painted boards as unlockable wood themes.
- The screw finishes from the other directions (enamel, powder coat, candy gloss) as metal themes.
- A falling plank tumbling in 3D for its last second.

## From Phase 2 (19 October 2026)

Levels (game-designer):

- Add the blueprint house rules to the engine validator as warnings: a one-hole plank hangs
  straight below its hole, and a covered screw sits at least 8 units under its wood.
- A block-built picture style (like Cat and Step temple) for future themed packs.

Tools and help (level-engine-dev):

- A designer preview tool that runs the validator and the solver while a blueprint is edited,
  and shows where careless players lose.
- Use each level's stored solution as the move behind the "hint button for stuck players" idea.
- A generator variation that adds a covering plank, to give boards with little covering some
  tray pressure.
- A lower-bound (A*) solver, if much denser boards arrive.

Testing (qa-tester):

- A bot that spends and buys helpers, to check the star economy.
- A time model for the bots where thinking time grows with the number of free choices.

## From Phase 3 (19 October 2026)

Sound (audio-dev):

- A master volume slider.
- A short haptic buzz on Android that matches the knock. It needs the VIBRATE permission,
  which ground rule 2 rules out, so only if Bart ever allows that one permission.

Level scene (gameplay-dev):

- A reduced-motion setting that uses the instant path the tests already use.
- A hidden frame-time and draw-call readout, to check 60 fps on a phone.

Screens and saves (ui-dev):

- A "Continue" note on the title when a level was left unfinished.
- The time on Level clear, before stars exist.
- A note in Settings when a save was repaired (a `.bad` file was kept).

Build (platform-dev):

- An adb helper script that installs and launches the app on the phone.
- An arm64-only build, a few MB smaller.

Level generator (level-engine-dev):

- A second coloring for Expert (the designer's "deep second wave"), so G9a could be required
  on tiers 9 and 10 too.
- Among the solutions with the fewest tray uses, prefer the one whose last tray use comes
  latest, so G9b measures the level rather than the search order.
- One solver setup shared by the novice playout and the search.
- On slow phones, let the prefetcher look two levels ahead before hard levels.

## From Phase 4 (21 October 2026)

Screens (ui-dev):

- Animate the picture on the first-time helper sheet (UX 3.13.1 describes a small animation).
- Remember the map's scroll position within a session.
- A long press on a cleared map node shows its best time.
- The time on the level clear screen for replays.
- Screen reader names for the dock tabs.

Build (platform-dev):

- A build script check that the manifest declares the Vulkan feature.
- A one-off look at the game under the Compatibility renderer (`--rendering-method
  gl_compatibility`), for the rare phone without Vulkan.

Level scene (gameplay-dev):

- The Screwdriver icon touches the screw for the full 100 ms before the flight.
- Keep the first-time helper highlight until the helper is first used.
- A small shaving or dust puff when a plank falls.
- An optional bars panel on `BoardView` in the stacked layout, so the boxes row and the tray sit
  on the bench as the rail does.

Sound (audio-dev):

- Music that changes slowly, such as a different key per world.
- A quiet music duck while a chime plays, and a real fade out instead of an instant stop.

QA (qa-tester):

- A screenshot gate script at 360 x 800, 412 x 915 and 360 x 922 before each playtest gate.
- A bot that retries and buys helpers, so the Hard and Expert star economy can be measured.
- `tests/bots/acceptance.gd` as the per-tier report in tools/levels.

## From Phase 5 (22 October 2026)

- **Tight endings (wave coloring).** A level is tight in its opening, but in its last third
  the tray is nearly empty and late wrong taps are always forgiven, whatever the tray size.
  A coloring with several tight moments along the queue, plus a "second peak" check from
  halfway, would fix that. It is unproven engine work, so it waits until Bart has played the
  smaller tray and says whether the endings still feel too easy.
- **A second shrink line at level 21,** such as "Only three slots now." The tray closing
  already marks the change.
- **Real width animation for the tray frame,** once TrayView can draw a fractional width, so
  Extra slot and the closing slide the frame instead of crossfading two frames.
- **One move from 11 to 12:** start the tray closing as the last box of level 11 clears.
