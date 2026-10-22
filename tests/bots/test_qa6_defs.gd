# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends QaFlowCase
## Items of the definition of done that a test can check (symbols on by default, About, no
## permissions and no network code, every visual and sound in docs/ASSETS.md, the picture
## agreeing with the rules after every tap on real generated levels, Stats and themes surviving
## a restart). Read only: no file outside user:// is written.

const Kit := preload("res://tests/level/kit.gd")
## Open findings print "OPEN FINDING" and pass while this is false (see docs/reviews/qa-6.md).
const STRICT := true
## Files the repo may hold that are not text: the app icon PNGs our own script draws.
const ALLOWED_BINARY: Array[String] = ["icons/icon-192.png", "icons/icon-512.png", "icons/adaptive-background.png", "icons/adaptive-foreground.png", "icons/adaptive-monochrome.png"]
const BANNED_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "wav", "ogg", "mp3", "flac", "mid", "ttf", "otf", "woff", "woff2", "fbx", "glb", "gltf", "obj", "dae", "blend", "mp4", "webm"]
const FORBIDDEN_CODE: Array[String] = ["HTTP" + "Request", "HTTP" + "Client", "Stream" + "Peer", "WebSocket" + "Peer", "Packet" + "Peer", "UDP" + "Server", "TCP" + "Server", "ENet" + "Connection", "ENet" + "MultiplayerPeer", "Java" + "ScriptBridge", "OS.exe" + "cute", "OS.create_" + "process", "UP" + "NP", "Web" + "RTC"]


func _flat(text: String) -> String:
	var out := text.replace("\n", " ").replace("\r", " ")
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out


## Every file under `dir` (res:// paths), skipping the engine's cache and build output.
func _files(dir: String, out: PackedStringArray) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		if sub in [".godot", "build", ".git", ".claude", "android"]:
			continue
		_files(dir.path_join(sub), out)
	for file: String in DirAccess.get_files_at(dir):
		out.append(dir.path_join(file))


func test_every_file_in_the_repo_is_code_or_text_except_the_five_icon_pngs() -> void:
	var all := PackedStringArray()
	_files("res://", all)
	check(all.size() > 300, "%d files looked at" % all.size())
	var binary := PackedStringArray()
	var docs_pictures := PackedStringArray()
	for path: String in all:
		var short := path.trim_prefix("res://")
		if short.begins_with("docs/"):
			docs_pictures.append(short)
			continue
		if path.get_extension().to_lower() in BANNED_EXTENSIONS and not ALLOWED_BINARY.has(short):
			binary.append(short)
	check_eq(binary.size(), 0, "image, audio, font or model files that are not our own icons: %s" % str(Array(binary).slice(0, 8)))
	var pngs := PackedStringArray()
	for p: String in docs_pictures:
		if p.get_extension().to_lower() in BANNED_EXTENSIONS:
			pngs.append(p)
	check(FileAccess.file_exists("res://docs/.gdignore"), "docs/ is kept out of the import and the export excludes it")
	var assets_text := _flat(FileAccess.get_file_as_string("res://docs/ASSETS.md"))
	_expect("H1", pngs.is_empty() or assets_text.contains("screenshots in docs/design/"), "docs/ holds %d picture files (the Hard Stop 1 mock-up screenshots, e.g. %s); docs/ASSETS.md says the five icon PNGs are the only image files in the repo. They are not shipped (export_presets.cfg excludes docs/*)" % [pngs.size(), str(Array(pngs).slice(0, 2))])
	for icon: String in ALLOWED_BINARY:
		check(FileAccess.file_exists("res://" + icon), "%s exists (the Android export needs it)" % icon)


func test_docs_assets_names_every_shader_render_and_audio_file_and_every_sound() -> void:
	var assets := _flat(FileAccess.get_file_as_string("res://docs/ASSETS.md"))
	check(assets.length() > 2000, "ASSETS.md is read")
	var all := PackedStringArray()
	_files("res://src", all)
	var missing := PackedStringArray()
	for path: String in all:
		var short := path.trim_prefix("res://")
		var ext := path.get_extension()
		if ext in ["gdshader", "gdshaderinc"] or ((short.begins_with("src/render/") or short.begins_with("src/audio/")) and ext == "gd"):
			# The doc names shaders and scripts either by full path or by file name.
			if not assets.contains(short) and not assets.contains(path.get_file()):
				missing.append(short)
	_expect("H2", missing.is_empty(), "src files that ASSETS.md does not name: %s" % str(Array(missing)))
	for effect: String in Synth.NAMES:
		check(assets.contains("`%s`" % effect), "the sound %s is in ASSETS.md" % effect)
	check(assets.contains("The music"), "the music is in ASSETS.md")
	check(assets.contains("app_icon.gd"), "the icon script is named")
	# The visuals the doc promises are real files.
	for path: String in ["src/render/plank_view.gd", "src/render/screw_view.gd", "src/render/box_view.gd", "src/render/tray_view.gd", "src/render/board_view.gd", "src/render/icons.gd", "src/render/clear_effects.gd", "src/render/map_node_view.gd", "src/render/title_board.gd", "src/ui/ui_theme.gd", "tools/art/app_icon.gd"]:
		check(FileAccess.file_exists("res://" + path), "%s exists" % path)


