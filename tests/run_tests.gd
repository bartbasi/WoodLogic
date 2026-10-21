# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends SceneTree
## Headless test runner. From the project folder (or use tools/test.sh, which imports first):
##   godot --headless --fixed-fps 60 --path . -s res://tests/run_tests.gd
##   godot --headless --fixed-fps 60 --path . -s res://tests/run_tests.gd -- <text>
## Runs every tests/**/test_*.gd. With <text>, runs only the tests whose file path or test
## name contains it. Exits with code 1 if any test fails.

const TESTS_ROOT := "res://tests"

## Game seconds before a stuck test gives up and the run fails. Under --fixed-fps 60 every
## frame is 1/60 s, so this is the total animated time of the whole run plus room to grow.
## It only catches a test stuck on an await; tools/test.sh adds a wall-clock limit for a test
## stuck in a loop.
const TIME_LIMIT := 3600.0

var _errors := ErrorCatcher.new()
var _current := ""
var _save_dir := ""


## Collects engine and script errors as they happen, so a test that hits one fails instead of
## quietly passing. (A GDScript runtime error just stops the test function.)
class ErrorCatcher extends Logger:
	var _mutex := Mutex.new()
	var _found := PackedStringArray()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		_found.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> PackedStringArray:
		_mutex.lock()
		var found := _found.duplicate()
		_found.clear()
		_mutex.unlock()
		return found


func _initialize() -> void:
	OS.add_logger(_errors)
	create_timer(TIME_LIMIT, true, false, true).timeout.connect(func() -> void:
		print("\nTIMED OUT after %d s in %s" % [TIME_LIMIT, _current])
		_remove_dir(_save_dir)
		_quit(1))
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var only: String = args[0] if args.size() > 0 else ""
	# Tests never touch the player's real saves.
	var save_dir := "user://test_%d/" % OS.get_process_id()
	# (A -s script compiles before the autoloads exist as names, so it finds Save by its node.)
	var save := root.get_node("Save")
	save.set("dir", save_dir)
	if save.get("dir") != save_dir:
		print("Could not point Save at %s, so no test runs (they would touch the real saves)." % save_dir)
		_quit(1)
		return
	_save_dir = save_dir
	# No music in test runs: it would play through every suite and still be alive at quit.
	var audio := root.get_node_or_null("Audio")
	if audio != null:
		audio.set("render_music", false)
		audio.call("set_music", false)
	# The game data loads once, on the main thread, as the app does at boot.
	var loaded := LevelCatalog.load_all()
	var load_errors := _errors.take()
	if not loaded or not load_errors.is_empty():
		for error: String in load_errors:
			print(error)
		print("\nThe game data failed to load.")
		_quit(1)
		return
	var files: Array[String] = []
	_find_suites(TESTS_ROOT, files)
	files.sort()
	var passed := 0
	var failed := 0
	for path: String in files:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			if only == "" or path.contains(only):
				failed += 1
				print(path.trim_prefix(TESTS_ROOT + "/"))
				print("  FAIL  could not load the suite (script error)")
			continue
		var names: Array[String] = []
		for method: Dictionary in script.get_script_method_list():
			var test_name: String = method["name"]
			if test_name.begins_with("test_") and not names.has(test_name) and (only == "" or path.contains(only) or test_name.contains(only)):
				names.append(test_name)
		if names.is_empty():
			continue
		print(path.trim_prefix(TESTS_ROOT + "/"))
		for test_name: String in names:
			_current = "%s %s" % [path.get_file(), test_name]
			_errors.take()  # before new(), so errors from the suite's own setup count too
			# No test ever opens a link: a test that doesn't set its own opener gets this one.
			Links.opener = _no_open
			Links.coffee_hidden_for_tests = -1
			var suite := script.new() as TestCase
			if suite == null:
				failed += 1
				print("  FAIL  the suite does not extend TestCase")
				break
			suite.tree = self
			await suite.call(test_name)
			await suite.cleanup()
			for error: String in _errors.take():
				suite.failures.append("error during the test: " + error)
			if suite.failures.is_empty():
				passed += 1
				print("  ok    ", test_name)
			else:
				failed += 1
				print("  FAIL  ", test_name)
				for failure: String in suite.failures:
					print("        ", failure)
	if passed + failed == 0:
		print("No tests found%s." % ("" if only == "" else " matching \"%s\"" % only))
	print("\n%d passed, %d failed" % [passed, failed])
	_remove_dir(save_dir)
	# A filter that matches nothing is a mistake (a typo, or suites in the wrong folder), not a pass.
	_quit(1 if failed > 0 or (only != "" and passed == 0) else 0)


## Stands in for the phone when a test taps a link: opens nothing.
func _no_open(_address: String) -> int:
	return OK


## Clears Links.opener first: a callable left in a static variable crashes the engine on quit.
func _quit(code: int) -> void:
	Links.opener = Callable()
	quit(code)


func _find_suites(dir: String, found: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		_find_suites(dir.path_join(sub), found)
	for file: String in DirAccess.get_files_at(dir):
		if file.begins_with("test_") and file.get_extension() == "gd" and file != "test_case.gd":
			found.append(dir.path_join(file))


## Deletes a folder the tests made, with everything in it.
func _remove_dir(dir: String) -> void:
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		_remove_dir(dir.path_join(sub))
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
