extends Node
## Verifies each USED door gets a strip of door tiles (its own DoorTiles TileMapLayer)
## instead of a coloured bar, and that locking tints them.
##   godot --headless --path <proj> res://tests/door_tiles_test.tscn

func _ready() -> void:
	var ok := true
	var room: RoomDef = load("res://rooms/combat/combat_cross.tscn").instantiate()
	room.configure(DungeonGenerator.RoomType.COMBAT, [0, 1, 2, 3])  # all four doors used
	add_child(room)

	var layers: Array[TileMapLayer] = []
	for child in room.get_children():
		if child is TileMapLayer and child.is_in_group(&"door_tiles"):
			layers.append(child)

	if layers.size() != 4:
		ok = false
		print("  expected 4 DoorTiles layers, got %d" % layers.size())
	for layer in layers:
		var cells := layer.get_used_cells().size()
		if cells != 6:  # DOOR_WIDTH 96 / 16px = 6 tiles
			ok = false
			print("  door strip has %d cells, expected 6" % cells)

	# Locking should tint the door tiles; clearing restores them.
	room._set_doors_locked(true)
	var tinted := layers.is_empty() or layers[0].modulate == RoomDef.DOOR_LOCKED_TINT
	room._set_doors_locked(false)
	var restored := layers.is_empty() or layers[0].modulate == Color.WHITE
	if not (tinted and restored):
		ok = false
		print("  lock tint wrong: tinted=%s restored=%s" % [tinted, restored])

	print("DOOR TILES TEST: %s (%d strips)" % ["PASS" if ok else "FAIL", layers.size()])
	get_tree().quit(0 if ok else 1)
