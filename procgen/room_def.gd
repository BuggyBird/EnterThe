class_name RoomDef
extends Node2D
## Root script for every hand-authored room scene. You build the room's INTERIOR by
## hand in the editor — floor decoration, obstacles/cover, and SpawnPoints markers —
## and drop DoorAnchor markers on the perimeter to declare where doors may be. At
## runtime RoomDef builds the perimeter walls procedurally from `room_size`, leaving
## a gap + lockable barrier only at the doors the generator actually connected, and
## sealing the rest as solid wall. This guarantees watertight rooms of any size while
## letting doors sit anywhere along an edge.
##
## Authoring recipe (all centred on the room's origin):
##   - Set `room_size` and `category`.
##   - Add a "Doors" node; under it, DoorAnchor markers ON the edges.
##   - Add a "SpawnPoints" node with Marker2D children where enemies/loot appear.
##   - Add anything else (Polygon2D pillars, StaticBody2D cover) freely.

const WALL_THICKNESS := 18.0
const DOOR_WIDTH := 48.0   ## 3 tiles. Must match DungeonGenerator.DOOR_WIDTH.
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

const DEFAULT_TILESET_PATH := "res://resources/dungeon_tileset.tres"
const DOOR_LOCKED_TINT := Color(1.0, 0.4, 0.42)   ## Red flash on the door tiles while sealed.
const SHROUD_COLOR := Color(0.015, 0.012, 0.03, 1.0)   ## Near-black fog over unentered rooms.
const SHROUD_Z := 100                              ## Above room interior + occupants, below UI.

## Floor atlas tiles that stay walkable (no collision) when we build tile collision.
const FLOOR_TILE := Vector2i(7, 13)                ## Doors get replaced with this floor tile.
const FLOOR_TILES: Array[Vector2i] = [Vector2i(7, 13), Vector2i(8, 13), Vector2i(7, 14), Vector2i(8, 14)]
const DOOR_TILES_WIDE := 3                          ## Door opening width in tiles (matches corridor).
const WALL_CLEAR_DEPTH := 4                          ## Tiles cleared inward from the wall line (through the wall onto the interior floor, which is invisible).
const GATE_TILE := Vector2i(4, 26)                  ## Placeholder door tile; solid, so it seals when painted at the opening.

const DUMMY_SCENE := "res://actors/enemies/dummy/dummy.tscn"
const PICKUP_SCENE := "res://weapons/pickup/weapon_pickup.tscn"
const TREASURE_POOL := [
	"res://weapons/data/gravedigger.tres",
	"res://weapons/data/wisp.tres",
	"res://weapons/data/bone_railbolt.tres",
]

## Mirrors DungeonGenerator.RoomType so a scene can declare its pool in the Inspector
## without depending on the generator being loaded.
enum Category { START, COMBAT, TREASURE, SHOP, BOSS }

@export var category: Category = Category.COMBAT
@export var room_size := Vector2(520, 360)
## Perimeter walls always collide; when off (default) they draw nothing, so the
## room's floor tiles alone show where the room ends. Turn on for a solid fill.
@export var draw_walls := false

@export_group("Door tiles")
## Tileset the door strips are painted from (defaults to the shared dungeon tileset).
@export var door_tileset: TileSet
@export var door_source_id := 0
@export var door_tile := Vector2i(1, 1)   ## Placeholder door tile (any tile for now).

var type: int = DungeonGenerator.RoomType.COMBAT
var is_cleared := true

var _half := Vector2.ZERO
var _exits: Array[Dictionary] = []       ## Stable list: {"pos": Vector2, "dir": Vector2i}.
var _used_exits: Array[int] = []
var _walls_body: StaticBody2D
var _barriers: Array = []                ## Each: {"shape": CollisionShape2D, "tiles": TileMapLayer}.
var _spawn_points: Array[Vector2] = []
var _activated := false
var _alive_enemies := 0
var _configured := false
var _shroud: Polygon2D            ## Dark fog covering the room until first entered.
var is_discovered := false        ## True once the player has entered (fog lifted).
var _tilemap_collision := false   ## True when an authored tilemap supplies wall collision.
var _gate_map: TileMapLayer       ## The tilemap doors are painted onto (tiled rooms).
var _gates: Array = []            ## Per used door: {"cells": Array[Vector2i], "tiles": Array[Vector2i]}.


func _ready() -> void:
	_half = room_size * 0.5
	_exits = _collect_exits()
	if not _configured:
		# Running the scene standalone (editor preview / direct play): show every
		# authored door open so the room is at least walkable and testable on its own.
		type = category
		for i in _exits.size():
			_used_exits.append(i)
	_build()


