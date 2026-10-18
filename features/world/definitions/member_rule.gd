@tool
class_name MemberRule
extends Resource
@export var definition: UnitDefinition
@export_range(1, 60) var min_count: int = 1
@export_range(1, 60) var max_count: int = 1
@export_range(1, 100) var min_level: int = 1
@export_range(1, 100) var max_level: int = 1
@export var equipment_power: int = 0
