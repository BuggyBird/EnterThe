extends Node
## Verifies the inventory/map + fog-of-war feature end to end against the REAL
## dungeon scene:
##   - EventBus.map_generated fires with room + corridor data.
##   - Non-start rooms start invisible (fog of war: not rendered until entered);
##     the start room is visible (the player spawns in it, so it begins
##     revealed / is_discovered).
##   - Owned-item accessors used by the inventory screen return sane data.
##   godot --headless --path <proj> res://tests/map_fog_test.tscn

var _frames := 0
var _dungeon: Node2D
var _map_rooms: Array = []
var _map_corridors: Array = []


func _ready() -> void:
	RNG.set_seed(1234)
	EventBus.map_generated.connect(_on_map_generated)
	_dungeon = load("res://procgen/dungeon.tscn").instantiate()
	add_child(_dungeon)


func _on_map_generated(rooms: Array, corridors: Array) -> void:
	_map_rooms = rooms
	_map_corridors = corridors


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 5:
		return

	# Map data broadcast for the minimap.
	var map_ok: bool = _map_rooms.size() >= 4 and _map_corridors.size() >= 3
	var rect_ok := true
	for room in _map_rooms:
		if not (room.has("node") and room.has("rect") and room.has("type")):
			rect_ok = false
		if (room["rect"] as Rect2).get_area() <= 0.0:
			rect_ok = false

	# Fog: start revealed (visible), other rooms hidden until entered.
	var start_revealed := false
	var others_shrouded := true
	var others := 0
	for child in _dungeon.get_children():
		if child is RoomDef:
			if child.type == DungeonGenerator.RoomType.START:
				start_revealed = child.is_discovered and child.visible
			else:
				others += 1
				if not child.is_discovered and child.visible:
					others_shrouded = false
	var fog_ok: bool = start_revealed and others_shrouded and others >= 1

	# Inventory accessors.
	var player: Player = null
	for child in _dungeon.get_children():
		if child is Player:
			player = child
	var inv_ok := false
	if player:
		var guns := player.weapon_holder.get_owned_weapons()
		inv_ok = guns.size() >= 1 and player.weapon_holder.get_equipped_index() >= 0
	# owned_upgrades starts empty (no upgrades taken) — must still be a typed array.
	var perks_ok: bool = Upgrades.owned_upgrades().size() == 0

	var ok: bool = map_ok and rect_ok and fog_ok and inv_ok and perks_ok
	print("MAP/FOG TEST: %s (rooms=%d corridors=%d start_revealed=%s others=%d shrouded=%s guns=%s perks_empty=%s)" % [
		"PASS" if ok else "FAIL", _map_rooms.size(), _map_corridors.size(),
		start_revealed, others, others_shrouded, inv_ok, perks_ok
	])
	get_tree().quit(0 if ok else 1)
