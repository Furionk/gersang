extends Node
var game: GameDirector
var passed: int = 0
var failed: int = 0
var capture: bool = false
var metrics: Dictionary = {}

func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("PASS | ",title)
	else: failed+=1; push_error("FAIL | "+title)

func _ready() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	get_tree().create_timer(90).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")

func shot(title: String) -> void:
	if not capture or DisplayServer.get_name()=="headless": return
	for i: int in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/shaolin-temple/"+title+".png")

func wait_world() -> void:
	while game.mode!=&"world" or game.world_context.state["mode"]!="EXPLORING": await get_tree().process_frame
	game.set_physics_process(false)
	for i: int in 3: await get_tree().process_frame

func legal(nav: WorldNavigationService, point: Vector2) -> bool:
	return nav.segment_legal("shaolin_temple","","PLAYER",point,point,16)

func run() -> void:
	check(not PartyProgress.persistence_enabled,"temple tests isolate formal progress")
	var original: Dictionary = PartyProgress.serialize().duplicate(true)
	WorldCatalog.initialize()
	var map: WorldMapDefinition = WorldCatalog.definitions["shaolin_temple"]
	var authored: WorldMap2D = load(map.scene_path).instantiate() as WorldMap2D
	check(authored.native_tiles_enabled and map.native_tile_layers.size()==2,"temple saved native floor and obstacle layers")
	check(WorldValidator.validate(map,WorldCatalog.definitions,authored).is_empty(),"enclosed geometry and connected habitat masks validate")
	var nav: WorldNavigationService = WorldNavigationService.new()
	nav.register_map(map)
	var floor: WorldTileLayer = authored.find_child("Ground_TileMap",true,false) as WorldTileLayer
	var walk: WorldTileLayer = authored.find_child("Walkable_Mask",true,false) as WorldTileLayer
	var obstacles: WorldTileLayer = authored.find_child("Obstacles_TileMap",true,false) as WorldTileLayer
	var atlas: TileSetAtlasSource = floor.tile_set.get_source(0) as TileSetAtlasSource
	check(atlas.texture.get_size()==Vector2(320,512) and atlas.get_tiles_count()==80,"external PNG retains all80 courtyard material variants")
	check(not floor.collision_enabled and not floor.navigation_enabled,"projected tiles do not alter protected planar movement")
	var confined: bool = true
	for cell: Vector2i in walk.get_used_cells(): confined = confined and Rect2(256,256,1536,1024).has_point(walk.logical_center(cell))
	check(confined,"every walkable cell is inside physical perimeter walls, away from map edges")
	var closed: bool = true
	var count: int = 0
	for x: int in range(224,1857,32):
		for y: int in [224,1312]:
			closed = closed and not legal(nav,Vector2(x,y))
			count+=1
	for y: int in range(224,1313,32):
		for x: int in [224,1824]:
			closed = closed and not legal(nav,Vector2(x,y))
			count+=1
	metrics["wall_body_samples"] = count
	check(closed,"whole perimeter blocks player bodies including apparent mountain-gate opening")
	for point: Vector2 in [Vector2(0,768),Vector2(2048,768),Vector2(1024,0),Vector2(1024,1536),Vector2(128,768),Vector2(1920,768),Vector2(1024,128),Vector2(1024,1408)]:
		check(not legal(nav,point) and not nav.find_path(map.map_id,"","PLAYER",Vector2(960,1120),point,16)["ok"],"outside wall target rejected "+str(point))
	for corners: Array in [[Vector2(288,288),Vector2(160,160)],[Vector2(1760,288),Vector2(1888,160)],[Vector2(288,1248),Vector2(160,1376)],[Vector2(1760,1248),Vector2(1888,1376)]]:
		check(not nav.segment_legal(map.map_id,"","PLAYER",corners[0],corners[1],16),"diagonal corner cannot escape "+str(corners[1]))
	check(not nav.segment_legal(map.map_id,"","PLAYER",Vector2(640,880),Vector2(640,704),16),"inner wall blocks straight crossing")
	check(nav.segment_legal(map.map_id,"","PLAYER",Vector2(832,880),Vector2(832,704),16),"inner mountain-gate passage remains traversable")
	check(not nav.segment_legal(map.map_id,"","PLAYER",Vector2(1120,640),Vector2(1312,640),16),"side court wall blocks straight crossing")
	check(nav.segment_legal(map.map_id,"","PLAYER",Vector2(1120,928),Vector2(1312,928),16),"side court doorway connects to training yard")
	for point: Vector2 in [Vector2(832,384),Vector2(1504,416),Vector2(640,1072),Vector2(1600,768)]: check(not legal(nav,point),"temple building footprint blocks walking "+str(point))
	for destination: Vector2 in [Vector2(832,640),Vector2(1392,928),Vector2(288,288)]:
		var route: Dictionary = nav.find_path(map.map_id,"","PLAYER",Vector2(960,1120),destination,16)
		var safe_route: bool = route["ok"]
		var points: PackedVector2Array = route["points"]
		for i: int in range(1,points.size()): safe_route = safe_route and nav.segment_legal(map.map_id,"","PLAYER",points[i-1],points[i],16)
		check(safe_route,"reachable courtyard route stays inside walls "+str(destination))
	check(obstacles.get_used_cells().size()>200,"walls and buildings are actual authored obstacle tiles")
	authored.free()
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	await wait_world()
	game.world_hover.set_process(false)
	var context: WorldContext = game.world_context
	check(not context.save.enabled,"integration uses isolated memory world saves")
	var old_parties: Dictionary = context.state["maps"]["river_bay"].duplicate(true)
	context.state["player"]["position"] = Vector2(5152,2336)
	game.world_hero.position = Vector2(5152,2336)
	game.world_pose.reset(game.world_hero.position)
	game.set_process(false)
	game.camera.position = Iso.project(Vector2(5184,2464))+Vector2(130,0)
	var gate_view: WorldSceneryView
	for candidate: WorldSceneryView in game.ground.scenery_views:
		if candidate.portal_id=="shaolin_door": gate_view = candidate
	var opaque: Vector2 = Vector2(128,280)
	for y: int in range(100,400,8):
		for x: int in range(100,400,8):
			if gate_view.mask.get_bit(x,y): opaque = Vector2(x,y); break
		if gate_view.mask.get_bitv(Vector2i(opaque)): break
	var gate_pixel: Vector2 = gate_view.sprite.to_global(opaque)
	check(game.world_hover.pick(gate_pixel)!=null and game.world_hover.pick(gate_pixel).portal_id=="shaolin_door","new temple gate alpha selects real entry")
	await shot("entrance-in-game")
	game.set_process(true)
	context.state["player"]["position"] = Vector2(5184,2464)
	check(context.begin_portal("shaolin_door")["ok"],"exterior entrance starts real temple transition")
	await wait_world()
	check(context.current_map().map_id==map.map_id,"director loads enclosed temple")
	check(context.state["maps"]["river_bay"]==old_parties and PartyProgress.serialize()==original,"temple addition retains original world monsters and party")
	check(game.world_views.size()==12,"D23 twelve temple monster parties")
	var start: Vector2 = context.state["player"]["position"]
	check(not context.move_player(Vector2(1024,1536))["ok"],"real world move command rejects map boundary click")
	for i: int in 90: context.tick(1.0/60.0)
	check(context.state["player"]["position"]==start,"boundary click never moves hero through gate or wall")
	var monster: Dictionary = context.state["maps"][map.map_id]["parties"].values().filter(func(p: Dictionary) -> bool: return p.habitat_id=="bronze_guardian")[0]
	check(monster["deployed_units"].size()>=2 and monster["deployed_units"].size()<=4,"training party contains2–4 actual combatants, not extra representatives")
	var member: Dictionary = monster["deployed_units"][0]
	check(member["level"]>=8 and member["level"]<=10 and member["definition_path"]=="res://features/units/data/monsters/shaolin_guardian.tres","Lv8–10 original bronze staff guardian")
	var definition: UnitDefinition = load(member["definition_path"]) as UnitDefinition
	var texture: Texture2D = load(definition.sprite_path) as Texture2D
	check(definition.sprite_layout.valid_for(texture.get_size()),"authored 48-frame staff atlas validates")
	check(definition.sprite_layout.frame_rects[3].size.x>181,"attack crops preserve staff outside old equal-grid bounds")
	check(SpriteAtlas.frames(texture,definition.sprite_layout).get_animation_names().size()==40,"new monk supports five states in eight directions")
	game.set_process(false)
	game.camera.zoom = Vector2.ONE*0.38
	game.camera.position = Iso.project(Vector2(1024,800))+Vector2(70,0)
	await shot("temple-overview")
	game.camera.zoom = Vector2.ONE*0.82
	context.state["player"]["position"] = Vector2(864,672)
	game.world_hero.position = Vector2(864,672)
	game.world_pose.reset(game.world_hero.position)
	game.camera.position = Iso.project(Vector2(832,600))+Vector2(100,0)
	await shot("main-courtyard")
	context.state["player"]["position"] = Vector2(1376,832)
	game.world_hero.position = Vector2(1376,832)
	game.world_pose.reset(game.world_hero.position)
	game.camera.position = Iso.project(Vector2(1456,880))+Vector2(80,0)
	await shot("training-courtyard")
	var boundary_cursor: Vector2 = game.get_canvas_transform()*Iso.project(Vector2(1904,928))
	context.player_path.clear()
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.position = get_viewport().get_stretch_transform()*boundary_cursor
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	get_viewport().push_input(mouse,false)
	await get_tree().process_frame
	mouse = mouse.duplicate() as InputEventMouseButton
	mouse.pressed = false
	get_viewport().push_input(mouse,false)
	await get_tree().process_frame
	check(context.player_path.is_empty(),"real left click beyond east wall cannot arm an escape route")
	game.set_process(true)
	context.state["player"]["position"] = monster["position"]+Vector2(24,0)
	context.state["player"]["protected_until_ms"] = 0
	context.state["player"]["cooldown_until_ms"] = 0
	check(context.encounters.try_begin("player",monster["party_id"],"player")["ok"],"temple guardian reserves one encounter")
	context.tick(5.1)
	while game.mode!=&"battle": await get_tree().process_frame
	var expected_guardians: int = 0
	for enemy_party: Dictionary in game.battle_snapshot["enemy_party_snapshots"]: expected_guardians += enemy_party["deployed_units"].size()
	check(game.living_ids(1).size()==expected_guardians,"real battle spawns every fixed guardian from the joined batches")
	check(game.encounter.id==&"shaolin_temple" and game.ground.ground_texture!=null,"new temple battle uses courtyard stone material")
	var enemy: TacticalUnit = game.units[game.living_ids(1)[0]]
	check(enemy.definition.id==&"shaolin_guardian" and enemy.persistent_unit_id==member["unit_id"],"real combat keeps guardian sprite and stable ID")
	game.camera.zoom = Vector2.ONE
	await shot("guardian-battle")
	game.retreat()
	game.start_world()
	await wait_world()
	check(context.party(monster["party_id"])["deployed_units"][0]["unit_id"]==member["unit_id"],"retreat preserves same temple guardian")
	context.state["player"]["position"] = Vector2(1024,1248)
	check(context.begin_portal("shaolin_exit")["ok"],"mountain gate portal permits deliberate exit")
	await wait_world()
	check(context.current_map().map_id=="river_bay" and context.state["player"]["position"]==Vector2(5152,2336),"return lands outside exterior trigger")
	check(context.state["control_owner"].is_empty(),"temple return releases transition control")
	var file: FileAccess = FileAccess.open("res://artifacts/shaolin-temple/"+("render-results.json" if capture else "results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"rendered":capture,"metrics":metrics},"\t"))
	file.close()
	print("SHAOLIN_TEMPLE_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
