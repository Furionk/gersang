@tool
class_name PartyTemplate
extends Resource
@export var template_id: String = ""
@export var display_name: String = "怪隊"
@export var representative: UnitDefinition
@export var members: Array[MemberRule] = []
