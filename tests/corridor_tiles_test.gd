extends Node
## Verifies corridors are floored with a TileMapLayer (not left empty): boots the
## real dungeon and asserts every corridor has a TileMapLayer carrying painted cells.
##   godot --headless --path <proj> res://tests/corridor_tiles_test.tscn

var _frames := 0
var _dungeon: Node2D


func _ready() -> void:
	RNG.set_seed(1234)
	_dungeon = load("res://procgen/dungeon.tscn").instantiate()
	add_child(_dungeon)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 5:
		return

	var corridors := get_tree().get_nodes_in_group(&"corridors")
	var floored := 0
	var total_cells := 0
	for c in corridors:
		for child in c.get_children():
			if child is TileMapLayer:
				var cells: int = child.get_used_cells().size()
				total_cells += cells
				if cells > 0:
					floored += 1
				break

	var ok: bool = corridors.size() >= 3 and floored == corridors.size() and total_cells > 0
	print("CORRIDOR TILES TEST: %s (corridors=%d floored=%d cells=%d)" % [
		"PASS" if ok else "FAIL", corridors.size(), floored, total_cells
	])
	get_tree().quit(0 if ok else 1)
