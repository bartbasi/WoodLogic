# Fun review 1: generated levels before Hard Stop 2

Reviewer: game-designer. Material: build/levels/report.md (numbered 9 to 200, 30 dailies, 20
Relaxed per band), build/levels/png/, build/bots/bots-seed1-n92.csv (levels 9 to 100). I parsed
the report and the bot file with a scratch script and checked every row against the GDD and
data/tuning.json, and looked at the pictures.

**APPROVE** the generator for Hard Stop 2: it follows the sawtooth, G1 to G6, tray par and par
time on every level. The fixes below are for variety (mostly my data) and for where the
pressure sits in hard levels. Do them before the Gate 2 playtest.

## What passes

- **Sawtooth (6.3):** tier(N) matches `steps[(N - 1) mod 5]` and the bases on all 192 numbered
  levels.
- **G1, G3, G4:** screws, colors, layers and fewest tray uses are inside their tier's range on all
  282 levels. The novice policy matches its tier everywhere: tiers 1 to 3 always win, tiers 7 to
  10 always lose.
- **Tray par (S7):** always fewest tray uses plus the slack (+2 to level 30, +1 to 100 and the
  daily, 0 after).
- **Par time (S8):** all 92 bot rows match 5 x ceil((10 + k x screws) / 5).
- **Helpers are a choice (checklist 19):** the perfect bot wins all 92 levels with no helpers and
  3 stars.
- **Mid game 1 to 3 minutes (checklist 10):** par times for tiers 5 to 7 average 91, 101 and 126
  seconds.
- **Milestones land well:** level 15 (Extra slot) is a tier 4 pagoda the novice loses, and level
  25 (Screwdriver, brass) is the brick wall with half its screws covered.
- **Economy (5, QA item 20):** stars per ten levels, levels 31 to 100: perfect 30, novice 18,
  random 12. The GDD assumes 22.5 for a good player and 15.5 for a careless one; 18 / 15.5 = 1.16
  and 12 / 15.5 = 0.79, both inside the factor of 1.5.
- **Relaxed easy and medium** pick their tiers evenly (easy 7, 5 and 8 levels; medium 6, 6 and 8).

## Ranked fixes

### 1. Hard levels trap the player in the first few taps (checklist 5, fair failure)

Evidence: on tiers 7 and 8 the novice loses after a median of about 8 taps, and six of the 13
hard levels in the bot run end by tap 7: levels 60, 70, 80, 84, 99 and 100. Five tray slots full by
tap 6 means almost every opening tap was wrong. Meanwhile the perfect line only ever holds 2 tray
screws (perfect peak tray = fewest tray uses, near full 0 on 12 of 13). So the whole level's
difficulty is one opening, and the remaining 20 or more taps carry no pressure.

Is it fair? Yes, narrowly: a loss by tap 10 is inside what the player can see (2 open boxes and 2
previewed boxes are 12 screws), so it traces back to visible choices. But it is too front loaded.
It feels like a gotcha on the first try, and on the retry the level is solved by memory. The
random bot also falls off a cliff here: it wins 34 percent of tier 6 levels but 6 percent of tier
7 and 3 percent of tier 8. The trap measure jumps from 0.49 (tier 6) to 0.92 (tier 7).

Fix (generator acceptance, for level-engine-dev and Bart):

- On tiers 7 to 10, accept a coloring only if the novice survives at least screws / 3 taps before
  it loses. That is 9 on a 27 screw level, 10 on 30 and 11 on 33. Prefer survival around half the
  screws.
- Prefer colorings whose fewest tray uses do not all happen in the first third of the solution.
- Target a mean trap of about 0.75 to 0.85 on tier 7 and 0.85 to 0.95 on tier 8, instead of 0.92
  and 0.96, so tier 7 works as a bridge from tier 6.

### 2. Too few boards in tiers 4 to 7 and in the daily (checklist 11, variety)

Evidence: boards used in levels 9 to 200, by tier:

| Tier | Levels | Boards |
|-|-|-|
| 4 | 21 | 4: tree 6, pagoda 6, bridge 5, barn 4 |
| 5 | 26 | 5: crane 10, weave 6, rings 5, bricks 3, barn 2 |
| 6 | 33 | 5: crates 13, castle 11, bricks 4, crane 4, weave 1 |
| 7 | 29 | 3: dominoes 14, ziggurat 9, skyline 6 |

The daily uses 6 boards in 30 days, so each board comes back about every 5 days.

Tier 7 is the worst: every hard level from 60 to 150 is tier 7 or 8, and half of the tier 7
levels are dominoes. G7 is met, but a player sees the same three pictures on the levels that
matter most. I agree with the engine's finding: with every screw free, the fewest tray uses is
always 0, because some screw always fits an open box. A board needs about 5 covered screws
(20 percent), at least 2 units deep, before coloring can make tray pressure.