## Called by the Dungeon BEFORE add_child: which authored exits (indices into
## get_exits()) the generator connected, and the assigned room type.
func configure(room_type: int, used_exit_indices: Array) -> void:
	type = room_type
	_used_exits = []
	for i in used_exit_indices:
		_used_exits.append(int(i))
	_configured = true


func _build() -> void:
	is_cleared = type != DungeonGenerator.RoomType.COMBAT and type != DungeonGenerator.RoomType.BOSS
	_tilemap_collision = _prepare_tilemap_collision()
	_build_walls()
	_build_interior_detector()
	_collect_spawn_points()
	_build_shroud()


## If the room authored a TileMapLayer, make the tiles carry the collision: every
## non-floor tile becomes solid (World layer) and each used door is carved back to
## floor so it stays walkable. The auto-built perimeter is then skipped — the room
## is enclosed by its own painted walls. Returns true when a tilemap took over.
func _prepare_tilemap_collision() -> bool:
	var tml := _find_floor_map()
	if tml == null:
		return false
	_align_tilemap(tml)
	_setup_tile_collision(tml.tile_set)
	_punch_doors(tml)
	tml.collision_enabled = true
	return true


## Nudge the tilemap so its cells land on the world 16px grid. Corridors are painted
## on that same world grid, so this makes a room's door opening line up exactly with
## the corridor — the player passes through cleanly instead of catching on a wall edge.
func _align_tilemap(tml: TileMapLayer) -> void:
	var cell := Vector2(tml.tile_set.tile_size)
	var world_origin := global_position + tml.position
	var snapped := Vector2(snappedf(world_origin.x, cell.x), snappedf(world_origin.y, cell.y))
	tml.position += snapped - world_origin


func _find_floor_map() -> TileMapLayer:
	for node in _all_descendants(self):
		if node is TileMapLayer and node.tile_set != null:
			return node
	return null


## Give every non-floor tile in the tileset a full-cell collision polygon on a
## World physics layer. Idempotent, so a tileset shared by several room instances
## is only wired up once.
func _setup_tile_collision(ts: TileSet) -> void:
	if ts.get_physics_layers_count() == 0:
		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(0, 1)   # World
	var half := Vector2(ts.tile_size) * 0.5
	var poly := PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	for si in ts.get_source_count():
		var src := ts.get_source(ts.get_source_id(si)) as TileSetAtlasSource
		if src == null:
			continue
		for ti in src.get_tiles_count():
			var coords := src.get_tile_id(ti)
			if coords in FLOOR_TILES:
				continue
			var td := src.get_tile_data(coords, 0)
			if td and td.get_collision_polygons_count(0) == 0:
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, poly)


## Carve every used door open on the room's own tilemap (so the opening, its
## collision, and its lock-gate all share one grid — no misaligned overlay). The
## opening is DOOR_TILES_WIDE tiles across and cleared through the wall only; a
## single row of gate cells at the wall line is recorded so the door can be
## sealed/reopened later by repainting those cells.
func _punch_doors(tml: TileMapLayer) -> void:
	_gate_map = tml
	_gates.clear()
	var half := DOOR_TILES_WIDE / 2
	for i in _used_exits:
		var door: Dictionary = _exits[i]
		var c := tml.local_to_map(door["pos"] - tml.position)
		var dir: Vector2i = door["dir"]
		var along := Vector2i(1, 0) if dir.y != 0 else Vector2i(0, 1)
		var inward := -dir   # toward the room centre (dir points outward)
		# A 3-tile opening, world-aligned to the corridor. Carve only through the
		# wall (a tile outside it, then inward WALL_CLEAR_DEPTH) so it does NOT gouge
		# a deep channel into the room.
		for a in range(-half, half + 1):
			for d in range(-1, WALL_CLEAR_DEPTH + 1):
				tml.set_cell(c + along * a + inward * d, 0, FLOOR_TILE)
		# 3-tile gate on the wall line (one placeholder tile), painted solid on lock.
		var cells: Array[Vector2i] = []
		for a in range(-half, half + 1):
			cells.append(c + along * a)
		_gates.append({"cells": cells})


## Cover the whole room (interior + walls) with near-black fog so unentered rooms
## read as dark, Enter-the-Gungeon style. The start room begins revealed since the
## player spawns inside it. Lifted on first entry by _reveal().
func _build_shroud() -> void:
	if type == DungeonGenerator.RoomType.START:
		is_discovered = true
		return
	var half := _half + Vector2(WALL_THICKNESS, WALL_THICKNESS) * 1.5
	_shroud = Polygon2D.new()
	_shroud.name = "Shroud"
	_shroud.color = SHROUD_COLOR
	_shroud.z_index = SHROUD_Z
	_shroud.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	add_child(_shroud)


