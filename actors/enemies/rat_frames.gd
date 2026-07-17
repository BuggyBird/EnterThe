class_name RatFrames
extends RefCounted
## Slices the existing rat sheet (Assets/Mobs/rat base v2-Sheet.png, a 10x7
## grid of 64x64 cells) into the SpriteFrames all rat enemies share — built
## once and cached, same pattern as RoomDef.portal_frames(). The sheet already
## contains the animation art; this just cuts clean cycles out of it:
##   walk  — row 0, the full 10-frame scurry cycle
##   idle  — row 1, a small 3-frame breathing loop
##   shoot — row 4 frames 0..4: rear up, then lunge with the flash (no loop,
##           so it freezes on the lunge until the AI beat ends)

const SHEET_PATH := "res://Assets/Mobs/rat base v2-Sheet.png"
const CELL := Vector2i(64, 64)

## name -> [row, first_col, frame_count, fps, loops]
const ANIMS := {
	&"idle": [1, 0, 3, 4.0, true],
	&"walk": [0, 0, 10, 12.0, true],
	&"shoot": [4, 0, 5, 12.0, false],
}

static var _shared: SpriteFrames


static func frames() -> SpriteFrames:
	if _shared != null:
		return _shared
	var tex: Texture2D = load(SHEET_PATH)
	var out := SpriteFrames.new()
	for anim: StringName in ANIMS:
		var spec: Array = ANIMS[anim]
		out.add_animation(anim)
		out.set_animation_speed(anim, spec[3])
		out.set_animation_loop(anim, spec[4])
		if tex == null:
			continue
		for i in int(spec[2]):
			var cell := AtlasTexture.new()
			cell.atlas = tex
			cell.region = Rect2(
				Vector2((int(spec[1]) + i) * CELL.x, int(spec[0]) * CELL.y), Vector2(CELL))
			out.add_frame(anim, cell)
	_shared = out
	return _shared
