extends Node
var game: GameDirector
var passed: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var notifications: int = 0

func check(ok: bool, caption: String) -> void:
	observations.append({"test":caption,"pass":ok})
	if ok:
		passed += 1
		print("PASS | ",caption)
	else:
		failures.append(caption)
		push_error("FAIL | "+caption)
func _ready() -> void:
	get_tree().create_timer(50).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	get_viewport().push_input(event,true)
	await get_tree().process_frame
	event = event.duplicate() as InputEventKey
	event.pressed = false
	get_viewport().push_input(event,true)
	await get_tree().process_frame
func click(control: Control, shift: bool = false) -> void:
	var modifier: InputEventKey = InputEventKey.new()
	modifier.keycode = KEY_SHIFT
	modifier.physical_keycode = KEY_SHIFT
	modifier.pressed = shift
	Input.parse_input_event(modifier)
	await get_tree().process_frame
	# Native-window pixels: exercise Godot stretch as well as dossier scale.
	var at: Vector2 = get_viewport().get_stretch_transform()*control.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	get_viewport().push_input(motion,false)
	await get_tree().process_frame
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.shift_pressed = shift
	event.pressed = true
	get_viewport().push_input(event,false)
	await get_tree().process_frame
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	get_viewport().push_input(event,false)
	modifier.pressed = false
	Input.parse_input_event(modifier)
	await get_tree().process_frame

