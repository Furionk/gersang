extends Node
var passed: int = 0
var failed: int = 0
func check(ok: bool, label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failed+=1
func _ready() -> void: call_deferred("run")
func fixture(approach: float, join: float) -> WorldContext:
	var species: UnitDefinition = Catalog.enemy(0).duplicate(true)
	species.reinforcement_approach_chance=approach; species.reinforcement_join_chance=join
	var path: String = "res://artifacts/editor-workflow-2026-10-11/species-%s-%s.tres" % [approach,join]
	ResourceSaver.save(species,path); species=load(path)
	var template: PartyTemplate = PartyTemplate.new(); template.representative=species; template.display_name="test"
	var member: MemberRule = MemberRule.new(); member.definition=Catalog.enemy(0); member.min_count=1; member.max_count=1
	template.members.assign([member])
	var profile: SpawnProfile = SpawnProfile.new(); profile.templates.assign([template]); profile.target_party_count=7; profile.speed=100
	profile.rules.reinforcement_check_ms=1000; profile.rules.reinforcement_radius=320
	var map: WorldMapDefinition = WorldMapDefinition.new(); map.map_id="river_bay"; map.extent=Vector2(1600,1600)
	map.walkable=[PolygonDomain.rectangle(Rect2(0,0,1600,1600))]
	var habitat: WorldHabitat = WorldHabitat.new(); habitat.habitat_id="test"; habitat.profile=profile
	habitat.spawn_domain=PolygonDomain.rectangle(Rect2(200,200,1000,1000)); habitat.activity_domain=map.walkable[0]; habitat.chase_domain=map.walkable[0]
	map.habitats.assign([habitat])
	var c: WorldContext = WorldContext.new(); c.initialize(PartyProgress.serialize(),14511,true,{"river_bay":map})
	c.state.player.position=Vector2(400,400)
	var points: Array[Vector2] = [Vector2(420,400),Vector2(560,400),Vector2(400,560),Vector2(240,400),Vector2(400,240),Vector2(650,500),Vector2(1100,1100)]
	var i: int = 0
	for party: Dictionary in c.state.maps.river_bay.parties.values():
		party.position=points[i]; party.home=points[i]; party.think_due_ms=99000
		i+=1
	var unrelated: Dictionary = c.state.maps.river_bay.parties.values()[-1]
	unrelated.path=PackedVector2Array([unrelated.position,unrelated.position+Vector2(100,0)])
	return c
func begin(c: WorldContext) -> void:
	check(c.encounters.try_begin("player",c.state.maps.river_bay.parties.values()[0].party_id,"player").ok,"countdown begins")
func advance(c: WorldContext, seconds: float) -> void:
	for tick: int in int(round(seconds*60)): c.tick(1.0/60.0)
func run() -> void:
	var c: WorldContext = fixture(1,1); begin(c)
	var session: Dictionary = c.state.active_encounter
	check(session.approaching_ids.is_empty() and session.enemy_ids.size()==1,"entry does not preselect all reinforcements")
	var unrelated: Dictionary = c.state.maps.river_bay.parties.values()[-1]
	var before: Vector2 = unrelated.position
	advance(c,0.9)
	check(session.approaching_ids.is_empty(),"no roll before first second")
	check(unrelated.position!=before,"unrelated monsters keep moving in countdown")
	advance(c,0.2)
	check(not session.approaching_ids.is_empty() and session.enemy_ids.size()==1,"per-second approach rolls do not prematurely admit enemies")
	var fixed: Dictionary = {}
	for party: Dictionary in c.state.maps.river_bay.parties.values(): fixed[party.party_id]=party.deployed_units.duplicate(true)
	advance(c,3.9)
	check(session.enemy_ids.size()==4 and session.enemy_party_snapshots.size()==4,"nearby arrivals obey maximum4 batches")
	var same: bool = true
	for party: Dictionary in session.enemy_party_snapshots: same=same and party.deployed_units==fixed[party.party_id]
	check(same,"arrivals retain their exact spawned members")
	check(session.approaching_ids.is_empty(),"unaccepted notices released at deadline")
	check(c.encounters.mark_in_battle(session.encounter_id),"real battle enters once")
	var clock: int = c.state.world_time_ms; c.tick(10)
	check(c.state.world_time_ms==clock,"formal battle freezes world clock")
	c=fixture(0,1); begin(c); advance(c,4.0)
	check(c.state.active_encounter.enemy_ids.size()==1 and c.state.active_encounter.approaching_ids.is_empty(),"species approach chance0 never approaches")
	check(c.state.active_encounter.join_rolls.values().all(func(rolls: Array) -> bool: return rolls.size()==4),"each candidate is reconsidered once per second")
	c=fixture(1,0); begin(c); advance(c,3.0)
	check(not c.state.active_encounter.approaching_ids.is_empty() and c.state.active_encounter.enemy_ids.size()==1,"exclamation notices may hesitate and never join")
	var id: String = c.state.active_encounter.encounter_id
	check(c.encounters.cancel(id).ok and c.state.maps.river_bay.parties.values().all(func(p: Dictionary) -> bool: return p.life_state=="ACTIVE" and p.encounter_id.is_empty()),"cancel releases joined and hesitant reservations")
	c=fixture(1,1)
	c.map_definitions.river_bay.blockers.assign([PolygonDomain.rectangle(Rect2(480,0,64,1600))])
	c.navigation.register_map(c.current_map()); begin(c); advance(c,4.9)
	var across: Dictionary = c.state.maps.river_bay.parties.values()[1]
	check(across.life_state=="ACTIVE" and not c.state.active_encounter.enemy_ids.has(across.party_id),"wall blocks approach and admission")
	print("DYNAMIC_REINFORCEMENT_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
