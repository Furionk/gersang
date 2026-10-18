@tool
class_name WorldSaveService
extends RefCounted
const VERSION: int = 2
var path: String = DemoRules.path("world_state.dat")
var enabled: bool = true
var fail_writes: int = 0
var protected: bool = false
var last_error: String = ""

func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version",-1) != VERSION or data.get("content_version",-1) != 1:
		return false
	for key: String in ["maps","player","progress","applied_results","rng","active_encounter","player_party"]:
		if not data.get(key) is Dictionary: return false
	for key: String in ["revision","world_time_ms","id_counter"]:
		if not data.get(key) is int or data[key] < 0: return false
	if data.get("mode","") not in ["EXPLORING","ENCOUNTER","TRANSITION"] or not data.get("control_owner") is String:
		return false
	var player: Dictionary = data["player"]
	if not player.get("map_id") is String or not player.get("position") is Vector2 or not player.get("facing") is Vector2:
		return false
	if not player["position"].is_finite() or not player["facing"].is_finite(): return false
	for key: String in ["composition","placement","wander","battle","reward"]:
		if not data["rng"].get(key) is int: return false
	if not data["progress"].get("party") is Array or data["progress"]["party"].is_empty(): return false
	for map: Variant in data["maps"].values():
		if not map is Dictionary or not map.get("parties") is Dictionary or not map.get("slots") is Dictionary: return false
		for party: Variant in map["parties"].values():
			if not party is Dictionary or not party.get("deployed_units") is Array or not party.get("position") is Vector2: return false
			for member: Variant in party["deployed_units"]:
				if not member is Dictionary or not member.get("unit_id") is String or not member.get("resolved_stats") is Dictionary or not member.get("definition_path") is String: return false
	return true

func read_snapshot(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file: FileAccess = FileAccess.open(file_path,FileAccess.READ)
	if file == null or file.get_length() > 16 * 1024 * 1024:
		return {}
	var payload: Variant = file.get_var(false)
	file.close()
	return payload if valid(payload) else {}

func load_best() -> Dictionary:
	var best: Dictionary = {}
	var had_file: bool = false
	for suffix: String in ["",".bak",".tmp"]:
		had_file = had_file or FileAccess.file_exists(path + suffix)
		var data: Dictionary = read_snapshot(path + suffix)
		if not data.is_empty() and (best.is_empty() or int(data["revision"]) > int(best["revision"])):
			best = data
	if best.is_empty() and had_file:
		protected = true
		last_error = "存檔損壞或版本不相容；原檔保留，拒絕覆寫。"
	return best

func commit(candidate: Dictionary) -> Dictionary:
	if not valid(candidate):
		return {"ok":false,"reason":"INVALID_SNAPSHOT"}
	if not enabled:
		return {"ok":true,"reason":"ISOLATED_MEMORY_COMMIT","revision":candidate["revision"]}
	if protected or not path.begins_with("user://"):
		return {"ok":false,"reason":"SAVE_PROTECTED"}
	if fail_writes > 0:
		fail_writes -= 1
		return {"ok":false,"reason":"INJECTED_WRITE_FAILURE"}
	var file: FileAccess = FileAccess.open(path + ".tmp",FileAccess.WRITE)
	if file == null:
		return {"ok":false,"reason":"OPEN_FAILED"}
	file.store_var(candidate,false)
	file.flush()
	file.close()
	if read_snapshot(path + ".tmp") != candidate:
		return {"ok":false,"reason":"VERIFY_FAILED"}
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(path,path + ".bak") != OK:
			return {"ok":false,"reason":"BACKUP_FAILED"}
		if DirAccess.remove_absolute(path) != OK:
			return {"ok":false,"reason":"REPLACE_FAILED"}
	if DirAccess.rename_absolute(path + ".tmp",path) != OK:
		return {"ok":false,"reason":"RENAME_FAILED"}
	return {"ok":true,"reason":"OK","revision":candidate["revision"]}
