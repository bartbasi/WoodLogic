# Playtest Gate 1: the core loop

Owner: game-designer. For Bart, on his own phone, with the Phase 3 debug build
(`adb install -r build/woodlogic-debug.apk`).

The one question for this gate (PROMPT.md section 16): **is tapping screws, filling boxes and
managing the tray fun before any polish?**

## What this build is

- Numbered levels only: the eight tutorial levels, then generated levels from 9 on. The game
  remembers where you are, so closing it and coming back continues at the same level (restarted
  from the beginning).
- Retry and Previous level. Pause has Resume, Retry and Quit to title.
- A plain placeholder look: flat shapes and colors, each screw color with its own line symbol.
  Judge the feel and the puzzle, not the looks. The wood, the screws and the polish come in
  Phase 4.
- Four kinds of sound: the ratchet as a screw turns, the pop as it comes free, the clink as it
  lands (duller in the tray), and the wooden knock as a plank falls (a dull knock for a covered
  screw or a refused tap).
- Not in this build, on purpose: stars, the timer display, helpers (Undo, Extra slot,
  Screwdriver), Daily, Relaxed, the level list, settings, about, music, the lid sound, the creak
  of a swing, the tray warning tick, the clear chime and the loss tone. Please don't count their
  absence against the build; do say if you missed one of them badly.

## What to try (about 40 minutes, in two sittings)

**Sitting 1, about 20 minutes: levels 1 to 20.**

1. Install, open the game and start without reading anything. Level 1 should take under 30
   seconds. Note if you had to stop and think about what to do.
2. Play the tutorial (levels 1 to 8) at your normal pace. Each one teaches one idea: tap a screw,
   screws go to their box, the tray, covered screws, a plank falls, a plank swings, the box queue,
   and the last one is about planning (its Undo line points at a helper this build doesn't have
   yet, so just play it).
3. Keep going to level 20. Levels 10, 15 and 20 are the hard ones of their group; 11 and 16 are
   breathers right after them.
4. Once, on purpose, tap a covered screw. Watch what tells you it is covered and what covers it.
5. Once, on purpose, fill the tray and keep tapping. Watch the refused tap (the screw turns back,
   the tray nudges, and the screws that do fit are ringed) and then the loss.

**Sitting 2, the next day, about 20 minutes: carry on from where you stopped, to about level
35.**

6. Notice whether you wanted to come back, and whether the game picked up where you left it.
7. On one level, lose on purpose and press Retry. Count roughly how long until you can tap again
   (the target is under 2 seconds). Is the retried level the same one?
8. After one loss, press Previous level on the sheet (that is where it lives in this build),
   play that level, and carry on forward again.
9. In the middle of a level, press the phone's home button, come back later, and also try the
   Android back button on the level and on the pause screen.
10. Levels 21 to 35 bring 4 and 5 colors and the first boards with several layers. Notice how long
    a typical level takes you (the target for mid levels is 1 to 3 minutes) and whether the tray
    starts to feel tight.

**Optional, only if the lead gives you a way to start at a chosen level:** play levels 55, 60, 61
and 65. Level 60 is the first tier 7 level, the first "Hard" one, and 61 is the breather after
it. This is where the Phase 3 "softer step into Hard" rule should show: a careless order should
still be able to lose, but not in the first few taps.

## What to watch for while you play

Jot a level number next to anything worth mentioning; it lets me find the level again.

- **First minute.** Level 1 cleared in under 30 seconds, with no reading.
- **Every tap answers at once,** with motion and sound, even when you tap fast while screws are
  still flying.
- **Look first.** Nothing on the board moves until your first tap.
- **No dead taps.** A covered screw shows what is covering it.
- **The tray.** You can see it filling, and you can tell when only one slot is left (without the
  tick sound, which comes later).
- **The first tap never has to go to the tray.**
- **A box closing** feels like a small win every time. Tray screws jumping into a new box read as
  a chain, one at a time, left to right.
- **A plank falling** is the best moment, even with plain shapes.
- **A swing** that covers or uncovers a screw changes that screw's look at once.
- **Fair failure.** When you lose, you can see which choices led to it. If a loss came out of
  nowhere, note the level.
- **The hidden queue.** You see the two open boxes and the next two. The boxes after those are
  hidden (Bart, Hard Stop 1). Did you ever feel cheated by a box you couldn't see coming?
- **Breathers.** The level after a hard one (11, 16, 21, 26, 31) feels like a rest.
- **Variety.** No two levels in a row look alike.
- **Waiting.** Any wait for a level to appear, especially the first one after opening the game.
- **One tap** from a cleared level to the next one.

## The form

Answer in a few words each. Level numbers help.

1. **Where did you smile?**

2. **Where were you bored?**

3. **Where were you confused?**

4. **Did any loss feel unfair?**

5. **Did anything feel slow?**

6. **What did you want to do next?**

7. **Would you play again tomorrow?**

Anything else (optional):

## What happens next

Send the answers to the lead in any form (a message with the seven lines is enough). I turn them
into a ranked fix list in this folder (`gate-1-fixes.md`), ordered by bugs first, then fun and
readability, then polish, each with the answer it comes from and a concrete change. You approve
the list before anyone works on it. Expect this gate to send work back; tuning is most of the
work.
