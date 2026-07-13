extends Node
## Verifies each USED door gets an animated dimensional portal, that locking the
## room dims the portals and clearing restores their base colour.
##   godot --headless --path <proj> res://tests/portal_test.tscn

func _ready() -> void:
	var ok := true
	var room: RoomDef = load("res://rooms/combat/combat_cross.tscn").instantiate()
	room.configure(DungeonGenerator.RoomType.COMBAT, [0, 1, 2, 3])  # all four doors used
	add_child(room)

	var portals: Array[Node2D] = []
	for child in room.get_children():
		if child is Node2D and child.is_in_group(&"door_portals"):
			portals.append(child)

	if portals.size() != 4:
		ok = false
		print("  expected 4 portals, got %d" % portals.size())
	for portal in portals:
		var sprite: AnimatedSprite2D = null
		for sub in portal.get_children():
			if sub is AnimatedSprite2D:
				sprite = sub
		if sprite == null or not sprite.is_playing():
			ok = false
			print("  portal has no playing AnimatedSprite2D")
		elif sprite.sprite_frames.get_frame_count(&"swirl") != 6:
			ok = false
			print("  expected 6 swirl frames, got %d" % sprite.sprite_frames.get_frame_count(&"swirl"))

	# Locking dims the portals; clearing restores the base colour.
	room._set_doors_locked(true)
	var dimmed := not portals.is_empty() and portals[0].modulate == RoomDef.PORTAL_LOCKED_TINT
	room._set_doors_locked(false)
	var restored := not portals.is_empty() and portals[0].modulate == Color.WHITE
	if not (dimmed and restored):
		ok = false
		print("  lock tint wrong: dimmed=%s restored=%s" % [dimmed, restored])

	print("PORTAL TEST: %s (%d portals)" % ["PASS" if ok else "FAIL", portals.size()])
	get_tree().quit(0 if ok else 1)
