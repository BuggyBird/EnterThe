extends Node
## Regression test for the door-lock physics error. Spawns the player inside a
## combat room so the room's Area2D fires body_entered DURING a physics query
## flush — the exact situation that previously errored on collision toggling.
## Passes if the encounter starts, doors lock, and no physics error is raised.

var _frames := 0
var _room: RoomDef


func _ready() -> void:
	_room = load("res://rooms/combat/combat_cross.tscn").instantiate()
	# Treat all four authored doors as connected so barriers exist on every side.
	_room.configure(DungeonGenerator.RoomType.COMBAT, [0, 1, 2, 3])
	add_child(_room)

	var player: Node2D = load("res://actors/player/player.tscn").instantiate()
	player.position = Vector2.ZERO
	add_child(player)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames >= 10:
		var enemies_spawned: bool = _room._alive_enemies > 0
		# combat_cross is a tiled room: a locked door shows the solid placeholder gate
		# tile in its gate cells (painting them adds collision that seals the opening).
		var doors_locked: bool = not _room._gates.is_empty() \
			and _room._gate_map.get_cell_atlas_coords(_room._gates[0]["cells"][0]) == RoomDef.GATE_TILE
		var ok := enemies_spawned and doors_locked and not _room.is_cleared
		print("ROOM LOCK TEST: %s (enemies=%s locked=%s)" % [
			"PASS" if ok else "FAIL", enemies_spawned, doors_locked
		])
		get_tree().quit(0 if ok else 1)
