extends Node
const APPROVED_CONTENT = preload("res://tests/world/approved_content_changes.gd")
const MONSTER_LAYOUT = preload("res://tests/world/monster_layout_fixture.gd")
var passed: int = 0
var failures: Array[String] = []
func _ready() -> void: call_deferred("run")
func check(value: bool, title: String) -> void:
	if value: passed+=1; print("PASS | ",title)
	else: failures.append(title); push_error("FAIL | "+title)

func fingerprint(profile: SpawnProfile) -> Dictionary:
	var parties: Array = []
	for template: PartyTemplate in profile.templates:
		var members: Array = []
		for rule: MemberRule in template.members:
			var unit: UnitDefinition = rule.definition
			members.append([unit.id,rule.min_count,rule.max_count,rule.min_level,rule.max_level,rule.equipment_power,unit.damage,unit.max_health,unit.max_mana,unit.strength,unit.agility,unit.intelligence,unit.speed,unit.skills.map(func(s: SkillDefinition) -> StringName: return s.id)])
		parties.append([template.template_id,template.display_name,template.representative.id,members])
	return {"parties":parties,"weights":profile.weights,"count":profile.target_party_count,"min":profile.respawn_min_ms,"max":profile.respawn_max_ms,"active":profile.rules.active,"radius":profile.radius,"speed":profile.speed,"arenas":profile.arena_pool}

