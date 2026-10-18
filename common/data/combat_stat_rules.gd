class_name CombatStatRules
extends Resource
@export var attribute_reference: float = 20.0
@export_group("力量／等級")
@export var attack_per_strength: float = 1.5
@export var defense_per_strength: float = 0.25
@export var health_per_strength: float = 4.0
@export var attack_per_level: float = 0.35
@export var defense_per_level: float = 0.25
@export var health_per_level: float = 8.0
@export var mana_per_level: float = 2.0
@export_group("敏捷／智力／幸運")
@export var speed_per_agility: float = 0.003
@export var accuracy_per_agility: float = 2.0
@export var accuracy_per_luck: float = 1.0
@export var evade_per_agility: float = 0.001
@export var evade_per_luck: float = 0.001
@export var mana_per_intelligence: float = 3.0
@export var crit_per_luck: float = 0.001
@export_group("隨機幅度／機率（測試預設）")
@export_range(0, 0.9) var attack_variance: float = 0.1
@export_range(0, 0.9) var defense_variance: float = 0.2
@export_range(0, 0.9) var accuracy_variance: float = 0.05
@export_range(0, 1) var base_hit_chance: float = 0.98
@export var accuracy_chance_factor: float = 0.001
@export_range(0, 1) var base_evasion: float = 0.03
@export_range(0, 1) var base_crit: float = 0.02
@export var crit_multiplier: float = 2.0
