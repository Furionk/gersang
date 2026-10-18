extends Node
const OUT: String = "res://artifacts/depth-sorting-2026-10-11/"
var passed: int = 0
var failed: int = 0
var observations: Array[Dictionary] = []
var graphical: bool
func _ready() -> void:
	graphical=DisplayServer.get_name()!="headless"
	get_tree().create_timer(90).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func check(ok: bool, title: String) -> void:
	observations.append({"test":title,"pass":ok})
	print("PASS | " if ok else "FAIL | ",title)
	if ok: passed+=1
	else: failed+=1; push_error(title)
func geometry(map: WorldMapDefinition) -> PackedByteArray:
	var domains: Array = []
	for group: Array[PolygonDomain] in [map.walkable,map.blockers,map.safe_areas]:
		for domain: PolygonDomain in group: domains.append([domain.outer,domain.holes])
	return var_to_bytes([domains,map.entries,map.portals,map.extent,map.grid_size])
func texture(size: Vector2i, color: Color) -> ImageTexture:
	var pixels: Image = Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	pixels.fill(color)
	return ImageTexture.create_from_image(pixels)
func solid(size: Vector2i, color: Color, point: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture=texture(size,color); sprite.centered=false
	sprite.offset=Vector2(-size.x*0.5,-size.y); sprite.position=point
	return sprite
func run() -> void:
	check(not PartyProgress.persistence_enabled,"SORT-01 isolated player progress")
	var config: WorldSceneryDefinition = WorldSceneryDefinition.new()
	check(config.sorting_mode==ScenerySorting.Mode.DEPTH,"SORT-02 unknown asset defaults to solid, never image-name guessing")
	var fern: WorldSceneryDefinition = load("res://features/world/data/scenery/river_biomes/forest_fern_cover.tres")
	var tree: WorldSceneryDefinition = load("res://features/world/data/scenery/river_biomes/autumn_maple_0.3.tres")
	check(fern.sorting_mode==0 and tree.sorting_mode==1,"SORT-02 reviewed grass below actors, maple depth sorted")
	var sprite: Sprite2D = Sprite2D.new()
	var atlas: AtlasTexture = AtlasTexture.new(); atlas.atlas=fern.texture; atlas.region=fern.region()
	sprite.texture=atlas
	check(ScenerySorting.preset_for(sprite).sorting_mode==0,"SORT-03 exact native texture/crop inherits shared preset")
	sprite.set_meta(ScenerySorting.OVERRIDE_KEY,2)
	check(ScenerySorting.mode_for(sprite)==2 and fern.sorting_mode==0,"SORT-03 local override never mutates shared preset")
	sprite.remove_meta(ScenerySorting.OVERRIDE_KEY)
	check(ScenerySorting.mode_for(sprite)==0,"SORT-03 follow-preset restores classification")
	var appearance: WorldSceneryDefinition = fern.duplicate()
	appearance.sorting_mode=1
	sprite.set_meta("world_scenery_definition",appearance)
	check(ScenerySorting.mode_for(sprite)==0,"SORT-03 embedded legacy appearance copy inherits exact shared sorting")
	sprite.free()
	var changed: Array[int] = [0]
	config.changed.connect(func() -> void: changed[0]+=1)
	config.sorting_mode=0
	check(changed[0]==1,"SORT-04 resource category emits native changed signal")
	for flip: bool in [false,true]:
		var pivot: Sprite2D = solid(Vector2i(64,96),Color.WHITE,Vector2(30,50))
		pivot.rotation=0.43; pivot.scale=Vector2(-0.7,1.3) if flip else Vector2(0.7,1.3); pivot.flip_h=flip
		var before: Transform2D = pivot.transform
		var origin: Vector2 = before*pivot.get_rect().position
		var anchor: Vector2 = Vector2(25,81)
		var values: Dictionary = ScenerySorting.calibration(pivot,anchor)
		pivot.position=values.position; pivot.offset=values.offset
		check((pivot.transform*pivot.get_rect().position).distance_to(origin)<0.001 and pivot.transform.x.is_equal_approx(before.x) and pivot.transform.y.is_equal_approx(before.y),"SORT-05 rotation/mirror foot calibration preserves every pixel "+str(flip))
		check(ScenerySorting.current_anchor(pivot).is_equal_approx(anchor),"SORT-05 calibrated origin is requested image foot "+str(flip))
		pivot.free()
	var source_paths: Array[String] = []
	for file: String in DirAccess.get_files_at("res://features/world/data"):
		if file.ends_with(".tscn"): source_paths.append("res://features/world/data/"+file)
	for file: String in DirAccess.get_files_at("res://features/battle/maps"):
		if file.ends_with(".tscn"): source_paths.append("res://features/battle/maps/"+file)
	for path: String in source_paths:
		var before_path: String = OUT+"before/"+path.trim_prefix("res://")
		check(FileAccess.get_sha256(path)==FileAccess.get_sha256(before_path),"SORT-06 artist scene bytes unchanged "+path.get_file())
		var map: Node2D = load(path).instantiate()
		var old: Node2D = load(before_path).instantiate()
		var transforms: Dictionary = {}
		for node: Node in WorldAuthorTree.nodes(map):
			if node is Node2D: transforms[map.get_path_to(node)]=[node.transform,node.get("offset") if node is Sprite2D else null,node.owner]
		ScenerySorting.apply_map(map)
		var exact: bool = true; var sorted: bool = map.y_sort_enabled; var count: int = 0
		for node: Node in WorldAuthorTree.nodes(map):
			if node is Node2D:
				var expected: Array = transforms[map.get_path_to(node)]
				exact=exact and expected[0]==node.transform and expected[2]==node.owner and (not node is Sprite2D or expected[1]==node.offset)
			if ScenerySorting.is_scenery_sprite(node):
				count+=1
				sorted=sorted and node.z_index==ScenerySorting.z_for(ScenerySorting.mode_for(node)) and not node.z_as_relative
				var parent: Node = node.get_parent()
				while parent!=map:
					if parent is Node2D: sorted=sorted and parent.y_sort_enabled
					parent=parent.get_parent()
		check(exact,path.get_file()+" positions/basis/Offset/owner untouched")
		check(sorted and count>0,path.get_file()+" nested groups join common foot sorting")
		if map is WorldMap2D:
			check(geometry(map.compile_definition())==geometry(old.compile_definition()),path.get_file()+" navigation, portals and arrivals exact")
			var snapshot: Dictionary = WorldAuthoringSnapshot.compile(map)
			check(snapshot.definition.scenery.size()==map.compile_definition().scenery.size(),path.get_file()+" detached editor retains all native scenery")
		else:
			check(BattlefieldCompiler.compile(map).blocked==BattlefieldCompiler.compile(old).blocked and BattlefieldCompiler.compile(map).zones==BattlefieldCompiler.compile(old).zones,path.get_file()+" painted blockers and deployment exact")
		map.free(); old.free()
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"classification.json"))
	var append_only: bool = true
	for row: Dictionary in record.records:
		var old: String = FileAccess.get_file_as_string(OUT+"before/"+String(row.path).trim_prefix("res://"))
		append_only=append_only and FileAccess.get_file_as_string(row.path).begins_with(old)
	check(record.records.size()==129 and append_only,"SORT-07 all129 presets only append sorting metadata; no appearance changes")
	var town: WorldMap2D = load("res://features/world/data/qingling_town.tscn").instantiate()
	var old_geometry: PackedByteArray = geometry(town.compile_definition())
	var parts: Node2D = load("res://features/world/authoring/templates/sorted_gate_parts.tscn").instantiate()
	town.get_node("Scenery").add_child(parts); parts.position=Vector2(300,250); parts.rotation=0.2; parts.scale=Vector2(-0.6,0.8)
	for node: Node in WorldAuthorTree.nodes(parts):
		if node is Sprite2D: node.set_meta("world_scenery_id","test_part_"+String(node.name))
	ScenerySorting.apply_map(town)
	check(WorldValidator.validate(town.compile_definition(),WorldCatalog.definitions,town).is_empty(),"SORT-13 translated/rotated/mirrored visual-only parts prefab accepted")
	check(geometry(town.compile_definition())==old_geometry,"SORT-13 parts prefab never changes walkability or portals")
	check(WorldAuthoringSnapshot.compile(town).errors.is_empty(),"SORT-13 detached editor preserves movable visual-group marker")
	var illegal: WorldTileLayer = WorldTileLayer.new(); parts.add_child(illegal)
	check(WorldValidator.validate(town.compile_definition(),WorldCatalog.definitions,town).any(func(error: String) -> bool: return error.contains("地景分件組只能包含外觀")),"SORT-13 parts container cannot bypass logical TileMap restrictions")
	illegal.free(); town.free()
	if graphical: await pixel_sorting()
	await real_game()
	var result: Dictionary = {"passed":passed,"failed":failed,"tests":observations,"rendered":graphical,"manual_mouse":"unverified"}
	var file: FileAccess = FileAccess.open(OUT+("render-results.json" if graphical else "headless-results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t")); file.close()
	print("DEPTH_SORTING_RESULT passed=",passed," failed=",failed," rendered=",graphical)
	get_tree().quit(0 if failed==0 else 1)
