class_name DungeonGenerator
extends RefCounted
## Pure, seeded procedural floor planner in the style of Enter the Gungeon:
## hand-authored rooms of arbitrary size, placed freely (not on a fixed grid) and
## joined by procedurally routed corridors. No nodes, no scenes — it consumes plain
## Template descriptions (size + exits) and returns a placement plan (world
## positions + corridors). The Dungeon node turns that plan into real scenes.
##
## Keeping this pure keeps it fast, deterministic (all randomness via the RNG
## autoload) and unit-testable with hand-made fake templates.
##
## Algorithm (a simple "flow"):
##   1. Place a START room at the origin; its open doors seed the frontier.
##   2. Grow a body of COMBAT rooms: repeatedly pop an open door, try to fit a
##      random combat template against it (aligned exit + straight corridor),
##      rejecting placements that overlap anything already placed.
##   3. Graft the specials (BOSS, then TREASURE, then SHOP) onto the open doors
##      that are FARTHEST from start by room-graph distance.
##   4. Any door left open just stays solid wall.
## If a required piece (boss) can't be placed, the caller rerolls.

enum RoomType { START, COMBAT, TREASURE, SHOP, BOSS }

const DOOR_WIDTH := 48.0     ## 3 tiles. Must match RoomDef.DOOR_WIDTH and corridor width.
const ROOM_MARGIN := 28.0    ## Empty gap kept between separate rooms/corridors.
const PLACE_ATTEMPTS := 14   ## Candidate tries per open door before giving up on it.
const CORRIDOR_LENGTHS: Array[float] = [64.0, 112.0, 160.0]  ## Multiples of 16 (tile grid).


## One authored room's generation-relevant data. `scene` is carried opaquely (the
## planner never touches it) so the Dungeon can instance the right scene later.
class Exit:
	var local_pos: Vector2   ## Doorway centre, relative to the room's origin.
	var dir: Vector2i        ## Outward side.
	func _init(p: Vector2, d: Vector2i) -> void:
		local_pos = p
		dir = d


class Template:
	var scene                 ## PackedScene (opaque here).
	var type: int = RoomType.COMBAT
	var size: Vector2 = Vector2(512, 384)
	var exits: Array[Exit] = []

	func bounds_at(pos: Vector2) -> Rect2:
		return Rect2(pos - size * 0.5, size)


## A room committed to the plan.
class PlacedRoom:
	var template: Template
	var position: Vector2         ## World position of the room's centre.
	var type: int
	var used_exits: Array[int] = []   ## Indices into template.exits that are connected.
	var neighbours: Array[int] = []   ## Indices of adjacent PlacedRooms (for BFS).


## A straight, axis-aligned hallway between two door mouths.
class Corridor:
	var a: Vector2   ## Mouth on the first room's wall.
	var b: Vector2   ## Mouth on the second room's wall.
	var dir: Vector2i
	var width: float = DOOR_WIDTH


class Result:
	var rooms: Array[PlacedRoom] = []
	var corridors: Array[Corridor] = []
	var ok: bool = false


# --- Public --------------------------------------------------------------------

## Plan a floor. `pools` maps RoomType -> Array[Template]. Returns a Result whose
## `ok` is false if a start or boss couldn't be placed (caller should reroll).
func generate(pools: Dictionary, combat_count: int) -> Result:
	var result := Result.new()
	var start_pool: Array = pools.get(RoomType.START, [])
	if start_pool.is_empty():
		return result

	# 1. Start room at the origin.
	var start := PlacedRoom.new()
	start.template = start_pool[RNG.randi_range(0, start_pool.size() - 1)]
	start.position = Vector2.ZERO
	start.type = RoomType.START
	result.rooms.append(start)

	# The frontier holds open doors as {"r": room_index, "e": exit_index}.
	var frontier: Array = _open_doors_of(result, 0)

	# 2. Grow the combat body.
	var combat_pool: Array = pools.get(RoomType.COMBAT, [])
	var placed := 0
	while placed < combat_count and not frontier.is_empty():
		var pick := RNG.randi_range(0, frontier.size() - 1)
		var door: Dictionary = frontier[pick]
		frontier.remove_at(pick)
		var new_index := _try_attach(result, door, combat_pool, RoomType.COMBAT)
		if new_index >= 0:
			placed += 1
			frontier.append_array(_open_doors_of(result, new_index))

	# 3. Graft specials onto the farthest open doors.
	_attach_special(result, frontier, pools.get(RoomType.BOSS, []), RoomType.BOSS)
	_attach_special(result, frontier, pools.get(RoomType.TREASURE, []), RoomType.TREASURE)
	_attach_special(result, frontier, pools.get(RoomType.SHOP, []), RoomType.SHOP)

	result.ok = _has_type(result, RoomType.BOSS) and result.rooms.size() >= 3
	return result


