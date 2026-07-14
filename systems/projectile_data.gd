class_name ProjectileData
extends Resource
## Pure data describing how a projectile looks and behaves. This is the heart of
## the data-driven design: a new bullet type is a new .tres file, no code needed.
## Weapons reference a ProjectileData and hand it to spawned Projectile scenes.

@export_group("Motion")
@export var speed: float = 620.0       ## Travel speed (px/s).
@export var lifetime: float = 1.5      ## Seconds before it despawns on its own.

@export_group("Impact")
@export var damage: float = 10.0
@export var knockback: float = 140.0   ## Impulse strength applied to what it hits.
@export var pierce: int = 0            ## Extra hurtboxes it passes through (0 = dies on first hit).

@export_group("Behaviour")
## Steering rate (deg/s). Non-zero = the shot flies in an arc; the Weapon
## alternates the curve side per pellet, so pellets=2 gives one right-curving
## and one left-curving projectile (boomerangs).
@export var curve_degrees: float = 0.0
## Damage grows with distance travelled: extra fraction of base damage per
## 100 px between spawn and impact (0 = off). Longbow-style reward for range.
@export var distance_damage_per_100: float = 0.0
## Cap for the distance multiplier so cross-room snipes don't go infinite.
@export var distance_damage_max_mult: float = 3.0

@export_group("Appearance")
@export var radius: float = 4.0        ## Collision + placeholder visual radius.
@export var color: Color = Color(1.0, 0.86, 0.4)
## Optional sprite drawn instead of the placeholder circle (e.g. the boomerang).
@export var texture: Texture2D
@export var texture_scale: float = 1.0
## Visual spin (rad/s). 0 = face travel direction. Spin follows the curve side.
@export var spin_speed: float = 0.0
