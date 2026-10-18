class_name UnitVoiceProfile
extends Resource
## Paths permit staged production: missing audio is silent, never a missing Resource dependency.
@export var unit_id: StringName
@export var nationality: String = ""
@export var language: String = ""
@export var gender: String = ""
@export var vocal_age: String = ""
@export var species: String = "human"
@export var profession: String = ""
@export var personality: String = ""
@export var voice_id: String = ""
@export var model_id: String = "eleven_v3"
@export var manifest_path: String = ""
@export var events: Dictionary = {}

func paths_for(event: StringName) -> PackedStringArray:
	return PackedStringArray(events.get(String(event), []))
