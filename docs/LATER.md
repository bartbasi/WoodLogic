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