func run() -> void:
	LegacyPartyFixture.install()
	check(not PartyProgress.persistence_enabled,"SHEET-01 isolated player state")
	var record: CharacterRecord = PartyProgress.records[0]
	record.add_experience(CharacterRecord.CURVE.threshold(100))
	record.changed.connect(func() -> void: notifications += 1)
	check(record.allocate("strength",100) and record.allocated["strength"]==100 and record.points()==296,"SHEET-02 bulk allocation spends exactly 100")
	check(notifications==1,"SHEET-02 bulk allocation emits one atomic update")
	check(not record.allocate("strength",0) and not record.allocate("unknown",100) and notifications==1,"SHEET-02 invalid allocation has no mutation")
	record.allocate("strength",100)
	record.allocate("strength",100)
	check(record.allocate("luck",100) and record.allocated["luck"]==96 and record.points()==0,"SHEET-02 remainder capped without overspending")
	check(not record.allocate("luck",100),"SHEET-02 zero remaining rejected")
	var legacy: Dictionary = record.serialize()
	for slot: StringName in [&"hands",&"belt",&"feet",&"ring_left",&"ring_right"]: legacy["equipment"].erase(slot)
	var restored: CharacterRecord = CharacterRecord.new()
	restored.initialize(record.definition,record.persistent_id,false)
	check(restored.restore(legacy) and restored.equipment.size()==9 and restored.allocated==record.allocated,"SHEET-03 old four-slot save migrates without losing allocated points")
	check(restored.equipment[&"hands"]==&"" and restored.equipment[&"ring_left"]==&"","SHEET-03 newly introduced slots empty, no duplicated charms")
	check(GearItemDefinition.Slot.CHARM==3 and GearItemDefinition.Slot.WEAPON==0,"SHEET-03 existing resource enum values unchanged")
	LegacyPartyFixture.install()
	record = PartyProgress.records[0]
	check(record.grant_and_equip(&"gs_fine_long_sword",true),"SHEET-04 equip fixture through existing service")
	var skills: Array[Dictionary] = SkillDescription.owned(record)
	check(skills.size()==2 and skills[1]["origin"].contains("高級長劍"),"SHEET-04 owned skills union includes equipment source")
	var duplicate_owner: CharacterRecord = CharacterRecord.new()
	duplicate_owner.initialize(Catalog.party()[1],"sheet_dedup",false)
	duplicate_owner.grant_and_equip(&"gs_fine_long_sword",true)
	check(SkillDescription.owned(duplicate_owner).size()==duplicate_owner.definition.skills.size(),"SHEET-04 same base and equipment skill merged by ID")
	var skill: SkillDefinition = load("res://features/skills/data/quake.tres")
	var values: Dictionary = record.stats()
	var description: String = SkillDescription.describe(skill,values,"兵種技能",{"defense":0,"armor":0,"magic_resistance":0.5})
	check(description.contains("strength*0.5") and description.contains("20*0.5 = 10.00") and description.contains("每次命中／tick"),"SHEET-05 description uses live attributes and per-tick formula")
	check(description.contains("→ 5.00") and description.contains("每 0.25 秒"),"SHEET-05 magic resistance applied once in preview")
	var translated: SkillDefinition = skill.duplicate(true)
	translated.damage_formula = "(力量 + 智力) × 2"
	check(SkillDescription.formula_values(translated,values).contains("20") and translated.result(values)["value"]==80,"SHEET-05 Chinese aliases and symbols shown using same evaluator")
	translated.damage_formula = "unknown / 0"
	check(SkillDescription.describe(translated,values,"測試",{}).contains("公式無效"),"SHEET-05 invalid formulas never display a fake damage number")
	for name: String in ["supply","heal","summon","ice_wall","critical"]:
		var specific: SkillDefinition = load("res://features/skills/data/%s.tres" % name)
		var text: String = SkillDescription.describe(specific,values,"兵種技能",{})
		var valid: bool = text.contains("回復公式") if name in ["supply","heal"] else text.contains("不造成傷害") if name=="ice_wall" else text.contains("普通攻擊／命中／防禦") if name=="summon" else text.contains("取代該次傷害")
		check(valid,"SHEET-05 distinct mechanism description "+name)
	LegacyPartyFixture.install()
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	var ui: ProgressionPanels = game.hud.progression
	await click(game.hud.world_hud.roster_buttons[6])
	check(ui.sheet.visible and ui.inventory_panel.visible and not ui.stat_panel.visible and not game.hud.world_hud.standee_panel.visible,"SHEET-06 portrait opens one unified inventory")
	check(ui.portrait.texture==CharacterArt.texture(PartyProgress.selected().definition) and ui.portrait.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"SHEET-06 uncropped full body preserves proportions")
	check(ui.equipment_buttons.size()==9 and ui.bag_buttons.size()==10,"SHEET-06 nine equipment slots and ten bag cells")
	check(ui.skill_buttons.size()==PartyProgress.selected().definition.skills.size(),"SHEET-07 only owned skills displayed")
	await click(ui.skill_buttons[-1])
	check(ui.skill_detail.text.contains("黑龍大車輪") and game.world_hero.active.is_empty(),"SHEET-07 skill review does not cast or move")
	await click(ui.roster_buttons[0])
	check(PartyProgress.selected_slot==0 and ui.skill_detail.text.contains("地震術") and not ui.skill_detail.text.contains("黑龍大車輪"),"SHEET-07 selection replaces skills and illustration")
	await key(KEY_S)
	check(ui.stat_panel.visible and not ui.inventory_panel.visible and ui.sheet.visible,"SHEET-08 S changes mode without an overlapping window")
	PartyProgress.selected().add_experience(CharacterRecord.CURVE.threshold(31))
	await click(ui.plus_buttons["strength"],true)
	check(PartyProgress.selected().allocated["strength"]==100 and PartyProgress.selected().points()==20,"SHEET-09 real Shift plus input allocates 100")
	check(ui.skill_detail.text.contains("120*0.5 = 60.00"),"SHEET-09 formula refreshes immediately after bulk allocation")
	check(ui.skill_calculation.text.contains("120*0.5 = 60.00"),"SHEET-09 formula remains visible outside scrolling description")
	(ui.preview_fields["magic_resistance"] as SpinBox).value = 50
	check(ui.skill_calculation.text.contains("傷害 30.00"),"SHEET-09 editable enemy resistance refreshes preview, not character stats")
	check(PartyProgress.selected().stats()["magic_resistance"]==0,"SHEET-09 preview cannot modify gameplay resistance")
	await click(ui.plus_buttons["luck"])
	check(PartyProgress.selected().allocated["luck"]==1 and PartyProgress.selected().points()==19,"SHEET-09 normal click remains +1")
	await click(ui.plus_buttons["agility"],true)
	check(PartyProgress.selected().allocated["agility"]==19 and PartyProgress.selected().points()==0,"SHEET-09 Shift click spends only remaining points")
	check((ui.plus_buttons["strength"] as Button).disabled,"SHEET-09 zero points disables buttons")
	await key(KEY_I)
	check(ui.inventory_panel.visible and not ui.stat_panel.visible,"SHEET-08 I switches mode")
	await click(ui.bag_buttons[0])
	check(PartyProgress.selected().equipment[&"weapon"]==&"blade","SHEET-10 bag click equips selected soldier")
	await click(ui.equipment_buttons[&"weapon"])
	check(PartyProgress.selected().equipment[&"weapon"]==&"","SHEET-10 equipment click removes same item")
	for extent: Vector2i in [Vector2i(800,450),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(900,900),Vector2i(1720,720)]:
		get_window().size = extent
		for frame: int in 8: await get_tree().process_frame
		var viewport: Rect2 = get_viewport().get_visible_rect()
		var fits: bool = true
		for control: Control in ui.equipment_buttons.values()+ui.bag_buttons+ui.roster_buttons:
			fits = fits and viewport.encloses(control.get_global_rect())
		check(fits and viewport.encloses(ui.portrait.get_global_rect()) and viewport.encloses(ui.skill_detail.get_global_rect()),"SHEET-11 all dossier controls inside "+str(extent))
		check(is_equal_approx(ui.canvas.scale.x,ui.canvas.scale.y),"SHEET-11 uniform character aspect "+str(extent))
		var defense_rect: Rect2 = (ui.preview_fields["defense"] as Control).get_global_rect()
		var armor_rect: Rect2 = (ui.preview_fields["armor"] as Control).get_global_rect()
		var magic_rect: Rect2 = (ui.preview_fields["magic_resistance"] as Control).get_global_rect()
		var armor_caption_x: float = (ui.canvas.get_global_transform()*Vector2(982,477)).x
		var magic_caption_x: float = (ui.canvas.get_global_transform()*Vector2(1112,477)).x
		check(not defense_rect.intersects(armor_rect) and not armor_rect.intersects(magic_rect) and defense_rect.end.x<=armor_caption_x and armor_rect.end.x<=magic_caption_x,"SHEET-11 preview controls never overlap captions "+str(extent))
		await click(ui.roster_buttons[3])
		check(PartyProgress.selected_slot==3 and ui.portrait.texture==CharacterArt.texture(PartyProgress.records[3].definition) and ui.skill_entries.any(func(entry: Dictionary) -> bool: return entry["skill"].id==&"dragon"),"SHEET-11 resized GUI selects correct soldier "+str(extent))
		await key(KEY_1)
	check(game.world_hero.active.is_empty(),"SHEET-12 modal background never sends ground command")
	var selected_record: CharacterRecord = PartyProgress.selected()
	var original_definition: UnitDefinition = selected_record.definition
	selected_record.definition = original_definition.duplicate(true) as UnitDefinition
	selected_record.definition.skills.clear()
	selected_record.changed.emit()
	check(ui.skill_buttons.is_empty() and ui.skill_detail.text.contains("沒有技能"),"SHEET-07 empty skill owner clears previous skill review")
	for name: String in ["quake","blast","lightning","supply","heal","wheel","dragon","summon","ice_wall","control","critical"]:
		selected_record.definition.skills.append(load("res://features/skills/data/%s.tres" % name))
	selected_record.changed.emit()
	await get_tree().process_frame
	check(ui.skill_buttons.size()==11 and ui.skill_scroll.get_v_scroll_bar().max_value>ui.skill_scroll.size.y,"SHEET-07 large configurable skill collection scrolls without covering formula")
	ui.skill_scroll.scroll_vertical = 1000
	await get_tree().process_frame
	await click(ui.skill_buttons[-1])
	check(ui.selected_skill==&"critical" and ui.skill_detail.text.contains("被動"),"SHEET-07 third-row skill selectable through native clipped grid")
	selected_record.definition = original_definition
	selected_record.changed.emit()
	check(ui.skill_buttons.size()==1 and ui.skill_calculation.text.contains("strength*0.5"),"SHEET-07 restoring owner clears temporary fixture skills")
	await key(KEY_ESCAPE)
	check(not ui.sheet.visible and not game.hud.is_modal_open(),"SHEET-12 Esc closes dossier before menu")
	await key(KEY_I)
	var monster: Dictionary = game.world_context.state["maps"][game.world_context.current_map().map_id]["parties"].values()[0]
	game.world_context.state["player"]["position"] = monster["position"]+Vector2(5,0)
	game.world_context.state["player"]["protected_until_ms"] = 0
	game.world_context.state["player"]["cooldown_until_ms"] = 0
	var encounter: Dictionary = game.world_context.encounters.try_begin("player",monster["party_id"],"player")
	game._physics_process(1.0/60.0)
	check(encounter["ok"] and game.mode==&"countdown" and game.hud.countdown.visible and not ui.sheet.visible,"SHEET-12 real world encounter closes dossier so 3-2-1 stays visible")
	await key(KEY_ESCAPE)
	check(game.mode==&"world" and not game.hud.countdown.visible and game.world_context.state["active_encounter"].is_empty(),"SHEET-12 cancelling encounter returns normal world UI")
	await key(KEY_I)
	await key(KEY_F2)
	check(game.hud.item_debug.visible and not ui.sheet.visible,"SHEET-12 Debug mutually excludes character sheet")
	game.hud.close_windows()
	game.start_battle(Catalog.encounters()[0])
	while game.mode!=&"battle": await get_tree().process_frame
	check(not ui.sheet.visible,"SHEET-12 battle transition clears character screen")
	var report: Dictionary = {"engine":Engine.get_version_info()["string"],"passed":passed,"failed":failures.size(),"failures":failures,"tests":observations,"rendered":DisplayServer.get_name()!="headless"}
	var file: FileAccess = FileAccess.open("res://artifacts/world/character-sheet-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	if DisplayServer.get_name()!="headless":
		var rendered_report: FileAccess = FileAccess.open("res://artifacts/world/character-sheet-render-results.json",FileAccess.WRITE)
		rendered_report.store_string(JSON.stringify(report,"\t"))
		rendered_report.close()
	print("CHARACTER_SHEET_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
