extends Node
var passed: int = 0
var failures: Array[String] = []
var game: GameDirector
func check(condition: bool, caption: String) -> void:
	if condition: passed += 1; print("PASS | ",caption)
	else: failures.append(caption); push_error("FAIL | "+caption)
func _ready() -> void:
	get_tree().create_timer(40).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new(); motion.position = at; get_viewport().push_input(motion,true)
	await get_tree().process_frame
	var event: InputEventMouseButton = InputEventMouseButton.new(); event.position = at; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	get_viewport().push_input(event,true)
	await get_tree().process_frame
	event = event.duplicate() as InputEventMouseButton; event.pressed = false; get_viewport().push_input(event,true)
	await get_tree().process_frame
func find_cell(record: CharacterRecord,id: StringName) -> int:
	for i: int in record.bag.size():
		if record.bag[i]["item"] == id: return i
	return -1
func run() -> void:
	LegacyPartyFixture.install()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://specs/sources/items52.json"))
	var counts: Dictionary = {}
	for row: Dictionary in source["items"]:
		var item: GearItemDefinition = ItemCatalog.get_item(StringName(row["id"]))
		check(item != null,"ITEM source definition " + row["id"])
		if item == null: continue
		counts[item.category] = int(counts.get(item.category,0))+1
		check(item.weight == float(row["weight"]) and item.required_level == int(row["level"]) and item.modifiers == row.get("modifiers",{}),"ITEM source numbers " + row["id"])
		check(item.icon != null and not item.source_image_url.is_empty(),"ITEM source icon " + row["id"])
	for category: String in ["armor","sword","staff","spear","axe","gun","food"]:
		check(counts.get(category,0)==5,"ITEM five per category " + category)
	var record: CharacterRecord = CharacterRecord.new(); record.initialize(Catalog.party()[0],"item_fixture",false)
	var before_stats: Dictionary = record.stats()
	check(record.grant_and_equip(&"gs_wood_staff"),"ITEM direct equip to a blank slot")
	check(is_equal_approx(record.stats()["attack_min"],before_stats["attack_min"]+1) and is_equal_approx(record.stats()["attack_max"],before_stats["attack_max"]+1),"ITEM exact additive attack interval")
	var original_definition_hash: String = FileAccess.get_sha256("res://features/progression/data/items/source52/gs_training_staff.tres")
	check(record.grant_and_equip(&"gs_training_staff"),"ITEM staff swap retains previous weapon")
	check(find_cell(record,&"gs_wood_staff")>=0,"ITEM old weapon goes to bag")
	check(record.stats()["intelligence"] == before_stats["intelligence"]+20 and record.stats()["mana"]>before_stats["mana"],"ITEM intelligence bonus changes mana")
	check(record.grant_and_equip(&"gs_samurai_coat"),"ITEM armor equips independently of weapon")
	check(record.stats()["strength"] == before_stats["strength"]+5 and record.stats()["defense"]>=10,"ITEM armor strength and defense are active")
	check(record.add_item(&"gs_bun",1),"ITEM food can be collected")
	var food_index: int = find_cell(record,&"gs_bun")
	var snapshot: Dictionary = record.serialize()
	check(not record.use_item(food_index) and record.serialize()==snapshot,"ITEM food has no invented healing effect or consumption")
	var low: CharacterRecord = CharacterRecord.new(); low.initialize(Catalog.party()[0],"low",false)
	check(low.add_item(&"gs_fine_long_sword",1),"ITEM high-level weapon fits bag")
	var weapon_index: int = find_cell(low,&"gs_fine_long_sword")
	var low_before: Dictionary = low.serialize()
	check(not low.use_item(weapon_index) and low.serialize()==low_before,"ITEM normal equip enforces level without partial mutation")
	check(low.use_item(weapon_index,true) and low.equipment_skills().size()==1,"ITEM debug level bypass and equipment skill")
	check(low.unequip(&"weapon") and low.equipment_skills().is_empty(),"ITEM unequip removes granted skill")
	check(record.add_item(&"debug_exp_book",3),"ITEM grant zero-weight experience books")
	var book: int = find_cell(record,&"debug_exp_book")
	var level: int = record.level()
	check(record.use_item(book) and record.level()==level+1,"ITEM book grants exactly one level")
	record.experience = CharacterRecord.CURVE.threshold(100)
	var capped: Dictionary = record.serialize()
	check(not record.use_item(book) and record.serialize()==capped,"ITEM level cap does not consume book")
	var party: Array[CharacterRecord] = []
	for i: int in 3:
		var member: CharacterRecord = CharacterRecord.new(); member.initialize(Catalog.party()[0],"recover_%d" % i,false)
		member.health = 0 if i==1 else 10; member.mana = 0; party.append(member)
	party[0].add_item(&"debug_medicine",1)
	var recovered: Dictionary = PartyItemService.use_item(party[0],find_cell(party[0],&"debug_medicine"),party)
	check(recovered["ok"] and party.all(func(member: CharacterRecord) -> bool: return member.health>0 and member.health<=member.stats()["health"] and member.mana==member.stats()["mana"]),"ITEM medicine revives and clamps whole party")
	var loaded: CharacterRecord = CharacterRecord.new(); loaded.initialize(record.definition,record.persistent_id,false)
	check(loaded.restore(record.serialize()) and loaded.equipment==record.equipment,"ITEM new IDs survive save round-trip")
	check(FileAccess.get_sha256("res://features/progression/data/items/source52/gs_training_staff.tres")==original_definition_hash,"ITEM shared definition remains immutable")
	var full: CharacterRecord = CharacterRecord.new(); full.initialize(Catalog.party()[0],"weight_fixture",false); full.max_weight = 0
	var full_before: Dictionary = full.serialize()
	check(not full.grant_and_equip(&"gs_old_gun",true) and full.serialize()==full_before,"ITEM overweight direct equip is atomic")
	game = load("res://main.tscn").instantiate() as GameDirector; add_child(game); game.audio.muted = true
	while game.mode != &"world": await get_tree().process_frame
	game.set_physics_process(false)
	var panel: ItemDebugPanel = game.hud.item_debug
	check(panel != null and OS.is_debug_build(),"ITEM debug panel is available in debug build")
	game.select_world_slot(2)
	await click(game.hud.root.get_node("OpenItemDebug"))
	check(panel.visible and panel.current_slot==2 and game.hud.is_modal_open(),"ITEM native button opens selected soldier debug panel")
	var movement: PackedVector2Array = game.world_context.player_path.duplicate()
	panel.selected = ItemCatalog.get_item(&"debug_exp_book"); panel.perform("grant")
	check(find_cell(PartyProgress.records[2],&"debug_exp_book")>=0 and game.world_context.player_path==movement,"ITEM grant targets selected soldier without ground input")
	panel.selected = ItemCatalog.get_item(&"gs_training_staff"); panel.perform("equip")
	check(PartyProgress.records[2].equipment[&"weapon"]==&"gs_training_staff" and PartyProgress.records[0].equipment[&"weapon"]==&"","ITEM direct equip does not affect another soldier")
	panel.hide()
	game.start_battle(Catalog.encounters()[0])
	while game.mode != &"battle": await get_tree().process_frame
	game.set_physics_process(false)
	var service: ItemDebugService = panel.service
	var permanent: Dictionary = PartyProgress.serialize()
	var battle: Array[CharacterRecord] = service.records()
	check(service.perform(&"gs_fine_long_sword","equip",4,1,true)["ok"],"ITEM combat debug equips temporary character")
	var healer: TacticalUnit = game.get_unit(game.roster_ids[4])
	game.selection.select_ids([healer.unit_id])
	check(healer.available_skills().any(func(skill: SkillDefinition) -> bool: return skill.id==&"blast") and game.selection.visible_skills().any(func(entry: Dictionary) -> bool: return entry["skill"].id==&"blast"),"ITEM equipment skill appears in selected unit skill bar")
	var wounded: TacticalUnit = game.get_unit(game.roster_ids[1]); wounded.vitals.damage_resolved(99999)
	check(not wounded.alive() and wounded.fsm.current==&"dead","ITEM revive fixture is actually dead")
	service.perform(&"debug_medicine","grant",4)
	check(service.perform(&"debug_medicine","use",4)["ok"] and wounded.alive() and wounded.fsm.current!=&"dead" and wounded.collision_layer==2,"ITEM medicine restores combat state and collision")
	check(PartyProgress.serialize()==permanent,"ITEM combat debug does not mutate permanent party")
	var before_slot: int = battle[4].level()
	service.perform(&"debug_exp_book","grant",4)
	check(service.perform(&"debug_exp_book","use",4)["ok"] and battle[4].level()==before_slot+1,"ITEM battle book levels only temporary target")
	check(PartyProgress.serialize()==permanent,"ITEM temporary level is not leaked to save")
	var ally: TacticalUnit = game.get_unit(game.roster_ids[2]); ally.vitals.health = 20
	var ally_before: float = ally.vitals.health
	service.perform(&"debug_exp_book","grant",4)
	service.perform(&"debug_exp_book","use",4)
	check(ally.vitals.health == ally_before,"ITEM single-target book cannot heal unrelated allies")
	var report: Dictionary = {"passed":passed,"failed":failures.size(),"failures":failures,"definitions":source["items"].size(),"engine":Engine.get_version_info()["string"]}
	var output: FileAccess = FileAccess.open("res://artifacts/world/items-results.json",FileAccess.WRITE); output.store_string(JSON.stringify(report,"\t")); output.close()
	print("ITEMS_SUITE_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
