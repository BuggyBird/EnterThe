class_name Dungeon
extends Node2D
## Turns a DungeonGenerator plan into a real, walkable floor: instances the chosen
## hand-authored room scene at each planned world position, carves the corridors
## between them, and spawns the player in the start room. Press the regenerate key
## to roll a brand-new floor.
##
## Rooms come from a RoomCatalog (pools of .tscn scenes by type). The generator only
## sees each room's size + door anchors; this node owns everything scene-related.

const WALL_THICKNESS := 18.0
const DOOR_WIDTH := 48.0   ## 3 tiles. Must match DungeonGenerator.DOOR_WIDTH.
const MAX_ATTEMPTS := 24   ## Rerolls allowed before accepting a best-effort floor.

@export var catalog: RoomCatalog
@export var player_scene: PackedScene
@export var combat_count := 8
## Corridor side walls always collide; when off (default) they draw nothing, so the
## tiled corridor floor alone shows the hallway. Turn on for solid fill walls.
@export var draw_corridor_walls := false

@export_group("Background")
## Faint tile laid down everywhere behind the rooms so the void reads as dungeon.
@export var background_tile := Vector2i(2, 2)
@export var background_alpha := 0.6
@export var background_margin := 240.0   ## How far the backdrop extends past the rooms.

@export_group("Corridor floor tiles")
## Assign the shared dungeon TileSet to texture corridor floors like the rooms.
## Leave null to fall back to a flat placeholder floor.
@export var corridor_tileset: TileSet
@export var floor_source_id := 0
## Top-left atlas cell of the repeating floor motif (rooms use the 2x2 at (7,13)).
@export var floor_tile_origin := Vector2i(7, 13)
## Size of the repeating floor motif in tiles (rooms tile a 2x2 block).
@export var floor_pattern := Vector2i(2, 2)

var _spawned: Array[Node] = []   ## Everything we add per floor (freed on regen).
var _player: Node2D
var _map_rooms: Array = []       ## {"node", "rect", "type"} per room, for the minimap.
var _map_corridors: Array = []   ## {"a", "b"} world door-mouths, for the minimap.


func _ready() -> void:
	generate()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("regenerate"):
		generate()


## Build a fresh floor from scratch (new random seed each time).
func generate() -> void:
	_clear_floor()
	RNG.randomize_seed()
	if catalog == null:
		push_error("Dungeon: no RoomCatalog assigned.")
		return

	var pools := _build_templates()
	var generator := DungeonGenerator.new()
	var result: DungeonGenerator.Result = null
	for _attempt in MAX_ATTEMPTS:
		result = generator.generate(pools, combat_count)
		if result.ok:
			break
	if result == null:
		return
	if not result.ok:
		push_warning("Dungeon: accepted a best-effort floor (missing required rooms).")

	_build_background(result)
	_build_rooms(result)
	_build_corridors(result)
	_spawn_player(result)
	EventBus.map_generated.emit(_map_rooms, _map_corridors)
	EventBus.floor_generated.emit(0)


## Probe each catalog scene once to extract its size + door anchors as pure data
## for the generator, then discard the probe. Returns RoomType -> Array[Template].
func _build_templates() -> Dictionary:
	var pools := {}
	for room_type in [DungeonGenerator.RoomType.START, DungeonGenerator.RoomType.COMBAT,
			DungeonGenerator.RoomType.TREASURE, DungeonGenerator.RoomType.SHOP,
			DungeonGenerator.RoomType.BOSS]:
		var templates: Array[DungeonGenerator.Template] = []
		for scene in catalog.pool_for(room_type):
			if scene == null:
				continue
			var probe: RoomDef = scene.instantiate()
			var tmpl := DungeonGenerator.Template.new()
			tmpl.scene = scene
			tmpl.type = room_type
			tmpl.size = probe.get_room_size()
			for exit_data in probe.get_exits():
				tmpl.exits.append(DungeonGenerator.Exit.new(exit_data["pos"], exit_data["dir"]))
			probe.free()
			templates.append(tmpl)
		pools[room_type] = templates
	return pools


## Lay a faint tile across the whole floor's footprint, behind everything, so the
## empty void between rooms reads as dungeon rather than flat clear-colour. Rooms
## and corridors draw their opaque floors on top; only the gaps show this backdrop.
func _build_background(result: DungeonGenerator.Result) -> void:
	if corridor_tileset == null:
		return
	var bounds := _floor_bounds(result)
	if bounds.size == Vector2.ZERO:
		return
	bounds = bounds.grow(background_margin)

	var tml := TileMapLayer.new()
	tml.name = "Background"
	tml.tile_set = corridor_tileset
	tml.collision_enabled = false
	tml.z_index = -100   # behind rooms/corridors (which sit at z 0)
	tml.modulate = Color(1.0, 1.0, 1.0, background_alpha)

	var cell: Vector2i = corridor_tileset.tile_size
	var c0 := Vector2i(floori(bounds.position.x / cell.x), floori(bounds.position.y / cell.y))
	var c1 := Vector2i(ceili(bounds.end.x / cell.x), ceili(bounds.end.y / cell.y))
	for cx in range(c0.x, c1.x):
		for cy in range(c0.y, c1.y):
			tml.set_cell(Vector2i(cx, cy), 0, background_tile)

	add_child(tml)
	_spawned.append(tml)


