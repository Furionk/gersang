@tool
class_name BattleTileLayer
extends TileMapLayer
enum Role { GROUND, WALKABLE, BLOCKERS }
@export var role: Role = Role.GROUND
func _ready() -> void:
	collision_enabled=false
	navigation_enabled=false
	if role!=Role.GROUND: hide()
func set_editor_selected(value: bool) -> void:
	if role==Role.GROUND: return
	visible=Engine.is_editor_hint() and value
	self_modulate=Color(0.25,1,0.5,0.28) if role==Role.WALKABLE else Color(1,0.25,0.15,0.4)
