# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name MenuFactory
extends RefCounted
## Builds the menu screens of docs/UX.md 1.6 by name, so the app flow only wires them up.

const NAMES: Array[String] = ["title", "map", "stats", "info", "settings", "about", "license", "credits", "relaxed"]
## The dock tab each tab id opens.
const TAB_SCREENS := {"home": "title", "map": "map", "stats": "stats", "info": "info", "settings": "settings", "about": "about"}


## ctx: next_level, paused_text, version, progress (Save.progress_copy()), settings (the
## Settings dictionary), last_band, daily_note, daily_locked, relaxed_locked.
static func make(menu_name: String, ctx: Dictionary) -> MenuScreen:
	var next := int(ctx.get("next_level", 1))
	var paused := str(ctx.get("paused_text", ""))
	var progress: Dictionary = ctx.get("progress", {})
	var s: MenuScreen
	match menu_name:
		"title":
			return TitleScreen.make(next, str(ctx.get("version", "")), {
				"paused_text": paused,
				"bank": int(progress.get("star_bank", 0)),
				"daily_note": ctx.get("daily_note", "Today's puzzle"),
				"daily_locked": ctx.get("daily_locked", false),
				"relaxed_locked": ctx.get("relaxed_locked", false),
			})
		"map":
			s = MapScreen.make(progress)
			s.configure("map", "Progress map", true, true, next, paused)
		"stats":
			s = StatsScreen.make(progress)
			s.configure("stats", "Stats", true, true, next, paused)
		"info":
			s = InfoScreen.new()
			s.configure("info", "How to play", true, true, next, paused)
		"settings":
			s = SettingsScreen.make(ctx.get("settings", {}))
			s.configure("settings", "Settings", true, true, next, paused)
		"about":
			s = AboutScreen.make(str(ctx.get("version", "")))
			s.configure("about", "About", false, true, next, paused)
		"license":
			s = LicenseScreen.make()
			s.configure("about", "License", false, true, next, paused)
		"credits":
			s = CreditsScreen.make_credits()
			s.configure("about", "Credits", false, true, next, paused)
		"relaxed":
			s = RelaxedScreen.make(str(ctx.get("last_band", "")))
			s.configure("home", "Relaxed", true, false, next, paused)
		_:
			push_warning("MenuFactory: unknown menu " + menu_name)
			return null
	return s