Fix (my data, after Hard Stop 2, so blueprint changes and the generator version bump come
together):

a. Add covering to six medium boards, keeping their pictures. Target at least 5 covered:
   - robot 21: chest panel over the torso holes, hands over the arm ends;
   - train 21: wheels over the body and rail;
   - balloon 21: gore over envelope holes, basket over the ropes;
   - owl 18: wings over the body sides;
   - butterfly 24 and steamboat 24: wings, smoke and hull covering more.

   That gives tier 4 about 8 boards, tier 5 about 10, and tier 6 and the daily about 7.
b. Raise castle and crates (27 screws) from 4 covered to about 8, so they qualify for tier 7.
c. Add three new boards of 27 to 30 screws on 4 or 5 layers, with 25 to 35 percent covered and
   round shapes:
   - a workshop pegboard with hanging tools (it fits the Workshop look);
   - a Ferris wheel (ring, spokes and cabins);
   - a hedgehog or a ladybug.

   Tiers 7 to 10 today are mostly rectangles (tiles, falling blocks, cat, skyline, step temple,
   dominoes, lattice), so round shapes would help these tiers look different. With (b) and (c),
   tier 7 would have about 8 boards.

The other medium boards (rocket, lighthouse, snowman, car, sailboat) can stay light: they serve
tiers 2 and 3, where 0 tray uses is the target.

### 3. A fallback level can repeat the next level's picture (checklist 11, G7)

Evidence: level 125 is a lattice fallback and level 130 is lattice; level 169 is a jellyfish
fallback and level 174 is jellyfish. G7 exempts the fallback itself, but the next level then
repeats a picture inside 5 levels.

Fix: when falling back, pick a stored level whose blueprint is not in the 5 levels before or
after in the deal.

Related: tiers 8 to 10 fall back 10 to 11 percent of the time. After level 151 that is about one
level in fifteen from a small stored pool. Allow more attempts on tiers 8 to 10, or store at least
6 fallbacks per tier with different blueprints.

### 4. Relaxed hard leans on tier 8 (6.6)

Evidence: 16 of 20 Relaxed hard levels are tier 8 and only 4 are tier 7, where about half each
was expected. Two of the 20 are fallbacks. Please check whether tier 7 attempts fail and fall
through to tier 8. Relaxed is for unwinding, so a lean toward tier 7 would be better than one
toward 8.

### 5. Tier 5 is easier than tier 4 for a careless player (6.1, the curve)

Evidence: novice win rate is 0.68 on tier 4, 0.94 on tier 5 and 0.62 on tier 6. Random bot win
rates fall smoothly (0.83, 0.72, 0.34), so the dip only shows for the novice. The cause is
tier 5's boards: crane, weave and rings cover only 13 to 19 percent. Fix 2a mostly solves it.
Until then, the generator could prefer colorings where the novice loses about a third of the time
on tier 5.

### 6. Clean on breathers after level 100 (S3, S7, for Gate 2)

From level 101 the slack is 0, so a breather such as level 106 (tier 4 bridge, fewest 1, par 1,
the novice loses) asks for perfect play to earn Clean. That is the rule as approved. If Gate 2
says it feels stingy, give breather levels (N mod 5 = 1) +1 slack after 100. No change now.

### 7. Two small things

- The report has no G5 column (first tap fits an open box). Please add one so QA can check
  checklist item 14 from the report.
- The cat (catface) reads weakly as a cat at board size (level 115). I will redraw its ears and
  face with fix 2.

## Ten levels to show Bart at Hard Stop 2

All in build/levels/png/.

| File | Tier | One line |
|-|-|-|
| numbered-11.png | 1 | A breather: the mug, 9 screws in 2 colors, nothing covered. |
| numbered-13.png | 2 | The house: 15 screws in 3 colors, the roof covers a few wall screws. |
| numbered-14.png | 3 | The windmill: a third of the screws start under the sails. |
| numbered-15.png | 4 | The pagoda, where Extra slot arrives: a careless order can now fill the tray. |
| numbered-25.png | 5 | The brick wall, where the Screwdriver arrives: half the screws start covered. |
| daily-20261021.png | 6 | A daily: the castle, 27 screws in 5 colors, the same for everyone that day. |
| numbered-60.png | 7 | The first tier 7 level: the step temple, 30 screws in 6 colors. |
| numbered-95.png | 8 | The jellyfish: 33 screws in 7 colors, at least 4 tray uses needed. |
| numbered-190.png | 10 | The bookshelf: 33 screws in 7 colors, books behind three shelves. |
| numbered-155.png | 10 | The hardest shape: overlapping tiles, 36 screws in 8 colors, 4 tray uses. |
