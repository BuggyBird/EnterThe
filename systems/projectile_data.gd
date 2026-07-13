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

@export_group("Appearance")
@export var radius: float = 4.0        ## Collision + placeholder visual radius.
@export var color: Color = Color(1.0, 0.86, 0.4)
