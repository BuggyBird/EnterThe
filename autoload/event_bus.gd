extends Node
## Global signal hub (autoload singleton "EventBus").
##
## Systems EMIT and LISTEN here instead of holding direct references to each
## other. This keeps the UI, audio, combat, and run logic decoupled: the HUD
## does not know the Player exists; it just reacts to `player_health_changed`.
##
## Guidelines:
##  - Keep signals coarse-grained and named in past tense ("something happened").
##  - Group by domain with a comment header.
##  - Prefer passing plain data / node references, not deep object graphs.

# --- Player -------------------------------------------------------------------
signal player_spawned(player: Node)
signal player_health_changed(current: float, maximum: float)
signal player_dodged()

# --- Combat -------------------------------------------------------------------
signal damage_dealt(target: Node, amount: float)
signal entity_died(entity: Node)

# --- Weapons ------------------------------------------------------------------
signal weapon_equipped(weapon_data: Resource)          ## Player switched to this weapon.
signal weapon_added(weapon_data: Resource)             ## A new weapon entered the inventory.
signal weapon_ammo_changed(clip: int, reserve: int)    ## Ammo of the equipped weapon changed.
signal weapon_fired()                                  ## A shot left the muzzle (drives recoil).

# --- Progression ----------------------------------------------------------------
signal player_xp_changed(xp: int, to_next: int, level: int)  ## XP pool after a gain.
signal player_leveled_up(new_level: int)                     ## Crossed a threshold.
signal upgrade_chosen(id: StringName)                        ## A card was picked.

# --- Run / flow ---------------------------------------------------------------
signal room_entered(room: Node)
signal room_cleared(room: Node)
signal floor_generated(floor_index: int)

# --- Map ----------------------------------------------------------------------
## A fresh floor's layout, for the minimap. `rooms` = Array of
## {"node": RoomDef, "rect": Rect2 (world), "type": int}; `corridors` = Array of
## {"a": Vector2, "b": Vector2} world-space door mouths.
signal map_generated(rooms: Array, corridors: Array)
