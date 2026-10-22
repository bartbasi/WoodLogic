# Security and privacy review, Phase 6

**Summary: 0 Critical, 0 High, 1 Medium, 3 Low.** The promise holds in the code: no network
code, no permissions in either APK, only three fixed addresses, and save parsing that never
decodes objects. The Medium is the missing privacy policy. The Lows are hardening.

Reviewed at HEAD 53011c0 (Phase 5), the whole repo and its full history (14 commits), plus
build/woodlogic-debug.apk and build/woodlogic-timing.apk (built 22 October 2026, 14:36 and
14:37). Scratch probes are in build/sec6/ (ignored by git). They wrote hostile files only into
an absolute folder, build/sec6/save/, never into user://, and that folder has been deleted.

## Findings

### Medium 1. The privacy policy does not exist

- **Where:** docs/store/ holds only `.gitkeep`. There is no `docs/store/privacy-policy.md`.
- **Why it matters:** CLAUDE.md requires the policy, and Google Play asks for a privacy policy
  address before a listing goes live. Without it there is nothing public that states the
  promise, and nothing for this review to check against the code. It blocks release, not
  play.
- **Fix (platform-dev, docs/store/):** write it and publish it with GitHub Pages. It should say
  exactly what the code does today, which is:
  - WoodLogic collects nothing and sends nothing. No internet, ads, analytics, crash reports,
    accounts or cloud saves. The Android build asks for no permissions (both APKs checked
    with aapt: none).
  - What it saves on the phone, in the app's private storage: `progress.json` (level number,
    stars, best times, helper counts, daily streak and dates, unlocked woods and metals,
    stats), `settings.json` (sound, music, symbols, chosen wood and metal), and
    `next_level.json` (the next level's layout, so it starts faster). A damaged file is kept
    once as `<name>.bad`. The engine also keeps a graphics cache. Nothing in them identifies
    the player.
  - Android backup is off (`user_data_backup/allow=false`, so `allowBackup=false` in the
    manifest), so progress is not copied to Google's backup. It is removed on uninstall.
  - How to clear it: Settings, Reset progress (keeps the settings), or the phone's app settings
    (Clear storage), or uninstall.
  - The three links: Send feedback opens a draft in the player's email app, addressed to
    bartbasi@gmail.com, whose last line names the game version, the phone model and the OS
    version; the player can edit or delete it and nothing is sent unless they send it. Source
    code and Buy me a coffee open a web page in the phone's browser.
  - Google Play, the App Store, GitHub and Buy Me a Coffee are outside that promise and follow
    their own policies.
  - Contact: bartbasi@gmail.com.

### Low 1. The saved next level is played without being solved or bounded

- **Where:** src/ui/app_flow.gd:94 plays whatever `Save.read_next_level` returns.
  src/save/save.gd:516 to 539 checks the key, the kind and the generator version, and
  `LevelData.from_dict` (src/logic/level_data.gd:202) checks types and ranges, but nothing
  runs the solver. `from_dict` also has no cap on the number of planks (level_data.gd:246),
  allows planks with no holes (src/logic/plank_data.gd:200 reads holes with a minimum of 0, so
  the 60 screw cap at level_data.gd:273 does not stop them), has no cap on points per outline
  (plank_data.gd:182 and 189), and takes `line` text of any length, which the HUD then shows
  (src/level/level_scene.gd:709).
- **Steps to reproduce (probes in build/sec6/probe2.gd and probe3.gd):**
  1. Take level 60's stored form (`LevelData.to_dict()` plus `"key": "numbered:60"`), shuffle
     its queue and set `"tray": 1`.
  2. Write it as `next_level.json` in a Save folder and call
     `read_next_level("numbered:60", Generator.GENERATOR_VERSION)`.
  3. Result: accepted. `Solver.solve` on the same level: `complete=true solved=false`. The
     game would show a level its solver has proved unsolvable, which breaks ground rule 5.
  Also accepted, each with a fingerprint different from the generated level: 6,000 extra
  planks without holes (476 KB, 277 ms to read), one extra polygon of 90,000 points (722 KB,
  181 ms to read), and a 900,000 character `line`. How the board views and the HUD cope with
  those was not tested; a hang or very slow first frame is likely.
- **Why it matters:** only someone who can write the app's private files can do this (a rooted
  phone, or `run-as` on a debuggable build, see Low 3), so it is not an attack from outside.
  But a file edited by hand, or by a bug in a future version, can break the "every level is
  solvable" promise and could stall the boot, and the code comment says the file "only saves
  time".
- **Fix (ui-dev with level-engine-dev):**
  - Before playing a saved level, run `Solver.solve` on it with the generator's state cap (it
    took 8 to 13 ms for level 30 in the probe) and use it only if the result is complete and
    solved. Otherwise delete the file and generate as usual.
  - Give `from_dict` (or `read_next_level`) cheap caps that no real level comes near: every
    plank of a playable level has at least one hole, at most 32 planks, at most 64 points per
    outline or path, and a `line` of at most 200 characters (or ignore `line` for numbered
    levels, which never have one).
  - Add these cases to tests/save/test_next_level.gd.

