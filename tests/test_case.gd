class_name TestCase
extends Node
## Base class of headless tests. tests/run_tests.tscn loads every tests/test_*.gd,
## adds it to the tree and awaits run(). Tests add their nodes as children of
## themselves, so everything is freed with the test.
## Run all:  godot --headless --path . res://tests/run_tests.tscn
## Run some: godot --headless --path . res://tests/run_tests.tscn -- --only=enemy,level

var failures: int = 0
var checks: int = 0


## Override in a test; may use await.
func run() -> void:
	pass


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("  FAIL: ", description)


func physics_frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


## Packs a node into a scene the way a .tscn would hold it, then frees the template.
func pack(node: Node) -> PackedScene:
	var scene: PackedScene = PackedScene.new()
	scene.pack(node)
	node.free()
	return scene
