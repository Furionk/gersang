extends Node
var game: GameDirector
var passed: int = 0
var failures: int = 0
func check(condition: bool, caption: String) -> void:
	if condition:
		passed += 1
		print("PASS | ",caption)
	else:
		failures += 1
		push_error("FAIL | "+caption)
func _ready() -> void:
	get_tree().create_timer(35).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	get_viewport().push_input(event,true)
	await get_tree().process_frame
	event = event.duplicate() as InputEventKey
	event.pressed = false
	get_viewport().push_input(event,true)
	await get_tree().process_frame
func click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	get_viewport().push_input(motion,true)
	await get_tree().process_frame
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event,true)
	await get_tree().process_frame
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	get_viewport().push_input(event,true)
	await get_tree().process_frame
func run() -> void:
	LegacyPartyFixture.install()
	check(not PartyProgress.persistence_enabled,"world HUD tests do not touch player's save")
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	await get_tree().create_timer(0.15).timeout
	var world: WorldHud = game.hud.world_hud
	check(world.visible and not game.hud.root.get_node("Header").visible and not game.hud.root.get_node("BattleDock").visible,"world replaces legacy header and battle dock")
	check(world.roster_buttons.size()==12 and world.roster_buttons[7].disabled,"roster reserves twelve positions without fabricating mercenaries")
	var regions: Array[Rect2] = []
	for i: int in 7:
		var data: UnitDefinition = PartyProgress.records[i].definition
		var portrait: AtlasTexture = CharacterArt.texture(data,"eyes") as AtlasTexture
		check(data.illustration_index==i and portrait.atlas==CharacterArt.SHEET and portrait.atlas.resource_path!=data.sprite_path,"independent portrait assigned to role %d" % i)
		regions.append(portrait.region)
	check(regions[0]!=regions[1] and regions[1]!=regions[2] and regions[3]!=regions[6],"portrait regions are distinct")
	check(not world.point_buttons[2].visible,"no points means no plus marker")
	PartyProgress.records[2].add_experience(20)
	PartyProgress.records[2].health = float(PartyProgress.records[2].stats()["health"])*0.5
	PartyProgress.records[2].mana = float(PartyProgress.records[2].stats()["mana"])*0.25
	world.refresh()
	check(world.point_buttons[2].visible and is_equal_approx(world.hp_bars[2].value,50) and is_equal_approx(world.mp_bars[2].value,25),"live HP MP and unspent points update independently")
	await click(world.roster_buttons[2])
	check(PartyProgress.selected_slot==2 and game.hud.progression.inventory_panel.visible and not world.standee_panel.visible and game.hud.progression.portrait.texture==CharacterArt.texture(PartyProgress.records[2].definition),"native portrait click opens unified dossier with matching full-body art")
	check(game.world_hero.active.is_empty(),"portrait does not issue world movement")
	await key(KEY_I)
	await click(world.point_buttons[2])
	check(game.hud.progression.stat_panel.visible and not world.standee_panel.visible and PartyProgress.selected_slot==2,"plus marker opens selected stat panel without auto-allocation")
	await key(KEY_S)
	await click(world.toolbar[0])
	check(game.hud.progression.inventory_panel.visible and game.hud.progression.portrait.texture==CharacterArt.texture(PartyProgress.records[2].definition),"inventory uses independent full-body illustration not battle sprite")
	await key(KEY_I)
	await click(world.toolbar[5])
	check(world.info_panel.visible and world.info_title.text=="商團資料" and world.info_text.text.contains("本機"),"guild button opens explicit offline state")
	await key(KEY_ESCAPE)
	await click(world.toolbar[6])
	check(world.info_title.text=="朋友資料" and world.info_text.text.contains("未連線"),"friend button does not invent online friends")
	await key(KEY_ESCAPE)
	await click(world.toolbar[7])
	check(game.hud.window.visible,"bottom right icon opens travel menu")
	game.hud.show_settings()
	check(game.hud.settings_panel.visible,"settings remains accessible")
	check(game.hud.settings_panel.find_children("WorldTrial_*","Button",true,false).size()==4,"settings retains three terrain and stress trial entries")
	game.hud.close_windows()
	await key(KEY_M)
	check(world.map_panel.visible and game.hud.is_modal_open(),"M opens projected full map")
	game.world_hero.position = Vector2(700,600)
	world.refresh()
	var mapped: Vector2 = world.map_view.to_uv(Vector2(700,600))
	check(world.minimap.player_uv.is_equal_approx(mapped) and world.map_view.player_screen.is_equal_approx(world.map_view.logical_to_screen(Vector2(700,600))),"map marker follows native scene projection")
	check(world.minimap.player_screen.is_equal_approx(world.minimap.size*0.5) and world.minimap.source==world.map_view.source,"local map stays player-centered and shares native scenery")
	await key(KEY_M)
	check(not world.map_panel.visible,"second M closes map")
	world.chat_input.grab_focus()
	world.chat_input.text = "[img]res://not-a-texture[/img] local"
	await key(KEY_ENTER)
	check(world.entries[-1]["text"].contains("[img]") and not world.messages.bbcode_enabled and world.chat_input.text=="","local chat displays literal text without markup execution")
	world.chat_input.release_focus()
	check(world.battle_power.text.contains(str(PowerCalculator.make_summary(game.world_context.state["player_party"])["power"])) and world.credit_level.text.contains("—"),"battle power uses authored rating while credit remains pending")
	for extent: Vector2i in [Vector2i(1024,768),Vector2i(1920,1080),Vector2i(800,450),Vector2i(900,900)]:
		get_window().size = extent
		for frame: int in 8: await get_tree().process_frame
		var rect: Rect2 = get_viewport().get_visible_rect()
		check(rect.encloses(world.status_panel.get_global_rect()) and rect.encloses(world.actions_panel.get_global_rect()),"footer stays visible at %s" % extent)
		check(is_equal_approx(world.status_panel.get_global_rect().end.y,rect.end.y) and is_equal_approx(world.actions_panel.get_global_rect().end.x,rect.end.x),"footer remains edge-anchored at %s" % extent)
		check(not world.status_panel.get_global_rect().intersects(world.log_panel.get_global_rect()) and not world.log_panel.get_global_rect().intersects(world.actions_panel.get_global_rect()),"three footer panels do not overlap at %s" % extent)
	get_window().size = Vector2i(1280,720)
	game.start_battle(Catalog.encounters()[0])
	while game.mode!=&"battle": await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	check(not world.visible and game.hud.root.get_node("BattleDock").visible,"combat returns to existing command and skill HUD")
	game.start_world()
	while game.mode!=&"world": await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	check(world.visible and not world.is_modal(),"return to world restores classic HUD without stale windows")
	print("GERSANG_WORLD_HUD_%s | passed=%d failed=%d" % ["PASS" if failures==0 else "FAIL",passed,failures])
	get_tree().quit(0 if failures==0 else 1)