func pixel_sorting() -> void:
	var viewport: SubViewport = SubViewport.new(); viewport.size=Vector2i(300,240); viewport.world_2d=World2D.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; add_child(viewport)
	var root: Node2D = Node2D.new(); root.y_sort_enabled=true; viewport.add_child(root)
	var group: Node2D = Node2D.new(); group.name="Scenery"; root.add_child(group)
	var nested: Node2D = Node2D.new(); group.add_child(nested)
	var tree: Sprite2D = solid(Vector2i(80,120),Color.MAGENTA,Vector2(150,160)); nested.add_child(tree)
	var actor: Sprite2D = solid(Vector2i(24,60),Color.GREEN,Vector2(150,130)); root.add_child(actor)
	ScenerySorting.apply_map(root); ScenerySorting.apply_item(actor)
	for front: bool in [false,true]:
		actor.position.y=190 if front else 130
		await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
		var frame: Image = viewport.get_texture().get_image()
		check(frame.get_pixel(150,145 if front else 100).is_equal_approx(Color.GREEN if front else Color.MAGENTA),"SORT-08 actual GPU nested tree/actor exchange front/back "+str(front))
	tree.hide()
	var grass: Sprite2D = solid(Vector2i(120,120),Color.BLUE,Vector2(150,190)); nested.add_child(grass)
	grass.set_meta(ScenerySorting.OVERRIDE_KEY,0); ScenerySorting.apply_map(root); actor.position.y=130
	await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().get_pixel(150,100).is_equal_approx(Color.GREEN),"SORT-09 low ground sprite never covers actor despite lower footY")
	grass.set_meta(ScenerySorting.OVERRIDE_KEY,2); ScenerySorting.apply_map(root)
	await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().get_pixel(150,100).is_equal_approx(Color.BLUE),"SORT-09 explicitly fixed foreground remains above actor")
	viewport.queue_free(); await get_tree().process_frame
