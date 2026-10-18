extends Node
var passed: int = 0
var failed: int = 0
func check(ok: bool, label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failed+=1
func _ready() -> void: call_deferred("run")
func run() -> void:
	var native: Sprite2D = Sprite2D.new()
	native.texture=load("res://art/terrain/props.png")
	native.region_enabled=true; native.region_rect=Rect2(0,0,512,512)
	native.hframes=2; native.vframes=2; native.frame_coords=Vector2i(1,1)
	native.centered=false; native.offset=Vector2(-128,-244)
	var clone: Sprite2D = Sprite2D.new()
	NativeScenery.copy_sprite(native,clone)
	check(clone.hframes==2 and clone.vframes==2 and clone.frame_coords==Vector2i(1,1),"native Sprite frame settings survive editor snapshot copy")
	var root: Node2D = Node2D.new(); root.add_child(native)
	var entry: Dictionary = NativeScenery.entry(native,root)
	check(entry.definition.atlas_region==Rect2(256,256,256,256) and entry.definition.foot_anchor==Vector2(128,244),"native sheet frame and foot offset compile to exact runtime region")
	root.free(); clone.free()
	var moves: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://specs/unit_resource_moves.json"))
	var identities: Dictionary = {}
	for old_path: String in moves:
		var definition: UnitDefinition = load(moves[old_path])
		check(definition!=null and UnitResourcePaths.canonical(old_path)==moves[old_path],"canonical definition "+definition.display_name)
		identities[definition.id]=true
	var discovered: Dictionary={}
	for definition: UnitDefinition in UnitResourcePaths.definitions(): discovered[definition.id]=true
	check(identities.size()==32 and identities.keys().all(func(id: StringName) -> bool: return discovered.has(id)),"all32 original definitions still discoverable after folder move; additive units allowed")
	check(UnitResourcePaths.canonical("res://unknown/no.tres")=="res://unknown/no.tres","unknown resource paths never rewritten")
	var progress: Dictionary = PartyProgress.serialize()
	var fixture: Dictionary = {"progress":progress.duplicate(true),"maps":{"old":{"parties":{"x":{"representative_path":"res://features/units/data/beast.tres","deployed_units":[{"definition_path":"res://features/units/data/gunner.tres","unit_id":"keep","level":50,"current_hp":12.0}]}}}},"applied_results":{"receipt":{"gold":123}}}
	check(UnitResourcePaths.rewrite_saved_paths(fixture),"legacy nested snapshot paths migrate")
	check(fixture.progress==progress and fixture.maps.old.parties.x.deployed_units[0].unit_id=="keep" and fixture.maps.old.parties.x.deployed_units[0].level==50 and fixture.applied_results.receipt.gold==123,"migration preserves progress identities levels vitals receipts")
	check(not UnitResourcePaths.rewrite_saved_paths(fixture),"path migration idempotent")
	for file: String in DirAccess.get_files_at("res://artifacts/editor-workflow-2026-10-11/scenery-before"):
		if not file.ends_with(".tscn"): continue
		var battle: bool = file.begins_with("battle-")
		var scene_name: String = file.trim_prefix("battle-").trim_prefix("world-")
		var source: Node2D = load("res://artifacts/editor-workflow-2026-10-11/scenery-before/"+file).instantiate()
		var current: Node2D = load(("res://features/battle/maps/" if battle else "res://features/world/data/")+scene_name).instantiate()
		var exact: bool = true
		var count: int = 0
		for node: Node in WorldAuthorTree.nodes(source):
			if not node is Node2D or node.get_child_count()!=1 or not node.get_child(0) is Sprite2D or node.get_child(0).name!=&"Artwork": continue
			var path: NodePath = source.get_path_to(node)
			var flat: Node = current.get_node_or_null(path)
			if not flat is Sprite2D: continue # Entrances/landmarks intentionally keep logic.
			var old_art: Sprite2D = node.get_child(0)
			var old_transform: Transform2D = WorldAuthorTree.canvas_transform(old_art,source)
			var new_transform: Transform2D = WorldAuthorTree.canvas_transform(flat,current)
			var old_origin: Vector2 = old_transform*old_art.offset
			var new_origin: Vector2 = new_transform*flat.offset
			exact=exact and old_origin.distance_to(new_origin)<0.001 and old_transform.x.is_equal_approx(new_transform.x) and old_transform.y.is_equal_approx(new_transform.y) and flat.position.is_equal_approx(node.position)
			if node is WorldAuthorNode: exact=exact and str(flat.get_meta("world_scenery_id",""))==node.stable_id
			count+=1
		check(count>0 and exact,scene_name+" single-sprite artwork pixels / foot sort / stable IDs preserved")
		if current is WorldMap2D:
			var a: WorldMapDefinition = source.compile_definition()
			var b: WorldMapDefinition = current.compile_definition()
			check(a.entries==b.entries and a.portals==b.portals and nav(a)==nav(b),scene_name+" entrances and navigation untouched")
			var snap: Dictionary = WorldAuthoringSnapshot.compile(current)
			check(snap.definition.scenery.size()==b.scenery.size(),scene_name+" detached editor snapshot includes native sprites")
			var runtime: Node2D = Node2D.new(); add_child(runtime)
			var ground: GroundMap = GroundMap.new(); ground._build_exploration_props(runtime,b)
			check(ground.scenery_views.size()==b.scenery.size(),scene_name+" every authored native sprite appears in runtime")
			runtime.free(); ground.free()
		else:
			if scene_name=="millennium_lake.tscn":
				check(current.get_node("SpawnZones/Position_3").capacity==54 and current.get_node("SpawnZones/Position_3").position==source.get_node("SpawnZones/Position_3").position,"approved lake Capacity54 changes no spawn position")
				source.get_node("SpawnZones/Position_3").capacity=54 # explicit user-approved capacity-only delta
			var before_errors: Array = BattlefieldCompiler.compile(source).errors
			var after_errors: Array = BattlefieldCompiler.compile(current).errors
			if not after_errors.is_empty(): print("EXISTING_DRAFT_ERRORS ",scene_name," ",after_errors)
			check(after_errors==before_errors,scene_name+" native battle validation identical before/after flatten")
		source.free(); current.free()
	print("EDITOR_WORKFLOW_DATA_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
func nav(map: WorldMapDefinition) -> PackedByteArray:
	var values: Array = []
	for domains: Array[PolygonDomain] in [map.walkable,map.blockers,map.safe_areas]:
		for shape: PolygonDomain in domains: values.append([shape.outer,shape.holes])
	return var_to_bytes(values)
