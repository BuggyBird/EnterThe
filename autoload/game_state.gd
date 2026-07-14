extends Node
## Persistent meta-progression (autoload singleton "GameState").
##
## Holds data that survives BETWEEN runs: currency, unlocks, statistics.
## Run-local state (current HP, held weapons, current floor) lives in the
## RunManager instead and is wiped each run. SaveManager (later milestone)
## serializes this object to `user://`.

# --- Meta currency & unlocks --------------------------------------------------
var soul_shards: int = 0                      ## Persistent currency spent on unlocks.
var unlocked_weapons: Array[StringName] = []  ## Weapon ids permanently unlocked.
var unlocked_items: Array[StringName] = []    ## Item ids permanently unlocked.

# --- Statistics ---------------------------------------------------------------
var runs_started: int = 0
var runs_won: int = 0
var deepest_floor: int = 0

# --- Run currency (gold) -------------------------------------------------------
## Gold collected THIS run: dropped as coins by dying enemies, spent to open
## chests. Run-local, so it is NOT serialized in to_dict; it lives here only
## until a RunManager exists (same story as Upgrades.reset()).
const COIN_SCENE_PATH := "res://items/coin/coin.tscn"
const COINS_PER_KILL_MIN := 2
const COINS_PER_KILL_MAX := 4

var gold: int = 0


func _ready() -> void:
	EventBus.entity_died.connect(_on_entity_died)


func add_gold(amount: int) -> void:
	gold += amount
	EventBus.gold_changed.emit(gold)


## Pay `amount` if the purse covers it. Returns whether the payment happened.
func try_spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	EventBus.gold_changed.emit(gold)
	return true


func reset_gold() -> void:
	gold = 0
	EventBus.gold_changed.emit(gold)


## Every slain enemy bursts into a few coins at its death spot. entity_died is
## emitted while the entity is still in the tree, so its position is valid.
func _on_entity_died(entity: Node) -> void:
	if entity is Player or not entity is Node2D:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	for i in RNG.randi_range(COINS_PER_KILL_MIN, COINS_PER_KILL_MAX):
		var coin: Node2D = load(COIN_SCENE_PATH).instantiate()
		scene.add_child(coin)
		coin.global_position = (entity as Node2D).global_position


func unlock_weapon(id: StringName) -> void:
	if id not in unlocked_weapons:
		unlocked_weapons.append(id)


func is_weapon_unlocked(id: StringName) -> bool:
	return id in unlocked_weapons


## Serialize meta-progression to a plain Dictionary for saving.
func to_dict() -> Dictionary:
	return {
		"soul_shards": soul_shards,
		"unlocked_weapons": unlocked_weapons,
		"unlocked_items": unlocked_items,
		"runs_started": runs_started,
		"runs_won": runs_won,
		"deepest_floor": deepest_floor,
	}


func from_dict(data: Dictionary) -> void:
	soul_shards = data.get("soul_shards", 0)
	unlocked_weapons.assign(data.get("unlocked_weapons", []))
	unlocked_items.assign(data.get("unlocked_items", []))
	runs_started = data.get("runs_started", 0)
	runs_won = data.get("runs_won", 0)
	deepest_floor = data.get("deepest_floor", 0)
