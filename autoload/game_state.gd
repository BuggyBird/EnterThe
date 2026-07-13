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