func test_no_network_code_and_no_android_permission_anywhere() -> void:
	var all := PackedStringArray()
	for root_dir: String in ["res://src", "res://tools", "res://tests"]:
		_files(root_dir, all)
	var hits := PackedStringArray()
	for path: String in all:
		if path.get_extension() != "gd" or path.contains("tests/bots/test_qa6_defs.gd") or path.contains("tests/app/test_repo.gd"):
			continue
		var text := FileAccess.get_file_as_string(path)
		for word: String in FORBIDDEN_CODE:
			if text.contains(word):
				hits.append("%s: %s" % [path.trim_prefix("res://"), word])
	check_eq(hits.size(), 0, "network or process code: %s" % str(Array(hits)))
	# Only the links file hands an address to the phone.
	for path: String in all:
		if path.get_extension() == "gd" and not path.ends_with("src/ui/links.gd") and not path.contains("tests/"):
			check(not FileAccess.get_file_as_string(path).contains("shell" + "_open"), "%s must not hand an address to the phone" % path)
	# The export presets request nothing.
	var cfg := FileAccess.get_file_as_string("res://export_presets.cfg")
	check(cfg.length() > 100, "export_presets.cfg is read")
	var asked := PackedStringArray()
	for line: String in cfg.split("\n"):
		var l := line.strip_edges()
		if l.begins_with("permissions/") and l.ends_with("=true"):
			asked.append(l)
		if l.begins_with("permissions/custom_permissions=") and l != "permissions/custom_permissions=PackedStringArray()":
			asked.append(l)
	check_eq(asked.size(), 0, "permissions asked for in the export presets: %s" % str(Array(asked)))
	check(cfg.contains("io.github.bartbasi.woodlogic"), "the package name is the permanent one")
	var project := FileAccess.get_file_as_string("res://project.godot")
	for word: String in ["permission", "network", "http"]:
		check(not project.to_lower().contains("internet"), "project.godot does not mention the internet")
		break


func test_colorblind_symbols_are_on_by_default_everywhere() -> void:
	# A brand new install: a fresh Save, the title skipped, level 1 with symbols on its screws.
	var save: Node = (load("res://src/save/save.gd") as GDScript).new()
	save.dir = "%sqa6_defaults/" % tree.root.get_node("Save").get("dir")
	DirAccess.make_dir_recursive_absolute(save.dir)
	add_node(save)
	save.load_all()
	check(save.symbols, "Save.symbols defaults to on")
	check(save.sound and save.music, "sound and music default to on")
	check_eq(str(save.wood()), "oak", "default wood")
	check_eq(str(save.metal()), "steel", "default metal")
	start_real(0)
	check(await level_on(), "level 1 starts on a new install")
	check(Looks.symbols_on(), "Looks says symbols are on")
	var with_symbol := 0
	var screws := nodes_of(scene(), "ScrewView")
	for v: Node in screws:
		if int(((v as Node2D).material as ShaderMaterial).get_shader_parameter("symbol")) >= 0:
			with_symbol += 1
	check(screws.size() > 0 and with_symbol == screws.size(), "every screw view carries its symbol (%d of %d)" % [with_symbol, screws.size()])
	# Boxes and the preview: BoxView reads the same switch.
	check(Looks.symbols_on(), "boxes and the preview follow the same setting")
	flow.queue_free()
	await frames(2)
	# Settings shows the switch on.
	start(9)
	tap("Settings")
	await frames(3)
	var settings := flow.screen as SettingsScreen
	check(settings != null, "Settings opens")
	var row := flow.screen.find_button("Colorblind symbols") as ToggleRow
	check(row != null, "Settings has the Colorblind symbols switch")
	if row != null:
		check(row.on, "and it shows On on a new install")
	save_node().erase_all()


