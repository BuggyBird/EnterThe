class_name HubArea
extends Node2D
## The spawn area ("the Breach", Enter-the-Gungeon style): every session starts
## here. A safe, warmly lit stone chamber built from the shared dungeon tileset;
## walking into the big dimensional portal resets run state and loads a fresh
## dungeon floor. Dying in the dungeon brings the player back here.
##
## Fully code-built like the corridors: floor motif + wall art ring + collision,
## reusing Dungeon's static wall helpers so the hub matches the dungeon's look.

const CELL := 16.0
const HALF_TILES := Vector2i(13, 7)          ## Interior half-size in tiles (26x14).
## Warmer and brighter than the dungeon's darkness — the hub reads as safe.
const AMBIENT := Color(0.5, 0.47, 0.55)
## Same floor motif the rooms and corridors tile (2x2 block at (7,13)).
const FLOOR_ORIGIN := Vector2i(7, 13)
const FLOOR_PATTERN := Vector2i(2, 2)
const PORTAL_SCALE := 2.0                    ## Run portal is bigger than door portals.
const DUNGEON_SCENE := "res://procgen/dungeon.tscn"

@export var player_scene: PackedScene
@export var tileset: TileSet

var _started := false


func _ready() -> void:
	var ambience := CanvasModulate.new()
	ambience.name = "Ambience"
	ambience.color = AMBIENT
	add_child(ambience)

	var cells := _build_room()
	_spawn_player()
	_build_run_portal(cells)


## Rectangular chamber centred on the origin: floor motif inside, the rooms' wall
## art ring around it (tall faces on top, skirt below, columns at the sides), and
## invisible collision strips on the ring. Returns the floor cell set.
func _build_room() -> Dictionary:
	var cells := {}
	for cx in range(-HALF_TILES.x, HALF_TILES.x):
		for cy in range(-HALF_TILES.y, HALF_TILES.y):
			cells[Vector2i(cx, cy)] = true

	var floor_map := TileMapLayer.new()
	floor_map.name = "Floor"
	floor_map.tile_set = tileset
	for cell: Vector2i in cells:
		var atlas := FLOOR_ORIGIN + Vector2i(posmod(cell.x, FLOOR_PATTERN.x), posmod(cell.y, FLOOR_PATTERN.y))
		floor_map.set_cell(cell, 0, atlas)
	add_child(floor_map)

	var walls := {}
	for cell: Vector2i in cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var n := cell + Vector2i(dx, dy)
				if not cells.has(n):
					walls[n] = true

	var wall_map := TileMapLayer.new()
	wall_map.name = "Walls"
	wall_map.tile_set = tileset
	for cell: Vector2i in walls:
		var atlas := Dungeon.wall_tile_for(cell, cells)
		wall_map.set_cell(cell, 0, atlas)
		var above := cell + Vector2i.UP
		if atlas == Dungeon.WALL_ABOVE and not walls.has(above) and not cells.has(above):
			wall_map.set_cell(above, 0, Dungeon.WALL_ABOVE_CAP)
	add_child(wall_map)

	var body := StaticBody2D.new()
	for strip in Dungeon.merge_cell_rows(walls):
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = strip.size
		shape.shape = rect
		shape.position = strip.get_center()
		body.add_child(shape)
	add_child(body)
	return cells


func _spawn_player() -> void:
	var player: Node2D = player_scene.instantiate()
	player.position = Vector2(-HALF_TILES.x * CELL + 64.0, 0.0)
	add_child(player)


## The big dimensional portal on the east wall: step in to start the run. Uses the
## same animated sheet as the door portals, scaled up, with a small prompt above.
func _build_run_portal(cells: Dictionary) -> void:
	var frames := RoomDef.portal_frames()
	if frames == null:
		return
	var root := Node2D.new()
	root.name = "RunPortal"
	root.position = Vector2((HALF_TILES.x - 2) * CELL - 8.0, 0.0)
	add_child(root)

	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * PORTAL_SCALE
	root.add_child(sprite)
	sprite.play(&"swirl")

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2   # PlayerBody
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24.0, 56.0)
	shape.shape = rect
	area.add_child(shape)
	root.add_child(area)
	area.body_entered.connect(_on_portal_entered)

	var prompt := Label.new()
	prompt.text = "START RUN"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 8)
	prompt.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	prompt.custom_minimum_size = Vector2(80.0, 0.0)
	prompt.position = root.position + Vector2(-40.0, -52.0)
	add_child(prompt)


## Into the underhalls: wipe the previous run's upgrades/XP and load a fresh
## floor. Deferred — body_entered fires during the physics flush.
func _on_portal_entered(body: Node2D) -> void:
	if _started or not (body is Player):
		return
	_started = true
	Upgrades.reset()
	get_tree().change_scene_to_file.call_deferred(DUNGEON_SCENE)
