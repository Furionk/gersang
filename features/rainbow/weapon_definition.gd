class_name RainbowWeaponDefinition
extends Resource
## Action-only equipment and presentation. Never replaces a persistent UnitDefinition.
@export var unit_id: StringName
@export var layout: SpriteSheetLayout
@export var effect_texture: Texture2D
@export var sprite_scale: float = 0.30
@export var melee_name: String = "連斬"
@export var ranged_name: String = "飛刃"
@export var specialty: String = "均衡連擊"
@export var tint: Color = Color("77e7dd")
@export_enum("blade", "heavy", "rifle", "scatter", "lightning", "needle", "talisman", "seal", "kunai", "crescent", "curse") var effect: String = "blade"
@export var melee_range: float = 82.0
@export var melee_half_angle: float = 1.0
@export var melee_windup: float = 0.14
@export var melee_recovery: float = 0.28
@export var melee_power: float = 1.0
@export var ranged_windup: float = 0.20
@export var ranged_recovery: float = 0.45
@export var ranged_power: float = 0.65
@export var mana_cost: float = 3.0
@export var projectile_speed: float = 650.0
@export var projectile_lifetime: float = 0.8
@export_range(1,5,1) var projectile_count: int = 1
@export var spread: float = 0.0
@export_range(1,4,1) var pierce: int = 1
@export var splash: float = 0.0
@export var stagger: float = 0.14
@export var knockback: float = 145.0
@export var move_multiplier: float = 1.0
@export var guard_damage_scale: float = 0.2

func apply_to(base: RainbowActionProfile) -> RainbowActionProfile:
	var effective: RainbowActionProfile = base.duplicate()
	for key: String in ["melee_range", "melee_half_angle", "melee_windup", "melee_recovery", "ranged_windup", "ranged_recovery", "ranged_power", "projectile_speed", "projectile_lifetime", "guard_damage_scale"]:
		effective.set(key, get(key))
	return effective
