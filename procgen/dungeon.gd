class_name Dungeon
extends Node2D
## Turns a DungeonGenerator plan into a real, walkable floor: instances the chosen
## hand-authored room scene at each planned world position, carves the corridors
## between them, and spawns the player in the start room. Press the regenerate key
## to roll a brand-new floor.
##
## Rooms come from a RoomCatalog (pools of .tscn scenes by type). The generator only
## sees each room's size + door anchors; this node owns everything scene-related.

const CELL := 16.0         ## Tile grid pitch (px); matches the dungeon tileset and RoomDef.
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

@export_group("Lighting")
## Global darkness laid over the whole floor via a CanvasModulate; the player's light
## (and any others) brighten areas back up. Raise toward white for a brighter dungeon,
## lower toward black for a pitch-dark one. UI lives on separate CanvasLayers, so only
## the world is dimmed.
@export var dark_ambient := Color(0.16, 0.15, 0.22)
var _canvas_modulate: CanvasModulate

@export_group("Corridor floor tiles")
## Assign the shared dungeon TileSet to texture corridor floors like the rooms.
## Leave null to fall back to a flat placeholder floor.
@export var corridor_tileset: TileSet
@export var floor_source_id := 0
## Top-left atlas cell of the repeating floor motif (rooms use the 2x2 at (7,13)).
@export var floor_tile_origin := Vector2i(7, 13)
## Size of the repeating floor motif in tiles (rooms tile a 2x2 block).
@export var floor_pattern := Vector2i(2, 2)

## Corridor wall art: the same directional tiles the hand-authored rooms paint,
## so hallways read as built walls instead of bare floor strips in the void.
## Names are from the FLOOR's point of view (WALL_ABOVE sits above the channel).
const WALL_ABOVE := Vector2i(3, 19)        ## Face row directly above the floor.
const WALL_ABOVE_CAP := Vector2i(11, 17)   ## Second row on top of the face (tall walls).
const WALL_BELOW := Vector2i(6, 4)         ## Skirt row below the floor.
const WALL_LEFT := Vector2i(3, 2)          ## Column left of the floor.
## Column right of the floor cycles three variants, like the rooms' right walls.
const WALL_RIGHT: Array[Vector2i] = [Vector2i(11, 21), Vector2i(11, 22), Vector2i(11, 23)]
const CORNER_TL := Vector2i(5, 1)          ## Outer corners (diagonal floor contact only).
const CORNER_TR := Vector2i(7, 1)
const CORNER_BL := Vector2i(5, 4)
const CORNER_BR := Vector2i(11, 16)

var _spawned: Array[Node] = []   ## Everything we add per floor (freed on regen).
var _player: Node2D
var _map_rooms: Array = []       ## {"node", "rect", "type"} per room, for the minimap.
var _map_corridors: Array = []   ## {"a", "b"} world door-mouths, for the minimap.


func _ready() -> void:
	_setup_darkness()
	# The boss portal advances the run: next StageDef, then a fresh floor. The
	# rebuild is deferred — the signal fires from a body_entered physics callback.
	EventBus.stage_portal_entered.connect(func() -> void:
		Stages.advance()
		generate.call_deferred())
	generate()


## Dim the whole world once (persists across regens — it's not part of _spawned).
## A CanvasModulate multiplies every CanvasItem on the default canvas by dark_ambient;
## the player's PointLight2D adds brightness back around the player.
func _setup_darkness() -> void:
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "Darkness"
	_canvas_modulate.color = dark_ambient
	add_child(_canvas_modulate)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("regenerate"):
		generate()


## Build a fresh floor from scratch (new random seed each time). The floor
## belongs to Stages.current; entering the boss portal advances the stage and
## calls this again, so every stage is built by the same path as the first.
func generate() -> void:
	if Stages.current == null:
		Stages.start_run()   # dungeon.tscn launched directly, without the hub
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
	EventBus.floor_generated.emit(Stages.current.stage_number)
	EventBus.stage_started.emit(Stages.current.display_name, Stages.current.stage_number)


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
		for cr in corridor.rects():
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
		var art_rect: Rect2 = room.art_rect_local()
		_map_rooms.append({
			"node": room,
			"rect": Rect2(placed.position - placed.template.size * 0.5, placed.template.size),
			"type": placed.type,
			# Tight bounds of the room's actual painted art (asymmetric), for
			# clipping corridor walls. The symmetrized "rect" overshoots offset
			# art on one side, and clipping by it would leave corridors unwalled
			# there — an open path into the void.
			"clip": Rect2(art_rect.position + placed.position, art_rect.size),
		})


