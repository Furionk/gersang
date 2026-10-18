@tool
class_name MonkeyProfile
extends Resource
@export_file("*.tscn") var scene: String = "res://features/monkey/garden.tscn"

func resolved_scene() -> String:
	return scene if ResourceLoader.exists(scene) else "res://features/monkey/garden.tscn"

@export var run_speed: float = 6.0
@export var sneak_speed: float = 2.0
@export var net_reach: float = 2.0
@export var hit_hp: float = 10.0
@export var stun_seconds: float = 1.5
@export var sight_range: float = 10.0
@export var sight_degrees: float = 110.0
@export var confirmation_seconds: float = 0.6
@export var search_seconds: float = 4.0
@export var camera_shake: bool = true
@export var zone_name: String = "庭園追捕"
@export var time_limit: float = 180.0
@export var escape_multiplier: float = 1.2
@export var burst_multiplier: float = 1.35
@export var decision_seconds: float = 0.85
@export var dodge_chance: float = 0.4
@export var jump_seconds: float = 0.7
@export var hearing_range: float = 5.0
@export var look_back_interval: float = 0.9
@export var burst_cooldown: float = 2.2
@export var dodge_reaction: float = 0.18
@export var dodge_cooldown_seconds: float = 1.5
@export var prediction_seconds: float = 0.35

@export_range(5, 20) var monkey_count: int = 5
@export_range(1, 100) var monkey_level: int = 1
@export_range(0, 3) var difficulty: int = 0
@export var alarm_radius: float = 0.0
@export var feint_chance: float = 0.0
@export var attack_windup: float = 0.6
@export var attack_recovery: float = 0.65
@export var exhaustion_seconds: float = 0.65
@export var stun_resistance: float = 0.0
@export var acceleration: float = 38.0
@export var braking: float = 48.0
@export var turn_rate: float = 14.0
@export var mouse_sensitivity: float = 0.0025
