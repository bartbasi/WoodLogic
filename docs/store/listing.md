# WoodLogic: Google Play listing

Everything to paste into Play Console for WoodLogic, and the answers to its App content
questions. Bart does all Play Console work himself. Character counts are given for each text.

## Store listing (Grow > Store presence > Main store listing)

**App name** (30 characters at most): 9 characters

> WoodLogic

**Short description** (80 characters at most): 70 characters

> A free screw puzzle in wood. Tap screws out and fill the boxes to win.

**Full description** (4,000 characters at most): about 1,760 characters

<!-- full description start -->
A wooden picture hangs on the board: a house, a boat, a windmill, a pattern. It is made of planks, and every plank is held on by colored screws. Tap a screw to spin it out. It flies to an open box of its color, and when a box has three screws it closes and the next one slides in. Take out every screw to win.

If no open box wants a screw, it waits in the tray, and the tray is small. Plan ahead, because a full tray ends the try. Planks swing and fall as their last screws come out, and what they were covering comes into reach.

Every level is made on your phone and checked by a solver first, so every level can be solved by thinking, and the levels never run out. The first eight teach one idea each, and from there the boards grow from a handful of screws in two colors to crowded boards in eight, up to five layers deep.

• Earn up to three stars on each level: cleared, fast, and clean
• Spend stars on helpers: Undo, Extra slot and Screwdriver
• A new Daily puzzle, the same for everyone
• Relaxed mode with no clock
• Woods and metals to unlock by playing: oak, walnut, maple, cherry, ebony, and steel, brass, copper and black screws
• Colorblind symbols on every screw, on by default
• Retry is always free
• Plays in portrait, and one hand is enough

WoodLogic is free, and always will be. There are no ads, no purchases, no account and no tracking, and it never goes online. It asks for no permissions. Your progress stays on your phone. Every picture and sound in the game is made by its own code.

WoodLogic is open source (GNU GPL v3) and made by Play, Inc. The code is at github.com/bartbasi/WoodLogic. If you would like to support more games like it, there is a quiet Buy me a coffee button, never expected and always appreciated.
<!-- full description end -->

**Category**: Game > Puzzle.

**Tags** (pick up to 5 from Play's list): Puzzle, Casual, Offline, Single player, Relaxing.

**Contact details**:

- Email (required, shown publicly): bartbasi@gmail.com
- Website: https://github.com/bartbasi/WoodLogic
- Phone: leave empty.

**Privacy policy URL**: https://bartbasi.github.io/WoodLogic/privacy-policy/ (published from
[privacy-policy.md](privacy-policy.md) by GitHub Pages; the workflow is written but Pages is not
switched on yet).

**Graphics**: made by the game's own code into `build/store/` (see docs/release.md, section 7):
`icon-512.png`, `feature-1024x500.png`, and phone screenshots `phone-1.png` and up.

## App content (Policy > App content)

- **Privacy policy**: the URL above.
- **Ads**: No, the app contains no ads.
- **App access**: All functionality is available without special access (no login).
- **Data safety**: "Does your app collect or share any of the required user data types?" **No.**
  Encryption in transit: not applicable, nothing is sent. Account creation: none. The listing
  then shows "No data collected" and "No data shared". Send feedback, Source code and Buy me a
  coffee only hand an address to the phone's own email app or browser; the app itself sends
  nothing, so the answer stays No.
- **Content rating** (IARC questionnaire): category Game. Answer No to violence, fear,
  sexuality, language, controlled substances, gambling, user interaction or chat, sharing
  location, and digital purchases (stars are earned only by playing and cannot be bought).
  Expect Everyone and PEGI 3.
- **Target audience and content**: 13 and over is the safe choice. Including under 13s brings in
  Google's Families policy, which is strict about links that take a child out of the app to a
  payment page, such as the Buy me a coffee button.
- **Government app, financial features, health, news**: No.

## Known risk: the Buy me a coffee button

Google Play's payments policy only allows in-app donation links to tax-exempt charities outside
the US. Bart decided on 22 October 2026 to show the button on Play anyway. Review could flag it.
If review rejects the app for it, build with the export feature `no_coffee` added to the
"Android release APK" and "Android release AAB" presets (Custom features), which hides every
coffee button, then upload again with a higher version code.

## Countries

Production > Countries/regions: add all, or just the ones you want.
