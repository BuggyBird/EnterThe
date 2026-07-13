class_name DoorAnchor
extends Marker2D
## Authoring marker you drop onto a handmade room's perimeter to declare where a
## door (and therefore a corridor) may attach. Its POSITION is the centre of the
## doorway on the wall; `direction` is the outward-facing side of the room.
##
## The generator connects two rooms by aligning an anchor on one room with an
## opposite-facing anchor on another, then carving a corridor between them. Anchors
## the generator doesn't use are simply left as solid wall (no gap).
##
## Convention: parent your anchors under a node named "Doors" and place them exactly
## on the room's edge (e.g. for a 520x360 room centred at origin, the right edge is
## x = +260). RoomDef builds the actual wall gap + lockable barrier at each USED one.

enum Dir { UP, DOWN, LEFT, RIGHT }

@export var direction: Dir = Dir.UP


## Outward normal of this door as a grid direction.
func dir_vec() -> Vector2i:
	match direction:
		Dir.UP: return Vector2i.UP
		Dir.DOWN: return Vector2i.DOWN
		Dir.LEFT: return Vector2i.LEFT
		Dir.RIGHT: return Vector2i.RIGHT
	return Vector2i.ZERO
