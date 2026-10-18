extends Node
var game: GameDirector
func _ready() -> void:
	get_tree().create_timer(25).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func save(caption: String) -> void:
	await get_tree().create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(TestArtifacts.output("world_hud","world-hud-"+caption+".png"))
func run() -> void:
	print("ART_SIZES | characters=",CharacterArt.SHEET.get_size()," skin=",ClassicSkin.ATLAS.get_size())
	PartyProgress.records[0].add_experience(140)
	PartyProgress.records[1].add_experience(20)
	PartyProgress.records[3].add_experience(50)
	PartyProgress.records[0].health = 180
	PartyProgress.records[0].mana = 50
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	get_window().gui_disable_input = true
	for extent: Vector2i in [Vector2i(1024,768),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(800,450),Vector2i(900,900)]:
		game.hud.world_hud.close_windows()
		get_window().size = extent
		for frame: int in 8: await get_tree().process_frame
		await save("%dx%d" % [extent.x,extent.y])
		print("LAYOUT | ",extent," status=",game.hud.world_hud.status_panel.get_global_rect()," map=",game.hud.world_hud.map_panel.visible," toolbar=",game.hud.world_hud.toolbar[0].size," level=",game.hud.world_hud.hero_level.get_global_rect())
	get_window().size = Vector2i(1024,768)
	for frame: int in 8: await get_tree().process_frame
	game.hud.world_hud._select(3)
	await save("standee")
	game.hud.world_hud.toggle_map()
	var button: Button = game.hud.world_hud.map_panel.get_child(game.hud.world_hud.map_panel.get_child_count()-1) as Button
	print("BUTTON_LAYOUT | rect=",button.get_global_rect()," text=",button.text," font=",button.get_theme_font_size("font_size")," min=",button.get_minimum_size()," margins=",button.get_theme_stylebox("normal").get_minimum_size())
	print("STYLE_OFFSET | ",button.get_theme_stylebox("normal").get_offset()," content=",button.get_theme_stylebox("normal").get_margin(SIDE_TOP)," fontheight=",button.get_theme_font("font").get_height(11))
	await save("map")
	game.hud.world_hud.close_windows()
	game.hud.world_hud._toolbar(5)
	await save("guild")
	game.hud.world_hud.close_windows()
	game.hud.progression.toggle_inventory()
	await save("inventory")
	print("GERSANG_WORLD_HUD_VISUAL_PASS")
	get_tree().quit(0)
