extends Node
signal notification(text: String)
var context: WorldContext
var last_error: String = ""
var booted: bool = false
var roster_committing: bool = false

func _ready() -> void:
	var isolated: bool = false
	for argument: String in OS.get_cmdline_args():
		if argument.begins_with("res://tests/") or argument.begins_with("res://tools/") or argument == "--isolated-world-tests" or argument.begins_with("res://features/battle/maps/"):
			isolated = true
	context = WorldContext.new()
	context.initialize(PartyProgress.serialize(),42047,isolated)
	context.notification.connect(func(text: String) -> void: notification.emit(text))
	if not isolated:
		var saved: Dictionary = context.save.load_best()
		if not saved.is_empty():
			var paths_changed: bool = UnitResourcePaths.rewrite_saved_paths(saved) if context.save.valid(saved) else false
			if validate_content(saved) and PartyProgress.restore(saved["progress"]):
				context.publish(saved)
				if paths_changed: context.population_layout_changed=true
				recover()
				if context.population_layout_changed:
					var migrated: Dictionary = context.checkpoint()
					if not migrated.ok:
						context.paused = true
						last_error = "新增怪區／位置更新保存失敗；原檔保留，請重試："+str(migrated.reason)
					else:
						context.population_layout_changed = false
			else:
				context.save.protected = true
				last_error = "世界存檔內容版本／單位配置不相容；原檔保留。"
		elif context.save.protected or PartyProgress.save_protected:
			context.save.protected = true
			last_error = "原存檔不相容；禁止覆寫，請從備份恢復。"
	# One complete save owner. Legacy save remains an untouched migration source.
	if not context.save.protected:
		PartyProgress.persistence_enabled = false
	PartyProgress.changed.connect(_progress_changed)
	booted = true
	if OS.has_feature("web"):
		var stocks: Array=[]
		for record: CharacterRecord in PartyProgress.records+PartyProgress.reserves:
			var medicine: int=0; var books: int=0
			for cell: Dictionary in record.bag:
				if cell.item==&"debug_medicine": medicine+=cell.count
				if cell.item==&"debug_exp_book": books+=cell.count
			stocks.append([medicine,books])
		print("WEB_DEMO_READY ",JSON.stringify({"active":PartyProgress.records.size(),"reserve":PartyProgress.reserves.size(),"maps":context.map_definitions.size(),"items":ItemCatalog.all_items().size(),"stocks":stocks,"persistent":OS.is_userfs_persistent()}))

func validate_content(data: Dictionary) -> bool:
	if not context.save.valid(data) or not WorldCatalog.definitions.has(data["player"].get("map_id","")):
		return false
	data=data.duplicate(true)
	UnitResourcePaths.rewrite_saved_paths(data)
	for map_id: String in data["maps"]:
		if not WorldCatalog.definitions.has(map_id):
			return false
		var map: WorldMapDefinition = context.map_definitions[map_id]
		var runtime: Dictionary = data["maps"][map_id]
		var layout_version: Variant = runtime.get("definition_version",1)
		if not layout_version is int or layout_version<1 or layout_version>map.content_version: return false
		var upgrade: bool = WorldPopulationLayout.can_upgrade(map,runtime)
		for party: Dictionary in data["maps"][map_id].get("parties",{}).values():
			if not party.has("slot_id") or not data["maps"][map_id]["slots"].has(party["slot_id"]):
				return false
			if data["maps"][map_id]["slots"][party["slot_id"]].get("party_id","") != party.get("party_id",""):
				return false
			if WorldCatalog.definitions[map_id].habitat(party.get("habitat_id","")) == null:
				return false
			for unit: Dictionary in party.get("deployed_units",[]):
				if not ResourceLoader.exists(unit.get("definition_path","")):
					return false
				var definition: UnitDefinition = load(unit["definition_path"]) as UnitDefinition
				if definition == null or definition.content_revision != unit.get("definition_revision",-1):
					return false
			if not party["position"].is_finite() or not party.get("home") is Vector2 or not party["home"].is_finite(): return false
			if not upgrade and not context.navigation.segment_legal(map_id,party["habitat_id"],"CHASE",party["position"],party["position"],map.habitat(party["habitat_id"]).profile.radius):
				# A finite, repairable pose is not a corrupt/incompatible save.
				if not WorldPositionRecovery.replacement(context,map,party).ok: return false
	return true

