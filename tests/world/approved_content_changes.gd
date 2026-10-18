extends RefCounted
## Test-only explicit approvals. Immutable migration backups stay untouched.
static func portal_baseline(map_id: String, source: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(source.duplicate(true))
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/world/approved_portal_edits.json"))
	assert(fixture.get("version")==1,"Unsupported approved-content fixture")
	for edit: Dictionary in fixture["changes"]:
		if edit["map_id"]!=map_id: continue
		var before: Vector2 = Vector2(edit["before"][0],edit["before"][1])
		var after: Vector2 = Vector2(edit["after"][0],edit["after"][1])
		for portal: Dictionary in result:
			if portal.get("id")==edit["portal_id"] and portal.get("point")==before:
				portal["point"] = after
	return result
