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
const REVEAL_FADE_TIME := 0.9                      ## Seconds a room takes to fade in on discovery.

## Floor atlas tiles that stay walkable (no collision) when we build tile collision.
const FLOOR_TILE := Vector2i(7, 13)                ## Doors get replaced with this floor tile.
const FLOOR_TILES: Array[Vector2i] = [Vector2i(7, 13), Vector2i(8, 13), Vector2i(7, 14), Vector2i(8, 14)]
const DOOR_TILES_WIDE := 3                          ## Door opening width in tiles (matches corridor).
const WALL_CLEAR_DEPTH := 4                          ## Tiles floored inward from the door mouth (through the wall art onto the interior floor).
const OUTWARD_ERASE_DEPTH := 6                       ## Tiles erased outward from the mouth — clears wall face + any trim/skirt rows crossing the corridor.
const GATE_TILE := Vector2i(4, 26)                  ## Placeholder door tile; solid, so it seals when painted at the opening.

## Animated door portals: every connected doorway is gated by a swirling
## dimensional portal (3x2 sprite sheet). Base colour while passable, darkened
## while the room is locked, removed for good once the player steps through.
const PORTAL_TEXTURE_PATH := "res://Assets/Dimensional_Portal.png"
const PORTAL_FRAME := Vector2i(32, 32)             ## Cell size of the 3x2 sheet.
const PORTAL_FPS := 8.0
const PORTAL_LOCKED_TINT := Color(0.42, 0.36, 0.55)   ## Dimmed swirl while sealed.
const PORTAL_Z := 10                               ## Above floor + wall art.

