class_name Torch
extends AnimatedSprite2D
## A 32x32 wall-mounted torch: animated flame sprite plus a small, DIM pool of
## warm light. Following the "simple 2D lighting" approach the dungeon already
## uses: the world sits under a dark CanvasModulate and many subtle MIX-blended
## gradient lights layer over it — so each torch stays faint and small, and
## neighbouring pools merge into soft, natural wall light instead of bright
## hotspots. RoomDef mounts these along the rooms' walls automatically.

const SHEET_PATH := "res://Assets/Torch/torch.png"
const FRAME := Vector2i(32, 32)
const FPS := 5.0

@export_group("Glow")
@export var glow_radius := 60.0                     ## Lit radius (px) — a small pool.
@export var glow_energy := 0.5                      ## Deliberately dim (mood, not vision).
@export var glow_color := Color(1.0, 0.72, 0.42)    ## Warm fire tint.
## Torch flame waver — a touch livelier than the lamps, still no vibration.
@export var glow_flicker := 0.05
@export var glow_flicker_speed := 3.0

const GLOW_TEX_HALF := 64.0
var _light: PointLight2D
var _t := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_frames = _torch_frames()
	play(&"burn")
	# De-sync neighbouring torches so a wall of them doesn't pulse in lockstep.
	frame = RNG.randi_range(0, sprite_frames.get_frame_count(&"burn") - 1)
	_t = RNG.randf_range(0.0, TAU)

	_light = PointLight2D.new()
	_light.name = "TorchLight"
	_light.texture = _build_glow_texture()
	# MIX (not ADD): overlapping torch/lamp/player lights union instead of
	# stacking into a double-bright lens.
	_light.blend_mode = Light2D.BLEND_MODE_MIX
	# The glow pools slightly below the sconce, onto the floor it illuminates.
	_light.position = Vector2(0.0, 10.0)
	add_child(_light)
	_apply(0.0)


## The 3-frame sheet sliced into a looping burn animation, built once and shared.
static var _shared_frames: SpriteFrames

static func _torch_frames() -> SpriteFrames:
	if _shared_frames != null:
		return _shared_frames
	var tex: Texture2D = load(SHEET_PATH)
	var frames := SpriteFrames.new()
	frames.add_animation(&"burn")
	frames.set_animation_speed(&"burn", FPS)
	frames.set_animation_loop(&"burn", true)
	if tex != null:
		for c in int(tex.get_width()) / FRAME.x:
			var cell := AtlasTexture.new()
			cell.atlas = tex
			cell.region = Rect2(Vector2(c * FRAME.x, 0), Vector2(FRAME))
			frames.add_frame(&"burn", cell)
	_shared_frames = frames
	return frames


## Soft radial glow generated in code (same recipe as the lamps): bright centre
## fading to transparent, so no separate light art is needed.
func _build_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.5, Color(1, 1, 1, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = int(GLOW_TEX_HALF * 2.0)
	tex.height = int(GLOW_TEX_HALF * 2.0)
	return tex


func _process(delta: float) -> void:
	_apply(delta)


## Drive radius/energy from the export vars each frame with a two-sine waver.
func _apply(delta: float) -> void:
	_t += delta
	var wobble := sin(_t * glow_flicker_speed) * 0.6 \
		+ sin(_t * glow_flicker_speed * 2.1 + 1.3) * 0.4
	var radius := glow_radius * (1.0 + glow_flicker * wobble)
	_light.texture_scale = maxf(radius, 1.0) / GLOW_TEX_HALF
	_light.color = glow_color
	_light.energy = glow_energy * (1.0 + glow_flicker * 0.5 * wobble)
