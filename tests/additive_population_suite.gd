extends Node
var passed: int = 0
var failed: int = 0
func check(ok: bool, label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failed+=1
func _ready() -> void: call_deferred("run")
func run() -> void:
	WorldCatalog.initialize()
	var map: WorldMapDefinition = WorldCatalog.definitions.millennium_lake
	var new_habitat: WorldHabitat
	for habitat: WorldHabitat in map.habitats:
		if habitat.habitat_id!="lake_guardian": new_habitat=habitat
	check(new_habitat!=null,"actual artist-added lake region exists")
	if new_habitat==null: get_tree().quit(1); return
	var old_map: WorldMapDefinition = map.duplicate(true)
	old_map.habitats.assign([old_map.habitat("lake_guardian")])
	var old: WorldContext = WorldContext.new()
	old.initialize(PartyProgress.serialize(),51110,true,{map.map_id:old_map})
	old.ensure_map(map.map_id)
	var saved: Dictionary = old.snapshot()
	var old_runtime: Dictionary = saved.maps[map.map_id].duplicate(true)
	var c: WorldContext = WorldContext.new()
	c.initialize(PartyProgress.serialize(),51110,true)
	c.publish(saved)
	c.ensure_map(map.map_id)
	check(c.population_layout_changed,"same-version region addition marks checkpoint needed")
	for id: String in old_runtime.parties:
		check(c.state.maps[map.map_id].parties[id]==old_runtime.parties[id],"existing party identity and roster untouched")
	for id: String in old_runtime.slots:
		check(c.state.maps[map.map_id].slots[id]==old_runtime.slots[id],"existing slot and timers untouched")
	var added_id: String = "%s/%s/0" % [map.map_id,new_habitat.habitat_id]
	check(c.state.maps[map.map_id].slots[added_id].state=="OCCUPIED","new region spawns in existing world")
	check(c.state.progress==saved.progress and c.state.player==saved.player and c.state.applied_results==saved.applied_results and c.state.world_time_ms==saved.world_time_ms,"progress player receipts and clock untouched")
	check(c.state.maps.river_bay==saved.maps.river_bay,"other map populations untouched")
	var once: Dictionary = c.snapshot()
	c.ensure_map(map.map_id)
	check(c.snapshot()==once,"repeat map entry does not duplicate or reroll")
	var restored: WorldContext = WorldContext.new()
	restored.initialize(PartyProgress.serialize(),51110,true)
	restored.publish(once)
	restored.ensure_map(map.map_id)
	check(restored.snapshot()==once,"save snapshot reopen preserves new and old parties")
	var deferred: WorldContext = WorldContext.new()
	deferred.initialize(PartyProgress.serialize(),51110,true)
	deferred.publish(saved)
	deferred.state.active_encounter={"encounter_id":"test_lock"}
	deferred.state.mode="ENCOUNTER"
	deferred.ensure_map(map.map_id)
	check(deferred.state.maps[map.map_id]==old_runtime,"active encounter defers additive sync")
	deferred.state.active_encounter={}
	deferred.state.mode="EXPLORING"
	deferred.ensure_map(map.map_id)
	check(deferred.state.maps[map.map_id].slots.has(added_id),"safe return applies deferred addition")
	var growth_map: WorldMapDefinition = map.duplicate(true)
	growth_map.habitat("lake_guardian").profile.target_party_count=3
	var growth: WorldContext = WorldContext.new()
	growth.initialize(PartyProgress.serialize(),51110,true,{map.map_id:growth_map})
	growth.publish(once)
	growth.ensure_map(map.map_id)
	check(growth.state.maps[map.map_id].slots.size()==once.maps[map.map_id].slots.size()+2,"population increase adds exactly two missing indices, independent of other artist populations")
	growth_map.habitat("lake_guardian").profile.target_party_count=0
	var before_reduce: Dictionary = growth.snapshot()
	growth.ensure_map(map.map_id)
	check(growth.snapshot()==before_reduce,"lowering target never deletes existing saved parties")
	# An existing overdue slot must not be respawned by the additive operation.
	var waiting: WorldContext = WorldContext.new()
	waiting.initialize(PartyProgress.serialize(),51110,true)
	waiting.publish(saved)
	var slot: Dictionary = waiting.state.maps[map.map_id].slots.values()[0]
	waiting.state.maps[map.map_id].parties.erase(slot.party_id)
	slot.merge({"state":"COOLDOWN","party_id":"","respawn_due_ms":0},true)
	var waiting_before: Dictionary = slot.duplicate(true)
	waiting.ensure_map(map.map_id)
	check(slot==waiting_before,"sync does not consume old cooldowns even when overdue")
	var before_failure: Dictionary = c.snapshot()
	c.save.enabled=true
	c.save.fail_writes=1
	c.save.path="user://additive-population-test.dat"
	check(not c.checkpoint().ok and c.snapshot()==before_failure,"save failure retains same synced candidate and members")
	c.save.enabled=false
	check(c.checkpoint().ok,"same population checkpoint can retry without reroll")
	var formal_path: String = ProjectSettings.globalize_path("user://world_state.dat")
	if FileAccess.file_exists(formal_path):
		var formal_hash: String = FileAccess.get_sha256(formal_path)
		var file: FileAccess = FileAccess.open(formal_path,FileAccess.READ)
		var actual: Dictionary = file.get_var(false)
		file.close()
		var probe: WorldContext = WorldContext.new()
		probe.initialize(PartyProgress.serialize(),51110,true)
		probe.publish(actual)
		var expected: Dictionary = actual.duplicate(true)
		UnitResourcePaths.rewrite_saved_paths(expected) # Only the approved known resource-path relocation.
		var old_parties: Dictionary = expected.maps[map.map_id].parties.duplicate(true)
		probe.ensure_map(map.map_id)
		check(probe.state.maps[map.map_id].slots.has(added_id),"read-only real-save copy gains missing artist region")
		var unchanged: bool = true
		for id: String in old_parties: unchanged = unchanged and probe.state.maps[map.map_id].parties[id]==old_parties[id]
		check(unchanged and probe.state.progress==expected.progress and probe.state.applied_results==expected.applied_results,"real-save copy preserves identities progress rewards with only known-path migration")
		check(FileAccess.get_sha256(formal_path)==formal_hash,"formal world save never written by test")
	var previous: WorldContext = WorldSession.context
	c.state.player.map_id=map.map_id
	c.state.player.position=map.entries.values()[0].point
	WorldSession.context=c
	var game: GameDirector = load("res://main.tscn").instantiate()
	add_child(game)
	game.audio.muted=true
	while game.mode!=&"world": await get_tree().process_frame
	var new_party: String = c.state.maps[map.map_id].slots[added_id].party_id
	check(game.world_views.has(new_party),"real game presents newly synced monster party")
	game.queue_free()
	await get_tree().process_frame
	WorldSession.context=previous
	print("ADDITIVE_POPULATION_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