func _build_corridors(result: DungeonGenerator.Result) -> void:
	for corridor in result.corridors:
		_build_corridor(corridor)
		_map_corridors.append({"a": corridor.a, "b": corridor.b, "points": corridor.points})


## A hallway, straight or L-shaped: floor across every channel rect, then walls
## derived from the floor cells. Working in whole grid cells keeps any corridor
## shape watertight and exactly aligned with the rooms' tilemaps.
func _build_corridor(corridor: DungeonGenerator.Corridor) -> void:
	var node := Node2D.new()
	node.name = "Corridor"
	node.add_to_group(&"corridors")
	add_child(node)
	_spawned.append(node)

	# The walkable channel as a set of world grid cells. Rects are grid-aligned by
	# construction (door mouths + leg lengths are chosen for it), and the elbow
	# square is shared by both legs' rects — the set union handles that for free.
	var cells := {}
	for rect in corridor.rects():
		var c0 := Vector2i(roundi(rect.position.x / CELL), roundi(rect.position.y / CELL))
		var c1 := Vector2i(roundi(rect.end.x / CELL), roundi(rect.end.y / CELL))
		for cx in range(c0.x, c1.x):
			for cy in range(c0.y, c1.y):
				cells[Vector2i(cx, cy)] = true

	_build_corridor_floor(node, corridor, cells)
	_build_corridor_walls(node, corridor, cells)


## Floor the channel cells: paint a TileMapLayer with the same repeating motif the
## rooms use so hallways read as part of the dungeon. Painted on WORLD grid cells
## (the layer stays at the origin) with the motif keyed to world-cell parity, so
## the pattern stays in phase with the rooms and across every corridor. Falls back
## to flat fills if no tileset is assigned.
func _build_corridor_floor(parent: Node2D, corridor: DungeonGenerator.Corridor,
		cells: Dictionary) -> void:
	if corridor_tileset == null:
		for rect in corridor.rects():
			parent.add_child(_rect_polygon(rect.get_center(), rect.size, Color(0.07, 0.06, 0.10)))
		return
	var tml := TileMapLayer.new()
	tml.tile_set = corridor_tileset
	var mod_x := maxi(1, floor_pattern.x)
	var mod_y := maxi(1, floor_pattern.y)
	for cell: Vector2i in cells:
		var atlas := floor_tile_origin + Vector2i(posmod(cell.x, mod_x), posmod(cell.y, mod_y))
		tml.set_cell(cell, floor_source_id, atlas)
	parent.add_child(tml)


## Solid collision hugging the channel: every cell that touches a floor cell (8-way,
## so outer elbow corners seal too) and is not itself floor becomes wall — except
## the opening in front of each door mouth, which stays clear so the player can pass
## into the rooms. Runs of wall cells merge into row strips to keep shape counts low.
## Walls collide but stay invisible unless draw_corridor_walls is on, same as before.
func _build_corridor_walls(node: Node2D, corridor: DungeonGenerator.Corridor,
		cells: Dictionary) -> void:
	# Cells just beyond each mouth (3 wide, matching the door opening, 2 deep) are
	# exempt from becoming wall: they're the doorway into the room.
	var open := {}
	var last := corridor.points.size() - 1
	for end_index in [0, last]:
		var mouth := corridor.points[end_index]
		var neighbour := corridor.points[1] if end_index == 0 else corridor.points[last - 1]
		var out_dir := (mouth - neighbour).normalized()   # points into the room
		var along := Vector2(absf(out_dir.y), absf(out_dir.x))
		for k in 2:
			for s in range(-1, 2):
				var p := mouth + out_dir * (CELL * (0.5 + k)) + along * (CELL * s)
				open[Vector2i(floori(p.x / CELL), floori(p.y / CELL))] = true

	var walls := {}
	for cell: Vector2i in cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var n := cell + Vector2i(dx, dy)
				# Cells inside a room's footprint are the room's responsibility —
				# rooms are watertight on their own. Corridor wall blocks in there
				# (flanking the doorway strip) are invisible snags: hugging the room
				# wall toward the door catches on them at the corner.
				if not cells.has(n) and not open.has(n) and not _inside_any_room(n):
					walls[n] = true
	if walls.is_empty():
		return
	_paint_corridor_walls(node, cells, walls)

	var body := StaticBody2D.new()
	node.add_child(body)
	for strip in merge_cell_rows(walls):
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = strip.size
		shape.shape = rect
		shape.position = strip.get_center()
		body.add_child(shape)
		if draw_corridor_walls:
			node.add_child(_rect_polygon(strip.get_center(), strip.size, Color(0.16, 0.14, 0.2)))