## Fade the fog out the first time the player steps into the room.
func _reveal() -> void:
	if is_discovered:
		return
	is_discovered = true
	if is_instance_valid(_shroud):
		var tween := create_tween()
		tween.tween_property(_shroud, "modulate:a", 0.0, 0.3)
		tween.tween_callback(_shroud.queue_free)
		_shroud = null


# --- Queried by the generator (via a throwaway instance) ----------------------

## The room's doors as {"pos": Vector2 (local), "dir": Vector2i}, in a stable order.
func get_exits() -> Array[Dictionary]:
	if _exits.is_empty():
		_exits = _collect_exits()
	return _exits


func get_room_size() -> Vector2:
	return room_size


func _collect_exits() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var doors := get_node_or_null("Doors")
	var source: Array = doors.get_children() if doors else _all_descendants(self)
	for node in source:
		if node is DoorAnchor:
			# Snap doors to the 16px tile grid. Corridor lengths are multiples of 16
			# and rooms grow from the origin, so grid-aligned doors keep every door
			# position on the grid — the 2-tile opening and 2-tile corridor line up.
			found.append({"pos": node.position.snapped(Vector2(16, 16)), "dir": node.dir_vec()})
	return found


func _all_descendants(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_all_descendants(child))
	return out


# --- Perimeter geometry -------------------------------------------------------

func _build_walls() -> void:
	_walls_body = StaticBody2D.new()
	_walls_body.name = "Walls"
	add_child(_walls_body)
	for dir in DIRECTIONS:
		_build_side(dir)


## Build one wall side as segments, leaving a gap (+ barrier) at each USED door on
## that side. Doors may sit anywhere along the edge, so we sort the gaps and fill
## the ranges between them.
func _build_side(dir: Vector2i) -> void:
	var horizontal := dir.y != 0
	var axis_half: float = _half.x if horizontal else _half.y
	# Along-edge centres of the used doors on this side.
	var gaps: Array[float] = []
	for i in _exits.size():
		if i in _used_exits and _exits[i]["dir"] == dir:
			var p: Vector2 = _exits[i]["pos"]
			gaps.append(p.x if horizontal else p.y)
	gaps.sort()

	var cursor := -axis_half
	for centre in gaps:
		var g_start: float = clampf(centre - DOOR_WIDTH * 0.5, -axis_half, axis_half)
		var g_end: float = clampf(centre + DOOR_WIDTH * 0.5, -axis_half, axis_half)
		# Tiled rooms build both the wall spans AND the door gates from tiles, so
		# skip the code-drawn segment and StaticBody barrier here.
		if not _tilemap_collision:
			if g_start > cursor:
				_add_edge_segment(dir, cursor, g_start)
			_add_barrier_on(dir, centre)
		cursor = maxf(cursor, g_end)
	if cursor < axis_half and not _tilemap_collision:
		_add_edge_segment(dir, cursor, axis_half)


## Add a wall segment along `dir`'s edge spanning [from, to] in the edge axis.
func _add_edge_segment(dir: Vector2i, from: float, to: float) -> void:
	var length := to - from
	if length <= 0.01:
		return
	var mid := (from + to) * 0.5
	if dir.y != 0:  # top/bottom edge
		_add_wall(Vector2(mid, _half.y * dir.y), Vector2(length, WALL_THICKNESS))
	else:           # left/right edge
		_add_wall(Vector2(_half.x * dir.x, mid), Vector2(WALL_THICKNESS, length))


## At a used door: a collision barrier (open until the room locks) plus a strip of
## door tiles filling the opening, so doors read as tiles rather than a coloured bar.
func _add_barrier_on(dir: Vector2i, centre: float) -> void:
	var horizontal := dir.y != 0
	var center := Vector2(centre, _half.y * dir.y) if horizontal else Vector2(_half.x * dir.x, centre)
	var size := Vector2(DOOR_WIDTH, WALL_THICKNESS) if horizontal else Vector2(WALL_THICKNESS, DOOR_WIDTH)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = center
	shape.disabled = true          # open until locked
	_walls_body.add_child(shape)

	var tiles := _add_door_tiles(dir, centre)
	_barriers.append({"shape": shape, "tiles": tiles})


