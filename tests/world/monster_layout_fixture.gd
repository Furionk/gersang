extends RefCounted
## Explicit reviewed D23 expectations; never learn values from the live scene.
static func record(map_id: String, habitat_id: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/world/approved_monster_layouts.json"))
	assert(data.version==1)
	return data.maps.get(map_id,{}).get(habitat_id,{})
static func domain(record: Dictionary, field: String) -> PolygonDomain:
	var result: PolygonDomain = PolygonDomain.new()
	var outer: PackedVector2Array = PackedVector2Array()
	for point: Array in record[field].outer: outer.append(Vector2(point[0],point[1]))
	result.outer = outer
	for contour: Array in record[field].holes:
		var hole: PackedVector2Array = PackedVector2Array()
		for point: Array in contour: hole.append(Vector2(point[0],point[1]))
		result.holes.append(hole)
	return result
static func shape_matches(map_id: String, habitat: WorldHabitat) -> bool:
	var expected: Dictionary = record(map_id,habitat.habitat_id)
	if expected.is_empty(): return false
	for field: String in ["spawn_domain","activity_domain","chase_domain"]:
		var current: PolygonDomain = habitat.get(field)
		var target: PolygonDomain = domain(expected,field)
		if current.outer!=target.outer or current.holes!=target.holes: return false
	return true
