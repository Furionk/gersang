extends SceneTree
func _initialize() -> void: call_deferred("run")
func report(context: WorldContext, tag: String) -> void:
	print(tag," ",JSON.stringify({"mode":context.state.mode,"owner":context.state.control_owner,"paused":context.paused,"map":context.state.player.map_id,"position":str(context.state.player.position),"player_encounter":context.state.player.encounter_id,"session":context.state.active_encounter.get("state","EMPTY"),"parties":context.state.maps[context.state.player.map_id].parties.size(),"layout":context.state.maps[context.state.player.map_id].get("definition_version",1)}))
func run() -> void:
	var file: FileAccess = FileAccess.open("user://world_state.dat",FileAccess.READ)
	assert(file!=null)
	var data: Dictionary = file.get_var(false)
	file.close()
	var session: Node = root.get_node("WorldSession")
	var progress: Node = root.get_node("PartyProgress")
	var context: WorldContext = session.get("context")
	context.save.enabled = false
	for map_id: String in data.maps:
		for habitat: WorldHabitat in context.map_definitions[map_id].habitats:
			if not habitat.chase_domain.covers_domain(habitat.activity_domain): print("DOMAIN_NOT_NESTED ",map_id," ",habitat.habitat_id)
	print("FRESH_PLAYER_MOVE ",context.move_player(context.state.player.position+Vector2(32,0)))
	print("SAVE_VALID ",context.save.valid(data)," CONTENT_VALID ",session.call("validate_content",data))
	for map_id: String in data.maps:
		var map: WorldMapDefinition = context.map_definitions[map_id]
		var runtime: Dictionary = data.maps[map_id]
		if int(runtime.get("definition_version",1))>map.content_version: print("BAD_LAYOUT ",map_id," saved=",runtime.get("definition_version")," current=",map.content_version)
		for party: Dictionary in runtime.parties.values():
			var habitat: WorldHabitat = map.habitat(party.habitat_id)
			if habitat==null: print("BAD_HABITAT ",map_id," ",party.habitat_id); continue
			if not runtime.slots.has(party.slot_id) or runtime.slots[party.slot_id].party_id!=party.party_id: print("BAD_SLOT ",party.party_id)
			for unit: Dictionary in party.deployed_units:
				if not ResourceLoader.exists(unit.definition_path): print("MISSING_UNIT ",unit.definition_path); continue
				var def: UnitDefinition = load(unit.definition_path) as UnitDefinition
				if def.content_revision!=unit.definition_revision: print("BAD_UNIT_REVISION ",unit.definition_path," saved=",unit.definition_revision," current=",def.content_revision)
			if not WorldPopulationLayout.can_upgrade(map,runtime) and not context.navigation.segment_legal(map_id,party.habitat_id,"CHASE",party.position,party.position,habitat.profile.radius): print("BAD_POSITION ",party.party_id," habitat=",party.habitat_id," position=",party.position)
	context.publish(data)
	progress.call("restore",data.progress)
	report(context,"BEFORE_RECOVER")
	session.call("recover")
	report(context,"AFTER_RECOVER")
	var at: Vector2 = context.state.player.position
	print("MOVE_RESULT ",context.move_player(at+Vector2(32,0)))
	var target: Dictionary = context.state.maps[context.state.player.map_id].parties.values()[0]
	context.state.player.position = target.position+Vector2(5,0)
	context.state.player.cooldown_until_ms = 0
	context.state.player.protected_until_ms = 0
	print("ENCOUNTER_RESULT ",context.encounters.try_begin("player",target.party_id,"player"))
	quit()