## Dress the corridor's wall ring in the rooms' wall art. Each wall cell picks its
## tile from where the channel floor sits relative to it (face above the floor,
## skirt below, columns at the sides, corner pieces on diagonal-only contact).
## Purely visual — collision stays on the invisible StaticBody strips — and painted
## on world grid cells so it lines up with the floor and the rooms. Walls above the
## channel also get a second cap row, matching the rooms' tall north walls.
func _paint_corridor_walls(parent: Node2D, cells: Dictionary, walls: Dictionary) -> void:
	if corridor_tileset == null:
		return
	var tml := TileMapLayer.new()
	tml.name = "WallTiles"
	tml.tile_set = corridor_tileset
	tml.collision_enabled = false
	for cell: Vector2i in walls:
		var atlas := wall_tile_for(cell, cells)
		tml.set_cell(cell, floor_source_id, atlas)
		# Tall wall: cap the face row, unless something else already owns that cell.
		var above := cell + Vector2i.UP
		if atlas == WALL_ABOVE and not cells.has(above) and not walls.has(above) \
				and not _inside_any_room(above):
			tml.set_cell(above, floor_source_id, WALL_ABOVE_CAP)
	parent.add_child(tml)


## Whether a world grid cell's centre lies within any placed room's painted art
## (the tight per-room "clip" rect — see _build_rooms). Inside it, the room's own
## tiles carry walls and collision; outside it, the corridor must enclose itself.
func _inside_any_room(cell: Vector2i) -> bool:
	var center := (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
	for room in _map_rooms:
		if (room["clip"] as Rect2).has_point(center):
			return true
	return false


## The art tile for one wall cell, from the direction of the adjacent floor.
## Orthogonal contact wins (faces/columns); diagonal-only contact means the cell
## is an outer corner. Static so the hub area can dress its walls the same way.
static func wall_tile_for(cell: Vector2i, floor_cells: Dictionary) -> Vector2i:
	if floor_cells.has(cell + Vector2i.DOWN):
		return WALL_ABOVE
	if floor_cells.has(cell + Vector2i.UP):
		return WALL_BELOW
	if floor_cells.has(cell + Vector2i.RIGHT):
		return WALL_LEFT
	if floor_cells.has(cell + Vector2i.LEFT):
		return WALL_RIGHT[posmod(cell.y, WALL_RIGHT.size())]
	if floor_cells.has(cell + Vector2i(1, 1)):
		return CORNER_TL
	if floor_cells.has(cell + Vector2i(-1, 1)):
		return CORNER_TR
	if floor_cells.has(cell + Vector2i(1, -1)):
		return CORNER_BL
	return CORNER_BR


## Merge a set of grid cells into one Rect2 (world px) per horizontal run.
## Static so the hub area can build its wall collision the same way.
static func merge_cell_rows(cell_set: Dictionary) -> Array[Rect2]:
	var keys: Array = cell_set.keys()
	keys.sort_custom(func(u: Vector2i, v: Vector2i) -> bool:
		return u.y < v.y or (u.y == v.y and u.x < v.x))
	var out: Array[Rect2] = []
	var run := Rect2()
	var prev := Vector2i(2147483647, 2147483647)
	for c: Vector2i in keys:
		if c.y == prev.y and c.x == prev.x + 1:
			run.size.x += CELL
		else:
			if run.size.x > 0:
				out.append(run)
			run = Rect2(c.x * CELL, c.y * CELL, CELL, CELL)
		prev = c
	if run.size.x > 0:
		out.append(run)
	return out


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