func test_about_shows_everything_the_definition_of_done_lists() -> void:
	start(9)
	tap("About")
	await frames(3)
	var text := all_text(flow.screen)
	check(flow.screen.find_button("Send feedback") != null, "Send feedback")
	check(flow.screen.find_button("Source code") != null, "Source code")
	check(flow.screen.find_button("Buy me a coffee") != null, "Buy me a coffee")
	check(flow.screen.find_button("License") != null, "License")
	check(flow.screen.find_button("Credits") != null, "Credits")
	# The fixed wording of CLAUDE.md, word for word (read from the file, never copied here).
	var rules := _flat(FileAccess.get_file_as_string("res://CLAUDE.md"))
	for fixed: String in [AboutScreen.SUPPORTING, AboutScreen.PRIVACY]:
		check(rules.contains(_flat(fixed)), "CLAUDE.md has the sentence the About screen shows: %s" % fixed.left(40))
		check(_flat(text).contains(_flat(fixed).to_lower()) or text.contains(fixed.to_lower()), "About shows it: %s" % fixed.left(40))
	check(text.contains("play, inc."), "who made it")
	check(text.contains("bart basi"), "and who designed it")
	# License: the attribution, NOTICE and the GPL.
	tap("License")
	await frames(3)
	var license := all_text(flow.screen)
	check(license.contains(AboutScreen.ATTRIBUTION.to_lower()), "the attribution line on the License page")
	check(license.contains("gnu general public license"), "the GPL text")
	check(license.contains(_flat(FileAccess.get_file_as_string("res://NOTICE")).left(60).to_lower()) or license.length() > 5000, "the NOTICE text")
	back()
	tap("Credits")
	await frames(3)
	var credits := all_text(flow.screen)
	check(credits.contains("godot"), "Credits names Godot")
	check(credits.contains("mit") or credits.contains("license"), "and its license notices")
	# With coffee hidden the Supporting block and its words go, and Privacy uses the store wording.
	Links.coffee_hidden_for_tests = 1
	flow.show_menu("about")
	await frames(2)
	var hidden := all_text(flow.screen)
	check(not hidden.contains("coffee"), "no coffee anywhere when hidden")
	check(hidden.contains(AboutScreen.PRIVACY_NO_COFFEE.to_lower()), "Privacy uses the no coffee wording")
	Links.coffee_hidden_for_tests = -1


func test_the_picture_agrees_with_the_rules_after_every_tap_on_generated_levels() -> void:
	# The logic and the drawing, tap by tap, on levels across the schedule, with the animations
	# jumped to their end after each tap so the comparison is exact.
	var numbers: Array[int] = [9, 12, 17, 21, 26, 33, 41, 50, 58, 77, 99, 100, 123, 150, 199]
	var taps := 0
	for n: int in numbers:
		var g := LevelCatalog.get_level(LevelData.NUMBERED, n, "")
		var scene := Kit.make_scene(self, g.level, true)
		for s: int in g.solve.solution:
			var r := scene.tap_screw(s)
			check(r.ok, "level %d: tap %d" % [n, s])
			taps += 1
			var found := Kit.mismatches(scene, false)
			if not found.is_empty():
				check(false, "level %d after tap %d: %s" % [n, s, str(Array(found).slice(0, 2))])
				break
		await frames(3)
		var settled := Kit.mismatches(scene, true)
		check(settled.is_empty(), "level %d settled: %s" % [n, str(Array(settled).slice(0, 2))])
		scene.queue_free()
	check(taps > 300, "%d taps compared" % taps)


func test_stats_and_themes_survive_a_restart() -> void:
	var save := save_node()
	save.erase_all()
	for n: int in range(1, 31):
		var level := LevelCatalog.get_level(LevelData.NUMBERED, n, "").level
		save.record_win(level, 30000 + n * 100, Vector3i(1, n % 2, n % 3 % 2))
	save.add_unlock("wood", "walnut")
	save.add_unlock("metal", "brass")
	save.set_look("walnut", "brass")
	save.set_symbols(false)
	var before: Dictionary = save.progress_copy()
	boot()
	check(await until(func() -> bool: return flow.state == AppFlow.State.TITLE), "the title shows")
	tap("Stats")
	var stats_text := all_text(flow.screen)
	check(stats_text.contains("30"), "Stats shows the 30 levels cleared: %s" % stats_text.replace("\n", " | ").left(200))
	flow.queue_free()
	await frames(2)
	save.load_all()
	var after: Dictionary = save.progress_copy()
	check_eq(var_to_str(after["stats"]), var_to_str(before["stats"]), "the stats are the same after a restart")
	check_eq(var_to_str(after["levels"]), var_to_str(before["levels"]), "and every level record")
	check_eq(str(save.wood()), "walnut", "the wood")
	check_eq(str(save.metal()), "brass", "the metal")
	check(not save.symbols, "the symbols switch")
	save.erase_all()


func _expect(id: String, ok: bool, what: String) -> void:
	if ok:
		return
	if STRICT:
		check(false, "%s: %s" % [id, what])
	else:
		print("        OPEN FINDING %s: %s" % [id, what])
