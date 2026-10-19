# WoodLogic. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
class_name TestCase
extends RefCounted
## Base class for test suites. A suite is a file tests/<area>/test_*.gd that extends TestCase;
## each method whose name starts with "test_" is one test, run on a fresh instance of the suite.
## A test may await (frames, timers, signals). It fails if any check fails or if an engine or
## script error is logged while it runs.

var tree: SceneTree
var failures := PackedStringArray()
var _nodes: Array[Node] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, what: String) -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s = %s, expected %s" % [what, var_to_str(actual), var_to_str(expected)])


func check_between(value: float, low: float, high: float, what: String) -> void:
	check(value >= low and value <= high, "%s = %.3f, expected %.3f .. %.3f" % [what, value, low, high])


## Adds a node to the scene tree for this test. It is freed when the test ends.
func add_node(node: Node) -> Node:
	tree.root.add_child(node)
	_nodes.append(node)
	return node


func frames(count: int) -> void:
	for i: int in count:
		await tree.process_frame


func physics_frames(count: int) -> void:
	for i: int in count:
		await tree.physics_frame


func cleanup() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()
	await tree.process_frame
