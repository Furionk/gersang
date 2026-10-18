@tool
class_name ArenaDefinition
extends Resource
## 穩定Arena ID，怪區Battlefields以此選擇戰場。
@export var arena_id: String = "meadow"
@export var encounter: EncounterDefinition
## Arena可接納的敵人總數上限（最多60）。
@export_range(1, 60) var enemy_capacity: int = 60
## Arena可接納的我方總數上限（最多12）。
@export_range(1, 12) var player_capacity: int = 12
