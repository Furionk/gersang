extends Node
const BEFORE:String="res://artifacts/tests/tower-challenge/before/"
var passed:int=0
var failed:int=0
func check(ok:bool,label:String)->void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok:passed+=1
	else:failed+=1
func _ready()->void:call_deferred("run")
func run()->void:
	var context:WorldContext=WorldContext.new();context.initialize(PartyProgress.serialize(),481,true)
	context.ensure_map("shenchao_tower")
	var runtime:Dictionary=context.state.maps.shenchao_tower
	var party:Dictionary=runtime.parties.values()[0]
	var member:Dictionary=party.deployed_units[0]
	var definition:UnitDefinition=load(member.definition_path)
	member.balance_revision=definition.balance_revision-1
	member.resolved_stats.health*=0.75;member.current_hp=member.resolved_stats.health*0.37
	var identity:String=member.unit_id;var level:int=member.level;var location:Vector2=party.position
	var slots:Dictionary=runtime.slots.duplicate(true);var progress:Dictionary=context.state.progress.duplicate(true)
	context.paused=true
	check(not MonsterBalanceRefresh.apply(context,runtime),"paused world defers numerical refresh")
	context.paused=false;context.state.active_encounter={"encounter_id":"test"}
	check(not MonsterBalanceRefresh.apply(context,runtime),"active encounter defers numerical refresh")
	context.state.active_encounter={}
	check(MonsterBalanceRefresh.apply(context,runtime),"old tower member receives new balance")
	check(is_equal_approx(member.resolved_stats.health,definition.puzzle_monster.monster_health(level)) and is_equal_approx(member.current_hp/member.resolved_stats.health,0.37),"new maximum HP preserves wounded ratio")
	check(member.unit_id==identity and member.level==level and party.position==location and runtime.slots==slots and context.state.progress==progress and runtime.parties.size()==36,"refresh preserves identity location timers progress and population")
	check(not MonsterBalanceRefresh.apply(context,runtime),"refresh is idempotent")
	var old:WorldMap2D=load(BEFORE+"features/world/data/shenchao_tower.tscn").instantiate()
	var current:WorldMap2D=load("res://features/world/data/shenchao_tower.tscn").instantiate()
	var a:WorldMapDefinition=old.compile_definition();var b:WorldMapDefinition=current.compile_definition()
	var same:bool=a.walkable.size()==b.walkable.size() and a.blockers.size()==b.blockers.size()
	for i:int in a.walkable.size():same=same and a.walkable[i].outer==b.walkable[i].outer
	for i:int in a.blockers.size():same=same and a.blockers[i].outer==b.blockers[i].outer
	check(same and a.portals.all(func(p:Dictionary)->bool:return p in b.portals),"celestial art preserves native navigation and all original portals")
	old.free();current.free()
	var old_arena:BattlefieldMap=load(BEFORE+"features/battle/maps/shenchao_tower.tscn").instantiate()
	var arena:BattlefieldMap=load("res://features/battle/maps/shenchao_tower.tscn").instantiate()
	var compiled:Dictionary=BattlefieldCompiler.compile(arena);var baseline:Dictionary=BattlefieldCompiler.compile(old_arena)
	check(compiled.errors.is_empty() and compiled.blocked==baseline.blocked and compiled.zones==baseline.zones,"celestial arena preserves collision and deployment zones")
	old_arena.free();arena.free()
	print("TOWER_CHALLENGE_RESULT ",passed," passed / ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)
