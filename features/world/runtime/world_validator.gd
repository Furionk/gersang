@tool
class_name WorldValidator
extends RefCounted

static func polygon_errors(domain: PolygonDomain, label: String) -> Array[String]:
	var errors: Array[String] = []
	if domain == null or domain.outer.size() < 3:
		return [label + ": 至少三個外框頂點"]
	if Geometry2D.triangulate_polygon(domain.outer).is_empty():
		errors.append(label + ": 外框無效／自交")
	var outer: PolygonDomain = PolygonDomain.new()
	outer.outer = domain.outer
	for i: int in domain.holes.size():
		var hole: PackedVector2Array = domain.holes[i]
		if Geometry2D.triangulate_polygon(hole).is_empty() or not outer.covers(hole):
			errors.append(label + ": 孔洞無效或超出外框")
		for vertex: Vector2 in hole:
			for edge: int in domain.outer.size():
				if Geometry2D.get_closest_point_to_segment(vertex,domain.outer[edge],domain.outer[(edge+1)%domain.outer.size()]).distance_to(vertex) < 0.01:
					errors.append(label + ": 孔洞接觸外框")
		for j: int in i:
			if not Geometry2D.intersect_polygons(hole,domain.holes[j]).is_empty():
				errors.append(label + ": 孔洞重疊／巢狀")
	return errors

