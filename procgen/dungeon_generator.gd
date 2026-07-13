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
##      random combat template against it (aligned exit + a straight or L-shaped
##      corridor), rejecting placements that overlap anything already placed.
##   3. Graft the specials (BOSS, then TREASURE, then SHOP) onto the open doors
##      that are FARTHEST from start by room-graph distance.
##   4. Any door left open just stays solid wall.
## If a required piece (boss) can't be placed, the caller rerolls.

enum RoomType { START, COMBAT, TREASURE, SHOP, BOSS }

const DOOR_WIDTH := 48.0     ## 3 tiles. Must match RoomDef.DOOR_WIDTH and corridor width.
const ROOM_MARGIN := 28.0    ## Empty gap kept between separate rooms/corridors.
const PLACE_ATTEMPTS := 14   ## Candidate tries per open door before giving up on it.
## Straight-corridor lengths: multiples of 16 (tile grid). The minimum must stay
## comfortably >= RoomDef.OUTWARD_ERASE_DEPTH tiles so the door carve's outward
## erasing always lands under the corridor floor.
const CORRIDOR_LENGTHS: Array[float] = [96.0, 160.0, 224.0]
## L-corridor leg lengths: 8 mod 16. A door mouth sits on a grid LINE along its
## outward axis but on a cell CENTRE across it; a half-tile-offset leg is exactly
## what maps one convention onto the perpendicular leg's, keeping the elbow's
## channel rects on the tile grid.
const CORRIDOR_ELBOW_LENGTHS: Array[float] = [88.0, 152.0, 216.0]
const ELBOW_CHANCE := 0.6    ## Odds a corridor tries to turn once before running straight.


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


## An axis-aligned hallway between two door mouths: 2 points is a straight run,
## 3 points is an L-shape with one turn. Points and leg lengths are chosen so every
## channel rect corner lands on the 16px tile grid.
class Corridor:
	var points := PackedVector2Array()
	var width: float = DOOR_WIDTH

	var a: Vector2:   ## Mouth on the first room's wall.
		get:
			return points[0]
	var b: Vector2:   ## Mouth on the second room's wall.
		get:
			return points[points.size() - 1]

	## The walkable channel as one width-wide rect per segment. Ends that meet at an
	## elbow are extended by half a width so consecutive rects cover the corner
	## square between them; mouth ends stop exactly on the room's wall face.
	func rects() -> Array[Rect2]:
		var out: Array[Rect2] = []
		var half := width * 0.5
		for i in points.size() - 1:
			var p := points[i]
			var q := points[i + 1]
			var d := (q - p).normalized()
			if i > 0:
				p -= d * half
			if i < points.size() - 2:
				q += d * half
			var across := Vector2(absf(d.y), absf(d.x)) * half
			var lo := Vector2(minf(p.x, q.x), minf(p.y, q.y)) - across
			var hi := Vector2(maxf(p.x, q.x), maxf(p.y, q.y)) + across
			out.append(Rect2(lo, hi - lo))
		return out


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
		# Roll a corridor shape, falling back to the other one when the candidate
		# room has no door facing the right way for the rolled shape.
		var plan := {}
		if RNG.randf() < ELBOW_CHANCE:
			plan = _plan_elbow(a_world, da, tmpl)
			if plan.is_empty():
				plan = _plan_straight(a_world, da, tmpl)
		else:
			plan = _plan_straight(a_world, da, tmpl)
			if plan.is_empty():
				plan = _plan_elbow(a_world, da, tmpl)
		if plan.is_empty():
			continue
		var exit_b_index: int = plan["exit"]
		var points: PackedVector2Array = plan["points"]
		var pos: Vector2 = points[points.size() - 1] - tmpl.exits[exit_b_index].local_pos

		var corridor := Corridor.new()
		corridor.points = points
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


## Plan a straight corridor from mouth `a` along `da` to a door of `tmpl` facing
## back at it. Returns {"exit": int, "points": PackedVector2Array}, or {} when the
## template has no opposite-facing door.
func _plan_straight(a: Vector2, da: Vector2i, tmpl: Template) -> Dictionary:
	var exit_index := _pick_exit(tmpl, -da)
	if exit_index < 0:
		return {}
	var length: float = CORRIDOR_LENGTHS[RNG.randi_range(0, CORRIDOR_LENGTHS.size() - 1)]
	return {"exit": exit_index, "points": PackedVector2Array([a, a + Vector2(da) * length])}


## Plan an L-shaped corridor: leg 1 runs along `da`, then one turn onto a
## perpendicular leg ending at a door of `tmpl` that faces back along that leg.
## Both turn directions are tried in random order; {} when neither has a door.
func _plan_elbow(a: Vector2, da: Vector2i, tmpl: Template) -> Dictionary:
	var turns: Array[Vector2i] = [Vector2i(da.y, da.x), Vector2i(-da.y, -da.x)]
	if RNG.randf() < 0.5:
		turns.reverse()
	for d2 in turns:
		var exit_index := _pick_exit(tmpl, -d2)
		if exit_index < 0:
			continue
		var l1: float = CORRIDOR_ELBOW_LENGTHS[RNG.randi_range(0, CORRIDOR_ELBOW_LENGTHS.size() - 1)]
		var l2: float = CORRIDOR_ELBOW_LENGTHS[RNG.randi_range(0, CORRIDOR_ELBOW_LENGTHS.size() - 1)]
		var elbow := a + Vector2(da) * l1
		return {"exit": exit_index, "points": PackedVector2Array([a, elbow, elbow + Vector2(d2) * l2])}
	return {}


## A random exit of `tmpl` facing `dir`, or -1 if it has none.
func _pick_exit(tmpl: Template, dir: Vector2i) -> int:
	var matching: Array[int] = []
	for i in tmpl.exits.size():
		if tmpl.exits[i].dir == dir:
			matching.append(i)
	if matching.is_empty():
		return -1
	return matching[RNG.randi_range(0, matching.size() - 1)]


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
## The corridor is checked one channel rect (segment) at a time.
func _fits(result: Result, room_bounds: Rect2, corridor: Corridor, from_room: int) -> bool:
	var corridor_rects := corridor.rects()
	for i in result.rooms.size():
		var other := result.rooms[i].template.bounds_at(result.rooms[i].position)
		if room_bounds.grow(ROOM_MARGIN).intersects(other):
			return false
		# The corridor legitimately touches the room it sprouts from; ignore that one.
		if i == from_room:
			continue
		for cr in corridor_rects:
			if cr.grow(ROOM_MARGIN).intersects(other):
				return false
	for c in result.corridors:
		for existing in c.rects():
			if room_bounds.intersects(existing):
				return false
			for cr in corridor_rects:
				if cr.grow(ROOM_MARGIN * 0.5).intersects(existing):
					return false
	return true


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