func run() -> void:
	WorldCatalog.initialize()
	for file: String in DirAccess.get_files_at("res://features/world/data"):
		if not file.ends_with(".tscn"): continue
		var map: WorldMap2D = load("res://features/world/data/"+file).instantiate() as WorldMap2D
		var old: WorldMap2D = preload("res://tests/world/legacy_scene_fixture.gd").load_scene("res://artifacts/workflow-2026-10-10/original-scenes/"+file).instantiate() as WorldMap2D
		var before: WorldMapDefinition = old.compile_definition()
		var after: WorldMapDefinition = map.compile_definition()
		check(map.has_node("Ground") and map.has_node("MonsterRegions") and map.has_node("Entrances") and map.has_node("Scenery"),file+" meaningful native scene groups")
		var expected_portals: Array[Dictionary] = APPROVED_CONTENT.portal_baseline(before.map_id,before.portals)
		check(expected_portals==after.portals and before.entries==after.entries and before.roads==after.roads and before.landmarks==after.landmarks,file+" routes, arrivals, roads and landmarks exact with explicit approved position edit")
		for field: String in ["portals","entries","roads","landmarks"]:
			if (expected_portals if field=="portals" else before.get(field))!=after.get(field): print("AUTHORING_DIFF | ",field," before=",before.get(field)," after=",after.get(field))
		var geometry: bool = true
		for field: String in ["walkable","blockers","safe_areas"]:
			var a: Array = before.get(field)
			var b: Array = after.get(field)
			geometry = geometry and a.size()==b.size()
			for index: int in a.size(): geometry = geometry and a[index].outer==b[index].outer and a[index].holes==b[index].holes
		check(geometry,file+" terrain/navigation exact before and after")
		for prior: WorldHabitat in before.habitats:
			var expected: WorldHabitat = prior.duplicate(true) as WorldHabitat
			var approved: Dictionary = MONSTER_LAYOUT.record(before.map_id,prior.habitat_id)
			if not approved.is_empty():
				expected.spawn_domain = MONSTER_LAYOUT.domain(approved,"spawn_domain")
				expected.activity_domain = MONSTER_LAYOUT.domain(approved,"activity_domain")
				expected.chase_domain = MONSTER_LAYOUT.domain(approved,"chase_domain")
				expected.profile.target_party_count = approved.profile.count
				expected.profile.rules.active = approved.profile.active
				expected.profile.templates[0].display_name = approved.profile.display_name
				expected.profile.templates[0].template_id = approved.profile.template_id
				for index: int in approved.profile.members.size():
					var rule: MemberRule = expected.profile.templates[0].members[index]
					var member: Dictionary = approved.profile.members[index]
					rule.min_count=member.minimum; rule.max_count=member.maximum; rule.min_level=member.min_level; rule.max_level=member.max_level
			var next: WorldHabitat = after.habitat(prior.habitat_id)
			check(next!=null and fingerprint(expected.profile)==fingerprint(next.profile),file+" complete profile matches preserved/explicit D23 configuration "+prior.habitat_id)
			var region: WorldMonsterRegion = map.get_node("MonsterRegions/"+prior.habitat_id) as WorldMonsterRegion
			check(region!=null and region.coordinate_space==WorldAuthorNode.CoordinateSpace.CANVAS,file+" native visual-space region "+prior.habitat_id)
			var spawn: WorldRegionPolygon = region.get_node("SpawnArea") as WorldRegionPolygon
			var domain: PolygonDomain = spawn.logical_domain(map)
			check(domain.outer==expected.spawn_domain.outer and domain.holes==expected.spawn_domain.holes,file+" native polygon matches exact approved outer/holes")
			var original: Vector2 = region.position
			region.position += Vector2(80,40)
			var moved: PolygonDomain = region.compile_habitat(map).spawn_domain
			check(moved.outer[0].is_equal_approx(domain.outer[0]+Vector2(80,0)),file+" native drag maps correctly to planar coordinates")
			region.position = original
			var count: int = region.party_count
			region.party_count = 9
			check(region.compile_habitat(map).profile.target_party_count==9 and expected.profile.target_party_count==count,file+" flat population edits isolated")
			region.party_count = count
			var vertices: PackedVector2Array = spawn.polygon.duplicate()
			spawn.polygon = PackedVector2Array()
			check(not WorldValidator.validate(map.compile_definition(),WorldCatalog.definitions,map).is_empty(),file+" invalid native draft blocks play")
			spawn.polygon = vertices
		var visuals: bool = true
		for node: Node in WorldAuthorTree.nodes(map):
			if node is WorldAuthorNode and node.sprite_definition!=null:
				var art: Sprite2D = node.get_node_or_null("Artwork") as Sprite2D
				visuals = visuals and art!=null and art.owner==map and not art.has_meta("_edit_lock_") and node.coordinate_space==WorldAuthorNode.CoordinateSpace.CANVAS and not node.editor_selected
		check(visuals,file+" owned native Sprite2D, true-position gizmos, no unselected markers")
		var snapshot: Dictionary = WorldAuthoringSnapshot.compile(map)
		check(snapshot.ok and snapshot.errors.is_empty() and snapshot.definition.portals==after.portals and snapshot.definition.habitats.size()==after.habitats.size(),file+" recursive detached build snapshot")
		check(WorldValidator.validate(after,WorldCatalog.definitions,map).is_empty(),file+" valid grouped map")
		map.free(); old.free()
	var original_portals: Array[Dictionary] = [{"id":"town_door","point":Vector2(4800,1900),"target_map_id":"qingling_town","radius":65.0},{"id":"well_door","point":Vector2(2800,3260)}]
	var approved: Array[Dictionary] = APPROVED_CONTENT.portal_baseline("river_bay",original_portals)
	check(approved[0].point==Vector2(4284.5,2723.5) and original_portals[0].point==Vector2(4800,1900) and approved[0].target_map_id=="qingling_town" and approved[0].radius==65.0 and approved[1]==original_portals[1],"explicit portal approval changes only copied position; backups/destinations untouched")
	original_portals[0].point = Vector2(4900,1900)
	check(APPROVED_CONTENT.portal_baseline("river_bay",original_portals)==original_portals and APPROVED_CONTENT.portal_baseline("other_map",original_portals)==original_portals,"approval never accepts an unrelated source point or another map")
	var template: WorldMonsterRegion = load("res://features/world/authoring/templates/monster_region.tscn").instantiate() as WorldMonsterRegion
	var rock: Node2D = Node2D.new()
	rock.add_child(template)
	check(template.compile_habitat(rock).profile.templates[0].members[0].definition.id==&"beast","template works under unrelated Node2D without game services")
	check(template.compile_habitat(rock).activity_domain.covers(template.compile_habitat(rock).spawn_domain.outer),"new native template nested shapes legal")
	var hole: WorldRegionPolygon = WorldRegionPolygon.new()
	hole.is_hole = true
	hole.polygon = PackedVector2Array([Vector2(0,-10),Vector2(20,0),Vector2(0,10),Vector2(-20,0)])
	template.get_node("SpawnArea").add_child(hole)
	var cut: PolygonDomain = template.compile_habitat(rock).spawn_domain
	check(cut.holes.size()==1 and not cut.contains(Vector2.ZERO) and cut.contains(Vector2(70,0)),"native child polygon hole excludes correct planar area")
	var species: UnitDefinition = template.monster
	template.monster = load("res://features/units/data/monsters/elite.tres") as UnitDefinition
	check(template.compile_habitat(rock).profile.templates[0].members[0].definition.id==&"elite" and species.id==&"beast","flat species replacement changes generated members without modifying shared definition")
	rock.free()
	var plugin: String = FileAccess.get_file_as_string("res://addons/world_authoring/plugin.gd")
	check(not plugin.contains("add_control_to_dock") and not plugin.contains("_forward_canvas_gui_input"),"no permanent dock or intercepted native paint/polygon input")
	var report: Dictionary = {"passed":passed,"failed":failures.size(),"failures":failures,"manual_mouse_gate":"unverified"}
	var output: FileAccess = FileAccess.open("res://artifacts/workflow-2026-10-10/tests.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t")); output.close()
	print("HUMAN_AUTHORING_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
