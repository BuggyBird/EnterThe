extends Node
## End-to-end smoke test: boots the REAL dungeon scene (real RoomCatalog, authored
## room .tscn scenes, procedural corridors, player) and asserts a full floor
## materialized with a start room, a boss room, corridors, and a spawned player.
## Complements dungeon_gen_test (pure planner) by covering the scene-assembly path.
##   godot --headless --path <proj> res://tests/dungeon_boot_test.tscn

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

	var rooms := 0
	var has_start := false
	var has_boss := false
	var has_player := false
	for child in _dungeon.get_children():
		if child is RoomDef:
			rooms += 1
			if child.type == DungeonGenerator.RoomType.START:
				has_start = true
			elif child.type == DungeonGenerator.RoomType.BOSS:
				has_boss = true
		elif child is Player:
			has_player = true

	var corridors := get_tree().get_nodes_in_group(&"corridors").size()

	var ok: bool = rooms >= 4 and corridors >= 3 and has_start and has_boss and has_player
	print("DUNGEON BOOT TEST: %s (rooms=%d corridors=%d start=%s boss=%s player=%s)" % [
		"PASS" if ok else "FAIL", rooms, corridors, has_start, has_boss, has_player
	])
	get_tree().quit(0 if ok else 1)