## World-space AABB covering every room and corridor in the plan.
func _floor_bounds(result: DungeonGenerator.Result) -> Rect2:
	var bounds := Rect2()
	var first := true
	for placed in result.rooms:
		var r := Rect2(placed.position - placed.template.size * 0.5, placed.template.size)
		bounds = r if first else bounds.merge(r)
		first = false
	for corridor in result.corridors:
		var cr := Rect2(corridor.a, Vector2.ZERO).expand(corridor.b)
		bounds = cr if first else bounds.merge(cr)
		first = false
	return bounds


func _build_rooms(result: DungeonGenerator.Result) -> void:
	for placed in result.rooms:
		var room: RoomDef = placed.template.scene.instantiate()
		room.configure(placed.type, placed.used_exits)   # BEFORE add_child (fires _ready).
		room.position = placed.position
		add_child(room)
		_spawned.append(room)
		_map_rooms.append({
			"node": room,
			"rect": Rect2(placed.position - placed.template.size * 0.5, placed.template.size),
			"type": placed.type,
		})


func _build_corridors(result: DungeonGenerator.Result) -> void:
	for corridor in result.corridors:
		_build_corridor(corridor)
		_map_corridors.append({"a": corridor.a, "b": corridor.b})


## A straight hallway: a floor strip plus a solid wall down each long side.
func _build_corridor(corridor: DungeonGenerator.Corridor) -> void:
	var length := corridor.a.distance_to(corridor.b)
	if length < 1.0:
		return
	var mid := (corridor.a + corridor.b) * 0.5
	var horizontal := corridor.dir.x != 0
	# Extend the walls a touch past each mouth so the corners seal against room walls.
	var span := length + WALL_THICKNESS * 2.0

	var node := Node2D.new()
	node.name = "Corridor"
	node.add_to_group(&"corridors")
	add_child(node)
	_spawned.append(node)

	_build_corridor_floor(node, corridor, length, horizontal)

	var body := StaticBody2D.new()
	node.add_child(body)
	var offset := DOOR_WIDTH * 0.5 + WALL_THICKNESS * 0.5
	if horizontal:
		_corridor_wall(body, node, Vector2(mid.x, mid.y - offset), Vector2(span, WALL_THICKNESS))
		_corridor_wall(body, node, Vector2(mid.x, mid.y + offset), Vector2(span, WALL_THICKNESS))
	else:
		_corridor_wall(body, node, Vector2(mid.x - offset, mid.y), Vector2(WALL_THICKNESS, span))
		_corridor_wall(body, node, Vector2(mid.x + offset, mid.y), Vector2(WALL_THICKNESS, span))


func _corridor_wall(body: StaticBody2D, visual_parent: Node2D, center: Vector2, size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = center
	body.add_child(shape)
	if draw_corridor_walls:
		visual_parent.add_child(_rect_polygon(center, size, Color(0.16, 0.14, 0.2)))


## Floor the corridor: paint a TileMapLayer with the same repeating motif the rooms
## use so hallways read as part of the dungeon. Falls back to a flat fill if no
## tileset is assigned. Corridor spans are multiples of the tile size, so cells fit.
func _build_corridor_floor(parent: Node2D, corridor: DungeonGenerator.Corridor,
		length: float, horizontal: bool) -> void:
	var x0: float
	var y0: float
	var w: float
	var h: float
	if horizontal:
		x0 = minf(corridor.a.x, corridor.b.x)
		y0 = corridor.a.y - DOOR_WIDTH * 0.5
		w = length
		h = DOOR_WIDTH
	else:
		x0 = corridor.a.x - DOOR_WIDTH * 0.5
		y0 = minf(corridor.a.y, corridor.b.y)
		w = DOOR_WIDTH
		h = length

	if corridor_tileset == null:
		parent.add_child(_rect_polygon(Vector2(x0 + w * 0.5, y0 + h * 0.5),
			Vector2(w, h), Color(0.07, 0.06, 0.10)))
		return

	var tml := TileMapLayer.new()
	tml.tile_set = corridor_tileset
	tml.position = Vector2(x0, y0)
	var tile: Vector2i = corridor_tileset.tile_size
	var cols := int(round(w / tile.x))
	var rows := int(round(h / tile.y))
	var mod_x := maxi(1, floor_pattern.x)
	var mod_y := maxi(1, floor_pattern.y)
	for col in cols:
		for row in rows:
			var atlas := floor_tile_origin + Vector2i(col % mod_x, row % mod_y)
			tml.set_cell(Vector2i(col, row), floor_source_id, atlas)
	parent.add_child(tml)


func _rect_polygon(center: Vector2, size: Vector2, color: Color) -> Polygon2D:
	var half := size * 0.5
	var poly := Polygon2D.new()
	poly.color = color
	poly.polygon = PackedVector2Array([
		center + Vector2(-half.x, -half.y), center + Vector2(half.x, -half.y),
		center + Vector2(half.x, half.y), center + Vector2(-half.x, half.y),
	])
	return poly


func _spawn_player(result: DungeonGenerator.Result) -> void:
	var start_pos := Vector2.ZERO
	for placed in result.rooms:
		if placed.type == DungeonGenerator.RoomType.START:
			start_pos = placed.position
			break
	_player = player_scene.instantiate()
	_player.position = start_pos
	add_child(_player)


func _clear_floor() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	_map_rooms.clear()
	_map_corridors.clear()
	if is_instance_valid(_player):
		_player.queue_free()
	_player = null
	# Sweep up any in-flight projectiles (they parent to this scene root).
	for child in get_children():
		if child is Projectile:
			child.queue_free()
