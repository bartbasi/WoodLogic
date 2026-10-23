# Releasing WoodLogic

Everything needed to put WoodLogic on Google Play, or to hand the APK to friends from GitHub.

| | |
|---|---|
| App name | WoodLogic |
| Package (app ID) | `io.github.bartbasi.woodlogic`. It can never change once the app is on Play. |
| Version | `1.0.0`, `version/code` 1 for the first release |
| Android | 7.0 and newer (min SDK 24), target SDK 36 (Godot 4.7.2's defaults; section 3 shows how to check them) |
| Phones | 64-bit ARM (arm64-v8a) and 32-bit ARM (armeabi-v7a) |
| Permissions | none |
| Network, ads, analytics, accounts | none; Send feedback, Source code and Buy me a coffee only hand an address to the phone's email app or browser |
| Data stored | `progress.json`, `settings.json` and `next_level.json` in the app's private storage. Android backup is off. |

Presets in `export_presets.cfg`:

| Preset | For | Output |
|---|---|---|
| Android debug | Bart's phone, tests (debuggable, debug key) | `build/woodlogic-debug.apk` |
| Android timing | the phone timing build (debuggable, debug key) | `build/woodlogic-timing.apk` |
| Android release APK | GitHub Releases (release key) | `build/woodlogic.apk` |
| Android release AAB | Google Play (release key) | `build/woodlogic.aab` |

Never publish the debug or timing build: they can be debugged, and their saves read with `adb run-as`.

## 1. Make the release key (once, only when Bart says go)

The release key is not made yet. Bart decided on 22 October 2026 to wait. When he says go:

1. Make a folder outside the repo: `C:\Users\<user>\.woodlogic-keys\`.
2. Make the key. In Git Bash, with JDK 17 on the PATH. The command has no password in it: keytool
   asks for one (twice). That keeps the password out of `~/.bash_history` and the process list.
   Choose a long random password and keep it in your password manager.

   ```bash
   mkdir -p "$USERPROFILE/.woodlogic-keys"
   keytool -genkeypair -v -keystore "$USERPROFILE/.woodlogic-keys/woodlogic-release.keystore" \
     -storetype PKCS12 -alias woodlogic -keyalg RSA -keysize 4096 -validity 10000 \
     -dname "CN=Bart Basi, O=Play, Inc."
   ```
3. Save the same password in `C:\Users\<user>\.woodlogic-keys\woodlogic-release-password.txt` as one
   line: `password: <the password>`. Make the file in an editor, not with an `echo` command, for the
   same reason. (`-storepass:file` would also keep it off the command line, but it wants a file with only
   the password, not this format.)
4. Write down the certificate fingerprint, to check builds against later:

   ```bash
   keytool -list -v -keystore "$USERPROFILE/.woodlogic-keys/woodlogic-release.keystore" -alias woodlogic
   ```

That is all: `tools/build/android-release.sh` finds the key in that folder. To keep the key
somewhere else, set `WOODLOGIC_KEYSTORE` (and `WOODLOGIC_KEY_ALIAS`, `WOODLOGIC_PASSWORD_FILE` or
`WOODLOGIC_KEYSTORE_PASSWORD`). The script hands them to Godot through its own environment
variables for that one build. Nothing secret goes in the repo, in `export_presets.cfg` or in any
tracked file. `*.keystore`, `*.jks` and `*-password.txt` are already in `.gitignore`.

**Back it up the same day.** Copy both files to somewhere safe and private, such as a password
manager or private cloud storage, not the repo and not email. Every update on Play has to be
signed with this key, and so does every APK on GitHub; a phone refuses an update signed with a
different key. With Play App Signing (section 5) Google can reset a lost upload key after a
support request, but a lost key for the GitHub APK cannot be recovered: everyone would have to
uninstall and lose their progress.

## 2. Build the release

```bash
bash tools/build/android-release.sh
```

With no key it stops at once and says so. With the key it:

- exports the signed APK (`build/woodlogic.apk`) and the signed AAB (`build/woodlogic.aab`). The AAB
  is built with Gradle from the Android build template in `android/build`, which is not in git.
  The script unpacks it from `%APPDATA%\Godot\export_templates\4.7.2.stable\android_source.zip` when
  missing, and turns off the Gradle daemon so that Godot can finish. It needs a few GB free on C:
  and takes a few minutes.
- fails if the APK is debuggable or asks for any permission, if either file holds anything under
  `tests/`, `tools/`, `docs/` or `build/`, a Markdown file, PROMPT.md or a key file, or if either
  lacks LICENSE or NOTICE.
- prints the package, version, SDK levels, the data file count and the signing certificate.

Check that the certificate matches the fingerprint you wrote down in section 1.

**On the first real release build, look for the password once.** Search the export output and the
build folder for the password text, for example (type the password at the prompt, not on the
command line):

```bash
bash tools/build/android-release.sh > build/release-log.txt 2>&1
read -r -s -p "password: " P; echo
grep -c -F -- "$P" build/release-log.txt
grep -rl -a -F -- "$P" build/ android/ 2>/dev/null
unset P; rm build/release-log.txt
```

Both searches should find nothing (the count is 0 and the list is empty). Godot prints the signing
command with the password redacted, and the build folder is not part of the repo, but check once.

## 3. Check a build by hand

```bash
C:/Android/Sdk/build-tools/36.1.0/aapt2.exe dump badging build/woodlogic.apk | head -4
C:/Android/Sdk/build-tools/36.1.0/aapt2.exe dump permissions build/woodlogic.apk
C:/Android/Sdk/build-tools/36.1.0/apksigner.bat verify --print-certs build/woodlogic.apk
jarsigner -verify build/woodlogic.aab
```

Expected: package `io.github.bartbasi.woodlogic`, versionName `1.0.0`, `targetSdkVersion:'36'`, no
`application-debuggable`, no permissions, and a verified signature.

To try the release APK on the phone: a debug build installed with `adb` is signed with the debug
key, so the release APK will not install over it. The debug and release APKs share the package name
and the version, but they are signed with different keys, and Android refuses to update an app with a
differently signed one. Uninstall the debug one first, which loses its progress, then
`adb install -r build/woodlogic.apk`. The same goes the other way round.

## 4. Version rule

- `version/code` is a whole number that only goes up. **Raise it by 1 for every upload to Play**,
  even a test upload; Play rejects a code it has seen. Raise it in both release presets, and in the
  debug and timing presets too, to keep them in step (`export_presets.cfg`).
- `version/name` in each of the four presets and `application/config/version` in `project.godot`
  hold the same text, for example `1.0.1`. The game shows it on the title screen and in the
  feedback email. Change all five together.
- A change to the blueprints or the level generator changes which level a number gives. Read
  docs/ARCHITECTURE.md (the generator version) before shipping one, because a player's saved
  progress refers to level numbers.

## 5. Google Play

Bart does all Play Console work himself. Nothing has been entered in Play Console yet.

### One-time setup

1. Use Play, Inc.'s organization account (<https://play.google.com/console/signup>, a one-time fee).
   An organization account needs the company's DUNS number. New personal accounts must run a closed
   test with a number of testers first; check the current rule in the Console.
2. Create the app: name **WoodLogic**, default language English (US), **Game**, **Free** (free
   cannot be changed to paid later), then accept the declarations.
3. Play App Signing: accept the default ("Let Google manage and protect your app signing key") on
   the first upload. `woodlogic-release.keystore` becomes the **upload key**.

### Upload

Testing > Internal testing (a quick check first), or Production > Create release. Upload
`build/woodlogic.aab`, add release notes ("First release."), Review, Start rollout.

### Checklist for Bart

Everything to paste is in [store/listing.md](store/listing.md).

- [ ] **Main store listing:** app name, short description, full description, category Game > Puzzle,
      contact email bartbasi@gmail.com, website https://github.com/bartbasi/WoodLogic.
- [ ] **Graphics:** the 512 icon, the 1024 x 500 feature graphic and the phone screenshots from
      `build/store/` (made by `bash tools/build/make_store_graphics.sh`, section 7).
- [ ] **Privacy policy URL:** https://bartbasi.github.io/WoodLogic/privacy-policy/ (after Pages is
      switched on, section 6). Open it in a browser before you paste it.
- [ ] **Ads:** No.
- [ ] **App access:** all functionality is available without special access.
- [ ] **Data safety:** collects no data, shares no data, nothing encrypted in transit because
      nothing is sent, no account creation. The listing then says "No data collected".
- [ ] **Content rating:** the IARC questionnaire, category Game. Answer No to violence, fear,
      sexuality, language, controlled substances, gambling, user interaction, sharing location and
      digital purchases. Expect Everyone.
- [ ] **Target audience and content:** 13 and over is the safe choice. Including under 13s brings in
      Google's Families policy, which is strict about links that lead out of the app, such as Buy me
      a coffee.
- [ ] **Government, financial, health and news apps:** No.
- [ ] **Countries:** add the ones you want.
- [ ] **The Buy me a coffee button:** Bart decided on 22 October 2026 to show it on Play. Play's
      payments policy only allows donation links to tax-exempt charities outside the US, so review
      could flag it. If it does, add the custom feature `no_coffee` to both release presets
      (Export > Features), raise `version/code`, and build again: every coffee button is hidden.

## 6. GitHub Pages (the privacy policy)

`.github/workflows/pages.yml` publishes only `docs/store/` (the privacy policy and a short index) to
https://bartbasi.github.io/WoodLogic/ on every push to main that changes it. Each job asks for the
least permission it needs, and its actions are pinned to a commit. To turn it on (Bart): GitHub repo,
Settings, Pages, Source: **GitHub Actions**. Then push, or run the workflow from the Actions tab.
It is written but not enabled yet.

## 7. Store graphics

```bash
bash tools/build/make_store_graphics.sh
```

Writes `build/store/icon-512.png`, `feature-1024x500.png` and `phone-1.png` to `phone-6.png`
(1080 x 1920). It needs a desktop session: the pictures are drawn in a real window from the real
game, with a scratch save and no links opened. The icon is `icons/icon-512.png`, made by
`tools/art/app_icon.gd`. Look at them before uploading.

## 8. Publish a GitHub Release (only with Bart's go)

Needs a release build (section 2) and a clean `main`. Bart or the lead does this, never an agent.

1. Tag the commit: `git tag v1.0.0`, then push the tag.
2. On GitHub: Releases, Draft a new release, choose the tag, title `WoodLogic 1.0.0`, write short
   notes, and attach `build/woodlogic.apk`.
3. Say in the notes that it is the same game as on Play, free, with no ads and no tracking, that the
   source is in the repo, and give the SHA-256 of the APK (`sha256sum build/woodlogic.apk`).

### Sharing the APK directly

Send `build/woodlogic.apk`. On the phone, open it, then allow installing from that app when asked.
Play Protect may warn that it does not know the app; "Install anyway" is fine for your own build.