### Low 2. The repo guard test misses some ways out

- **Where:** tests/app/test_repo.gd:18 to 25 (the banned names) and 61 to 66 (the
  `shell_open` check).
- **What:** the test bans the network classes well, but not these other ways to reach outside
  the game: `OS.execute`, `OS.execute_with_pipe`, `OS.create_process`, `OS.create_instance`,
  `OS.request_permission` and `OS.request_permissions`, `JavaClassWrapper`, `JNISingleton` and
  `Engine.get_singleton` (Android's Java bridge, which could call Java networking code),
  `StreamPeerExtension`, `PacketPeerExtension`, `MultiplayerPeerExtension`,
  `WebRTCDataChannel`, and the decoders `str_to_var`, `bytes_to_var`, `bytes_to_var_with_objects`,
  `Expression` and `JSON.to_native`. The `shell_open` check is a plain text match, so a call
  through `OS.call` with a built name would slip past it.
- **Today:** none of them are used. A search of src/, tests/ and tools/ (all .gd, .sh, .py,
  .tscn, .tres, .godot and .cfg files) finds none, and the APKs have no INTERNET permission, so
  even engine code could not connect.
- **Why it matters:** the test is the guard that keeps the promise true as agents keep
  editing. A future change could add one of these without a failing test.
- **Fix (lead, tests/app/test_repo.gd):** add the names above to the banned lists, and also
  fail on `OS.call(`, `OS.callv(` and `Callable(OS` anywhere outside links.gd.

### Low 3. Both APKs are debuggable, and there is no release preset yet

- **Where:** export_presets.cfg has only "Android debug" (line 3) and "Android timing" (line
  65). tools/build/_common.sh exports with Godot's debug export. `aapt2 dump badging` shows
  `application-debuggable` for both APKs and the manifest has `android:debuggable=true`.
- **Why it matters:** on a debuggable app anyone holding the unlocked phone with USB debugging
  on can read and change the saves with `run-as`, and attach a debugger. That is fine on
  Bart's phone. It would not be fine in a build handed to testers or players.
- **Fix (platform-dev, Phase 7, after Bart's go-ahead for the keystore):**
  - A release preset exported with Godot's release export (not the debug one), with the
    keystore and its passwords outside the repo (environment variables or Godot's
    `export_credentials.cfg`, both already ignored).
  - In the release build script, fail if `aapt2 dump badging` prints `application-debuggable`,
    as it already fails on any permission.
  - The store preset with the custom feature `no_coffee` when Bart wants one (the switch itself
    works, see below; no preset sets it yet).
  - Optionally add `*.p12`, `*.pem` and `keystore.properties` to .gitignore, in case a key is
    ever made in another format.
  - Never publish the debug or timing APK.

## Checked and clean

| What | How it was checked | Result |
|---|---|---|
| No network code | Searched every file outside .git, .godot, build/, PROMPT.md and LICENSE for HTTPRequest, HTTPClient, StreamPeer, WebSocket, PacketPeer, UDPServer, TCPServer, DTLS, ENet, Multiplayer, multiplayer, JavaScript, UPNP, WebRTC, `IP.`, `@rpc`, `rpc(`, Crypto, JNISingleton, JavaClassWrapper, `get_singleton`, `request_permission`, curl, wget and Invoke-WebRequest. | Only hits are the ban lists in CLAUDE.md, .claude/agents/ and tests/app/test_repo.gd. |
| Scenes and resources | Listed every node type and external resource in all 8 tracked .tscn files; there are no .tres files. | Only Control, ColorRect, Label, Node2D and Node, each with a script from our own folders. `test_no_built_in_scripts_or_shaders` passes. |
| Other ways out | Searched for `OS.execute`, `create_process`, `create_instance`, `shell_show_in_file_manager`, `move_to_trash`, clipboard, `get_unique_id`, `get_environment`, `get_cmdline`, ClassDB, `set_script`, `source_code`. | None in src/, tests/ or tools/. |
| No permissions | export_presets.cfg lines 61 and 123: `permissions/custom_permissions=PackedStringArray()` and no permission key set; project.godot has no permission or network setting. `aapt dump permissions` and `aapt2 dump permissions` on both APKs (build tools 36.1.0). Full manifest with `aapt2 dump xmltree`. | No `uses-permission` in either APK. `allowBackup=false`. Only the launcher alias is exported; the FileProvider and the startup provider are not exported; the profile receiver needs the system's DUMP permission. No `usesCleartextTraffic`. |
| APK contents | `unzip -l` of the debug APK. | Only src/, data/, icons, LICENSE, NOTICE and Godot's own files. No tests, tools, docs, build, Markdown, PROMPT.md, keys or config with secrets. |
| Three fixed addresses | `shell_open` appears once, src/ui/links.gd:62, reached only from `open_feedback`, `open_source` and `open_coffee`, which pass the constants at links.gd:9 to 11. | Never built from input or a save. The mailto body (links.gd:48 to 55) holds only fixed words, the version from project.godot, `OS.get_model_name()`, `OS.get_name()` and `OS.get_version()`, and both subject and body are URI encoded. `test_repo` (shell_open only in links.gd) and `test_links` (5 tests) pass. |
| The coffee switch | Every coffee control is built only when `Links.coffee_visible()` is true: the menu header chip (src/ui/menu_screen.gd:85, used by Title, Map, Stats, Info, Settings and About), the Pause chip (src/ui/pause_screen.gd:40), the About Supporting block (src/ui/about_screen.gd:49, which also switches the Privacy text), and the level's cup (app_flow.gd:662 passes the switch to the scene; its hit area exists only while the cup shows, src/level/level_hud.gd:391). `Links.open_coffee` refuses when hidden. | Clean. Covered by tests/ui/test_screens.gd:220, tests/ui/test_flow_menus.gd:206 and tests/ui/test_links.gd. |
| Save parsing | Read all of src/save/save.gd. Only `JSON.parse` is used; no `str_to_var`, `bytes_to_var`, `load()`, ResourceLoader or Expression on user files. The only `load()` calls in src/ use fixed res:// paths (app_flow.gd:624, main.gd:14 and 17, level_catalog.gd:135 under res://data and res://src/logic/fallback). | Every field is type and range checked; files over 4 MB (progress, settings) or 1 MB (next level) are not read; lists and maps are capped (100,000 level records, 4,000 days, 32 unlocks, 32 gifts). |
| Hostile save files, tried | build/sec6/probe.gd against a fresh Save pointed at build/sec6/save/: empty, truncated, invalid UTF-8, not an object, 300,000 deep and 2,000 deep nesting, over 4 MB, 260,000 level records (3 MB), 500,000 list entries, 1e400 and 9223372036854775807 and 1.5 as numbers, object text such as `Object(Node)`, settings with `../../evil` and `res://x` ids. | No crash, no hang, nothing decoded. Each fell back to defaults or the clean fields and kept the file as .bad. Godot's JSON parser refuses deep nesting. Slowest case: 260,000 records took 1.15 s on the PC (several seconds on a slow phone), only possible with a hand edited file. |
| Existing save tests | `bash tools/test.sh tests/save/` (42 passed), `tests/app/` (4 passed), `test_links` (5 passed). | All pass, including hostile file, deep nesting and huge file tests. |
| No secrets now | `find` for *.keystore, *.jks, *password*, *credential*, *.pem, *.p12, .env* outside .git. | None. `.godot/export_credentials.cfg` does not exist. |
| No secrets in history | The full patch history of every branch scanned for keystore, storePassword, password, BEGIN PRIVATE, .jks, api key, secret and token; files ever added scanned by name. | Only documentation that says no secrets go in the repo, and the `Tokens` color class. export_presets.cfg never held a keystore path or password. |
| .gitignore | `git check-ignore -v` on export_credentials.cfg, .godot/export_credentials.cfg, x.keystore, x.jks, release-password.txt and build/x.apk. | All ignored. |
| PROMPT.md | The log of PROMPT.md on every branch and a scan of every path ever committed. | Never committed. Ignored by .git/info/exclude:7 and excluded from both export presets. |
| Personal data in the repo | `git grep` and `git log -p` for email addresses, user folders, serial numbers and IMEI. | Only bartbasi@gmail.com (the public contact) and the GitHub noreply author address. |
| GitHub Actions | `.github/` does not exist and never existed in history. | No workflows yet. Check again when platform-dev adds them. |
| Dependencies | Searched for addons, plugin.cfg, .gdextension, .dll, .so, .jar and .aar in the repo. | None. The only outside code is the Godot 4.7.2 engine and its Android template (the APK reports `org.godotengine.library.version` 4.7.2.stable). |
| Writing outside user:// and logging | Every FileAccess and DirAccess write in src/ goes through Save (`dir`, default user://) or the timing build's `user://timing.txt`. Log lines in src/ name only game data, never player data. | Clean. The timing build shows the phone model on screen and in its own file and log, on the phone only, in a build not meant for players. |
| Text from saves | The level `line` is drawn with draw_string; no RichTextLabel has BBCode on, and nothing listens for link clicks. | A saved string can't become a link. |
| Public statements | README.md:9 and 10. | Match the code. |

## Not checked

- How the board views draw the oversized levels from Low 1 (a windowed run was out of scope).
- The release build, which does not exist yet. Review it again in Phase 7, with the store
  preset and any workflows.