func recover() -> void:
	var session: Dictionary = context.state["active_encounter"]
	if not session.is_empty():
		var id: String = session["encounter_id"]
		if context.state["applied_results"].has(id):
			context.ensure_map(context.state["player"]["map_id"])
			context.encounters.complete_return(id)
		else:
			context.state["progress"] = session["progress_before"].duplicate(true)
			PartyProgress.restore(context.state["progress"])
			context.state["player"]["map_id"] = session["return_map_id"]
			context.state["player"]["position"] = session["return_position"]
			context.encounters.cancel(id,"RECOVER_PRE_BATTLE",true)
	elif context.state["mode"] == "TRANSITION":
		context.state["control_owner"] = ""
		context.state["mode"] = "EXPLORING"
	context.ensure_map(context.state["player"]["map_id"])
	for runtime:Dictionary in context.state.maps.values():
		if MonsterBalanceRefresh.apply(context,runtime):context.population_layout_changed=true
	if WorldPositionRecovery.repair(context): context.population_layout_changed = true
	context.refresh_player(context.state["progress"])

func _progress_changed(_slot: int) -> void:
	if not booted or roster_committing or context.state["mode"] != "EXPLORING":
		return
	context.refresh_player(PartyProgress.serialize())
	var saved: Dictionary = context.checkpoint()
	if not saved["ok"]:
		notification.emit("保存失敗：" + str(saved["reason"]))

func save_exploration() -> Dictionary:
	if context.state["mode"] == "EXPLORING":
		context.refresh_player(PartyProgress.serialize())
		return context.checkpoint()
	return {"ok":true,"reason":"KEEP_ENCOUNTER_CHECKPOINT"}

func change_mercenary_roster(operation: String, identifier: String, slot: int = -1) -> Dictionary:
	if not DemoRules.tools_enabled() or context==null or context.paused or context.state.mode!="EXPLORING" or context.state.control_owner!="":
		return {"ok":false,"reason":"請在大地圖、未遇怪時管理傭兵倉庫。"}
	var before: Dictionary = PartyProgress.serialize()
	var progress: Dictionary = {}
	match operation:
		"recruit": progress=MercenaryRoster.recruit(before,identifier)
		"exchange": progress=MercenaryRoster.exchange(before,identifier,slot)
		"deposit": progress=MercenaryRoster.deposit(before,slot)
		"withdraw": progress=MercenaryRoster.withdraw(before,identifier)
	if progress.is_empty() or MercenaryRoster.decode(progress).is_empty():
		return {"ok":false,"reason":"無可用席位、倉庫已滿、候補無效，或選中了固定主角位。"}
	var candidate: Dictionary = context.snapshot()
	candidate.progress=progress
	candidate.revision+=1
	var projection: WorldContext = WorldContext.new()
	projection.state=candidate
	projection.refresh_player(progress)
	candidate=projection.state
	# Save the complete candidate before publishing either roster or world state.
	var saved: Dictionary = context.save.commit(candidate)
	if not saved.ok: return {"ok":false,"reason":"保存失敗，隊伍尚未變更："+str(saved.reason)}
	roster_committing=true
	PartyProgress.restore(progress,false)
	context.publish(candidate)
	context.refresh_player(progress)
	PartyProgress.changed.emit(PartyProgress.selected_slot)
	roster_committing=false
	var messages: Dictionary={"recruit":"Lv1 傭兵已加入倉庫並保存。","exchange":"已交換；原兵完整留在倉庫。","deposit":"已存入倉庫；經驗、裝備及背包完整保留。","withdraw":"已從倉庫取出，加入出戰隊伍並保存。"}
	return {"ok":true,"reason":messages[operation]}
