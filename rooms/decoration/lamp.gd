class_name Lamp
extends Sprite2D
## A hanging lamp decoration that casts a small, warm pool of ambient light. Drop it
## into a room (mounted near a wall reads best) and it builds its own PointLight2D so
## the glow follows the sprite. The lit radius is deliberately MUCH smaller than the
## player's torch — this is mood lighting that pools around the lamp, not vision.
##
## The lamp art (Lamp.png) is a transparent-background pixel sprite; with the project's
## nearest texture filter and the importer's alpha-border fix it sits on the dungeon
## tiles cleanly, no black fringe.

@export_group("Glow")
@export var glow_radius := 88.0                     ## Lit radius (px) — small, ambient.
@export var glow_energy := 0.95
@export var glow_color := Color(1.0, 0.84, 0.54)    ## Warm lantern tint.
## Candle-like waver so the pool of light breathes. Kept small/slow so it's a gentle
## breathe, not a vibration. 0 = perfectly steady.
@export var glow_flicker := 0.03
@export var glow_flicker_speed := 2.0

const GLOW_TEX_HALF := 64.0
var _light: PointLight2D
var _t := 0.0


func _ready() -> void:
	# Match the crisp pixel look of the tileset (no bilinear smear on the sprite edge).
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_light = PointLight2D.new()
	_light.name = "LampLight"
	_light.texture = _build_glow_texture()
	# MIX (not ADD) so overlapping lights merge as a union instead of stacking into a
	# brighter lens; the lamp still radiates fully where nothing overlaps it.
	_light.blend_mode = Light2D.BLEND_MODE_MIX
	add_child(_light)
	_apply(0.0)


## Soft radial glow generated in code: bright centre fading to transparent, so the
## lamp needs no separate light art.
func _build_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.5, Color(1, 1, 1, 0.6))
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


## Drive radius/energy from the export vars each frame (so runtime tweaks apply) with
## a gentle two-sine flicker.
func _apply(delta: float) -> void:
	_t += delta
	var wobble := sin(_t * glow_flicker_speed) * 0.6 \
		+ sin(_t * glow_flicker_speed * 1.9 + 0.8) * 0.4
	var radius := glow_radius * (1.0 + glow_flicker * wobble)
	_light.texture_scale = maxf(radius, 1.0) / GLOW_TEX_HALF
	_light.color = glow_color
	_light.energy = glow_energy * (1.0 + glow_flicker * 0.5 * wobble)
