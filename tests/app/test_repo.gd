# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
extends TestCase
## Checks on the whole repo: the license header, no network code, and links handed to the
## phone from one place only.

const HEADER_LINES: Array[String] = [
	"WoodLogic. Copyright 2026 Play, Inc.",
	"Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.",
]
const SOURCE_EXTENSIONS: Array[String] = ["gd", "gdshader", "sh", "py"]
## Scenes, resources and project.godot can create nodes or hold built-in scripts too.
const OTHER_CODE_EXTENSIONS: Array[String] = ["tscn", "tres", "godot"]
## Folders at the top of the repo that hold no source of ours.
const SKIP_ROOT_DIRS: Array[String] = [".git", ".godot", "android", "build"]

## Engine classes that reach the network. None of them may appear in our code.
const NETWORK_CLASSES: Array[String] = [
	"HTTPRequest", "HTTPClient", "StreamPeerTCP", "StreamPeerTLS", "TCPServer", "UDPServer",
	"PacketPeerUDP", "PacketPeerDTLS", "DTLSServer", "WebSocketPeer", "WebSocketMultiplayerPeer",
	"WebRTCPeerConnection", "WebRTCMultiplayerPeer", "ENetConnection", "ENetMultiplayerPeer",
	"UPNP", "JavaScriptBridge", "SceneMultiplayer",
]
## The IP singleton (DNS lookups), and making classes from a name, which would hide them.
const NETWORK_PATTERNS: Array[String] = ["\\bIP\\.", "ClassDB\\.instantiate"]


func test_every_source_file_carries_the_license_header() -> void:
	var missing := PackedStringArray()
	var files := _files(SOURCE_EXTENSIONS)
	for path: String in files:
		var mark := "//" if path.get_extension() == "gdshader" else "#"
		var lines := FileAccess.get_file_as_string(path).replace("\r\n", "\n").split("\n")
		var first := 1 if lines[0].begins_with("#!") else 0
		if lines.size() < first + 2 \
				or lines[first] != mark + " " + HEADER_LINES[0] \
				or lines[first + 1] != mark + " " + HEADER_LINES[1]:
			missing.append(path)
	check(files.has("res://tests/run_tests.gd"), "the scan finds .gd files")
	check(files.has("res://tools/test.sh"), "the scan finds .sh files")
	check(files.any(func(p: String) -> bool: return p.ends_with(".gdshader")), "the scan finds shaders")
	check(missing.is_empty(), "files without the header at the top: %s" % ", ".join(missing))


func test_no_network_code_anywhere() -> void:
	var patterns: Array[RegEx] = []
	for pattern: String in NETWORK_PATTERNS:
		patterns.append(RegEx.create_from_string(pattern))
	var found := PackedStringArray()
	for path: String in _code_files():
		var text := FileAccess.get_file_as_string(path)
		for name: String in NETWORK_CLASSES:
			if text.contains(name):
				found.append("%s in %s" % [name, path])
		for regex: RegEx in patterns:
			if regex.search(text) != null:
				found.append("%s in %s" % [regex.get_pattern(), path])
	check(found.is_empty(), "network code: %s" % ", ".join(found))


func test_links_are_opened_only_from_links_gd() -> void:
	var found := PackedStringArray()
	for path: String in _code_files():
		if path != "res://src/ui/links.gd" and FileAccess.get_file_as_string(path).contains("shell_open"):
			found.append(path)
	check(found.is_empty(), "OS.shell_open outside src/ui/links.gd: %s" % ", ".join(found))


func test_no_built_in_scripts_or_shaders() -> void:
	# A script or shader inside a scene would escape the header and code checks above.
	var found := PackedStringArray()
	for path: String in _files(["tscn", "tres"]):
		var text := FileAccess.get_file_as_string(path)
		if text.contains("type=\"GDScript\"") or text.contains("type=\"Shader\""):
			found.append(path)
	check(found.is_empty(), "built-in scripts or shaders: %s" % ", ".join(found))


## Every file that could hold code, except this one, which names what it looks for.
func _code_files() -> Array[String]:
	var files := _files(SOURCE_EXTENSIONS + OTHER_CODE_EXTENSIONS)
	files.erase(get_script().resource_path)
	return files


## Every file in the repo with one of these extensions, hidden folders included.
func _files(extensions: Array[String]) -> Array[String]:
	var found: Array[String] = []
	var dirs: Array[String] = ["res://"]
	while not dirs.is_empty():
		var dir_path: String = dirs.pop_back()
		var dir := DirAccess.open(dir_path)
		dir.include_hidden = true
		for sub: String in dir.get_directories():
			if sub != "__pycache__" and not (dir_path == "res://" and sub in SKIP_ROOT_DIRS):
				dirs.append(dir_path.path_join(sub))
		for file: String in dir.get_files():
			if file.get_extension() in extensions:
				found.append(dir_path.path_join(file))
	found.sort()
	return found
