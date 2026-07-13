extends Node
## Headless automated test for the free-placement dungeon generator. Run as a SCENE:
##   godot --headless --path <proj> res://tests/dungeon_gen_test.tscn
##
## Uses hand-made fake Templates (no scenes needed — the generator is pure) and
## asserts every plan is well-formed across several seeds: one start, one boss, a
## healthy number of combat rooms, fully connected, no rooms overlapping, and the
## boss placed a few rooms deep from the start.

const UP := Vector2i.UP
const DOWN := Vector2i.DOWN
const LEFT := Vector2i.LEFT
const RIGHT := Vector2i.RIGHT


func _ready() -> void:
	var all_ok := true
	for seed_value in [1, 42, 1337, 90210, 555]:
		if not _check_seed(seed_value):
			all_ok = false
	print("DUNGEON GEN TEST: %s" % ["PASS" if all_ok else "FAIL"])
	get_tree().quit(0 if all_ok else 1)


func _check_seed(seed_value: int) -> bool:
	RNG.set_seed(seed_value)
	var generator := DungeonGenerator.new()
	var result := generator.generate(_pools(), 8)

	var starts := 0
	var bosses := 0
	var combats := 0
	var boss_index := -1
	for i in result.rooms.size():
		match result.rooms[i].type:
			DungeonGenerator.RoomType.START: starts += 1
			DungeonGenerator.RoomType.BOSS:
				bosses += 1
				boss_index = i
			DungeonGenerator.RoomType.COMBAT: combats += 1

	var distances := _bfs(result)
	var connected: bool = distances.size() == result.rooms.size()
	var no_overlap := _no_overlaps(result)
	var boss_deep: bool = boss_index >= 0 and int(distances.get(boss_index, 0)) >= 2

	var ok: bool = (
		result.ok
		and starts == 1
		and bosses == 1
		and combats >= 4
		and connected
		and no_overlap
		and boss_deep
	)
	if not ok:
		print("  seed %d FAILED: ok=%s rooms=%d start=%d boss=%d combat=%d connected=%s no_overlap=%s boss_deep=%s" % [
			seed_value, result.ok, result.rooms.size(), starts, bosses, combats,
			connected, no_overlap, boss_deep,
		])
	return ok


# --- Fixtures ------------------------------------------------------------------

func _pools() -> Dictionary:
	return {
		DungeonGenerator.RoomType.START:
			[_template(Vector2(420, 300), [RIGHT, DOWN, LEFT, UP])],
		DungeonGenerator.RoomType.COMBAT: [
			_template(Vector2(520, 360), [UP, DOWN, LEFT, RIGHT]),
			_template(Vector2(360, 520), [UP, DOWN, RIGHT]),
			_template(Vector2(640, 320), [LEFT, RIGHT, DOWN]),
		],
		DungeonGenerator.RoomType.TREASURE: [_template(Vector2(300, 240), [LEFT, RIGHT])],
		DungeonGenerator.RoomType.SHOP: [_template(Vector2(340, 260), [UP, DOWN])],
		DungeonGenerator.RoomType.BOSS: [_template(Vector2(760, 560), [UP, DOWN, LEFT, RIGHT])],
	}


## A fake template with a door centred on each named edge.
func _template(size: Vector2, dirs: Array) -> DungeonGenerator.Template:
	var tmpl := DungeonGenerator.Template.new()
	tmpl.size = size
	var half := size * 0.5
	for d in dirs:
		var pos := Vector2(d.x * half.x, d.y * half.y)
		tmpl.exits.append(DungeonGenerator.Exit.new(pos, d))
	return tmpl


# --- Checks --------------------------------------------------------------------

func _bfs(result: DungeonGenerator.Result) -> Dictionary:
	var distances := {0: 0}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for n in result.rooms[current].neighbours:
			if not distances.has(n):
				distances[n] = int(distances[current]) + 1
				queue.append(n)
	return distances


func _no_overlaps(result: DungeonGenerator.Result) -> bool:
	for i in result.rooms.size():
		var a := result.rooms[i].template.bounds_at(result.rooms[i].position)
		for j in range(i + 1, result.rooms.size()):
			var b := result.rooms[j].template.bounds_at(result.rooms[j].position)
			if a.intersects(b):
				return false
	return true
