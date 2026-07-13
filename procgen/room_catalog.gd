class_name RoomCatalog
extends Resource
## The pools of handmade room scenes the dungeon generator draws from, one array
## per room type. Author rooms as .tscn scenes (root script = RoomDef), then drag
## them into the matching array here in the Inspector. Adding content = author a
## scene + drop it in a pool; no code changes.
##
## Each pool needs at least one scene except SHOP (optional). START rooms should be
## small with 1-2 doors; BOSS rooms large with a single door.

@export var start: Array[PackedScene] = []
@export var combat: Array[PackedScene] = []
@export var treasure: Array[PackedScene] = []
@export var shop: Array[PackedScene] = []
@export var boss: Array[PackedScene] = []


## Return the scene pool for a DungeonGenerator.RoomType value.
func pool_for(room_type: int) -> Array[PackedScene]:
	match room_type:
		DungeonGenerator.RoomType.START: return start
		DungeonGenerator.RoomType.COMBAT: return combat
		DungeonGenerator.RoomType.TREASURE: return treasure
		DungeonGenerator.RoomType.SHOP: return shop
		DungeonGenerator.RoomType.BOSS: return boss
	return []