static func validate(map: WorldMapDefinition, registry: Dictionary, root: WorldMap2D = null) -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(map.tile_authoring_errors)
	if map.map_id.is_empty(): errors.append("map_id 不能空白")
	if map.walkable.is_empty(): errors.append("至少需要一個通行區")
	if map.grid_size <= 0 or map.extent.x <= 0 or map.extent.y <= 0: errors.append("地圖尺寸／格尺寸必須為正值")
	if map.atlas_projection_scale.x <= 0 or map.atlas_projection_scale.y <= 0: errors.append("Atlas 對位比例必須為正值")
	var ids: Dictionary = {}
	if root != null:
		if not is_zero_approx(root.rotation) or not root.scale.is_equal_approx(Vector2.ONE): errors.append("地圖根節點只允許平移")
		for node: Node in WorldAuthorTree.nodes(root):
			if NativeScenery.is_author(node):
				var id: String = str(node.get_meta("world_scenery_id",""))
				if id.is_empty() or ids.has(id): errors.append("地景Sprite ID重複／空白："+node.name)
				ids[id]=true
				if not node.transform.x.is_finite() or not node.transform.y.is_finite() or not node.position.is_finite() or absf(node.transform.determinant())<0.000001: errors.append("地景Sprite變換無效："+node.name)
			elif node is WorldAuthorNode:
				if node.stable_id.is_empty() or ids.has(node.stable_id): errors.append("作者 ID 重複或空白：" + node.name)
				ids[node.stable_id] = true
				var visual_author: bool = node.kind in [WorldAuthorNode.Kind.PORTAL,WorldAuthorNode.Kind.LANDMARK,WorldAuthorNode.Kind.SCENERY] and node.sprite_definition!=null and node.coordinate_space==WorldAuthorNode.CoordinateSpace.CANVAS
				if visual_author:
					if not node.transform.x.is_finite() or not node.transform.y.is_finite() or not node.position.is_finite() or absf(node.transform.determinant())<0.000001:
						errors.append("外觀變換無效（不能為零比例或非有限值）："+node.name)
				elif not is_zero_approx(node.rotation) or not node.scale.is_equal_approx(Vector2.ONE): errors.append("邏輯範圍節點只允許平移：" + node.name)
			elif node is Node2D and not node is Sprite2D and not node is WorldRegionPolygon and not node is WorldSceneryView and not node is WorldTileLayer:
				if node.get_meta("scenery_parts",false):
					if not node.position.is_finite() or not node.transform.x.is_finite() or not node.transform.y.is_finite() or absf(node.transform.determinant())<0.000001: errors.append("地景分件組變換無效："+node.name)
					for part: Node in WorldAuthorTree.nodes(node):
						if part is WorldAuthorNode or part is WorldTileLayer or part is WorldRegionPolygon: errors.append("地景分件組只能包含外觀，不得包導航／入口／怪區："+node.name)
				elif not is_zero_approx(node.rotation) or not node.scale.is_equal_approx(Vector2.ONE) or node.position!=Vector2.ZERO: errors.append("分類圖層保持原點／比例1："+node.name)
	for domain: PolygonDomain in map.walkable: errors.append_array(polygon_errors(domain,"通行區"))
	for domain: PolygonDomain in map.blockers: errors.append_array(polygon_errors(domain,"障礙區"))
	for domain: PolygonDomain in map.safe_areas: errors.append_array(polygon_errors(domain,"安全區"))
	for entry: Dictionary in map.scenery:
		var visual: WorldSceneryDefinition = entry.get("definition")
		if visual==null or visual.texture==null:
			errors.append(str(entry.get("id","Sprite"))+": 未配置地景圖片")
			continue
		if visual.sprite_scale<=0 or not Rect2(Vector2.ZERO,visual.texture.get_size()).encloses(visual.region()): errors.append(str(entry["id"])+": 圖片裁切／比例無效")
	ids.clear()
	for habitat: WorldHabitat in map.habitats:
		if ids.has(habitat.habitat_id): errors.append("重複怪區 ID：" + habitat.habitat_id)
		ids[habitat.habitat_id] = true
		for domain: PolygonDomain in [habitat.spawn_domain,habitat.activity_domain,habitat.chase_domain]: errors.append_array(polygon_errors(domain,habitat.habitat_id))
		if habitat.spawn_domain != null and habitat.activity_domain != null and not habitat.activity_domain.covers_domain(habitat.spawn_domain): errors.append(habitat.habitat_id + ": 出生域不在活動域內")
		if habitat.activity_domain != null and habitat.chase_domain != null and not habitat.chase_domain.covers_domain(habitat.activity_domain): errors.append(habitat.habitat_id + ": 活動域不在追擊域內")
		if habitat.profile == null or habitat.profile.templates.is_empty():
			errors.append(habitat.habitat_id + ": 未配置怪隊模板")
			continue
		if habitat.profile.respawn_min_ms<0 or habitat.profile.respawn_max_ms<habitat.profile.respawn_min_ms: errors.append(habitat.habitat_id+": 重生秒數範圍無效")
		for template: PartyTemplate in habitat.profile.templates:
			if template.representative == null or template.members.is_empty(): errors.append(habitat.habitat_id + ": 怪隊模板沒有外觀／成員")
			for rule: MemberRule in template.members:
				if rule.definition == null or rule.min_count < 1 or rule.max_count < rule.min_count or rule.max_level < rule.min_level: errors.append(habitat.habitat_id + ": 無效成員規則")
		for arena_id: String in habitat.profile.arena_pool:
			if not WorldCatalog.arenas.has(arena_id): errors.append(habitat.habitat_id + ": 戰場不存在 " + arena_id)
	var nav: WorldNavigationService = WorldNavigationService.new()
	nav.register_map(map)
	for entry_id: String in map.entries:
		var at: Vector2 = map.entries[entry_id]["point"]
		if not nav.segment_legal(map.map_id,"","PLAYER",at,at,16): errors.append("非法到達點：" + entry_id)
		for portal: Dictionary in map.portals:
			if at.distance_to(portal["point"]) <= float(portal["radius"]): errors.append("到達點落在觸發區：" + entry_id)
	for portal: Dictionary in map.portals:
		var destination: WorldMapDefinition = registry.get(portal["target_map_id"])
		if destination == null or not destination.entries.has(portal["target_entry_id"]): errors.append("入口目的地不存在：" + portal["id"])
	return errors
