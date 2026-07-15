class_name WeaponData
extends Resource
## Pure data defining a weapon. This is the core of the "collect hundreds of
## guns" design: a new weapon is a new .tres file — no code. A runtime Weapon
## node reads these numbers to fire; a WeaponHolder carries several of them.
##
## `tags` feed the synergy system later (Milestone 6): e.g. an item that boosts
## all weapons tagged &"spectral", or a combo that triggers on &"pierce".

@export var id: StringName = &""
@export var display_name: String = "Unnamed Weapon"
@export_multiline var description: String = ""

@export_group("Projectile")
@export var projectile_scene: PackedScene
@export var projectile_data: ProjectileData

@export_group("Firing")
@export var fire_rate: float = 7.0        ## Shots per second.
@export var auto: bool = true             ## Hold to fire vs. one shot per click.
## Draw-up delay: the trigger starts a channel and the shot looses this many
## seconds later, aimed at where the cursor is THEN. The held sprite pulls back
## while drawing (longbow). 0 = instant.
@export var channel_time: float = 0.0
@export var pellets: int = 1              ## Projectiles per shot (>1 = shotgun).
@export var spread_degrees: float = 0.0   ## Total scatter cone for the pellets.

@export_group("Charging")
## >0 makes this a charge weapon: hold the trigger to bank up to this many
## shots, release to loose them as a rapid salvo — one after another (crossbow).
@export var charge_max_shots: int = 0
@export var charge_time_per_shot: float = 0.35   ## Hold time to bank each extra shot.
@export var charge_burst_interval: float = 0.07  ## Gap between the salvo's shots (s).

@export_group("Combo")
## Curving weapons only (projectile curve_degrees != 0): landed hits advance a
## throw cycle — hit 0 throws a LEFT curver, 1 a RIGHT curver, 2 BOTH hands at
## once, then wraps. Missing repeats the same throw (bonerang).
@export var curve_combo: bool = false

@export_group("Animation")
## Wind-up frames for channel/charge weapons: while drawing or charging, the held
## sprite steps through these (last frame = fully wound); at rest it shows `sprite`.
@export var draw_frames: Array[Texture2D] = []
## Thrown weapons: the held sprite does a quick flourish spin each time it fires.
@export var fire_spin: bool = false
## Amplitude (px) of the held sprite's gentle idle bob, so the weapon never sits
## frozen in the hand. 0 = perfectly still.
@export var idle_sway: float = 0.0

@export_group("Ammo")
@export var mag_size: int = 12            ## Shots per clip before reloading.
@export var reload_time: float = 1.0      ## Seconds to reload.
@export var max_reserve: int = -1         ## Reserve ammo pool; -1 = infinite.

@export_group("Identity")
@export var color: Color = Color.WHITE    ## Placeholder tint (projectiles/pickup/held sprite).
@export var sprite: Texture2D             ## In-hand weapon image (tinted by `color`).
@export var sprite_scale: float = 1.0     ## Per-weapon size multiplier for the held sprite.
@export var tags: Array[StringName] = []  ## For synergies (e.g. &"bullet", &"pierce").
