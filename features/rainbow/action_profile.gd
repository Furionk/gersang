class_name RainbowActionProfile
extends Resource
## Only encounters explicitly referencing this profile use direct action control.
@export var allowed_maps: PackedStringArray = PackedStringArray(["rainbow_temple"])
@export var weapons: Array[RainbowWeaponDefinition] = []
@export var enemies: Array[RainbowEnemyDefinition] = []
@export var acceleration: float = 1400.0
@export var braking: float = 1800.0
@export var run_multiplier: float = 1.65
@export var bp_max: float = 100.0
@export var bp_drain: float = 28.0
@export var bp_regen: float = 18.0
@export var melee_range: float = 82.0
@export var melee_half_angle: float = 1.0
@export var melee_windup: float = 0.14
@export var melee_recovery: float = 0.28
@export var ranged_windup: float = 0.20
@export var ranged_recovery: float = 0.45
@export var ranged_power: float = 0.65
@export var projectile_speed: float = 650.0
@export var projectile_lifetime: float = 0.8
@export var guard_duration: float = 0.38
@export var guard_recovery: float = 0.30
@export var guard_damage_scale: float = 0.2
@export var knockback: float = 145.0
@export var hit_stun: float = 0.14
@export var ally_leash: float = 340.0
@export var follow_distance: float = 90.0
@export_group("Combat feedback")
@export var input_buffer: float = 0.18
@export var impact_pause: float = 0.045
@export var impact_flash: float = 0.10
@export var camera_kick: float = 2.5
@export var impact_volume_db: float = -9.0
@export var comic_voice_volume_db: float = -8.0
