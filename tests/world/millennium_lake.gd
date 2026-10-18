extends Node
var game: GameDirector
var failed: int = 0
var passed: int = 0
var capture: bool = false

func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("PASS | ",title)
	else: failed+=1; push_error("FAIL | "+title)

func _ready() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	get_tree().create_timer(65).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")

func shot(title: String) -> void:
	if not capture or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/millennium-lake/"+title+".png")

func wait_world() -> void:
	while game.mode!=&"world" or game.world_context.state["mode"]!="EXPLORING": await get_tree().process_frame
	game.set_physics_process(false)
	for i: int in 3: await get_tree().process_frame

func run() -> void:
	check(not PartyProgress.persistence_enabled,"test cannot read or overwrite formal progress")
	var original: Dictionary = PartyProgress.serialize().duplicate(true)
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	await wait_world()
	var context: WorldContext = game.world_context
	check(not context.save.enabled,"test world uses memory saves")
	var map: WorldMapDefinition = WorldCatalog.definitions["millennium_lake"]
	check(WorldValidator.validate(map,WorldCatalog.definitions).is_empty(),"native lake geometry, habitats and portal destination validate")
	check(map.native_tile_layers.size()==2,"saved ground and obstacle TileMapLayers")
	var atlas: TileSetAtlasSource = map.native_tile_layers[0].tile_set.get_source(0) as TileSetAtlasSource
	check(atlas.texture.get_size()==Vector2(320,512) and atlas.get_tiles_count()==80,"external atlas reloads all 80 material variants")
	var nav: WorldNavigationService = context.navigation
	check(not nav.segment_legal(map.map_id,"","PLAYER",Vector2(896,704),Vector2(896,704),16),"deep water rejects player body")
	check(not nav.segment_legal(map.map_id,"","PLAYER",Vector2(32,640),Vector2(32,640),16),"boundary rock wall rejects player body")
	check(nav.segment_legal(map.map_id,"","PLAYER",Vector2(1168,560),Vector2(1168,848),16),"wood bridge connects northern shore to shrine island")
	check(nav.find_path(map.map_id,"","PLAYER",Vector2(352,352),Vector2(1568,1216),16)["ok"],"entrance can reach guardian shore around water")
	var baseline_maps: Dictionary = context.state["maps"].duplicate(true)
	context.state["player"]["position"] = Vector2(4736,2368)
	game.world_hero.position = context.state["player"]["position"]
	game.world_pose.reset(game.world_hero.position)
	game.camera.position = Iso.project(Vector2(4608,2464))+Vector2(130,0)
	game.set_process(false)
	game.world_hover.set_process(false)
	game.world_hover.clear()
	for i: int in 3: await get_tree().process_frame
	var gate_pixel: Vector2 = Iso.project(Vector2(4608,2464))+Vector2(0,-100)
	var picked: WorldSceneryView = game.world_hover.pick(gate_pixel)
	check(picked!=null and picked.portal_id=="lake_door","new entrance sprite opacity picks correct portal")
	game.world_hover.update_hover(game.get_canvas_transform()*gate_pixel,false)
	await shot("entrance-in-game")
	game.world_hover.clear()
	game.set_process(true)
	context.state["player"]["position"] = Vector2(4608,2464)
	var entered: Dictionary = context.begin_portal("lake_door")
	check(entered["ok"],"exterior portal acquires transition and enters lake")
	await wait_world()
	check(context.state["player"]["map_id"]==map.map_id,"real director loads lake map")
	check(context.state["maps"]["river_bay"]==baseline_maps["river_bay"],"adding lake leaves original monster IDs and members intact")
	check(PartyProgress.serialize()==original,"entering lake retains party progression")
	check(game.world_views.size()==1,"exactly one roaming monster representative")
	var monster: Dictionary = context.state["maps"][map.map_id]["parties"].values()[0]
	check(monster["deployed_units"].size()==1,"representative resolves exactly one combat member")
	var member: Dictionary = monster["deployed_units"][0]
	check(member["level"]==6 and member["definition_path"]=="res://features/units/data/monsters/lake_guardian.tres","authored solo Lv6 lake guardian")
	var definition: UnitDefinition = load(member["definition_path"]) as UnitDefinition
	var texture: Texture2D = load(definition.sprite_path) as Texture2D
	check(definition.sprite_layout.valid_for(texture.get_size()),"48 authored frames match source atlas")
	var frames: SpriteFrames = SpriteAtlas.frames(texture,definition.sprite_layout)
	check(frames.get_animation_names().size()==40,"eight directions support idle walk attack cast and death")
	for i: int in 8:
		check(frames.get_frame_count(StringName("walk_%d" % i))==2,"two walking phases direction %d" % i)
	game.set_process(false)
	game.camera.position = Iso.project(map.extent*0.5)+Vector2(65,0)
	game.camera.zoom = Vector2.ONE*0.3
	await shot("lake-overview")
	game.camera.zoom = Vector2.ONE*0.8
	context.state["player"]["position"] = Vector2(1472,1248)
	game.world_hero.position = Vector2(1472,1248)
	game.world_pose.reset(game.world_hero.position)
	game.camera.position = Iso.project(Vector2(1320,1016))+Vector2(60,0)
	await shot("lake-in-game")
	game.set_process(true)
	context.state["player"]["position"] = monster["position"]+Vector2(24,0)
	context.state["player"]["protected_until_ms"] = 0
	context.state["player"]["cooldown_until_ms"] = 0
	var began: Dictionary = context.encounters.try_begin("player",monster["party_id"],"player")
	check(began["ok"],"click encounter reserves guardian")
	context.tick(5.1)
	while game.mode!=&"battle": await get_tree().process_frame
	check(game.living_ids(1).size()==1,"real RTS spawns only one guardian")
	check(game.encounter.id==&"millennium_lake" and game.ground.ground_texture!=null,"lake-specific arena uses newly generated earth material")
	var enemy: TacticalUnit = game.units[game.living_ids(1)[0]]
	check(enemy.persistent_unit_id==member["unit_id"] and enemy.definition.id==&"lake_guardian","combat preserves guardian identity and new sprite")
	game.camera.zoom = Vector2.ONE
	await shot("guardian-battle")
	game.retreat()
	game.start_world()
	await wait_world()
	check(context.party(monster["party_id"])["deployed_units"][0]["unit_id"]==member["unit_id"],"retreat restores same guardian without reroll")
	context.state["player"]["position"] = Vector2(224,224)
	var returned: Dictionary = context.begin_portal("lake_exit")
	check(returned["ok"],"lake exit permits return")
	await wait_world()
	check(context.state["player"]["map_id"]=="river_bay" and context.state["player"]["position"]==Vector2(4736,2368),"return arrives outside entrance trigger")
	check(context.state["control_owner"].is_empty(),"return releases transition control")
	var file: FileAccess = FileAccess.open("res://artifacts/millennium-lake/"+("render-results.json" if capture else "results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"rendered":capture},"\t"))
	file.close()
	print("MILLENNIUM_LAKE_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
