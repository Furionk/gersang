extends Node
var passed: int=0
var failed: int=0
func check(ok: bool,label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failed+=1
func _ready() -> void:
	WorldCatalog.initialize()
	var font: Font=load("res://art/fonts/NotoSansCJKtc-Regular.otf")
	var glyphs_ok: bool=true
	for letter: String in "千年湖少林寺大補丸經驗之書咒咒虐啊哇呾喀呾啦暴擊召喚":
		glyphs_ok=glyphs_ok and font.has_char(letter.unicode_at(0))
	check(glyphs_ok,"bundled font covers world and combat Chinese")
	var context: WorldContext=WorldContext.new()
	context.initialize(PartyProgress.serialize(),42047,true)
	var river: WorldMapDefinition=context.map_definitions.river_bay
	for portal: Dictionary in river.portals:
		if portal.target_map_id not in ["shaolin_temple","millennium_lake"]: continue
		var target: WorldMapDefinition=context.map_definitions.get(portal.target_map_id)
		check(target!=null and target.entries.has(portal.target_entry_id),"destination exists "+portal.id)
		if target==null or not target.entries.has(portal.target_entry_id): continue
		var point: Vector2=target.entries[portal.target_entry_id].point
		check(context.navigation.segment_legal(target.map_id,"","PLAYER",point,point,16),"arrival walkable "+portal.id+" "+str(point))
		var route: Dictionary=context.navigation.find_portal_approach(river.map_id,river.entries.start.point,portal.point,portal.radius,16)
		check(route.ok,"reachable "+portal.id+" "+str(route.get("reason")))
		if route.ok:
			context.state.player.position=route.points[-1]
			var result: Dictionary=context.begin_portal(portal.id)
			check(result.ok and context.state.player.map_id==target.map_id,"transition "+portal.id)
			if result.ok: context.complete_portal(result.token)
			context.state.player.map_id=river.map_id; context.state.player.position=river.entries.start.point
	var owner: CharacterRecord=PartyProgress.records[0]
	check(DemoRules.SETUP.starting_counts==[50,25],"initial medicine50 books25")
	owner.health=1; owner.mana=0
	for i: int in owner.bag.size():
		if owner.bag[i].item!=&"debug_medicine": continue
		var before: int=owner.bag[i].count
		var result: Dictionary=PartyItemService.use_item(owner,i,PartyProgress.records)
		check(result.ok and owner.health>1 and owner.mana>0 and owner.bag[i].count==before-1,"medicine heals and consumes exactly one")
	var game: GameDirector=load("res://main.tscn").instantiate(); add_child(game)
	while game.mode!=&"world": await get_tree().process_frame
	game.start_battle(Catalog.encounters()[0])
	while game.mode!=&"battle": await get_tree().process_frame
	var actor: TacticalUnit=game.get_unit(game.roster_ids[0])
	actor.vitals.health=0; actor.vitals.mana=0
	game.selection.select_ids([actor.unit_id])
	game.hud.quick_medicine.pressed.emit()
	check(actor.alive() and actor.vitals.health>0 and actor.vitals.mana>0,"quick medicine revives and heals in battle")
	print("WEB_REPAIRS_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
