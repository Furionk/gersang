class_name UnitStateMachine
extends Node
signal state_changed(previous: StringName, current: StringName)
@export var current: StringName = &"idle"
const STATES: Array[StringName] = [&"idle", &"move", &"chase", &"blocked", &"attack", &"cast", &"hold", &"controlled", &"dead"]
var transitions: int = 0
func _ready() -> void:
	for state: StringName in STATES:
		var leaf: Node = Node.new()
		leaf.name = String(state).capitalize()
		add_child(leaf)
func transition(next: StringName) -> void:
	if current == next or current == &"dead" or next not in STATES:
		return
	var previous: StringName = current
	current = next
	transitions += 1
	state_changed.emit(previous, current)

func revive() -> void:
	if current != &"dead": return
	current = &"idle"
	transitions += 1
	state_changed.emit(&"dead",current)
