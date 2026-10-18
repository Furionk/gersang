extends SceneTree
## One-shot, explicit migration. Never called at boot. Old scenes already backed up.
func _initialize() -> void:
	WorldCatalog.initialize()
	var reports: Array[Dictionary] = []
	for file: String in DirAccess.get_files_at("res://features/world/data"):
		if not file.ends_with(".tscn"): continue
		var path: String = "res://features/world/data/"+file
		var map: WorldMap2D = (load(path) as PackedScene).instantiate() as WorldMap2D
		if map==null: continue
		if map.has_node("MonsterRegions"):
			map.free()
			continue
		var before: WorldMapDefinition = map.compile_definition()
		var groups: Dictionary = {}
		for title: String in ["Ground","Scenery","Entrances","MonsterRegions","MapLabels","Technical"]:
			var group: Node2D = Node2D.new()
			group.name = title
			group.set_meta("_edit_lock_",true)
			map.add_child(group)
			group.owner = map
			groups[title] = group
		groups.Technical.set_meta("authoring_archived",true)
		groups.Technical.hide()
		groups.Scenery.y_sort_enabled = true
		groups.Entrances.y_sort_enabled = true
		var authored_index: int = 0
		for node: Node in map.get_children().duplicate():
			if node in groups.values(): continue
			node.set_meta("authoring_order",authored_index)
			authored_index+=1
			node.owner = null
			if node is WorldTileLayer:
				node.reparent(groups.Ground if node.role<=WorldTileLayer.Role.SAFE else groups.Technical,false)
				node.owner = map
			elif node is WorldAuthorNode:
				if node.kind==WorldAuthorNode.Kind.HABITAT:
					var source: WorldHabitat = before.habitat(node.stable_id)
					var region: WorldMonsterRegion = WorldMonsterRegion.new()
					region.name = node.name
					region.set_meta("authoring_order",node.get_meta("authoring_order"))
					region.stable_id = node.stable_id
					region.display_name = node.display_name
					region.habitat = source.duplicate(true) as WorldHabitat
					var profile: SpawnProfile = source.profile
					region.party_count = profile.target_party_count
					region.respawn_min_seconds = profile.respawn_min_ms/1000.0
					region.respawn_max_seconds = profile.respawn_max_ms/1000.0
					region.aggressive = profile.rules.active
					region.battlefields = profile.arena_pool.duplicate()
					region.simple_party = profile.templates.size()==1 and profile.templates[0].members.size()==1
					if region.simple_party:
						var rule: MemberRule = profile.templates[0].members[0]
						region.monster = rule.definition
						region.minimum_units = rule.min_count
						region.maximum_units = rule.max_count
						region.minimum_level = rule.min_level
						region.maximum_level = rule.max_level
					region.position = Iso.project(source.activity_domain.bounds().get_center())
					groups.MonsterRegions.add_child(region)
					region.owner = map
					for pair: Array in [["SpawnArea",source.spawn_domain],["RoamingArea",source.activity_domain],["PursuitArea",source.chase_domain]]:
						var shape: WorldRegionPolygon = polygon(pair[0],pair[1].outer,region.position)
						region.add_child(shape)
						shape.owner = map
						var index: int = 0
						for hole: PackedVector2Array in pair[1].holes:
							var cut: WorldRegionPolygon = polygon("Hole_%d" % index,hole,region.position)
							cut.is_hole = true
							shape.add_child(cut)
							cut.owner = map
							index+=1
					node.reparent(groups.Technical,false)
					node.owner = map
				elif node.kind==WorldAuthorNode.Kind.ROAD:
					node.reparent(groups.MapLabels,false)
					node.owner = map
				elif node.kind in [WorldAuthorNode.Kind.WALKABLE,WorldAuthorNode.Kind.BLOCKER,WorldAuthorNode.Kind.SAFE_AREA]:
					node.reparent(groups.Technical,false)
					node.owner = map
				else:
					node.coordinate_space = WorldAuthorNode.CoordinateSpace.CANVAS
					node.position = Iso.project(node.position)
					node.reparent(groups.Entrances if node.kind in [WorldAuthorNode.Kind.PORTAL,WorldAuthorNode.Kind.ARRIVAL] else groups.Scenery if node.sprite_definition!=null else groups.MapLabels,false)
					node.owner = map
					if node.sprite_definition!=null:
						var artwork: Sprite2D = Sprite2D.new()
						artwork.name = "Artwork"
						node.add_child(artwork)
						artwork.owner = map
						node.set_meta("_edit_group_",true)
						node.sync_artwork()
			else:
				node.reparent(groups.Scenery,false)
				node.owner = map
		var after: WorldMapDefinition = map.compile_definition()
		var visual_parity: bool = before.scenery.size()==after.scenery.size()
		for index: int in before.scenery.size():
			var old_visual: Dictionary = before.scenery[index]
			var new_visual: Dictionary = after.scenery[index]
			visual_parity = visual_parity and old_visual.id==new_visual.id and old_visual.point.is_equal_approx(new_visual.point) and old_visual.definition==new_visual.definition and old_visual.portal_id==new_visual.portal_id
			if old_visual.id!=new_visual.id or not old_visual.point.is_equal_approx(new_visual.point): print("VISUAL_DIFF ",index," old=",old_visual.id,"@",old_visual.point," new=",new_visual.id,"@",new_visual.point)
		var parity: bool = before.portals==after.portals and before.entries==after.entries and before.landmarks==after.landmarks and visual_parity and before.habitats.size()==after.habitats.size()
		print("PARITY | routes=",before.portals==after.portals," entries=",before.entries==after.entries," marks=",before.landmarks==after.landmarks," scenery=",before.scenery==after.scenery)
		for old: WorldHabitat in before.habitats:
			var next: WorldHabitat = after.habitat(old.habitat_id)
			print("REGION_PARITY | ",old.habitat_id," spawn=",same_domain(old.spawn_domain,next.spawn_domain)," activity=",same_domain(old.activity_domain,next.activity_domain)," chase=",same_domain(old.chase_domain,next.chase_domain)," old=",old.spawn_domain.outer," new=",next.spawn_domain.outer)
			parity = parity and next!=null and same_domain(old.spawn_domain,next.spawn_domain) and same_domain(old.activity_domain,next.activity_domain) and same_domain(old.chase_domain,next.chase_domain)
			parity = parity and old.profile.target_party_count==next.profile.target_party_count and old.profile.arena_pool==next.profile.arena_pool
		var errors: Array[String] = WorldValidator.validate(after,WorldCatalog.definitions,map)
		if not parity or not errors.is_empty():
			push_error(file+": migration rejected parity="+str(parity)+" errors="+str(errors))
			map.free()
			quit(1)
			return
		var packed: PackedScene = PackedScene.new()
		if packed.pack(map)!=OK or ResourceSaver.save(packed,path)!=OK:
			push_error("Could not save "+path)
			map.free()
			quit(1)
			return
		reports.append({"map":file,"parity":true,"regions":after.habitats.size(),"scenery":after.scenery.size()})
		print("MIGRATED | ",file," regions=",after.habitats.size()," visuals=",after.scenery.size())
		map.free()
	var report: FileAccess = FileAccess.open("res://artifacts/workflow-2026-10-10/migration.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(reports,"\t"))
	report.close()
	quit()

func polygon(title: String, points: PackedVector2Array, origin: Vector2) -> WorldRegionPolygon:
	var shape: WorldRegionPolygon = WorldRegionPolygon.new()
	shape.name = title
	var vertices: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points: vertices.append(Iso.project(point)-origin)
	shape.polygon = vertices
	return shape

func same_domain(a: PolygonDomain,b: PolygonDomain) -> bool:
	return a.outer==b.outer and a.holes==b.holes