## Paint a strip of door tiles across one door opening on its own TileMapLayer,
## placed exactly at the gap so it lines up regardless of the room's tile phase.
func _add_door_tiles(dir: Vector2i, centre: float) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = "DoorTiles"
	layer.add_to_group(&"door_tiles")
	layer.tile_set = _door_tileset()
	var ts: Vector2i = layer.tile_set.tile_size
	var span := int(round(DOOR_WIDTH / ts.x))   # tiles across the opening
	if dir.y != 0:  # horizontal wall (top/bottom edge)
		layer.position = Vector2(centre - DOOR_WIDTH * 0.5, _half.y * dir.y - ts.y * 0.5)
		for c in span:
			layer.set_cell(Vector2i(c, 0), door_source_id, door_tile)
	else:           # vertical wall (left/right edge)
		layer.position = Vector2(_half.x * dir.x - ts.x * 0.5, centre - DOOR_WIDTH * 0.5)
		for c in span:
			layer.set_cell(Vector2i(0, c), door_source_id, door_tile)
	add_child(layer)
	return layer


func _door_tileset() -> TileSet:
	if door_tileset == null:
		door_tileset = load(DEFAULT_TILESET_PATH)
	return door_tileset


func _add_wall(center: Vector2, size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = center
	_walls_body.add_child(shape)
	if draw_walls:
		add_child(_make_rect_visual(center, size, Color(0.16, 0.14, 0.2)))


func _make_rect_visual(center: Vector2, size: Vector2, color: Color) -> Polygon2D:
	var half := size * 0.5
	var poly := Polygon2D.new()
	poly.color = color
	poly.polygon = PackedVector2Array([
		center + Vector2(-half.x, -half.y), center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y), center + Vector2(-half.x, half.y),
	])
	return poly


func _build_interior_detector() -> void:
	var area := Area2D.new()
	area.name = "Interior"
	area.collision_layer = 0
	area.collision_mask = 2  # PlayerBody
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = (room_size - Vector2(WALL_THICKNESS * 4, WALL_THICKNESS * 4)).max(Vector2(40, 40))
	shape.shape = rect
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


## Prefer authored SpawnPoints markers; fall back to a few random interior points.
func _collect_spawn_points() -> void:
	var holder := get_node_or_null("SpawnPoints")
	if holder:
		for child in holder.get_children():
			if child is Marker2D:
				_spawn_points.append(child.position)
	if _spawn_points.is_empty():
		var margin := 90.0
		for i in 4:
			_spawn_points.append(Vector2(
				RNG.randf_range(-_half.x + margin, _half.x - margin),
				RNG.randf_range(-_half.y + margin, _half.y - margin),
			))


# --- Encounter flow (unchanged behaviour from the grid version) ---------------

func _on_body_entered(body: Node2D) -> void:
	if not (body is Player):
		return
	_reveal()
	EventBus.room_entered.emit(self)
	if _activated:
		return
	_activated = true
	# Deferred: this runs inside body_entered (physics flush); spawning enemy/pickup
	# Area2Ds and toggling barrier collision touch the physics server.
	match type:
		DungeonGenerator.RoomType.COMBAT, DungeonGenerator.RoomType.BOSS:
			_begin_encounter.call_deferred()
		DungeonGenerator.RoomType.TREASURE:
			_spawn_treasure.call_deferred()


func _begin_encounter() -> void:
	var is_boss := type == DungeonGenerator.RoomType.BOSS
	var count := 1 if is_boss else RNG.randi_range(2, 4)
	for i in count:
		var enemy: Node2D = load(DUMMY_SCENE).instantiate()
		enemy.position = _spawn_points[i % _spawn_points.size()]
		if is_boss:
			enemy.scale = Vector2(2.2, 2.2)
			enemy.get_node("Health").max_health = 220.0
		add_child(enemy)
		enemy.get_node("Health").died.connect(_on_enemy_died)
		_alive_enemies += 1

	if _alive_enemies == 0:
		_clear_room()
	else:
		_set_doors_locked(true)


func _on_enemy_died() -> void:
	_alive_enemies -= 1
	if _alive_enemies <= 0:
		_clear_room()


func _clear_room() -> void:
	is_cleared = true
	_set_doors_locked(false)
	EventBus.room_cleared.emit(self)


func _spawn_treasure() -> void:
	var pickup: Node2D = load(PICKUP_SCENE).instantiate()
	pickup.weapon_data = load(RNG.pick(TREASURE_POOL))
	add_child(pickup)


func _set_doors_locked(locked: bool) -> void:
	# Tiled rooms: seal each door by painting the gate cells solid (or clearing them
	# back to floor). Same tilemap the walls live on, so it lines up exactly.
	if _tilemap_collision:
		for gate in _gates:
			for cell in gate["cells"]:
				_gate_map.set_cell(cell, 0, GATE_TILE if locked else FLOOR_TILE)
		return
	for barrier in _barriers:
		barrier["shape"].set_deferred("disabled", not locked)
		barrier["tiles"].modulate = DOOR_LOCKED_TINT if locked else Color.WHITE
