# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## user://next_level.json (docs/ARCHITECTURE.md 10.3): used when the key and the generator
## version match, ignored for anything else.

const SaveScript := preload("res://src/save/save.gd")
const KEY := "numbered:20"

var _save: Node
var _level: LevelData


func _setup(test_name: String) -> void:
	_save = SaveScript.new()
	_save.dir = "%s%s/" % [tree.root.get_node("Save").get("dir"), test_name]
	add_node(_save)
	DirAccess.make_dir_recursive_absolute(_save.dir)
	_save.load_all()
	_level = LevelCatalog.get_level(LevelData.NUMBERED, 20, "").level


func _file_text() -> String:
	return FileAccess.get_file_as_string(_save.dir + "next_level.json")


func _put(text: String) -> void:
	var f := FileAccess.open(_save.dir + "next_level.json", FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_used_when_the_key_and_version_match() -> void:
	_setup("nl_match")
	check(_save.write_next_level(KEY, _level), "written")
	var got: LevelData = _save.read_next_level(KEY, Generator.GENERATOR_VERSION)
	check(got != null, "read back")
	if got != null:
		check_eq(JSON.stringify(got.to_dict()), JSON.stringify(_level.to_dict()), "the same level")
		check_eq(got.number, 20, "number")


func test_ignored_when_missing() -> void:
	_setup("nl_missing")
	check(_save.read_next_level(KEY, Generator.GENERATOR_VERSION) == null, "no file")


func test_ignored_when_broken() -> void:
	_setup("nl_broken")
	_save.write_next_level(KEY, _level)
	_put(_file_text().substr(0, 100))
	check(_save.read_next_level(KEY, Generator.GENERATOR_VERSION) == null, "cut short")
	_put("[1, 2, 3]")
	check(_save.read_next_level(KEY, Generator.GENERATOR_VERSION) == null, "not an object")
	_put("")
	check(_save.read_next_level(KEY, Generator.GENERATOR_VERSION) == null, "empty")


func test_ignored_for_another_key() -> void:
	_setup("nl_key")
	_save.write_next_level(KEY, _level)
	check(_save.read_next_level("numbered:21", Generator.GENERATOR_VERSION) == null, "another level's key")
	_save.write_next_level("numbered:21", _level)
	check(_save.read_next_level("numbered:21", Generator.GENERATOR_VERSION) == null, "a key that does not match the level")


func test_ignored_for_another_version() -> void:
	_setup("nl_version")
	_save.write_next_level(KEY, _level)
	check(_save.read_next_level(KEY, Generator.GENERATOR_VERSION + 1) == null, "another generator version")


func test_ignored_when_from_dict_reports_an_error() -> void:
	_setup("nl_error")
	_save.write_next_level(KEY, _level)
	var d: Dictionary = JSON.parse_string(_file_text())
	var planks: Array = d["planks"]
	var first: Dictionary = planks[0]
	first["colors"] = [99]
	_put(JSON.stringify(d))
	check(_save.read_next_level(KEY, Generator.GENERATOR_VERSION) == null, "a bad color")
	_save.write_next_level(KEY, _level)
	d = JSON.parse_string(_file_text())
	d["surprise"] = 1
	_put(JSON.stringify(d))
	check(_save.read_next_level(KEY, Generator.GENERATOR_VERSION) == null, "an unknown field")
	_save.write_next_level(KEY, _level)
	d = JSON.parse_string(_file_text())
	d["kind"] = "daily"
	_put(JSON.stringify(d))
	check(_save.read_next_level(KEY, Generator.GENERATOR_VERSION) == null, "the wrong kind")


func test_ignored_when_too_large() -> void:
	_setup("nl_large")
	_put("{\"key\": \"%s\", \"pad\": \"%s\"}" % [KEY, "x".repeat(SaveScript.MAX_LEVEL_FILE_BYTES + 10)])
	check(_save.read_next_level(KEY, Generator.GENERATOR_VERSION) == null, "too large")
	_save.clear_next_level()
	check(not FileAccess.file_exists(_save.dir + "next_level.json"), "cleared")
