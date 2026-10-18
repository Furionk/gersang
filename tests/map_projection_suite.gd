extends Node
var game: GameDirector
var passed: int = 0
var failures: Array[String] = []
var rendered: bool

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("PASS | ",title)
	else:
		failures.append(title)
		push_error("FAIL | "+title)

func _ready() -> void:
	rendered = DisplayServer.get_name()!="headless"
	get_tree().create_timer(100).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")

func mouse(control: Control, local: Vector2, button: MouseButton) -> void:
	var at: Vector2 = get_viewport().get_stretch_transform()*control.get_global_transform()*local
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	get_viewport().push_input(motion,false)
	await get_tree().process_frame
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.button_index = button
	event.pressed = true
	get_viewport().push_input(event,false)
	await get_tree().process_frame
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	get_viewport().push_input(event,false)
	await get_tree().process_frame

func run() -> void:
	check(not PartyProgress.persistence_enabled and not WorldSession.context.save.enabled,"projection suite isolates real saves")
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.world_hover.set_process(false)
	var hud: WorldHud = game.hud.world_hud
	var view: CartographicMap = hud.map_view
	for id: String in ["river_bay","qingling_town","well_1","well_2","millennium_lake"]:
		var data: WorldMapDefinition = game.world_context.map_definitions[id]
		game.world_context.state["player"]["map_id"] = id
		game.world_context.state["player"]["position"] = data.entries.values()[0]["point"]
		game.start_world()
		while game.mode!=&"world": await get_tree().process_frame
		hud.refresh()
		hud.toggle_map()
		for frame: int in 5: await get_tree().process_frame
		view.refresh()
		check(hud.map_title.text.contains(data.display_name) and hud.listed_map==data,id+" current map title and list")
		check(not game.hud.item_debug_launcher.visible,id+" map title is clear of debug overlay")
		check(view.source==hud.minimap.source and view.map_viewport.world_2d==view.source.viewport.world_2d,id+" isolated shared native canvas")
		check(view.source.presentation.find_children("*","TacticalUnit",true,false).is_empty(),id+" map canvas has no gameplay actors")
		for layer: WorldTileLayerData in data.native_tile_layers:
			var shown: TileMapLayer = view.source.presentation.find_child(layer.layer_name,false,false) as TileMapLayer
			check(shown!=null and shown.tile_set==layer.tile_set and shown.tile_map_data==layer.cells and not shown.collision_enabled and not shown.navigation_enabled,id+" exact authored layer "+layer.layer_name)
		check(view.source.ground.scenery_views.size()==data.scenery.size(),id+" all authored scenery rendered")
		check(hud.map_places.get_child_count()==data.portals.size()+data.landmarks.size()+data.entries.size(),id+" complete current portals landmarks arrivals")
		var points: Array[Vector2] = [Vector2.ZERO,data.extent,data.extent*0.5,game.world_hero.position]
		for place: Dictionary in view.locations(): points.append(place["point"])
		for point: Vector2 in points:
			var at: Vector2 = view.logical_to_screen(point)
			var pixels: Vector2 = Vector2(view.map_viewport.size)/view.size
			check(view.screen_to_logical(at).distance_to(point)<0.01 and (view.map_viewport.canvas_transform*Iso.project(point)/pixels).distance_to(at)<0.01,id+" scene camera and marker agree "+str(point))
		check(hud.minimap.player_screen.distance_to(hud.minimap.size*0.5)<0.01,id+" local camera centered on player")
		var original: Dictionary = game.world_context.snapshot()
		var first: Button = hud.map_places.get_child(0) as Button
		await mouse(first,first.size*0.5,MOUSE_BUTTON_LEFT)
		check(view.selected_point==data.portals[0]["point"] and hud.map_panel.visible and not hud.info_panel.visible,id+" native list click locates exact portal inside map")
		check(game.world_context.snapshot()==original and game.world_hero.active.is_empty(),id+" map location leaves gameplay state untouched")
		var clicked: Array[Vector2] = []
		var record_click: Callable = func(point: Vector2) -> void: clicked.append(point)
		view.place_selected.connect(record_click)
		var portal: Vector2 = data.portals[0]["point"]
		await mouse(view,view.logical_to_screen(portal),MOUSE_BUTTON_LEFT)
		check(not clicked.is_empty() and clicked[-1]==portal,id+" native marker click returns authored portal coordinate")
		view.place_selected.disconnect(record_click)
		var cursor: Vector2 = view.size*0.5+Vector2(42,17)
		var before_zoom: Vector2 = view.screen_to_logical(cursor)
		await mouse(view,cursor,MOUSE_BUTTON_WHEEL_UP)
		check(view.zoom>1 and view.screen_to_logical(cursor).distance_to(before_zoom)<0.01,id+" wheel zoom preserves location under cursor")
		var before_drag: Vector2 = view.focus
		var press: InputEventMouseButton = InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_RIGHT
		press.pressed = true
		view._gui_input(press)
		var drag: InputEventMouseMotion = InputEventMouseMotion.new()
		drag.relative = Vector2(20,10)
		view._gui_input(drag)
		press.pressed = false
		view._gui_input(press)
		check(view.focus!=before_drag and not view.dragging,id+" drag updates map camera and releases")
		view.overview()
		check(view.zoom==1 and view.focus==Vector2(0.5,0.5),id+" overview restores full floor")
		for button_name: String in ["MapOverview","MapPlayerLocation","MapClose"]:
			var button: Button = hud.map_panel.get_node(button_name) as Button
			check(hud.map_panel.get_global_rect().encloses(button.get_global_rect()),id+" visible footer control "+button_name)
		var player_button: Button = hud.map_panel.get_node("MapPlayerLocation") as Button
		await mouse(player_button,player_button.size*0.5,MOUSE_BUTTON_LEFT)
		check(view.selected_point==game.world_hero.position and view.selected_name=="你的位置",id+" native player-location button")
		var overview_button: Button = hud.map_panel.get_node("MapOverview") as Button
		await mouse(overview_button,overview_button.size*0.5,MOUSE_BUTTON_LEFT)
		check(view.zoom==1 and view.selected_name.is_empty(),id+" native overview button clears selection")
		var close_button: Button = hud.map_panel.get_node("MapClose") as Button
		await mouse(close_button,close_button.size*0.5,MOUSE_BUTTON_LEFT)
		check(not hud.map_panel.visible and not hud.is_modal(),id+" native close button releases modal")
		hud.toggle_map()
		for frame: int in 3: await get_tree().process_frame
		check(hud.map_panel.visible and view.drawn_map_id==id and view.zoom==1,id+" reopen retains correct scene and resets camera")
		if rendered:
			for frame: int in 5: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image: Image = view.map_viewport.get_texture().get_image()
			var colors: Dictionary = {}
			var opaque: int = 0
			for y: int in range(0,image.get_height(),12):
				for x: int in range(0,image.get_width(),12):
					var color: Color = image.get_pixel(x,y)
					if color.a>0.5:
						opaque+=1
						colors[color.to_html()]=true
			check(opaque>100 and colors.size()>40,id+" native camera produces textured terrain and scenery")
			get_viewport().get_texture().get_image().save_png("res://artifacts/world/projected-map-"+id+".png")
		for extent: Vector2i in [Vector2i(800,450),Vector2i(1920,1080),Vector2i(900,900)]:
			get_window().size = extent
			for frame: int in 3: await get_tree().process_frame
			hud.refresh()
			var screen: Rect2 = get_viewport().get_visible_rect()
			check(screen.encloses(hud.map_panel.get_global_rect()) and hud.map_panel.get_global_rect().encloses(view.get_global_rect()),id+" full map stays inside window "+str(extent))
			check(view.screen_to_logical(view.logical_to_screen(portal)).distance_to(portal)<0.01,id+" resized portal alignment "+str(extent))
		get_window().size = Vector2i(1280,720)
		await get_tree().process_frame
		if rendered and id=="well_2":
			get_window().size = Vector2i(800,450)
			for frame: int in 5: await get_tree().process_frame
			hud.refresh()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://artifacts/world/projected-map-small.png")
			get_window().size = Vector2i(1280,720)
			hud.close_windows()
			hud.refresh()
			for frame: int in 5: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://artifacts/world/projected-minimap-well_2.png")
		hud.close_windows()
	game.queue_free()
	await get_tree().process_frame
	var report: Dictionary = {"passed":passed,"failed":failures.size(),"failures":failures,"rendered":rendered}
	var file: FileAccess = FileAccess.open("res://artifacts/world/map-projection-%s-results.json" % ("render" if rendered else "headless"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("MAP_PROJECTION_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