func shot(name_text: String) -> void:
	if not graphical: return
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name_text+".png")
func pose(game: GameDirector, point: Vector2) -> void:
	game.world_hero.position=point; game.world_hero.previous_position=point
	game.world_pose.reset(point); game.world_hero.view._process(0)
	game.camera.position=Iso.project(point)+Vector2(0,-80); game.camera.force_update_scroll()
func real_game() -> void:
	var game: GameDirector = load("res://main.tscn").instantiate(); add_child(game); game.audio.muted=true
	while game.mode!=&"world": await get_tree().process_frame
	game.set_process(false); game.set_physics_process(false)
	check(game.render_root.y_sort_enabled and game.world_hero.view.z_index==0,"SORT-10 world actor and scenery share native Y-sort")
	var maple: WorldSceneryView; var grass: WorldSceneryView
	for candidate: WorldSceneryView in game.ground.scenery_views:
		if maple==null and candidate.title=="秋楓": maple=candidate
		if candidate.definition.sorting_mode==0:
			var covered: bool = false
			for other: WorldSceneryView in game.ground.scenery_views:
				if other.definition.sorting_mode==1 and other.position.y>candidate.position.y and (other.sprite.get_global_transform()*other.sprite.get_rect()).has_point(candidate.position+Vector2(0,-30)): covered=true; break
			if not covered: grass=candidate
	check(maple!=null and grass!=null,"SORT-10 real maple and ground presets present")
	if maple!=null:
		pose(game,maple.logical_point+Vector2(-30,-30)); await shot("world-maple-behind")
		pose(game,maple.logical_point+Vector2(30,30)); await shot("world-maple-front")
	if grass!=null: pose(game,grass.logical_point); await shot("world-ground-cover")
	game.start_battle(Catalog.encounters()[2])
	while game.mode!=&"battle": await get_tree().process_frame
	game.set_physics_process(false); game.set_process(false)
	var all_zero: bool = true
	for unit: TacticalUnit in game.units.values():
		unit.view._process(0); all_zero=all_zero and unit.view.z_index==0
	check(all_zero and game.render_root.y_sort_enabled,"SORT-11 actual battle removes per-frame Y-to-Z for both teams")
	var cavern: Sprite2D
	for node: Node in WorldAuthorTree.nodes(game.render_root):
		if ScenerySorting.is_scenery_sprite(node) and ScenerySorting.mode_for(node)==1:
			if cavern==null or node.global_position.y>cavern.global_position.y: cavern=node
	if cavern!=null:
		var actor: TacticalUnit = game.get_unit(game.roster_ids[0])
		for front: bool in [false,true]:
			actor.position=Iso.unproject(cavern.global_position)+Vector2(30,30)*(1 if front else -1)
			actor.view._process(0); game.camera.position=cavern.global_position+Vector2(0,-50); game.camera.force_update_scroll()
			await shot("cave-"+("front" if front else "behind"))
	game.finish_battle("retreat"); game.start_world()
	while game.mode!=&"world": await get_tree().process_frame
	check(game.world_hero.view.z_index==0 and game.render_root.y_sort_enabled,"SORT-12 return retains world sorting")
	game.queue_free(); await get_tree().process_frame
