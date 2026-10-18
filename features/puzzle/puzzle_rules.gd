class_name PuzzleRules
extends Resource
@export var enemy_texture: Texture2D
@export var dark_monster: bool = false
@export var move_seconds: float = 6.0
@export var fade_seconds: float = 0.4
@export var extra_orb_bonus: float = 0.25
@export var combo_bonus: float = 0.25
@export var heart_fraction: float = 0.10
@export var enemy_attack_fraction: float = 0.08
@export_range(0.1, 120.0, 0.1) var enemy_cooldown_seconds: float = 10.0
@export_range(0.1, 120.0, 0.1) var enemy_initial_min_seconds: float = 8.0
@export_range(0.1, 120.0, 0.1) var enemy_initial_max_seconds: float = 12.0
@export var monster_health_attack_multiple: float = 12.0
@export var monster_level: int = 25
@export var monster_attack_reference: UnitDefinition

func monster_health(actual_level: int = -1) -> float:
	if monster_attack_reference == null: return 1.0
	var d: UnitDefinition = monster_attack_reference
	return CombatStats.calculate(d, {"strength":d.strength,"agility":d.agility,"vitality":d.vitality,"intelligence":d.intelligence,"luck":d.luck}, monster_level if actual_level < 0 else actual_level).attack * monster_health_attack_multiple

static func affinity(attacker: int, defender: int) -> float:
	if attacker == defender or attacker == 3 or defender == 3: return 1.0
	return 2.0 if (attacker == 0 and defender == 2) or (attacker == 2 and defender == 1) or (attacker == 1 and defender == 0) else 0.5