const DUMMY_SCENE := "res://actors/enemies/dummy/dummy.tscn"
const MONSTER_SCENE := "res://actors/enemies/monster.tscn"
const MONSTER_POOL := [
	"res://resources/monsters/rat_gunner.tres",
	"res://resources/monsters/rat_plague.tres",
	"res://resources/monsters/rat_warlock.tres",
]
const PICKUP_SCENE := "res://weapons/pickup/weapon_pickup.tscn"
const CHEST_SCENE := "res://items/chest/chest.tscn"
const TREASURE_POOL := [
	#"res://weapons/data/gravedigger.tres",
	#"res://weapons/data/wisp.tres",
	"res://weapons/data/bone_railbolt.tres",
	"res://weapons/data/bonerang.tres",
	"res://weapons/data/whisperwind_longbow.tres",
	"res://weapons/data/soulwood_repeater.tres",
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
var is_discovered := false        ## True once the player has entered (room made visible).
var _tilemap_collision := false   ## True when an authored tilemap supplies wall collision.
var _gate_map: TileMapLayer       ## The tilemap doors are painted onto (tiled rooms).
var _gates: Array = []            ## Per used door: {"cells": Array[Vector2i], "tiles": Array[Vector2i]}.
var _portals: Array = []          ## Animated portal (Node2D) per not-yet-crossed used door.
var _doors_locked := false        ## Mirrors _set_doors_locked, guards portal removal.
var _last_death_pos := Vector2.ZERO   ## Room-local spot of the latest kill (boss rewards).


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
	_build_portals()
	_build_interior_detector()
	_collect_spawn_points()
	_hide_until_discovered()


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
## opening is DOOR_TILES_WIDE tiles across. Cells are addressed relative to the door
## MOUTH (the anchor's grid line, where the corridor starts) by sampling half a tile
## to either side, so the carve is exact on every wall regardless of which way
## local_to_map rounds. OUTWARD of the mouth every painted cell is erased through
## OUTWARD_ERASE_DEPTH — walls often carry extra trim/skirt rows outside the face,
## and any one of them left solid is an invisible bar across the corridor. INWARD
## the strip is painted floor through WALL_CLEAR_DEPTH so the doorway stays walkable
## through the tall wall art. A row of gate cells on the first INWARD cell (inside
## the room, never hidden under the corridor's own floor tiles) is recorded so the
## door can be sealed/reopened later by repainting those cells.
func _punch_doors(tml: TileMapLayer) -> void:
	_gate_map = tml
	_gates.clear()
	var half := DOOR_TILES_WIDE / 2
	for i in _used_exits:
		var door: Dictionary = _exits[i]
		var mouth: Vector2 = door["pos"] - tml.position
		var dir: Vector2i = door["dir"]
		var along := Vector2i(1, 0) if dir.y != 0 else Vector2i(0, 1)
		var cells: Array[Vector2i] = []
		for a in range(-half, half + 1):
			for k in OUTWARD_ERASE_DEPTH:
				tml.erase_cell(_cell_from_mouth(tml, mouth, dir, k) + along * a)
			for k in WALL_CLEAR_DEPTH:
				tml.set_cell(_cell_from_mouth(tml, mouth, -dir, k) + along * a, 0, FLOOR_TILE)
			cells.append(_cell_from_mouth(tml, mouth, -dir, 0) + along * a)
		_gates.append({"cells": cells})


## The k-th cell on `side`'s side of a door mouth (k = 0 is the cell touching the
## mouth line). Sampled at the cell's centre so grid-line positions never round to
## the wrong side.
func _cell_from_mouth(tml: TileMapLayer, mouth: Vector2, side: Vector2i, k: int) -> Vector2i:
	var cell := Vector2(tml.tile_set.tile_size)
	return tml.local_to_map(mouth + Vector2(side) * cell * (0.5 + float(k)))


## Fog of war: an unentered room simply isn't rendered — no overlay, the void
## around the floor shows through where the room will be. Visibility doesn't touch
## physics, so the walls still collide and the interior detector still fires the
## reveal. The start room begins revealed since the player spawns inside it.
func _hide_until_discovered() -> void:
	if type == DungeonGenerator.RoomType.START:
		is_discovered = true
		return
	visible = false
	modulate = Color(1.0, 1.0, 1.0, 0.0)   # Fade-in starting point for _reveal().


## Materialise the room out of the void the first time the player steps in: a
## slow, eased fade-in rather than an instant pop.
func _reveal() -> void:
	if is_discovered:
		return
	is_discovered = true
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, REVEAL_FADE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- Queried by the generator (via a throwaway instance) ----------------------

## The room's doors as {"pos": Vector2 (local), "dir": Vector2i}, in a stable order.
func get_exits() -> Array[Dictionary]:
	if _exits.is_empty():
		_exits = _collect_exits()
	return _exits


## The footprint the generator must reserve for this room: the declared room_size,
## grown to cover the painted tilemap when the art overshoots it. Hand-authored
## art regularly extends past room_size (tall walls, trim, decoration); if the
## generator only saw room_size, two rooms' art could overlap on screen even
## though their declared bounds kept their distance.
func get_room_size() -> Vector2:
	return room_size.max(_art_extents())


## The painted art's TIGHT bounding rect in room-local px (asymmetric — exactly
## where tiles exist, unlike the symmetrized get_room_size footprint). Falls back
## to the declared room_size rect for rooms without a tilemap, whose auto-built
## perimeter sits exactly on that edge. Used by the Dungeon to clip corridor
## walls: clipping by the symmetrized rect would eat corridor walls in the
## phantom band where the rect overshoots the real art.
func art_rect_local() -> Rect2:
	var tml := _find_floor_map()
	if tml == null:
		return Rect2(-_half, room_size)
	var used: Rect2i = tml.get_used_rect()
	if used.size == Vector2i.ZERO:
		return Rect2(-_half, room_size)
	var cell := Vector2(tml.tile_set.tile_size)
	return Rect2(Vector2(used.position) * cell + tml.position, Vector2(used.size) * cell)


## How far the room's painted tilemap actually reaches, measured symmetrically
## about the origin (the generator treats rooms as rects centred on it).
func _art_extents() -> Vector2:
	var tml := _find_floor_map()
	if tml == null:
		return Vector2.ZERO
	var used: Rect2i = tml.get_used_rect()
	if used.size == Vector2i.ZERO:
		return Vector2.ZERO
	var cell := Vector2(tml.tile_set.tile_size)
	var tl := Vector2(used.position) * cell + tml.position
	var br := tl + Vector2(used.size) * cell
	return Vector2(maxf(absf(tl.x), absf(br.x)), maxf(absf(tl.y), absf(br.y))) * 2.0


func _collect_exits() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var doors := get_node_or_null("Doors")
	var source: Array = doors.get_children() if doors else _all_descendants(self)
	for node in source:
		if node is DoorAnchor:
			found.append({"pos": _snap_door_pos(node.position, node.dir_vec()), "dir": node.dir_vec()})
	return found


## Snap a door anchor to the 16px tile grid, axis-aware. ALONG the wall the doorway
## centre must sit on a tile CENTRE (16k + 8): the opening is an odd number of tiles
## (DOOR_TILES_WIDE = 3) centred on this point, and only a centre-of-cell anchor makes
## its 48px span cover whole cells. On the OUTWARD axis it snaps to a grid line, so
## corridor spans stay multiples of 16 and room origins stay on the grid. Together
## this makes the carved opening, the corridor floor tiles and the corridor wall
## collision all cover the exact same 3 tile rows/columns — no half-tile seams, no
## collision lips to get stuck on.
func _snap_door_pos(p: Vector2, dir: Vector2i) -> Vector2:
	if dir.x != 0:  # left/right wall: x on a grid line, y on a cell centre
		return Vector2(snappedf(p.x, 16.0), snappedf(p.y - 8.0, 16.0) + 8.0)
	return Vector2(snappedf(p.x - 8.0, 16.0) + 8.0, snappedf(p.y, 16.0))


func _all_descendants(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_all_descendants(child))
	return out


# --- Door portals ---------------------------------------------------------------

## One swirling portal per connected doorway, centred on the door mouth and turned
## to span the opening (the art swirls in a tall ellipse, so top/bottom doors get
## it sideways). A thin Area2D across the mouth detects the player stepping
## through; a crossed portal has served its purpose and is removed for good.
func _build_portals() -> void:
	var frames := portal_frames()
	if frames == null:
		return
	for i in _used_exits:
		var door: Dictionary = _exits[i]
		var dir: Vector2i = door["dir"]
		var root := Node2D.new()
		root.name = "Portal"
		root.add_to_group(&"door_portals")
		root.position = door["pos"]
		root.rotation = PI * 0.5 if dir.y != 0 else 0.0
		root.z_index = PORTAL_Z

		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.scale = Vector2.ONE * (DOOR_WIDTH / float(PORTAL_FRAME.x))
		root.add_child(sprite)

		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 2   # PlayerBody
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		# Local +x is the door's through-axis (rotation maps it for every wall):
		# a thin slab across the opening, only crossable by actually passing it.
		rect.size = Vector2(12.0, DOOR_WIDTH)
		shape.shape = rect
		area.add_child(shape)
		root.add_child(area)
		area.body_entered.connect(_on_portal_crossed.bind(root))

		add_child(root)
		_portals.append(root)
		sprite.play(&"swirl")
		# De-sync neighbouring portals so they don't all swirl in lockstep.
		sprite.frame = RNG.randi_range(0, frames.get_frame_count(&"swirl") - 1)


## The portal sheet sliced into a looping animation, built once and shared by
## every room and by the hub's run portal (the texture is a 3x2 grid of
## PORTAL_FRAME-sized cells).
static var _portal_sprite_frames: SpriteFrames

static func portal_frames() -> SpriteFrames:
	if _portal_sprite_frames != null:
		return _portal_sprite_frames
	var tex: Texture2D = load(PORTAL_TEXTURE_PATH)
	if tex == null:
		return null
	var frames := SpriteFrames.new()
	frames.add_animation(&"swirl")
	frames.set_animation_speed(&"swirl", PORTAL_FPS)
	frames.set_animation_loop(&"swirl", true)
	for r in int(tex.get_height()) / PORTAL_FRAME.y:
		for c in int(tex.get_width()) / PORTAL_FRAME.x:
			var cell := AtlasTexture.new()
			cell.atlas = tex
			cell.region = Rect2(Vector2(c * PORTAL_FRAME.x, r * PORTAL_FRAME.y), Vector2(PORTAL_FRAME))
			frames.add_frame(&"swirl", cell)
	_portal_sprite_frames = frames
	return frames


## The player stepped through an open portal — remove it. While the room is locked
## the portals are sealed, and brushing one (e.g. from the corridor side against a
## locked door) must not consume it.
func _on_portal_crossed(body: Node2D, portal: Node2D) -> void:
	if _doors_locked or not (body is Player):
		return
	_portals.erase(portal)
	portal.queue_free()


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
		var enemy: Node2D = load(MONSTER_SCENE).instantiate()
		enemy.data = load(RNG.pick(MONSTER_POOL))
		enemy.position = _free_spawn_position(_spawn_points[i % _spawn_points.size()],
			30.0 if is_boss else 14.0)
		add_child(enemy)
		if is_boss:
			enemy.scale *= 2.2
			var hc: HealthComponent = enemy.get_node("Health")
			hc.max_health = 220.0
			hc.current_health = 220.0
		enemy.get_node("Health").died.connect(_on_enemy_died.bind(enemy))
		_alive_enemies += 1

	if _alive_enemies == 0:
		_clear_room()
	else:
		_set_doors_locked(true)


## Monsters are physics bodies (dummies weren't): a spawn point that overlaps
## a wall/pillar would depenetrate the body on its first physics frame — a
## visible "teleport". Probe the spot and step outward until it's clear.
func _free_spawn_position(local_pos: Vector2, radius: float) -> Vector2:
	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.collision_mask = 1  # World
	for ring in 6:
		var offsets: Array[Vector2] = [Vector2.ZERO]
		if ring > 0:
			offsets = []
			for k in 8:
				offsets.append(Vector2.RIGHT.rotated(TAU * k / 8.0) * (ring * 20.0))
		for off in offsets:
			params.transform = Transform2D(0.0, to_global(local_pos + off))
			if space.intersect_shape(params, 1).is_empty():
				return local_pos + off
	return local_pos


func _on_enemy_died(enemy: Node2D) -> void:
	# Remember where the last enemy fell: in a boss room that's the boss, and
	# its corpse marks where the rewards (weapon + stage portal) appear.
	_last_death_pos = enemy.position
	_alive_enemies -= 1
	if _alive_enemies <= 0:
		_clear_room()


func _clear_room() -> void:
	is_cleared = true
	_set_doors_locked(false)
	EventBus.room_cleared.emit(self)
	if type == DungeonGenerator.RoomType.BOSS:
		# Deferred: died fires mid-physics-flush, and both rewards are Area2Ds.
		_spawn_boss_rewards.call_deferred(_last_death_pos)


## The boss pays out twice at its death spot: a weapon (the kill reward) laid
## beside the corpse, and — unless this stage is the campaign's final one — the
## purple portal onward to the next stage in the story graph.
func _spawn_boss_rewards(at: Vector2) -> void:
	var pickup: Node2D = load(PICKUP_SCENE).instantiate()
	pickup.weapon_data = load(RNG.pick(TREASURE_POOL))
	pickup.position = at + Vector2(-44.0, 0.0)
	add_child(pickup)
	if Stages.current == null or not Stages.current.is_final:
		var portal := StagePortal.new()
		portal.position = at
		add_child(portal)


func _spawn_treasure() -> void:
	# A locked chest instead of loot in the open: the player pays gold (dropped
	# by enemies) to open it. Rarity rolls on the same weights as perks.
	var chest: Node2D = load(CHEST_SCENE).instantiate()
	chest.rarity = int(RNG.pick_weighted(range(Upgrades.RARITY_WEIGHTS.size()), Upgrades.RARITY_WEIGHTS))
	chest.loot = load(RNG.pick(TREASURE_POOL))
	add_child(chest)


func _set_doors_locked(locked: bool) -> void:
	_doors_locked = locked
	# The portals mirror the lock state: dimmed while the fight seals the room,
	# back to their base colour once it's cleared.
	for portal in _portals:
		if is_instance_valid(portal):
			portal.modulate = PORTAL_LOCKED_TINT if locked else Color.WHITE
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
