extends Node
const APPROVED_CONTENT = preload("res://tests/world/approved_content_changes.gd")
const MONSTER_LAYOUT = preload("res://tests/world/monster_layout_fixture.gd")
var passed: int = 0
var failures: Array[String] = []
var metrics: Dictionary = {}
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("PASS | ",title)
	else: failures.append(title); push_error("FAIL | "+title)
func _ready() -> void: call_deferred("run")
func inside(domains: Array[PolygonDomain], point: Vector2) -> bool:
	for domain: PolygonDomain in domains:
		if domain.contains(point): return true
	return false
func run() -> void:
	var started: int = Time.get_ticks_msec()
	WorldCatalog.initialize()
	for id: String in ["river_bay","qingling_town","well_1","well_2"]:
		var before_root: WorldMap2D = preload("res://tests/world/legacy_scene_fixture.gd").load_scene("res://artifacts/tilemap-migration-2026-10-10/original-scenes/%s.tscn" % id).instantiate() as WorldMap2D
		var current: WorldMap2D = load("res://features/world/data/%s.tscn" % id).instantiate() as WorldMap2D
		var before: WorldMapDefinition = before_root.compile_definition()
		# Geometry has received authorized content since the first TileMap migration.
		# Preserve that current baseline; do not remove new obstacles to pass an old test.
		var geometry_root: WorldMap2D = preload("res://tests/world/legacy_scene_fixture.gd").load_scene("res://artifacts/workflow-2026-10-10/original-scenes/%s.tscn" % id).instantiate() as WorldMap2D
		var geometry_before: WorldMapDefinition = geometry_root.compile_definition()
		var compile_started: int = Time.get_ticks_usec()
		var after: WorldMapDefinition = current.compile_definition()
		metrics[id] = {"compile_ms":(Time.get_ticks_usec()-compile_started)/1000.0}
		check(current.native_tiles_enabled and after.native_tile_layers.size()==2,id+" saved native terrain and obstacles")
		var existing_portals: Array[Dictionary] = after.portals.filter(func(p: Dictionary) -> bool: return p["id"] not in ["lake_door","shaolin_door"]) if id=="river_bay" else after.portals
		var existing_entries: Dictionary = after.entries.duplicate(true)
		if id=="river_bay":
			existing_entries.erase("lake_return")
			existing_entries.erase("shaolin_return")
		check(before.extent==after.extent and before.map_id==after.map_id and APPROVED_CONTENT.portal_baseline(id,before.portals)==existing_portals and before.entries==existing_entries,id+" original identity, portals and arrivals preserved; added maps and explicit approved portal position allowed")
		check(before.habitats.size()==after.habitats.size(),id+" habitat count unchanged")
		var same: bool = true
		var mismatch: Array = []
		for y: int in range(17,int(after.extent.y),47):
			for x: int in range(13,int(after.extent.x),47):
				var at: Vector2 = Vector2(x,y)
				for property: String in ["walkable","blockers","safe_areas"]:
					if inside(geometry_before.get(property),at)!=inside(after.get(property),at):
						same=false
						if mismatch.size()<8: mismatch.append([property,at])
		check(same,id+" latest pre-workflow geometry parity; authorized later content retained "+str(mismatch))
		for old_habitat: WorldHabitat in before.habitats:
			var next: WorldHabitat = after.habitat(old_habitat.habitat_id)
			check(next!=null and next.habitat_id==old_habitat.habitat_id and next.profile.target_party_count==old_habitat.profile.target_party_count and next.profile.arena_pool==old_habitat.profile.arena_pool,id+" stable habitat and authored profile "+old_habitat.habitat_id)
			var shape_same: bool = true
			for property: String in ["spawn_domain","activity_domain","chase_domain"]:
				var approved: Dictionary = MONSTER_LAYOUT.record(id,old_habitat.habitat_id)
				var a: PolygonDomain = MONSTER_LAYOUT.domain(approved,property) if not approved.is_empty() else old_habitat.get(property)
				var b: PolygonDomain = next.get(property)
				shape_same = shape_same and a.bounds().is_equal_approx(b.bounds()) and is_equal_approx(PolygonDomain.area(a.outer),PolygonDomain.area(b.outer)) and a.holes.size()==b.holes.size()
			check(shape_same,id+" exact region bounds/area/holes "+old_habitat.habitat_id)
		var errors: Array[String] = WorldValidator.validate(after,WorldCatalog.definitions,current)
		check(errors.is_empty(),id+" configuration validation "+str(errors))
		var floor: WorldTileLayer = current.find_child("Ground_TileMap",true,false) as WorldTileLayer
		check(floor.tile_set.tile_shape==TileSet.TILE_SHAPE_ISOMETRIC and floor.logical_center(Vector2i.ONE)==Vector2(48,48),id+" native isometric brush coordinates")
		var expected_cells: int = int(ceilf(after.extent.x/32))*int(ceilf(after.extent.y/32))
		check(floor.get_used_cells().size()==expected_cells,id+" complete floor has no terrain-connect holes")
		floor.set_cells_terrain_connect([Vector2i(8,8),Vector2i(9,8)],0,1)
		check(floor.get_used_cells().size()==expected_cells and floor.get_cell_tile_data(Vector2i(8,8)).terrain==1,id+" native road terrain brush preserves neighboring ground")
		var walk: WorldTileLayer = current.find_child("Walkable_Mask",true,false) as WorldTileLayer
		var cell: Vector2i = Vector2i(5,5)
		var old_source: int = walk.get_cell_source_id(cell)
		var old_atlas: Vector2i = walk.get_cell_atlas_coords(cell)
		var old_alternate: int = walk.get_cell_alternative_tile(cell)
		walk.erase_cell(cell)
		check(not inside(current.compile_definition().walkable,walk.logical_center(cell)),id+" eraser changes gameplay walkable mask")
		walk.set_cell(cell,old_source,old_atlas,old_alternate)
		var obstacles: WorldTileLayer = current.find_child("Obstacles_TileMap",true,false) as WorldTileLayer
		obstacles.set_cell(cell,0,Vector2i(4,15))
		check(inside(current.compile_definition().blockers,walk.logical_center(cell)),id+" obstacle brush changes gameplay blockers")
		walk.position+=Vector2.ONE
		check(not current.compile_definition().tile_authoring_errors.is_empty(),id+" misplaced projected layer rejected instead of shifting navigation")
		walk.position-=Vector2.ONE
		for habitat: WorldHabitat in after.habitats:
			var author: WorldMonsterRegion = current.get_node("MonsterRegions/"+habitat.habitat_id) as WorldMonsterRegion
			author.shape_source = WorldMonsterRegion.ShapeSource.TILE_BRUSH
			var mask: WorldTileLayer
			for child: Node in WorldAuthorTree.nodes(current,true):
				if child is WorldTileLayer and child.role==WorldTileLayer.Role.SPAWN and child.region_id==habitat.habitat_id: mask=child
			var original_data: PackedByteArray = mask.tile_map_data.duplicate()
			var spawn_cell: Vector2i = mask.get_used_cells()[mask.get_used_cells().size()/2]
			mask.erase_cell(spawn_cell)
			check(not current.compile_definition().habitat(habitat.habitat_id).spawn_domain.contains(mask.logical_center(spawn_cell)),id+" monster spawn eraser updates actual habitat "+habitat.habitat_id)
			mask.clear()
			mask.set_cell(Vector2i.ZERO,0,Vector2i(0,15))
			mask.set_cell(Vector2i(8,8),0,Vector2i(0,15))
			check(not current.compile_definition().tile_authoring_errors.is_empty(),id+" disconnected habitat blocks preview "+habitat.habitat_id)
			mask.tile_map_data = original_data
			author.shape_source = WorldMonsterRegion.ShapeSource.POLYGON
		var packed: PackedScene = PackedScene.new()
		check(packed.pack(current)==OK,id+" edited scene packs with correct owners")
		var path: String = "res://artifacts/world/native-%s-roundtrip.tscn" % id
		check(ResourceSaver.save(packed,path)==OK,id+" native painted scene saves")
		var loaded: WorldMap2D = (ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate() as WorldMap2D
		check(loaded.find_child("Obstacles_TileMap",true,false).get_cell_atlas_coords(cell)==Vector2i(4,15),id+" painting survives reload")
		loaded.free()
		current.free()
		before_root.free()
		geometry_root.free()
	metrics["elapsed_ms"] = Time.get_ticks_msec()-started
	var report: Dictionary = {"passed":passed,"failed":failures.size(),"failures":failures,"metrics":metrics,"editor_brush_manual_gate":"unverified"}
	var file: FileAccess = FileAccess.open("res://artifacts/world/native-tilemap-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("NATIVE_TILEMAP_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
