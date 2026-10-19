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
const TIME_LIMIT := 1800.0

var _errors := ErrorCatcher.new()
var _current := ""


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
		quit(1))
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var only: String = args[0] if args.size() > 0 else ""
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
	# A filter that matches nothing is a mistake (a typo, or suites in the wrong folder), not a pass.
	quit(1 if failed > 0 or (only != "" and passed == 0) else 0)


func _find_suites(dir: String, found: Array[String]) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		_find_suites(dir.path_join(sub), found)
	for file: String in DirAccess.get_files_at(dir):
		if file.begins_with("test_") and file.get_extension() == "gd" and file != "test_case.gd":
			found.append(dir.path_join(file))
