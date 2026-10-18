extends Node
var game: GameDirector
var passed: int = 0
var failed: int = 0
var checks: Array[Dictionary] = []
const OUT: String = "res://artifacts/victory-cleanup-2026-10-11/"
func check(ok: bool, caption: String) -> void:
	checks.append({"test":caption,"pass":ok})
	print("PASS | " if ok else "FAIL | ",caption)
	if ok: passed += 1
	else: failed += 1
func _ready() -> void:
	get_tree().create_timer(60).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func battle() -> void:
	game.start_battle(Catalog.encounters()[0])
	while game.mode != &"battle": await get_tree().process_frame
	game.set_physics_process(false)
func wipe() -> void:
	for enemy: TacticalUnit in game.units.values():
		if enemy.team == 1: enemy.vitals.health = 0
func run() -> void:
	LegacyPartyFixture.install()
	DirAccess.make_dir_recursive_absolute(OUT)
	check(not PartyProgress.persistence_enabled,"isolated progress")
	game = load("res://main.tscn").instantiate(); add_child(game)
	while game.mode != &"world": await get_tree().process_frame
	await battle()
	var trial: Dictionary = game.debug_trial_unit("kohime")
	var hero: TacticalUnit = game.get_unit(trial.unit_id)
	var stakes: SkillDefinition = load("res://features/skills/data/earth_stakes.tres")
	game.resolve_skill(hero,stakes,hero.position,-1)
	var field: BattleSkillEffect = game.effects.back()
	var progress: Dictionary = PartyProgress.serialize().duplicate(true)
	wipe(); game._physics_process(0.01)
	check(game.mode == &"battle" and game.victory_pending,"all enemies dead starts operable battle cleanup")
	check(PartyProgress.serialize() == progress and game.result_flow.stage == BattleResultFlow.Stage.NONE,"no early XP or victory banner")
	var age: float = field.age
	game._physics_process(0.5)
	check(game.effects.has(field) and field.age > age and not field.done,"existing spell effect keeps ticking")
	check(game.selection.activate_skill(&"earth_claw"),"fresh immediate skill still accepted after extinction")
	hero.tick(1.0/60.0)
	check(hero.abilities.active_summon_groups.get(&"earth_claw",[]).size() == 1,"new summon created during cleanup")
	hero.position = game._safe_spawn(Vector2(750,650))
	var move_start: Vector2 = hero.position
	hero.issue_command({"kind":"move","point":game._safe_spawn(hero.position+Vector2(90,0))})
	check(hero.active.get("kind","") == "move","movement command accepted during cleanup")
	for frame: int in 30:
		await get_tree().physics_frame
		game._physics_process(1.0/60.0)
	check(hero.position.distance_to(move_start)>1,"unit actually moves during cleanup")
	game.retreat()
	check(game.mode == &"battle" and game.victory_pending,"retreat cannot discard pending victory reward")
	if DisplayServer.get_name() != "headless":
		game.camera.position = Iso.project(hero.position); game.camera.force_update_scroll()
		await get_tree().process_frame; await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT+"operable-cleanup.png")
	game._physics_process(0.99)
	check(game.mode == &"battle" and PartyProgress.serialize() == progress,"before two seconds battle remains active without XP")
	game._physics_process(0.02)
	check(game.mode == &"results" and game.result_flow.stage == BattleResultFlow.Stage.BANNER,"after cleanup settle and show banner without second hold")
	check(game.effects.is_empty(),"effects cleaned only at actual battle end")
	var settled: Dictionary = PartyProgress.serialize().duplicate(true)
	game.finish_battle("victory")
	check(PartyProgress.serialize() == settled,"duplicate finish cannot award twice")
	game.result_flow.tick(2.99)
	check(game.result_flow.stage == BattleResultFlow.Stage.BANNER,"three visible banner seconds retained")
	check(game.result_flow.request_return() and not game.result_flow.request_return(),"banner left-skip return remains one-shot")
	while game.mode != &"world": await get_tree().process_frame
	await battle(); wipe(); game._physics_process(0.01)
	var enemy: TacticalUnit = game.spawn_unit(load("res://features/units/data/monsters/beast.tres"),1,game._safe_spawn(Vector2(750,650)),false)
	game._physics_process(0.1)
	check(not game.victory_pending and game.victory_elapsed == 0,"new living enemy cancels pending victory")
	enemy.vitals.health = 0; game._physics_process(0.01)
	for friend: TacticalUnit in game.units.values():
		if friend.team == 0: friend.vitals.health = 0
	game._physics_process(0.01)
	check(game.mode == &"results" and game.last_result == "defeat","lingering damage can still defeat allies during cleanup")
	var flow: BattleResultFlow = BattleResultFlow.new()
	flow.begin("failed",false,true); flow.tick(100)
	check(flow.stage == BattleResultFlow.Stage.SAVE_BLOCKED and not flow.request_return(),"failed save cannot auto return even after cleanup")
	var report: Dictionary = {"passed":passed,"failed":failed,"tests":checks,"rendered":DisplayServer.get_name() != "headless"}
	var file: FileAccess = FileAccess.open(OUT+("headless.json" if DisplayServer.get_name()=="headless" else "render.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("VICTORY_CLEANUP_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failed == 0 else 1)
