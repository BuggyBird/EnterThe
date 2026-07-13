extends Node2D
## Verifies that combat rooms now collide via their authored tilemap tiles instead
## of the auto-built perimeter walls:
##   - the room detects its collidable tilemap (_tilemap_collision = true),
##   - no solid perimeter wall SEGMENTS are built (only disabled door barriers),
##   - the tilemap actually produces World-layer collision the player would hit
##     (physics point-queries inside the room find solid tiles).
##   godot --headless --path <proj> res://tests/tilemap_collision_test.tscn

var _room: RoomDef
var _frames := 0


func _ready() -> void:
	RNG.set_seed(1)
	_room = load("res://rooms/combat/combat_cross.tscn").instantiate()
	add_child(_room)   # standalone: all doors open, so all collision is from tiles


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 4:
		return

	var ok := true

	if not _room._tilemap_collision:
		ok = false
		print("  room did not detect a collidable tilemap")

	# The tileset must expose a World (layer 1) physics layer.
	var layer_ok := false
	for node in _room.find_children("*", "TileMapLayer", true, false):
		var ts: TileSet = node.tile_set
		if ts and ts.get_physics_layers_count() > 0 and ts.get_physics_layer_collision_layer(0) == 1:
			layer_ok = node.collision_enabled
	if not layer_ok:
		ok = false
		print("  tilemap physics layer missing / not on World / collision off")

	# No enabled perimeter wall segments — only disabled door barriers may exist.
	var enabled_segments := 0
	var walls := _room.get_node_or_null("Walls")
	if walls:
		for shape in walls.get_children():
			if shape is CollisionShape2D and not shape.disabled:
				enabled_segments += 1
	if enabled_segments != 0:
		ok = false
		print("  expected 0 auto wall segments, found %d" % enabled_segments)

	# The tiles really collide: sample the room area and count World-layer hits.
	var space := get_world_2d().direct_space_state
	var hits := 0
	var half := _room.room_size * 0.5
	for gx in range(-int(half.x), int(half.x), 16):
		for gy in range(-int(half.y), int(half.y), 16):
			var q := PhysicsPointQueryParameters2D.new()
			q.position = Vector2(gx, gy)
			q.collision_mask = 1   # World
			if not space.intersect_point(q).is_empty():
				hits += 1
	if hits < 20:
		ok = false
		print("  too few solid tiles collided (%d) — tilemap collision not live" % hits)

	print("TILEMAP COLLISION TEST: %s (tilemap=%s segments=%d wall_hits=%d)" % [
		"PASS" if ok else "FAIL", _room._tilemap_collision, enabled_segments, hits])
	get_tree().quit(0 if ok else 1)
