extends Node
var passed: int=0
var failed: int=0
var checks: Array[Dictionary]=[]
const OUT: String="res://artifacts/demo-web-2026-10-11/"
func check(ok: bool,label: String) -> void:
	checks.append({"test":label,"pass":ok}); print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failed+=1
func _ready() -> void:
	get_tree().create_timer(60).timeout.connect(func()->void:get_tree().quit(2)); call_deferred("run")
func run() -> void:
	check(not WorldSession.context.save.enabled,"isolated saves disabled")
	check(PartyProgress.records.size()==10 and PartyProgress.reserves.size()==1,"ten active and one reserve")
	check(PartyProgress.records[0].level()==1 and PartyProgress.reserves[0].definition.id==&"teppo","main Lv1 and teppo reserve")
	var unique: Dictionary={}
	for record: CharacterRecord in PartyProgress.records+PartyProgress.reserves:
		check(not unique.has(record.definition.id),"unique "+String(record.definition.id)); unique[record.definition.id]=true
		if record!=PartyProgress.records[0]: check(record.level()==25 and record.points()==96,"Lv25 with unallocated96 "+String(record.definition.id))
		for id: StringName in DemoRules.SETUP.starting_items:
			var count: int=0
			for cell: Dictionary in record.bag:
				if cell.item==id: count+=cell.count
			var expected: int=DemoRules.SETUP.starting_counts[DemoRules.SETUP.starting_items.find(id)]
			check(count==expected,"stock"+str(expected)+" "+String(record.definition.id)+"/"+String(id))
	check(MercenaryRoster.recruit(PartyProgress.serialize(),Catalog.PARTY_PATHS[1]).is_empty(),"permanent recruiting disabled")
	check(DemoRules.slot_for_key(KEY_0)==9 and DemoRules.slot_for_key(KEY_9)==8,"number mapping1 through0")
	check(WorldSession.context.save.path.contains(DemoRules.SETUP.save_namespace) and PartyProgress.save_path.contains(DemoRules.SETUP.save_namespace),"separate old-save namespace")
	var game: GameDirector=load("res://main.tscn").instantiate(); add_child(game)
	while game.mode!=&"world": await get_tree().process_frame
	var old: Dictionary=PartyProgress.records[1].serialize()
	var swap: Dictionary=WorldSession.change_mercenary_roster("exchange",PartyProgress.reserves[0].persistent_id,1)
	check(swap.ok and PartyProgress.records[1].definition.id==&"teppo" and PartyProgress.reserves[0].serialize()==old,"swap retains original full record")
	var before: Dictionary=PartyProgress.serialize().duplicate(true)
	var context: WorldContext=WorldSession.context
	context.save.enabled=true; context.save.path="user://demo_atomic_test_%d.dat"%OS.get_process_id(); context.save.fail_writes=1
	var snapshot: Dictionary=context.snapshot()
	check(not WorldSession.change_mercenary_roster("exchange",PartyProgress.reserves[0].persistent_id,1).ok,"failed save blocks publication")
	check(context.snapshot()==snapshot and PartyProgress.serialize()==before,"failed swap preserves full state")
	check(WorldSession.change_mercenary_roster("exchange",PartyProgress.reserves[0].persistent_id,1).ok,"retry swap succeeds once")
	check(context.save.load_best().progress==PartyProgress.serialize(),"disk snapshot matches published roster")
	context.save.enabled=false; before=PartyProgress.serialize().duplicate(true)
	game.hud.toggle_item_debug(); game.hud.item_debug.storage.refresh()
	check(PartyProgress.serialize()==before,"opening warehouse grants no stock")
	check(not game.hud.item_debug.storage.recruit_button.visible,"no recruit button")
	if DisplayServer.get_name()!="headless":
		await get_tree().process_frame; await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT+"team-tools.png")
	game.hud.close_windows(); game.start_battle(Catalog.encounters()[0])
	while game.mode!=&"battle": await get_tree().process_frame
	check(game.roster_ids.size()==10 and game.living_ids(0).size()==10,"ten units deploy in native battle scene")
	game.selection.select_ids(game.roster_ids)
	check(game.selection.selected_ids.size()==10,"ten-unit selection")
	game.finish_battle("retreat"); game.start_world()
	while game.mode!=&"world": await get_tree().process_frame
	check(PartyProgress.records.size()==10 and PartyProgress.reserves.size()==1,"return retains roster counts")
	var result: Dictionary={"passed":passed,"failed":failed,"checks":checks}
	var file: FileAccess=FileAccess.open(OUT+("headless.json" if DisplayServer.get_name()=="headless" else "render.json"),FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	print("DEMO_ROSTER_RESULT ",JSON.stringify(result)); get_tree().quit(0 if failed==0 else 1)
