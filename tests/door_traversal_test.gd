extends Node2D
## Regression: a player-sized body must be able to walk out through every used combat
## door across several seeds — guards against door openings that don't clear the wall
## or misalign with the corridor (the "stuck after clearing a room" bug). Each door is
## walked in three lanes — centred plus hugging each side of the 48px channel — so a
## collision lip from a door/corridor misalignment fails the test even when the
## centre lane happens to squeeze through.
##   godot --headless --path <proj> res://tests/door_traversal_test.tscn
const LANES: Array[float] = [-12.0, 0.0, 12.0]  ## Lateral offsets; ±12 + body radius 11 ~ touches the walls.
var _seeds := [1, 7, 13, 21]
var _si := 0
var _dungeon: Node2D
var _doors: Array = []
var _di := 0
var body: CharacterBody2D
var _f := 0
var _start := Vector2.ZERO
var _dir := Vector2.ZERO
var _fails := 0
var _total := 0
var _phase := "load"
func _ready() -> void:
	body = CharacterBody2D.new(); body.collision_layer = 2; body.collision_mask = 1
	var cs := CollisionShape2D.new(); var circ := CircleShape2D.new(); circ.radius = 11.0
	cs.shape = circ; body.add_child(cs); add_child(body); _load_seed()
func _load_seed() -> void:
	if _dungeon: _dungeon.queue_free()
	RNG.set_seed(_seeds[_si]); _dungeon = load("res://procgen/dungeon.tscn").instantiate(); add_child(_dungeon)
	_doors.clear(); _di = 0; _f = 0; _phase = "collect"
func _physics_process(_d: float) -> void:
	_f += 1
	if _phase == "collect":
		if _f < 3: return
		for c in _dungeon.get_children():
			if c is RoomDef and c.type == DungeonGenerator.RoomType.COMBAT:
				for ei in c._used_exits:
					var e: Dictionary = c._exits[ei]
					var dir := Vector2(e["dir"])
					var side := Vector2(-dir.y, dir.x)
					for lane in LANES:
						_doors.append({"pos": c.global_position + e["pos"] + side * lane, "dir": dir})
		_next_door()
	elif _phase == "move":
		if _f < 30: body.velocity = _dir * 240.0; body.move_and_slide()
		else:
			_total += 1
			if (body.global_position - _start).dot(_dir) <= 60.0: _fails += 1
			_next_door()
func _next_door() -> void:
	if _di >= _doors.size():
		_si += 1
		if _si >= _seeds.size():
			print("DOOR TRAVERSAL TEST: %s (%d/%d passable, %d stuck)" % ["PASS" if _fails == 0 else "FAIL", _total-_fails, _total, _fails])
			get_tree().quit(0 if _fails == 0 else 1)
		else: _load_seed()
		return
	var door: Dictionary = _doors[_di]; _di += 1
	_dir = door["dir"].normalized(); body.global_position = door["pos"] - _dir * 80.0; _start = body.global_position
	_f = 0; _phase = "move"
