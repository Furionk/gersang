extends Node
## Read-only access to the live save. Mutations/commits use an isolated copy only.
func _ready()->void:call_deferred("run")
func run()->void:
	var path:String="C:/Users/Furion Mashiou/AppData/Roaming/Godot/app_userdata/巨雙2.0/demo10-v3_world_state.dat"
	var file:FileAccess=FileAccess.open(path,FileAccess.READ)
	if file==null:push_error("Save not readable");get_tree().quit(1);return
	var raw:Variant=file.get_var(false);file.close()
	var source:Dictionary=raw if raw is Dictionary else {}
	var reports:Dictionary={"valid":WorldSession.context.save.valid(source),"compatible":WorldSession.validate_content(source),"mode":source.get("mode"),"owner":source.get("control_owner"),"active_encounter":source.get("active_encounter",{}).get("state","")}
	if source.is_empty():print(reports);get_tree().quit(1);return
	var context:WorldContext=WorldContext.new();context.initialize(source.progress,42047,true);context.publish(source.duplicate(true))
	var problems:Array=[];var canonical:Dictionary=source.duplicate(true);UnitResourcePaths.rewrite_saved_paths(canonical)
	for map_id:String in canonical.maps:
		var definition:WorldMapDefinition=context.map_definitions.get(map_id)
		if definition==null:problems.append({"map":map_id,"reason":"MISSING_MAP"});continue
		var runtime:Dictionary=canonical.maps[map_id]
		if runtime.get("definition_version",1)>definition.content_version:problems.append({"map":map_id,"reason":"MAP_VERSION","saved":runtime.definition_version,"current":definition.content_version})
		var upgrade:bool=WorldPopulationLayout.can_upgrade(definition,runtime)
		for party:Dictionary in runtime.parties.values():
			if not runtime.slots.has(party.slot_id) or runtime.slots[party.slot_id].party_id!=party.party_id:problems.append({"map":map_id,"reason":"SLOT_MISMATCH","party":party.party_id})
			var habitat:WorldHabitat=definition.habitat(party.habitat_id)
			if habitat==null:problems.append({"map":map_id,"reason":"MISSING_HABITAT","habitat":party.habitat_id});continue
			for member:Dictionary in party.deployed_units:
				var unit:UnitDefinition=load(member.definition_path)
				if unit==null or unit.content_revision!=member.get("definition_revision",-1):problems.append({"map":map_id,"reason":"UNIT_REVISION","path":member.definition_path,"stored":member.get("definition_revision"),"current":unit.content_revision if unit!=null else -1})
			if not upgrade and not context.navigation.segment_legal(map_id,party.habitat_id,"CHASE",party.position,party.position,habitat.profile.radius):
				if not WorldPositionRecovery.replacement(context,definition,party).ok:problems.append({"map":map_id,"reason":"NO_POSE_RECOVERY","habitat":party.habitat_id})
	reports.content_problems=problems
	context.save.path="user://entry_diagnosis_%d.dat"%OS.get_process_id();context.save.enabled=true
	var commit:Dictionary=context.checkpoint();reports.disk_commit=commit
	for map_id:String in context.map_definitions:
		var errors:Array=WorldValidator.validate(context.map_definitions[map_id],context.map_definitions)
		if not errors.is_empty():reports["map_errors_"+map_id]=errors
	var map:WorldMapDefinition=context.current_map();reports.player_position=context.state.player.position;reports.player_map=map.map_id
	var routes:Array=[]
	for portal:Dictionary in map.portals:
		var route:Dictionary=context.navigation.find_portal_approach(map.map_id,context.state.player.position,portal.point,portal.radius,16)
		routes.append({"portal":portal.id,"target":portal.target_map_id,"route_ok":route.ok,"reason":route.get("reason","")})
	reports.portal_routes=routes
	var before:Dictionary=context.snapshot();context.state.active_encounter={};context.state.control_owner="";context.state.mode="EXPLORING";context.state.player.encounter_id="";context.paused=false
	for portal:Dictionary in map.portals:
		context.state.player.position=portal.point
		var entered:Dictionary=context.begin_portal(portal.id)
		reports["enter_"+portal.id]=entered
		context.publish(before.duplicate(true));context.state.active_encounter={};context.state.control_owner="";context.state.mode="EXPLORING";context.state.player.encounter_id=""
		context.paused=false
	var members:int=0
	for runtime:Dictionary in source.maps.values():members+=runtime.parties.size()
	reports.stored_parties=members
	print("ENTRY_SAVE_DIAGNOSIS ",JSON.stringify(reports))
	get_tree().quit()
