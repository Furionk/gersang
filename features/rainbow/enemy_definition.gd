class_name RainbowEnemyDefinition
extends Resource
## Native action encounter tuning; never changes persistent unit identity.
@export var unit_id: StringName
@export var weapon: RainbowWeaponDefinition
@export_enum("slime", "beast", "priest", "dragon", "hound", "pincer", "troll", "bat") var pattern: String = "slime"
@export var boss: bool = false
@export var boss_tier: RainbowBossTier
## Logical ground footprint, independent of wings, robes and attack telegraphs.
@export_range(0.0, 120.0, 1.0) var body_radius: float = 0.0
@export var special_interval: float = 6.0
@export var warning_seconds: float = 1.4
@export var special_power: float = 65.0
@export var armored_damage_scale: float = 1.0
@export var exposed_damage_scale: float = 1.6
@export var exposure_seconds: float = 4.0
