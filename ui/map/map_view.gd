class_name MapView
extends Control
## Draws the floor minimap: rooms coloured by type, the corridors between them,
## and a marker at the player's current position. Rooms the player has not yet
## entered are hidden (Enter-the-Gungeon style) — a neighbour of a discovered
## room shows only as a faint outline, hinting there's more to explore.
##
## Fed purely by data (world-space room rects + corridors) so it stays decoupled
## from the live dungeon nodes; it just fits that data into its rectangle.

const PADDING := 14.0            ## Inner margin (px) between the map and this control's edge.
const PLAYER_RADIUS := 4.0

## Per-type fill colours for discovered rooms.
const TYPE_COLORS := {
	DungeonGenerator.RoomType.START: Color(0.45, 0.8, 0.5),
	DungeonGenerator.RoomType.COMBAT: Color(0.42, 0.46, 0.62),
	DungeonGenerator.RoomType.TREASURE: Color(0.9, 0.76, 0.35),
	DungeonGenerator.RoomType.SHOP: Color(0.4, 0.72, 0.74),
	DungeonGenerator.RoomType.BOSS: Color(0.82, 0.35, 0.4),
}
const UNDISCOVERED_OUTLINE := Color(0.3, 0.3, 0.38, 0.6)
const CORRIDOR_COLOR := Color(0.5, 0.5, 0.6, 0.7)
const PLAYER_COLOR := Color(0.98, 0.95, 0.6)

var _rooms: Array = []           ## {"node", "rect", "type"} in world space.
var _corridors: Array = []       ## {"a", "b"} world-space door mouths.
var _discovered: Dictionary = {} ## RoomDef node -> true.
var _player: Node2D

var _bounds := Rect2()           ## Union of all room rects, in world space.


## Swap in a freshly generated floor; discovery resets to just the start room.
func set_floor(rooms: Array, corridors: Array) -> void:
	_rooms = rooms
	_corridors = corridors
	_discovered.clear()
	for room in _rooms:
		if room["type"] == DungeonGenerator.RoomType.START:
			_discovered[room["node"]] = true
	_recompute_bounds()
	queue_redraw()


func set_player(player: Node2D) -> void:
	_player = player
	queue_redraw()


## Mark a room the player entered as discovered (idempotent).
func discover(room: Node) -> void:
	if room in _discovered:
		return
	_discovered[room] = true
	queue_redraw()


func _process(_delta: float) -> void:
	# The player marker tracks live position while the map is on screen.
	if is_visible_in_tree() and is_instance_valid(_player):
		queue_redraw()


func _recompute_bounds() -> void:
	if _rooms.is_empty():
		_bounds = Rect2()
		return
	var b: Rect2 = _rooms[0]["rect"]
	for room in _rooms:
		b = b.merge(room["rect"])
	_bounds = b


func _draw() -> void:
	if _rooms.is_empty() or _bounds.size.x <= 0.0 or _bounds.size.y <= 0.0:
		return
	# Uniform fit of the world bounds into this control, preserving aspect ratio.
	var avail := size - Vector2(PADDING, PADDING) * 2.0
	var scale := minf(avail.x / _bounds.size.x, avail.y / _bounds.size.y)
	var drawn := _bounds.size * scale
	var origin := Vector2(PADDING, PADDING) + (avail - drawn) * 0.5

	# Corridors first (under rooms), only where they touch discovered territory.
	# Drawn segment by segment so L-shaped corridors render with their turn.
	for corridor in _corridors:
		if not _corridor_visible(corridor):
			continue
		var pts: PackedVector2Array = corridor.get("points",
			PackedVector2Array([corridor["a"], corridor["b"]]))
		for i in pts.size() - 1:
			draw_line(_to_local(pts[i], origin, scale),
				_to_local(pts[i + 1], origin, scale), CORRIDOR_COLOR, 2.0)

	# Rooms.
	for room in _rooms:
		var r := _rect_to_local(room["rect"], origin, scale)
		if _discovered.has(room["node"]):
			var col: Color = TYPE_COLORS.get(room["type"], Color.GRAY)
			draw_rect(r, col, true)
			draw_rect(r, col.lightened(0.25), false, 1.0)
		elif _is_adjacent_to_discovered(room):
			draw_rect(r, UNDISCOVERED_OUTLINE, false, 1.0)

	# Player marker.
	if is_instance_valid(_player):
		draw_circle(_to_local(_player.global_position, origin, scale), PLAYER_RADIUS, PLAYER_COLOR)


func _to_local(world: Vector2, origin: Vector2, scale: float) -> Vector2:
	return origin + (world - _bounds.position) * scale


func _rect_to_local(world_rect: Rect2, origin: Vector2, scale: float) -> Rect2:
	return Rect2(_to_local(world_rect.position, origin, scale), world_rect.size * scale)


## A corridor is drawn once either room it connects has been discovered.
func _corridor_visible(corridor: Dictionary) -> bool:
	return _room_discovered_at(corridor["a"]) or _room_discovered_at(corridor["b"])


func _room_discovered_at(world: Vector2) -> bool:
	for room in _rooms:
		if _discovered.has(room["node"]) and (room["rect"] as Rect2).grow(4.0).has_point(world):
			return true
	return false


## True if any corridor endpoint of this (undiscovered) room sits in a discovered
## room — i.e. it's a direct neighbour worth teasing as an outline.
func _is_adjacent_to_discovered(room: Dictionary) -> bool:
	var rect: Rect2 = (room["rect"] as Rect2).grow(4.0)
	for corridor in _corridors:
		var a_in: bool = rect.has_point(corridor["a"])
		var b_in: bool = rect.has_point(corridor["b"])
		if a_in and _room_discovered_at(corridor["b"]):
			return true
		if b_in and _room_discovered_at(corridor["a"]):
			return true
	return false
