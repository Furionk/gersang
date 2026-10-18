extends Node
const APPROVED_CONTENT = preload("res://tests/world/approved_content_changes.gd")
var passed: int = 0
var failures: Array[String] = []
var game: GameDirector
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("PASS | ",title)
	else: failures.append(title); push_error("FAIL | "+title)
func _ready() -> void:
	get_tree().create_timer(60).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func click(at: Vector2) -> void:
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.position = get_viewport().get_stretch_transform()*at
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	get_viewport().push_input(mouse,false)
	await get_tree().process_frame
	mouse = mouse.duplicate() as InputEventMouseButton
	mouse.pressed = false
	get_viewport().push_input(mouse,false)
	await get_tree().process_frame
func capture(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://artifacts/world/entrance-%s.png" % id)
	var green: int = 0
	for y: int in range(70,image.get_height()-100):
		for x: int in range(300,image.get_width()-280):
			var color: Color = image.get_pixel(x,y)
			if color.g>0.85 and color.r<0.4 and color.b<0.3: green+=1
	check(green>60,id+" actual rendered green silhouette pixels "+str(green))
func opaque_pixel(view: WorldSceneryView) -> Vector2:
	for y: int in range(96,410,8):
		for x: int in range(96,410,8):
			if view.mask.get_bit(x,y): return Vector2(x,y)
	return Vector2(256,256)
func run() -> void:
	check(not PartyProgress.persistence_enabled,"scenery tests cannot write formal progress")
	WorldCatalog.initialize()
	for id: String in ["river_bay","qingling_town","well_1","well_2"]:
		var before: WorldMap2D = preload("res://tests/world/legacy_scene_fixture.gd").load_scene("res://artifacts/scenery-2026-10-10/original-scenes/%s.tscn" % id).instantiate() as WorldMap2D
		var old: WorldMapDefinition = before.compile_definition()
		var current: WorldMapDefinition = WorldCatalog.definitions[id]
		var routes_preserved: bool = current.extent==old.extent
		for portal: Dictionary in APPROVED_CONTENT.portal_baseline(id,old.portals): routes_preserved = routes_preserved and portal in current.portals
		for key: String in old.entries: routes_preserved = routes_preserved and current.entries.get(key)==old.entries[key]
		# Added routes are allowed; old routes stay exact except explicit user approvals.
		check(routes_preserved,id+" sprite authoring preserves every pre-existing portal route")
		check(not current.scenery.is_empty(),id+" scenery is native saved scene data")
		var portals: int = 0
		for entry: Dictionary in current.scenery:
			if not str(entry["portal_id"]).is_empty(): portals+=1
			check(entry["definition"]!=null,id+" valid sprite "+str(entry["id"]))
		check(portals==current.portals.size(),id+" each actual entrance has exactly one sprite")
		before.free()
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.world_hover.set_process(false)
	var hover: WorldHoverController = game.world_hover
	for id: String in ["river_bay","qingling_town","well_1","well_2"]:
		game.world_context.state["player"]["map_id"] = id
		game.world_context.state["player"]["position"] = WorldCatalog.definitions[id].entries.values()[0]["point"]
		game.start_world()
		while game.mode!=&"world": await get_tree().process_frame
		var view: WorldSceneryView
		for candidate: WorldSceneryView in game.ground.scenery_views:
			if not candidate.portal_id.is_empty(): view=candidate; break
		check(view!=null and view.mask!=null,id+" runtime entrance has cached alpha mask")
		game.camera.position = view.position-Vector2(0,70)
		game.camera.force_update_scroll()
		await get_tree().process_frame
		var pixel: Vector2 = opaque_pixel(view)
		var cursor: Vector2 = view.sprite.get_global_transform_with_canvas()*pixel
		check(view.hit_test(view.sprite.to_global(pixel)),id+" silhouette opaque pixel is interactive")
		check(not view.hit_test(view.sprite.to_global(Vector2.ZERO)),id+" transparent atlas padding clicks through")
		hover.update_hover(cursor,false)
		check(hover.selected==view and view.highlighted and hover.overlay.visible,id+" hover highlights exactly the entrance")
		check(hover.overlay.heading.text==view.title and not hover.overlay.description.text.is_empty(),id+" tooltip shows authored name and description")
		check(hover.overlay.mouse_filter==Control.MOUSE_FILTER_IGNORE,id+" following tooltip does not steal clicks")
		var material: ShaderMaterial = view.sprite.material
		check(material.get_shader_parameter("highlighted")==1.0,id+" silhouette shader active")
		await get_tree().process_frame
		await get_tree().process_frame
		hover.overlay.follow_cursor(cursor)
		check(hover.overlay.size.y<200*GameSettings.profile.ui_scale,id+" tooltip shrinks to compact content height")
		await capture(id)
		hover.update_hover(cursor,true)
		check(not view.highlighted and not hover.overlay.visible,id+" hovering GUI clears world feedback")
		hover.update_hover(cursor,false)
		game.hud.progression.toggle_inventory()
		hover.update_hover(cursor,false)
		check(not hover.overlay.visible and not view.highlighted,id+" character modal cancels hover")
		game.hud.close_windows()
		hover.update_hover(cursor,false)
		game.world_context.player_path.clear()
		var player_before: Vector2 = game.world_context.state.player.position
		await click(cursor)
		var portal: Dictionary = WorldCatalog.definitions[id].portals.filter(func(entry: Dictionary) -> bool: return entry.id==view.portal_id)[0]
		var route: PackedVector2Array = game.world_context.player_path
		var legal: bool = not route.is_empty() and route[-1].distance_to(view.logical_point)<=portal.radius and game.world_context.state.player.position==player_before
		var previous: Vector2 = player_before
		for point: Vector2 in route:
			legal=legal and game.world_context.navigation.segment_legal(id,"","PLAYER",previous,point,16)
			previous=point
		check(legal,id+" left-click sprite legally approaches within trigger radius without teleport")
		game.mode = &"countdown"
		hover.update_hover(cursor,false)
		check(not hover.overlay.visible and not view.highlighted,id+" countdown clears hover and does not arm portal")
		game.mode = &"world"
		for extent: Vector2i in [Vector2i(800,450),Vector2i(1920,1080)]:
			get_window().size = extent
			await get_tree().process_frame
			hover.overlay.present(view,Vector2(extent)-Vector2(4,4))
			await get_tree().process_frame
			hover.overlay.follow_cursor(Vector2(extent)-Vector2(4,4))
			check(get_viewport().get_visible_rect().encloses(hover.overlay.get_global_rect()),id+" tooltip clamped at "+str(extent))
		get_window().size = Vector2i(1280,720)
		await get_tree().process_frame
		hover.clear()
	var report: Dictionary = {"passed":passed,"failed":failures.size(),"failures":failures,"rendered":DisplayServer.get_name()!="headless","physical_mouse_manual_gate":"unverified"}
	var file: FileAccess = FileAccess.open("res://artifacts/world/scenery-%s-results.json" % ("headless" if not report["rendered"] else "render"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("WORLD_SCENERY_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