# --- Placement -----------------------------------------------------------------

## Try to fit a room from `pool` against an open door. Returns the new room's index
## in result.rooms, or -1 if nothing fit (the door is then left as wall).
func _try_attach(result: Result, door: Dictionary, pool: Array, room_type: int) -> int:
	if pool.is_empty():
		return -1
	var room_a: PlacedRoom = result.rooms[door["r"]]
	var exit_a: Exit = room_a.template.exits[door["e"]]
	var a_world: Vector2 = room_a.position + exit_a.local_pos
	var da: Vector2i = exit_a.dir

	for _attempt in PLACE_ATTEMPTS:
		var tmpl: Template = pool[RNG.randi_range(0, pool.size() - 1)]
		# Candidate must offer a door facing back at us (-da) for a straight corridor.
		var opposite: Array[int] = []
		for i in tmpl.exits.size():
			if tmpl.exits[i].dir == -da:
				opposite.append(i)
		if opposite.is_empty():
			continue
		var exit_b_index: int = opposite[RNG.randi_range(0, opposite.size() - 1)]
		var exit_b: Exit = tmpl.exits[exit_b_index]
		var length: float = CORRIDOR_LENGTHS[RNG.randi_range(0, CORRIDOR_LENGTHS.size() - 1)]
		var b_world: Vector2 = a_world + Vector2(da) * length
		var pos: Vector2 = b_world - exit_b.local_pos

		var corridor := Corridor.new()
		corridor.a = a_world
		corridor.b = b_world
		corridor.dir = da
		if not _fits(result, tmpl.bounds_at(pos), corridor, door["r"]):
			continue

		# Commit.
		var placed := PlacedRoom.new()
		placed.template = tmpl
		placed.position = pos
		placed.type = room_type
		placed.used_exits = [exit_b_index]
		placed.neighbours = [door["r"]]
		var new_index := result.rooms.size()
		result.rooms.append(placed)
		room_a.used_exits.append(door["e"])
		room_a.neighbours.append(new_index)
		result.corridors.append(corridor)
		return new_index
	return -1


## Attach one special room to whichever open door sits farthest from start.
func _attach_special(result: Result, frontier: Array, pool: Array, room_type: int) -> void:
	if pool.is_empty() or frontier.is_empty():
		return
	var distances := _bfs_distances(result)
	# Farthest room first — specials feel best deep in the floor.
	var ordered := frontier.duplicate()
	ordered.sort_custom(func(x, y): return distances.get(x["r"], 0) > distances.get(y["r"], 0))
	for door in ordered:
		var new_index := _try_attach(result, door, pool, room_type)
		if new_index >= 0:
			frontier.erase(door)
			return


## Reject a candidate room/corridor that would overlap anything already placed.
func _fits(result: Result, room_bounds: Rect2, corridor: Corridor, from_room: int) -> bool:
	var corridor_rect := _corridor_rect(corridor)
	for i in result.rooms.size():
		var other := result.rooms[i].template.bounds_at(result.rooms[i].position)
		if room_bounds.grow(ROOM_MARGIN).intersects(other):
			return false
		# The corridor legitimately touches the room it sprouts from; ignore that one.
		if i != from_room and corridor_rect.grow(ROOM_MARGIN).intersects(other):
			return false
	for c in result.corridors:
		var existing := _corridor_rect(c)
		if room_bounds.intersects(existing):
			return false
		if corridor_rect.grow(ROOM_MARGIN * 0.5).intersects(existing):
			return false
	return true


func _corridor_rect(c: Corridor) -> Rect2:
	if c.dir.x != 0:  # horizontal
		var x0: float = min(c.a.x, c.b.x)
		return Rect2(x0, c.a.y - c.width * 0.5, absf(c.b.x - c.a.x), c.width)
	var y0: float = min(c.a.y, c.b.y)
	return Rect2(c.a.x - c.width * 0.5, y0, c.width, absf(c.b.y - c.a.y))


# --- Graph helpers -------------------------------------------------------------

## Open doors (unused exits) of a placed room, as frontier entries.
func _open_doors_of(result: Result, room_index: int) -> Array:
	var room: PlacedRoom = result.rooms[room_index]
	var open: Array = []
	for e in room.template.exits.size():
		if e not in room.used_exits:
			open.append({"r": room_index, "e": e})
	return open


## Room-graph distances (in rooms) from the start room.
func _bfs_distances(result: Result) -> Dictionary:
	var distances := {0: 0}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for n in result.rooms[current].neighbours:
			if not distances.has(n):
				distances[n] = distances[current] + 1
				queue.append(n)
	return distances


func _has_type(result: Result, room_type: int) -> bool:
	for room in result.rooms:
		if room.type == room_type:
			return true
	return false
