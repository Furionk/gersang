class_name GameDirector
extends Node2D
signal message(text: String)
signal battle_finished(outcome: String)
signal mode_changed(mode: StringName)

var mode: StringName = &"loading"
var units: Dictionary = {}
var roster_ids: Array[int] = []
var next_id: int = 1
var simulation: Node2D
var render_root: Node2D
var ground: GroundMap
var camera: Camera2D
var hud: GameHud
var selection: SelectionController
var audio: GameAudio
var voices: UnitVoiceManager
var music: BackgroundMusic
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var encounter: EncounterDefinition
var world_return: Vector2 = Vector2(320, 560)
var markers: Array[WorldMarker] = []
var pending_marker: WorldMarker
var countdown_left: float = -1.0
var projectiles: Array[Dictionary] = []
var world_hero: TacticalUnit
var time_in_battle: float = 0.0
var victory_pending: bool = false
var victory_elapsed: float = 0.0
var stress: bool = false
var cinematic_camera: bool = true
var command_latency_ms: float = 0.0
var last_result: String = ""
var effects: Array[BattleSkillEffect] = []
var phases:BattlePhaseController
var effect_serial: int = 1
var effect_history: Array[Dictionary] = []
var battle_experience: int = 0
var reward_each: int = 0
var world_context: WorldContext
var world_hover: WorldHoverController
var world_views: Dictionary = {}
var battle_snapshot: Dictionary = {}
var settlement_result: Dictionary = {}
var battle_records: Array[CharacterRecord] = []
var battle_ready_token: String = ""
var level_serial: int = 0
var last_world_pick: Vector2 = Vector2.INF
var world_pick_cycle: int = 0
var world_pose: WorldVisualPose = WorldVisualPose.new()
var cursor_guard: BattleCursorGuard
var result_flow: BattleResultFlow = BattleResultFlow.new()
var result_tick_ms: int = 0
var transition_cover: SceneTransitionCover
var spell_flash: ScreenSpellFlash
var ground_click_feedback: Node2D
var puzzle_battle: PuzzleBattle
var action_battle: RainbowActionBattle
var monkey_garden: MonkeyGarden
var monkey_saved_zoom: Vector2 = Vector2.ONE
var monkey_preload: String = ""

func _ready() -> void:
	get_window().title="巨箱5.0"
	ground_click_feedback = preload("res://features/ui/ground_click_feedback.gd").new()
	ground_click_feedback.name = "GroundClickFeedback"
	add_child(ground_click_feedback)
	mode_changed.connect(func(next: StringName) -> void:
		if next != &"world": ground_click_feedback.clear())
	spell_flash=ScreenSpellFlash.new(); spell_flash.name="ScreenSpellFlash"; add_child(spell_flash)
	transition_cover=SceneTransitionCover.new()
	transition_cover.name="SceneTransitionCover"
	add_child(transition_cover)
	result_flow.banner_requested.connect(_show_victory_banner)
	result_flow.return_requested.connect(_queue_victory_return)
	rng.seed = 42047
	audio = GameAudio.new()
	audio.name = "Audio"
	add_child(audio)
	phases=preload("res://features/battle/battle_phase_controller.gd").new(); phases.game=self; add_child(phases)
	music = BackgroundMusic.new()
	music.name = "BackgroundMusic"
	add_child(music)
	voices = UnitVoiceManager.new()
	voices.name = "UnitVoices"
	voices.director = self
	add_child(voices)
	mode_changed.connect(func(_next: StringName) -> void: voices.reset_context())
	mode_changed.connect(_sync_music)
	camera = Camera2D.new()
	camera.name = "WorldCamera"
	camera.position = Iso.project(Vector2(620, 570))
	add_child(camera)
	camera.make_current()
	hud = GameHud.new()
	hud.name = "HUD"
	hud.director = self
	add_child(hud)
	world_hover = WorldHoverController.new()
	world_hover.name = "WorldHover"
	add_child(world_hover)
	world_hover.initialize(self)
	cursor_guard = BattleCursorGuard.new()
	cursor_guard.director = self
	cursor_guard.name = "BattleCursorGuard"
	add_child(cursor_guard)
	message.connect(hud.log_message)
	GameSettings.changed.connect(_apply_feel)
	PartyProgress.notification.connect(func(text: String) -> void: message.emit(text))
	world_context = WorldSession.context
	WorldSession.notification.connect(func(text: String) -> void: message.emit(text))
	world_context.encounters.battle_requested.connect(_encounter_battle)
	world_context.map_requested.connect(_portal_world)
	start_world()

func _sync_music(next_mode: StringName) -> void:
	if next_mode == &"puzzle": return # Keep the current battle track throughout the overlay.
	if world_context != null:
		music.follow(next_mode, world_context.state["player"]["map_id"])

func _apply_feel() -> void:
	for unit: TacticalUnit in units.values():
		unit.agent.radius = GameSettings.profile.collision_radius
		for child: Node in unit.get_children():
			if child is CollisionShape2D and child.shape is CircleShape2D:
				child.shape.radius = GameSettings.profile.collision_radius

func _clear_level() -> void:
	if is_instance_valid(action_battle):
		action_battle.dispose()
		remove_child(action_battle)
		action_battle.queue_free()
	action_battle = null
	if ground_click_feedback != null: ground_click_feedback.clear()
	if is_instance_valid(puzzle_battle): puzzle_battle.cancel()
	puzzle_battle = null
	if phases!=null: phases.reset()
	if spell_flash!=null: spell_flash.cancel()
	victory_pending = false
	victory_elapsed = 0.0
	if voices != null: voices.reset_context()
	transition_cover.begin()
	if world_hover!=null: world_hover.clear()
	result_flow.cancel()
	if cursor_guard != null: cursor_guard.release(false)
	for effect: BattleSkillEffect in effects:
		effect.finish()
	effects.clear()
	effect_history.clear()
	units.clear()
	roster_ids.clear()
	markers.clear()
	world_views.clear()
	projectiles.clear()
	pending_marker = null
	world_hero = null
	countdown_left = -1.0
	if selection != null:
		remove_child(selection)
		selection.queue_free()
		selection = null
	for old: Node2D in [simulation, render_root]:
		if old != null:
			remove_child(old)
			old.queue_free()
	simulation = Node2D.new()
	simulation.name = "Simulation"
	simulation.visible = false
	add_child(simulation)
	render_root = Node2D.new()
	render_root.name = "IsometricPresentation"
	render_root.y_sort_enabled = true
	render_root.visible = false # Stage off-screen until units AND camera are ready.
	render_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(render_root)
	ground = GroundMap.new()

func start_world() -> void:
	if mode == &"battle" and not battle_snapshot.is_empty():
		retreat()
		return
	if mode == &"results" and not settlement_result.is_empty() and world_context.state["active_encounter"].get("state","") == "SETTLING":
		_retry_settlement()
		return
	if battle_snapshot.is_empty():
		capture_party_vitals()
	level_serial += 1
	var serial: int = level_serial
	mode = &"loading"
	hud.close_windows()
	_clear_level()
	var map: WorldMapDefinition = world_context.current_map()
	world_context.ensure_map(map.map_id)
	ground.build_exploration(render_root,map)
	render_root.y_sort_enabled = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	if serial != level_serial:
		return
	world_return = world_context.state["player"]["position"]
	world_hero = spawn_unit(Catalog.party()[0], 0, world_return)
	world_hero.attach_character(PartyProgress.records[0], 0)
	world_pose.reset(world_return)
	_sync_world_views()
	var fire_ring: EncounterFireRing = EncounterFireRing.new()
	fire_ring.name = "EncounterFireRings"
	fire_ring.director = self
	fire_ring.z_index = 4
	render_root.add_child(fire_ring)
	var owner: String = world_context.state["control_owner"]
	if not owner.is_empty():
		if world_context.state["applied_results"].has(owner):
			world_context.encounters.complete_return(owner)
		else:
			world_context.complete_portal(owner)
	# A loaded map may defer artist additions until encounter/portal ownership ends.
	world_context.ensure_map(map.map_id)
	_sync_world_views()
	if world_context.population_layout_changed:
		var synced: Dictionary = world_context.checkpoint()
		if synced.ok:
			world_context.population_layout_changed = false
		else:
			world_context.paused = true
			message.emit("新增怪區同步保存失敗，已暫停以保留原檔："+str(synced.reason))
	world_context.refresh_player(PartyProgress.serialize())
	battle_snapshot.clear()
	battle_ready_token = ""
	battle_records.clear()
	settlement_result.clear()
	camera.position = Iso.project(world_return) + Vector2(130, 0)
	camera.reset_smoothing()
	camera.force_update_scroll()
	render_root.show()
	mode = &"world"
	transition_cover.complete()
	mode_changed.emit(mode)
	message.emit(map.display_name + "：左鍵行旅／點怪，走近藍色入口進城或上下樓。M 地圖。")
	if not WorldSession.last_error.is_empty():
		message.emit(WorldSession.last_error)

func _sync_world_views() -> void:
	for party_id: String in world_context.state["maps"][world_context.current_map().map_id]["parties"]:
		if not world_views.has(party_id):
			var view: WorldPartyView = WorldPartyView.new()
			view.party_id = party_id
			view.context = world_context
			render_root.add_child(view)
			world_views[party_id] = view

func _portal_world(_token: String) -> void:
	if world_context.state["control_owner"] != _token or world_context.state["mode"] != "TRANSITION":
		return
	start_world.call_deferred()

func _encounter_battle(snapshot: Dictionary) -> void:
	if snapshot["encounter_id"] != world_context.state["control_owner"]:
		return
	var arena: ArenaDefinition = WorldCatalog.arenas.get(snapshot["arena_id"])
	if arena == null:
		world_context.encounters.cancel(snapshot["encounter_id"],"ARENA_MISSING",true)
		return
	battle_snapshot = snapshot
	if arena.encounter.monkey_profile != null:
		_start_monkey(arena.encounter.monkey_profile)
		return
	start_battle.call_deferred(arena.encounter,false)

func _start_monkey(profile: MonkeyProfile) -> void:
	var token: String = battle_snapshot.encounter_id
	mode = &"monkey_transition"
	cursor_guard.release(false)
	hud.close_windows()
	monkey_saved_zoom = camera.zoom
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(camera,"zoom",Vector2.ONE*3.0,0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	var enemy: Dictionary = world_context.party(battle_snapshot.enemy_id)
	tween.tween_property(camera,"position",Iso.project(enemy.position),0.65)
	await tween.finished
	if world_context.state.control_owner != token: return
	var veil := CanvasLayer.new(); veil.layer=999; add_child(veil)
	var shade := ColorRect.new(); shade.color=Color(0,0,0,0); veil.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fade := create_tween(); fade.tween_property(shade,"color:a",1.0,0.3)
	await fade.finished
	if world_context.state.control_owner != token: veil.queue_free(); return
	var scene_path: String = profile.resolved_scene()
	if monkey_preload!=scene_path or ResourceLoader.load_threaded_get_status(scene_path) not in [ResourceLoader.THREAD_LOAD_LOADED,ResourceLoader.THREAD_LOAD_IN_PROGRESS]:
		monkey_preload=scene_path; ResourceLoader.load_threaded_request(scene_path)
	while ResourceLoader.load_threaded_get_status(scene_path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		if world_context.state.control_owner!=token: veil.queue_free(); return
	var packed: PackedScene = ResourceLoader.load_threaded_get(scene_path) as PackedScene if ResourceLoader.load_threaded_get_status(scene_path)==ResourceLoader.THREAD_LOAD_LOADED else null
	if packed==null or not world_context.encounters.mark_in_battle(token):
		veil.queue_free(); world_context.encounters.cancel(token,"MONKEY_LOAD_FAILED",true)
		battle_snapshot.clear(); camera.zoom=monkey_saved_zoom; start_world(); return
	render_root.hide(); hud.hide(); camera.enabled=false
	monkey_garden=packed.instantiate() as MonkeyGarden
	monkey_garden.profile=profile; monkey_garden.snapshot=battle_snapshot.duplicate(true)
	monkey_garden.completed.connect(_monkey_completed)
	add_child(monkey_garden)
	mode=&"monkey"
	fade=create_tween(); fade.tween_property(shade,"color:a",0.0,0.3); fade.tween_callback(veil.queue_free)

func _monkey_completed(outcome: String, hp: float, captured: Array[String]) -> void:
	if not is_instance_valid(monkey_garden) or mode != &"monkey": return
	var players: Array[Dictionary]=[]
	var members: Array=battle_snapshot.player_party_snapshot.deployed_units
	for i: int in members.size():
		players.append({"unit_id":members[i].unit_id,"hp":hp if i==0 else members[i].current_hp,"mp":members[i].current_mp})
	var result: Dictionary={"encounter_id":battle_snapshot.encounter_id,"outcome":outcome,"player_unit_results":players,"defeated_enemy_unit_ids":captured if outcome=="victory" else [],"consumed_items":[]}
	var settled: Dictionary=world_context.settlement.apply(result)
	if not settled.ok: monkey_garden.settlement_failed(str(settled.reason)); return
	PartyProgress.restore(world_context.state.progress)
	mode=&"monkey_return"
	monkey_garden.settlement_succeeded(outcome)
	await get_tree().create_timer(3.0).timeout
	monkey_garden.queue_free(); monkey_garden=null
	camera.enabled=true; camera.zoom=monkey_saved_zoom; hud.show()
	mode=&"results"; settlement_result.clear()
	start_world()

func start_battle(choice: EncounterDefinition, stress_test: bool = false) -> void:
	if mode == &"loading" and not battle_ready_token.is_empty():
		return
	if mode == &"battle" and not battle_snapshot.is_empty():
		message.emit("遭遇進行中，不能改開試驗戰場。")
		return
	if mode == &"results" and not battle_snapshot.is_empty():
		message.emit("請先返回行旅，再點選怪隊重新接戰。")
		start_world.call_deferred()
		return
	if battle_snapshot.is_empty():
		capture_party_vitals()
	level_serial += 1
	var serial: int = level_serial
	battle_ready_token = battle_snapshot.get("encounter_id","practice_%d" % serial)
	mode = &"loading"
	encounter = choice
	stress = stress_test
	battle_experience = 0
	reward_each = 0
	hud.close_windows()
	_clear_level()
	ground.ground_texture = choice.ground_texture
	ground.terrain = choice.terrain
	ground.cells = choice.battlefield_cells
	ground.authored_obstacles = choice.battlefield_obstacles.duplicate()
	ground.battle_id = String(choice.id)
	if not choice.battlefield_scene.is_empty():
		var packed: PackedScene = load(choice.battlefield_scene) as PackedScene
		if packed==null:
			_battle_map_failed("找不到戰場 Scene："+choice.battlefield_scene)
			return
		var instanced: Node = packed.instantiate()
		var scene: BattlefieldMap = instanced as BattlefieldMap
		if scene==null:
			instanced.free()
			_battle_map_failed("戰場根節點須為 BattlefieldMap")
			return
		var built: Dictionary = ground.build_scene(simulation,render_root,scene)
		if not built.ok:
			scene.free()
			_battle_map_failed(built.error)
			return
	else:
		ground.build(simulation, render_root, choice.terrain)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if serial != level_serial:
		return
	if not battle_snapshot.is_empty():
		rng.seed = battle_snapshot["battle_seed"]
	var party: Array[UnitDefinition] = []
	for record: CharacterRecord in PartyProgress.records: party.append(record.definition)
	if not battle_snapshot.is_empty():
		party.clear()
		for saved_member: Dictionary in battle_snapshot["player_party_snapshot"]["deployed_units"]:
			party.append(load(saved_member["definition_path"]) as UnitDefinition)
	for definition: UnitDefinition in party:
		for skill: SkillDefinition in definition.skills:
			GameSettings.register_skill(skill)
	var party_count: int = battle_snapshot["player_party_snapshot"]["deployed_units"].size() if not battle_snapshot.is_empty() else 12 if stress else party.size()
	var counts: Array[int] = [choice.melee_count, choice.ranged_count, choice.elite_count, choice.boss_count]
	if stress: counts=[40,15,4,1]
	var deployment: Array[Dictionary] = []
	if ground.authored_battlefield:
		var groups: Array[Dictionary] = [{"team":0,"count":party_count}]
		if not battle_snapshot.is_empty():
			for enemy_party: Dictionary in battle_snapshot["enemy_party_snapshots"]: groups.append({"team":1,"count":enemy_party["deployed_units"].size()})
		else:
			groups.append({"team":1,"count":counts.reduce(func(a: int,b: int) -> int: return a+b,0)})
		var planned: Dictionary = BattlefieldCompiler.deployment(ground,ground.battle_zones,groups,rng,GameSettings.profile.collision_radius*2.0+4.0)
		if not planned.ok:
			_battle_map_failed(planned.error)
			return
		deployment.assign(planned.groups)
	if not battle_snapshot.is_empty() and not world_context.encounters.mark_in_battle(battle_snapshot["encounter_id"]):
		battle_snapshot.clear()
		start_world.call_deferred()
		return
	for i: int in party_count:
		var at: Vector2 = deployment[0].points[i] if not deployment.is_empty() else Vector2(420 + (i % 3) * 55, 660 + (i / 3) * 49)
		var member: TacticalUnit = spawn_unit(party[i % party.size()], 0, at)
		if not deployment.is_empty(): member.set_meta("spawn_zone",deployment[0].id)
		if not battle_snapshot.is_empty():
			var saved_member: Dictionary = battle_snapshot["player_party_snapshot"]["deployed_units"][i]
			var record: CharacterRecord = CharacterRecord.new()
			record.initialize(party[i],saved_member["unit_id"],false)
			record.restore(saved_member["record"])
			battle_records.append(record)
			member.attach_character(record,i)
			member.persistent_unit_id = saved_member["unit_id"]
		elif not stress and i < PartyProgress.records.size():
			member.attach_character(PartyProgress.records[i], i)
	for member: TacticalUnit in units.values():
		if member.team == 0:
			for skill: SkillDefinition in member.available_skills(): GameSettings.register_skill(skill)
	var index: int = 0
	if not battle_snapshot.is_empty():
		var batch: int = 0
		for enemy_party: Dictionary in battle_snapshot["enemy_party_snapshots"]:
			var local_index: int = 0
			var center: Vector2 = choice.enemy_spawn_centers[batch % choice.enemy_spawn_centers.size()] if not choice.enemy_spawn_centers.is_empty() else Vector2(1160,440)
			for saved_enemy: Dictionary in enemy_party["deployed_units"]:
				var data: UnitDefinition = load(saved_enemy["definition_path"]) as UnitDefinition
				var at: Vector2 = deployment[batch+1].points[local_index] if not deployment.is_empty() else center+Vector2((local_index%5-2)*40,(local_index/5)*44)
				var member: TacticalUnit = spawn_unit(data,1,at)
				if not deployment.is_empty(): member.set_meta("spawn_zone",deployment[batch+1].id)
				member.persistent_unit_id = saved_enemy["unit_id"]
				member.set_meta("enemy_party_id",enemy_party["party_id"])
				member.set_meta("enemy_batch",batch)
				member.combat_stats = saved_enemy["resolved_stats"].duplicate(true)
				member.vitals.max_health = member.combat_stats["health"]
				member.vitals.max_mana = member.combat_stats["mana"]
				member.vitals.health = saved_enemy["current_hp"]
				member.vitals.mana = saved_enemy["current_mp"]
				local_index += 1
				index += 1
			batch += 1
	else:
		for enemy_kind: int in 4:
			for i: int in counts[enemy_kind]:
				var at: Vector2 = deployment[1].points[index] if not deployment.is_empty() else Vector2(880 + (index % 6) * 38, 440 + (index / 6) * 45)
				var enemy: TacticalUnit = spawn_unit(Catalog.enemy(enemy_kind), 1, at)
				if not deployment.is_empty(): enemy.set_meta("spawn_zone",deployment[1].id)
				index += 1
	# South art row faces the camera; logical XY must be unprojected first.
	for unit: TacticalUnit in units.values():
		unit.facing = Iso.unproject(Vector2.DOWN).normalized()
		if unit.view != null: unit.view.show_entry_pose()
	selection = SelectionController.new()
	selection.name = "SelectionAndCommands"
	selection.director = self
	add_child(selection)
	selection.selection_changed.connect(hud.on_skill_selection)
	selection.select_ids(living_ids(0))
	selection.restore_groups()
	selection.configure_sequence()
	camera.position = Iso.project(deployment[0].center if not deployment.is_empty() else Vector2(700,660))
	camera.reset_smoothing()
	camera.force_update_scroll()
	render_root.show()
	time_in_battle = 0.0
	mode = &"battle"
	if RainbowActionBattle.eligible(choice, battle_snapshot):
		action_battle = RainbowActionBattle.new()
		action_battle.name = "RainbowActionBattle"
		add_child(action_battle)
		action_battle.configure(self, choice.action_profile)
	transition_cover.complete()
	hud.on_skill_selection(selection.selected_ids)
	mode_changed.emit(mode)
	if is_instance_valid(action_battle):
		message.emit("%s | 方向鍵移動，A 加速、S 近攻、D 遠攻、空白防禦；點選隊員切換。" % choice.display_name)
	else:
		message.emit("%s | 左選右令，M/A/S/H 控兵，I/T/F/C 出技，E 預約，Tab 全選。" % choice.display_name)

func _battle_map_failed(reason: String) -> void:
	message.emit("戰場配置無效："+reason)
	if not battle_snapshot.is_empty(): world_context.encounters.cancel(battle_snapshot["encounter_id"],"INVALID_BATTLEFIELD",true)
	battle_snapshot.clear()
	battle_ready_token=""
	start_world.call_deferred()

func spawn_unit(data: UnitDefinition, side: int, at: Vector2, register_roster: bool = true) -> TacticalUnit:
	at = _safe_spawn(at) if data.movement_type == UnitDefinition.Movement.GROUND else at
	var unit: TacticalUnit = TacticalUnit.new()
	unit.name = "%s_%d" % [data.id, next_id]
	simulation.add_child(unit)
	unit.initialize(data, self, next_id, side, at)
	units[next_id] = unit
	if side == 0 and register_roster:
		roster_ids.append(next_id)
	next_id += 1
	var view: UnitView = UnitView.new()
	view.name = "View_%s" % unit.name
	render_root.add_child(view)
	view.initialize(unit)
	unit.died.connect(_unit_died)
	return unit

func spawn_summon(data: UnitDefinition, caster: TacticalUnit, at: Vector2, lifetime: float) -> TacticalUnit:
	var unit: TacticalUnit = spawn_unit(data, caster.team, at, false)
	unit.is_summon = true
	unit.summoner_id = caster.unit_id
	unit.summon_left = lifetime
	return unit

func evolve_unit(unit: TacticalUnit, next_form: UnitDefinition) -> void:
	for effect: BattleSkillEffect in effects:
		if effect.caster_id==unit.unit_id: effect.finish()
	unit.definition=next_form.duplicate(true) as UnitDefinition
	unit.active.clear(); unit.queued.clear(); unit.repeat_command.clear()
	unit.statuses.clear(); unit.cooldowns.clear(); unit.abilities.ai_attempts.clear()
	unit.cast_left=-1; unit.attack_windup_left=-1; unit.locked_attack_id=-1; unit.control_left=0; unit.charging=false
	unit.channeling=false; unit.petrified_left=0; unit.cast_visual_left=0
	unit._stop_motion(); unit.fsm.transition(&"idle")
	unit._refresh_stats()
	unit.vitals.armor=unit.definition.armor
	unit.vitals.health=unit.vitals.max_health; unit.vitals.mana=unit.vitals.max_mana
	unit.agent.set_navigation_map(ground.air_map if unit.definition.movement_type==UnitDefinition.Movement.AIR else ground.region.get_navigation_map())
	unit.agent.max_speed=float(unit.combat_stats.speed)*2.5
	unit.collision_mask=0 if unit.definition.movement_type==UnitDefinition.Movement.AIR else 5
	if is_instance_valid(unit.view): unit.view.queue_free()
	var view: UnitView=UnitView.new(); render_root.add_child(view); view.initialize(unit); view.position=Iso.project(unit.position)
	unit.vitals.changed.emit()
	message.emit("%s 進化！Lv.%d"%[unit.definition.display_name,unit.definition.level])

func debug_trial_unit(id: String, enemy: bool = false) -> Dictionary:
	if phases!=null and phases.frozen(): return {"ok":false,"reason":"首領變身暫停中"}
	if not DemoRules.tools_enabled() or mode!=&"battle": return {"ok":false,"reason":"請先進入戰鬥；新兵試玩只影響本場。"}
	var entry:UnitTrialEntry=Catalog.trial_entry(id)
	if entry==null: return {"ok":false,"reason":"未知試兵種類；請在Additional Mercenaries → Trials配置引用。"}
	if enemy and entry.enemy==null: return {"ok":false,"reason":"此兵種未配置敵方版本"}
	var side: int=1 if enemy else 0
	if living_ids(side).size()>=60: return {"ok":false,"reason":"本場隊伍已達60名上限"}
	var data:UnitDefinition=(entry.enemy if enemy else entry.friendly).duplicate() as UnitDefinition
	var anchor: TacticalUnit
	if selection!=null and not selection.selected_ids.is_empty(): anchor=get_unit(selection.selected_ids[0])
	if anchor==null:
		var allies: Array[int]=living_ids(0)
		if not allies.is_empty(): anchor=get_unit(allies[0])
	if anchor==null: return {"ok":false,"reason":"沒有存活友軍作試兵落點"}
	data.level=int(anchor.stats_snapshot().level)
	var trial: TacticalUnit=spawn_unit(data,side,anchor.position+Vector2(180,80) if enemy else anchor.position+Vector2(45,45),false)
	trial.is_summon=true # Transient: never settlement, XP roster or save participants.
	trial.summon_left=3600
	trial.vitals.max_mana=maxf(trial.vitals.max_mana,1500)
	trial.vitals.mana=trial.vitals.max_mana
	for ability: SkillDefinition in data.skills: GameSettings.register_skill(ability)
	if not enemy and data.controllable: selection.select_ids([trial.unit_id])
	message.emit("Debug加入%s：%s（本場限定，回圖不保存）" % ["敵軍" if enemy else "友軍",data.display_name])
	return {"ok":true,"reason":"已加入本場並給予1500 MP供技能試玩；不改正式編隊。","unit_id":trial.unit_id}

func _despawn_summon(id: int) -> void:
	var unit: TacticalUnit = get_unit(id)
	if unit == null:
		return
	if unit.view != null:
		unit.view.queue_free()
	units.erase(id)
	unit.queue_free()

func validate_skill_target(caster: TacticalUnit, skill: SkillDefinition, point: Vector2, target_id: int) -> String:
	if phases!=null and phases.frozen(): return "首領變身暫停中"
	if skill == null:
		return "技能不存在"
	if skill.target_mode in [SkillDefinition.Target.ALLY, SkillDefinition.Target.ENEMY]:
		var target: TacticalUnit = get_unit(target_id)
		if target == null or not target.alive():
			return "請指定存活單位"
		if skill.target_mode == SkillDefinition.Target.ALLY and target.team != caster.team:
			return "請指定友軍"
		if skill.target_mode == SkillDefinition.Target.ENEMY and target.team == caster.team:
			return "請指定敵人"
		if skill.target_mode == SkillDefinition.Target.ENEMY and target.statuses.hidden(): return "目標已隱身"
	if skill.effect_data!=null:
		if not skill.effect_data.resolved_duration(caster.stats_snapshot())["valid"]: return "持續公式無效"
		if skill.effect_data.kind==SkillEffectDefinition.Kind.STEALTH and not DamageFormula.evaluate(skill.effect_data.reveal_attack_formula,caster.stats_snapshot())["valid"]: return "現身攻擊公式無效"
	if skill.effect == SkillDefinition.Effect.SUMMON:
		if skill.effect_data == null or not (skill.effect_data.summon_definition is UnitDefinition):
			return "召喚模板無效"
		var scaling: Dictionary = SummonScaling.evaluate(skill.effect_data,caster.stats_snapshot())
		if not scaling["valid"]: return scaling["error"]
		if caster.team==1 and living_ids(1).size()+skill.effect_data.summon_count_min>60:
			return "敵方召喚容量不足"
		if ground._navigation_blocked(Vector2i(point / Iso.CELL)):
			return "召喚位置不能通行"
	if skill.effect == SkillDefinition.Effect.ICE_WALL:
		if skill.effect_data == null:
			return "冰牆效果資料缺失"
		var tiles: Array[Vector2i] = ground.wall_cells(point, caster.position.direction_to(point), skill.effect_data.wall_length)
		if tiles.is_empty():
			return "這裡無法建造冰牆"
		for tile: Vector2i in tiles:
			var rect: Rect2 = Rect2(Vector2(tile) * Iso.CELL, Vector2.ONE * Iso.CELL).grow(GameSettings.profile.collision_radius)
			for unit: TacticalUnit in units.values():
				if unit.alive() and unit.definition.movement_type == UnitDefinition.Movement.GROUND and rect.has_point(unit.position):
					return "冰牆位置有地面單位"
	return ""

func _spawn_is_free(at: Vector2) -> bool:
	if ground._navigation_blocked(Vector2i(at / Iso.CELL)):
		return false
	var clearance: float = GameSettings.profile.collision_radius * 2.0 + 4.0
	for existing: TacticalUnit in units.values():
		if existing.position.distance_squared_to(at) < clearance * clearance:
			return false
	return true

func _safe_spawn(at: Vector2) -> Vector2:
	if _spawn_is_free(at):
		return at
	var origin: Vector2i = Vector2i(at / Iso.CELL)
	for radius: int in range(0, 35):
		for x: int in range(origin.x - radius, origin.x + radius + 1):
			for y: int in range(origin.y - radius, origin.y + radius + 1):
				if maxi(absi(x - origin.x), absi(y - origin.y)) != radius:
					continue
				var candidate: Vector2 = (Vector2(x, y) + Vector2.ONE * 0.5) * Iso.CELL
				if _spawn_is_free(candidate):
					return candidate
	push_error("No available unit spawn cell.")
	return at

func get_unit(id: int) -> TacticalUnit:
	var unit: TacticalUnit = units.get(id)
	return unit if is_instance_valid(unit) else null

func living_ids(side: int) -> Array[int]:
	var result: Array[int] = []
	for unit: TacticalUnit in units.values():
		if unit.team == side and unit.alive():
			result.append(unit.unit_id)
	return result

func nearest_enemy(source: TacticalUnit, limit: float) -> TacticalUnit:
	var nearest: TacticalUnit
	var distance: float = limit * limit
	for candidate: TacticalUnit in units.values():
		if candidate.team == source.team or not candidate.alive() or candidate.statuses.hidden():
			continue
		var squared: float = source.position.distance_squared_to(candidate.position)
		if squared < distance:
			distance = squared
			nearest = candidate
	return nearest

func lowest_ally(source: TacticalUnit, mana: bool, limit: float) -> TacticalUnit:
	var result: TacticalUnit
	var ratio: float = 0.99
	for candidate: TacticalUnit in units.values():
		if candidate.team != source.team or not candidate.alive() or candidate.position.distance_to(source.position) > limit:
			continue
		if mana and candidate.vitals.max_mana <= 0.0:
			continue
		var value: float = candidate.vitals.mana / candidate.vitals.max_mana if mana else candidate.vitals.health / candidate.vitals.max_health
		if value < ratio:
			ratio = value
			result = candidate
	return result

func pick_unit(projected_point: Vector2, side: int = -1) -> TacticalUnit:
	var result: TacticalUnit
	var distance: float = 70.0
	for unit: TacticalUnit in units.values():
		if not unit.alive() or (side >= 0 and unit.team != side):
			continue
		var center: Vector2 = Iso.project(unit.position) + Vector2(0, -35)
		var d: float = center.distance_to(projected_point)
		if d < distance:
			distance = d
			result = unit
	return result

func mouse_ground() -> Vector2:
	return Iso.unproject(get_global_mouse_position())

func _unhandled_input(event: InputEvent) -> void:
	if mode in [&"monkey",&"monkey_transition",&"monkey_return"]: return
	if mode == &"battle" and is_instance_valid(action_battle):
		action_battle.handle_input(event)
		return
	if mode == &"puzzle": return
	if mode==&"battle" and phases!=null and phases.frozen(): return
	if event is InputEventKey and event.pressed and not event.echo:
		var debug_key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if debug_key == KEY_F2 and DemoRules.tools_enabled():
			hud.toggle_item_debug()
			get_viewport().set_input_as_handled()
			return
	if mode == &"countdown" and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		var cancelled: Dictionary = world_context.encounters.cancel(world_context.state["active_encounter"].get("encounter_id",""))
		if cancelled["ok"]:
			mode = &"world"
			countdown_left = -1
			hud.hide_countdown()
		get_viewport().set_input_as_handled()
		return
	if mode == &"world":
		if event is InputEventKey and event.pressed and not event.echo:
			var raw_key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if hud.progression.sheet.visible:
				if raw_key in [KEY_S,KEY_I]:
					if raw_key==KEY_S: hud.progression.toggle_stats()
					else: hud.progression.toggle_inventory()
					get_viewport().set_input_as_handled()
					return
				if DemoRules.slot_for_key(raw_key)>=0:
					select_world_slot(DemoRules.slot_for_key(raw_key), true)
					get_viewport().set_input_as_handled()
					return
			if raw_key==KEY_M and (not hud.is_modal_open() or hud.world_hud.map_panel.visible):
				hud.world_hud.toggle_map()
				get_viewport().set_input_as_handled()
				return
		if event is InputEventKey and event.pressed and not event.echo and not hud.is_modal_open():
			var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if key in [KEY_S, KEY_I]:
				if key == KEY_S:
					hud.progression.toggle_stats()
				else:
					hud.progression.toggle_inventory()
				get_viewport().set_input_as_handled()
				return
			if DemoRules.slot_for_key(key)>=0:
				select_world_slot(DemoRules.slot_for_key(key), true)
				return
		if event.is_action_pressed("open_menu"):
			hud.toggle_menu()
			return
		if hud.is_modal_open():
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if countdown_left >= 0.0:
				return
			var mouse_world: Vector2 = get_canvas_transform().affine_inverse() * event.position
			var entrance: WorldSceneryView = world_hover.pick(mouse_world)
			if entrance!=null:
				world_context.refresh_player(PartyProgress.serialize())
				var approach: Dictionary = world_context.approach_portal(entrance.portal_id)
				message.emit("前往 "+entrance.title if approach["ok"] else "入口周圍沒有可達落腳點，請檢查通行／障礙圖層。" if approach["reason"]=="PORTAL_NO_REACHABLE_APPROACH" else "入口無法前往："+str(approach["reason"]))
				get_viewport().set_input_as_handled()
				return
			var target: Dictionary = {}
			var candidates: Array[Dictionary] = []
			for monster: Dictionary in world_context.state["maps"][world_context.current_map().map_id]["parties"].values():
				var distance: float = Iso.project(monster["position"]).distance_to(mouse_world+Vector2(0,28))
				if monster["life_state"] == "ACTIVE" and distance < 65:
					candidates.append(monster)
			if not candidates.is_empty():
				candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a["party_id"] < b["party_id"])
				world_pick_cycle = (world_pick_cycle+1) % candidates.size() if mouse_world.distance_to(last_world_pick) < 8 else 0
				target = candidates[world_pick_cycle]
				last_world_pick = mouse_world
			elif mouse_world.distance_to(Iso.project(world_hero.position)-Vector2(0,28)) < 35:
				var summary: Dictionary = PowerCalculator.make_summary(world_context.state["player_party"])
				message.emit("%s · 戰力 %d · 上陣 %d 名。" % [summary["name"],summary["power"],summary["count"]])
				return
			var at: Vector2 = target["position"] if not target.is_empty() else Iso.unproject(mouse_world)
			world_context.refresh_player(PartyProgress.serialize())
			var path: Dictionary = world_context.move_player(at,target.get("party_id",""))
			if not target.is_empty():
				var summary: Dictionary = PowerCalculator.make_summary(target)
				message.emit("%s · 戰力 %d · %d 名；接近後進戰。" % [summary["name"],summary["power"],summary["count"]])
			if path["ok"] and target.is_empty():
				ground_click_feedback.play_at(mouse_world)
			if not path["ok"]:
				message.emit("無法前往：" + str(path["reason"]))

func _physics_process(delta: float) -> void:
	if mode in [&"world",&"countdown"] and not world_context.state.active_encounter.is_empty():
		var pending_arena: ArenaDefinition=WorldCatalog.arenas.get(world_context.state.active_encounter.arena_id)
		if pending_arena!=null and pending_arena.encounter.monkey_profile!=null:
			var path: String=pending_arena.encounter.monkey_profile.resolved_scene()
			if monkey_preload!=path or ResourceLoader.load_threaded_get_status(path) not in [ResourceLoader.THREAD_LOAD_LOADED,ResourceLoader.THREAD_LOAD_IN_PROGRESS]:
				monkey_preload=path; ResourceLoader.load_threaded_request(path)
	if mode not in [&"world", &"countdown", &"battle"]:
		return
	if mode in [&"world",&"countdown"]:
		world_context.movement_multiplier = GameSettings.profile.movement_multiplier
		world_context.turn_speed = GameSettings.profile.turn_speed
		var previous_pose: Vector2 = world_context.state["player"]["position"]
		var previous_map_id: String = world_context.state["player"]["map_id"]
		world_context.tick(delta)
		if world_hero != null:
			var old_position: Vector2 = world_hero.position
			world_hero.position = world_context.state["player"]["position"]
			world_hero.desired_velocity = (world_hero.position-old_position)/maxf(0.001,delta)
			world_hero.facing = world_context.state["player"]["facing"]
			if previous_map_id != world_context.state["player"]["map_id"]:
				world_pose.reset(world_hero.position)
				camera.position = Iso.project(world_hero.position)+Vector2(130,0)
			else:
				world_pose.step(previous_pose,world_hero.position)
		_sync_world_views()
		var session: Dictionary = world_context.state["active_encounter"]
		if not session.is_empty() and session["state"] == "COUNTDOWN":
			mode = &"countdown"
			countdown_left = maxf(0,float(session["deadline_ms"]-world_context.state["world_time_ms"])/1000.0)
			var target: Dictionary = session["enemy_party_snapshots"][0]
			hud.show_countdown(ceili(countdown_left),"%s · %d 批 · 總戰力 %d%s" % [target["display_name"],session["enemy_party_snapshots"].size(),session["entry_power_totals"][1],"\nEsc 取消" if session["initiator"] == "player" else "\n主動怪接戰"])
		elif mode==&"countdown" and world_context.state["mode"]=="EXPLORING":
			mode = &"world"
			countdown_left = -1.0
			hud.hide_countdown()
			mode_changed.emit(mode)
		return
	if phases!=null and phases.tick(delta): return
	if is_instance_valid(action_battle):
		action_battle.tick(delta)
	else:
		for unit: TacticalUnit in units.values():
			if phases!=null and phases.frozen(): break
			unit.tick(delta)
			if mode == &"puzzle": return
	if phases!=null and phases.frozen(): return
	_tick_projectiles(delta)
	if phases!=null and phases.frozen(): return
	_tick_effects(delta)
	if phases!=null and phases.frozen(): return
	if mode == &"battle":
		time_in_battle += delta
		if selection != null and not is_instance_valid(action_battle):
			selection.tick()
		if living_ids(0).is_empty():
			finish_battle("defeat")
		elif living_ids(1).is_empty() and (phases==null or phases.pending.is_empty()):
			if not victory_pending:
				victory_pending = true
				victory_elapsed = 0.0
				message.emit("敵軍全滅！兩秒收尾期間仍可移動與施法，稍後結算。")
			else:
				victory_elapsed += delta
				if victory_elapsed >= BattleResultFlow.HOLD_SECONDS:
					finish_battle("victory")
		else:
			victory_pending = false
			victory_elapsed = 0.0

func begin_countdown(marker: WorldMarker) -> void:
	hud.progression.close()
	hud.world_hud.close_windows()
	encounter = marker.encounter
	countdown_left = 3.0
	mode = &"countdown"
	world_hero.issue_command({"kind": "stop"})
	hud.show_countdown(3, encounter.display_name)

func edge_scroll_direction(mouse: Vector2) -> Vector2:
	var extent: Vector2 = get_viewport().get_visible_rect().size
	if not Rect2(Vector2.ZERO, extent).has_point(mouse):
		return Vector2.ZERO
	var direction: Vector2 = Vector2.ZERO
	if mouse.x < 10:
		direction.x = -1
	elif mouse.x > extent.x - 10:
		direction.x = 1
	if mouse.y < 10:
		direction.y = -1
	elif mouse.y > extent.y - 10:
		direction.y = 1
	return direction

func _process(delta: float) -> void:
	if mode==&"battle" and phases!=null and phases.frozen(): return
	if mode==&"results":
		# The first frame's delta may include scene-load time BEFORE victory.
		# Presentation countdown starts at the event, never before it.
		var now: int = Time.get_ticks_msec()
		result_flow.tick(maxf(0.0,float(now-result_tick_ms)/1000.0))
		result_tick_ms=now
	if mode == &"battle" and is_instance_valid(action_battle):
		action_battle.follow_camera(delta)
	elif mode == &"battle" and cinematic_camera and not hud.is_modal_open():
		var input_vector: Vector2 = Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
		var mouse: Vector2 = get_viewport().get_mouse_position()
		input_vector += edge_scroll_direction(mouse)
		camera.position += input_vector.limit_length(1.0) * delta * GameSettings.profile.camera_speed
		var bounds:Rect2=battle_camera_bounds()
		camera.position.x = clampf(camera.position.x, bounds.position.x, bounds.end.x)
		camera.position.y = clampf(camera.position.y, bounds.position.y, bounds.end.y)
	elif mode in [&"world",&"countdown"] and world_hero != null:
		camera.position = camera.position.lerp(Iso.project(world_visual_position()) + Vector2(130, 0),MovementFeel.follow_alpha(delta))

func battle_camera_bounds()->Rect2:
	var extent:Vector2=Vector2(ground.cells)*Iso.CELL
	var bounds:Rect2=Rect2(Iso.project(Vector2.ZERO),Vector2.ZERO)
	for corner:Vector2 in [Vector2(extent.x,0),extent,Vector2(0,extent.y)]:bounds=bounds.expand(Iso.project(corner))
	return bounds

func world_visual_position() -> Vector2:
	if world_hero == null: return Vector2.ZERO
	# Scene changes and explicit teleports cannot interpolate from the old map.
	if not world_pose.current.is_equal_approx(world_hero.position): world_pose.reset(world_hero.position)
	return world_pose.sample(Engine.get_physics_interpolation_fraction())

func _unit_died(id: int) -> void:
	if selection != null:
		selection.selected_ids.erase(id)
		selection._sync_selection()
	var unit: TacticalUnit = get_unit(id)
	if unit != null:
		if voices != null: voices.enemy_event(unit, &"death")
		if unit.team == 1 and mode in [&"battle", &"puzzle"] and not stress:
			battle_experience += maxi(0, unit.definition.experience_reward)
		message.emit("%s 倒下。" % unit.definition.display_name)
		if unit.is_summon:
			_despawn_summon.call_deferred(id)

func _begin_puzzle(config: PuzzleRules) -> void:
	if mode != &"battle" or is_instance_valid(puzzle_battle): return
	# Acquire synchronously before loading or yielding; every later actor stops this tick.
	mode = &"puzzle"
	var packed: PackedScene = load("res://features/puzzle/puzzle_battle.tscn") as PackedScene
	if packed == null:
		mode = &"battle"
		message.emit("轉珠世界載入失敗，已返回戰場。")
		return
	puzzle_battle = packed.instantiate() as PuzzleBattle
	add_child(puzzle_battle)
	if not puzzle_battle.configure(self,config):
		puzzle_battle.cancel()
		puzzle_battle = null
		mode = &"battle"
		message.emit("轉珠世界缺少參戰單位，已返回戰場。")
		return
	mode_changed.emit(mode)
	puzzle_battle.completed.connect(_puzzle_completed)

func _puzzle_completed(outcome: String) -> void:
	puzzle_battle = null
	mode = &"battle"
	mode_changed.emit(mode)
	if outcome == "defeat": finish_battle("defeat")

func basic_attack(attacker: TacticalUnit, target: TacticalUnit, power: float) -> void:
	if mode != &"battle": return
	if attacker.team == 1 and attacker.definition.puzzle_monster != null:
		_begin_puzzle(attacker.definition.puzzle_monster)
		return
	power+=attacker.statuses.reveal(true)
	for skill: SkillDefinition in attacker.available_skills():
		if skill.effect==SkillDefinition.Effect.CLAW_STRIKE:
			var value: Dictionary=skill.result(attacker.stats_snapshot())
			if not value.valid: return
			for enemy: TacticalUnit in units.values():
				if enemy.alive() and enemy.team!=attacker.team and enemy.definition.movement_type==UnitDefinition.Movement.GROUND and enemy.position.distance_to(target.position)<=skill.radius:
					apply_damage(enemy,float(value.value)*summon_field_multiplier(attacker,enemy.position),false,skill.damage_type,true,attacker.definition.outgoing_damage_scale)
			spawn_spike_burst(target.position,skill.effect_data)
			return
	audio.play("attack")
	if attacker.definition.attack_range > 100:
		var duration: float = attacker.position.distance_to(target.position) / 700.0
		projectiles.append({"left": maxf(0.1, duration), "target": target.unit_id, "attacker": attacker.unit_id, "power": power})
		var effect: CombatEffect = CombatEffect.new()
		effect.kind = -1
		effect.position = Iso.project(attacker.position)
		effect.from_point = effect.position + Vector2(0, -35)
		effect.to_point = Iso.project(target.position) + Vector2(0, -35)
		effect.life = maxf(0.1, duration)
		effect.tint = Color(1, 0.76, 0.32) if attacker.team == 0 else Color(0.93, 0.3, 0.15)
		effect.z_index = 3500
		render_root.add_child(effect)
	else:
		_basic_hit(attacker, target, power)

func summon_field_multiplier(unit: TacticalUnit, point: Vector2, attack_speed: bool=false) -> float:
	if not unit.is_summon or unit.summoner_id<0: return 1.0
	var multiplier: float=1.0
	for owned: SkillDefinition in unit.available_skills():
		var data: SkillEffectDefinition=owned.effect_data
		if owned.effect!=SkillDefinition.Effect.CLAW_STRIKE or data==null or data.synergy_skill_id==&"": continue
		for field: BattleSkillEffect in effects:
			if field.done or field.caster_id!=unit.summoner_id or field.team!=unit.team or field.skill.id!=data.synergy_skill_id: continue
			if field.data.kind!=SkillEffectDefinition.Kind.STAKES or field.age>=field.data.duration: continue
			if point.distance_to(field.point)<=field.data.radius:
				multiplier=maxf(multiplier,data.synergy_attack_speed_multiplier if attack_speed else data.synergy_damage_multiplier)
	return multiplier

func _basic_hit(attacker: TacticalUnit, target: TacticalUnit, power: float) -> void:
	var source: Dictionary = attacker.combat_stats if attacker != null else {}
	var r: CombatStatRules = attacker.rules() if attacker != null else CombatStats.DEFAULT_RULES
	if not source.is_empty() and rng.randf() >= CombatMath.hit_chance(source, target.combat_stats, r, rng):
		_damage_popup(target, "MISS", Color(0.76, 0.82, 0.86))
		return
	power = rng.randf_range(power * (1 - r.attack_variance), power * (1 + r.attack_variance))
	var result: Dictionary = attacker.abilities.critical_attack(power) if attacker != null and attacker.alive() else {"power":power, "critical":false}
	if not result["critical"] and not source.is_empty() and rng.randf() < float(source["crit"]):
		result["power"] = float(result["power"]) * r.crit_multiplier
		result["critical"] = true
	var actual_damage: float = apply_damage(target, float(result["power"]), bool(result["critical"]),CombatMath.Kind.PHYSICAL,true,attacker.definition.outgoing_damage_scale if attacker!=null else 1.0)
	if attacker != null and attacker.alive(): attacker.abilities.on_basic_damage_landed(actual_damage,target)

func _tick_projectiles(delta: float) -> void:
	for i: int in range(projectiles.size() - 1, -1, -1):
		projectiles[i]["left"] = float(projectiles[i]["left"]) - delta
		if float(projectiles[i]["left"]) <= 0.0:
			var unit: TacticalUnit = get_unit(int(projectiles[i]["target"]))
			if unit != null and unit.alive():
				_basic_hit(get_unit(int(projectiles[i].get("attacker", -1))), unit, float(projectiles[i]["power"]))
			projectiles.remove_at(i)

func apply_damage(target: TacticalUnit, power: float, critical: bool = false, damage_type: CombatMath.Kind = CombatMath.Kind.PHYSICAL, critical_flash: bool = true, final_scale:float=1.0) -> float:
	if power <= 0 or not target.alive():
		return 0.0
	var damage: float = CombatMath.mitigate(power, target.combat_stats, target.vitals.armor, damage_type, rng)*maxf(0,final_scale)
	var actual_damage: float = minf(target.vitals.health,damage)
	target.vitals.damage_resolved(damage)
	if not is_instance_valid(action_battle): audio.play("hit")
	_damage_popup(target, ("暴擊 " if critical else "") + str(int(damage)), Color(1.0, 0.85, 0.4))
	if critical and critical_flash:
		var flash: SkillEffectDefinition = SkillEffectDefinition.new()
		flash.sprite_path = "res://features/skills/art/critical.png"
		flash.duration = 0.4
		spawn_flash(target.position, flash)
	return actual_damage

func _damage_popup(target: TacticalUnit, caption: String, color: Color) -> void:
	var effect: CombatEffect = CombatEffect.new()
	effect.position = Iso.project(target.position)
	effect.text = caption
	effect.tint = color
	effect.z_index = 3500
	render_root.add_child(effect)

func resolve_skill(caster: TacticalUnit, skill: SkillDefinition, point: Vector2, target_id: int) -> void:
	if skill.effect_data != null and skill.effect_data.kind != SkillEffectDefinition.Kind.INSTANT:
		var ongoing: BattleSkillEffect = BattleSkillEffect.new()
		ongoing.initialize(self, caster, skill, point, target_id, effect_serial)
		effect_serial += 1
		effects.append(ongoing)
		message.emit("%s：%s" % [caster.definition.display_name, skill.display_name])
		return
	var power: float = float(skill.result(caster.stats_snapshot())["value"])
	var effect: CombatEffect = CombatEffect.new()
	effect.position = Iso.project(point)
	effect.tint = skill.tint
	effect.radius = skill.radius
	effect.kind = skill.effect
	effect.z_index = 3500
	if skill.effect==SkillDefinition.Effect.LIGHTNING and skill.effect_data!=null and not skill.effect_data.sprite_path.is_empty():
		spawn_flash(point,skill.effect_data,skill.radius)
		effect.free()
	elif skill.effect in [SkillDefinition.Effect.SUPPLY,SkillDefinition.Effect.HEAL]:effect.free()
	else: render_root.add_child(effect)
	if skill.effect in [SkillDefinition.Effect.SUPPLY, SkillDefinition.Effect.HEAL]:
		var target: TacticalUnit = get_unit(target_id)
		if target != null and target.alive() and target.team == caster.team:
			var visual:SupportVfx=SupportVfx.new();visual.target=target;visual.mana=skill.effect==SkillDefinition.Effect.SUPPLY
			render_root.add_child(visual)
			if skill.effect == SkillDefinition.Effect.SUPPLY:
				target.vitals.restore(power)
			else:
				target.vitals.heal(power)
	else:
		for target: TacticalUnit in units.values():
			if target.team != caster.team and target.alive() and target.position.distance_to(point) <= skill.radius:
				if skill.effect==SkillDefinition.Effect.PETRIFY:
					target.control_left=maxf(target.control_left,skill.duration); target.petrified_left=maxf(target.petrified_left,skill.duration)
					target.channeling=false
					_damage_popup(target,"石化",Color(0.75,0.78,0.8)); continue
				apply_damage(target, power, false, skill.damage_type,true,caster.definition.outgoing_damage_scale)
				if skill.effect == SkillDefinition.Effect.CONTROL:
					target.control_left = skill.duration
	message.emit("%s：%s" % [caster.definition.display_name, skill.display_name])

func spawn_flash(point: Vector2, definition: SkillEffectDefinition, radius_value: float=40.0) -> SkillVfx:
	var visual: SkillVfx = SkillVfx.new()
	visual.position = Iso.project(point)
	visual.z_index = 3500
	visual.initialize(definition.sprite_path, radius_value, definition.duration, definition.kind,definition.tick_interval,definition.sprite_grounded,definition.sprite_foot_ratio)
	render_root.add_child(visual)
	var tween: Tween = visual.create_tween()
	tween.tween_property(visual, "age", definition.duration, definition.duration)
	tween.tween_callback(visual.queue_free)
	return visual

func spawn_spike_burst(point: Vector2, definition: SkillEffectDefinition) -> AdvancedSkillVisual:
	var visual: AdvancedSkillVisual=AdvancedSkillVisual.new()
	visual.kind=SkillEffectDefinition.Kind.STAKES
	visual.life=definition.duration
	render_root.add_child(visual)
	visual.create_stakes(definition.sprite_path,point,definition.radius,0.2)
	var tween: Tween=visual.create_tween()
	tween.tween_property(visual,"age",definition.duration,definition.duration)
	tween.tween_callback(visual.queue_free)
	return visual

func _tick_effects(delta: float) -> void:
	for effect: BattleSkillEffect in effects:
		if phases!=null and phases.frozen(): break
		effect.tick(delta)
	for i: int in range(effects.size() - 1, -1, -1):
		if effects[i].done:
			effect_history.append({"skill":String(effects[i].skill.id), "ticks":effects[i].ticks, "hits":effects[i].hit_counts.duplicate(), "age":effects[i].age})
			if effect_history.size() > 256:
				effect_history.pop_front()
			effects.remove_at(i)

func finish_battle(outcome: String) -> void:
	if mode != &"battle":
		return
	mode = &"results"
	cursor_guard.release(false)
	last_result = outcome
	if not battle_snapshot.is_empty():
		var players: Array[Dictionary] = []
		var defeated: Array[String] = []
		for unit: TacticalUnit in units.values():
			# Only original persistent snapshot members belong in the world receipt.
			# Phase echoes / trial actors must never add blank reward IDs.
			if unit.is_summon or unit.persistent_unit_id.is_empty():
				continue
			if unit.team == 0:
				players.append({"unit_id":unit.persistent_unit_id,"hp":unit.vitals.health,"mp":unit.vitals.mana})
			elif not unit.alive():
				defeated.append(unit.persistent_unit_id)
		settlement_result = {"encounter_id":battle_snapshot["encounter_id"],"outcome":outcome,"player_unit_results":players,"defeated_enemy_unit_ids":defeated,"consumed_items":[]}
		_retry_settlement(false)
	elif outcome == "victory" and not stress:
		capture_party_vitals()
		var participants: Array[int] = []
		for unit: TacticalUnit in units.values():
			if unit.permanent_slot >= 0 and unit.team == 0:
				participants.append(unit.permanent_slot)
		reward_each = PartyProgress.award_victory(battle_experience, participants)
		message.emit("勝利經驗合計 %d，每名隊員約獲得 %d。" % [battle_experience, reward_each])
	elif not stress:
		PartyProgress.save_party()
	for unit: TacticalUnit in units.values():
		unit._stop_motion()
	projectiles.clear()
	for effect: BattleSkillEffect in effects:
		effect.finish()
	effects.clear()
	if selection != null:
		selection.cancel()
	hud.close_windows()
	hud.on_skill_selection([])
	if outcome=="victory":
		var pending: bool = not battle_snapshot.is_empty() and world_context.state["active_encounter"].get("state","")=="SETTLING"
		result_flow.begin(_result_identity(),not pending,victory_pending and victory_elapsed >= BattleResultFlow.HOLD_SECONDS)
		result_tick_ms=Time.get_ticks_msec()
		if pending: hud.show_result(outcome)
	else:
		result_flow.cancel()
		hud.show_result(outcome)
		audio.play("win")
	battle_finished.emit(outcome)
	mode_changed.emit(mode)

func _result_identity() -> String:
	return str(battle_snapshot.get("encounter_id","test:%d" % level_serial))
func _result_ticket_live(ticket: int, id: String) -> bool:
	return mode==&"results" and last_result=="victory" and result_flow.ticket==ticket and result_flow.encounter_id==id and _result_identity()==id
func _show_victory_banner(ticket: int, id: String) -> void:
	if not _result_ticket_live(ticket,id): return
	hud.show_result("victory")
	message.emit("戰鬥勝利！三秒後返回；左鍵可立即回圖。")
	audio.play("win")
func _queue_victory_return(ticket: int, id: String) -> void:
	if _result_ticket_live(ticket,id): _complete_victory_return.call_deferred(ticket,id)
func _complete_victory_return(ticket: int, id: String) -> void:
	if _result_ticket_live(ticket,id) and result_flow.stage==BattleResultFlow.Stage.RETURNING:
		start_world()

func _retry_settlement(return_after: bool = true) -> void:
	var settled: Dictionary = world_context.settlement.apply(settlement_result)
	if settled["ok"]:
		PartyProgress.restore(world_context.state["progress"])
		reward_each = int(settled["receipt"]["experience"]) / maxi(1,battle_records.size())
		message.emit("結算已保存：經驗 %d，戰利品 %d。" % [settled["receipt"]["experience"],settled["receipt"]["loot"]])
		if return_after:
			start_world.call_deferred()
	else:
		message.emit("結算未提交：%s。按返回行旅重試；未發放獎勵。" % settled["reason"])

func retreat() -> void:
	if phases!=null and phases.frozen(): return
	if mode == &"battle":
		if victory_pending:
			message.emit("敵軍已全滅，收尾後會自動結算。")
			return
		finish_battle("retreat")

func capture_party_vitals() -> void:
	for unit: TacticalUnit in units.values():
		if unit.permanent_slot >= 0 and unit.character != null:
			unit.character.health = maxf(1, unit.vitals.health)
			unit.character.mana = unit.vitals.mana

func select_world_slot(slot: int, player_issued: bool = false) -> void:
	if mode == &"world":
		if slot < 0 or slot >= PartyProgress.records.size(): return
		capture_party_vitals()
		PartyProgress.select_slot(slot)
		if player_issued and hud.progression.sheet.visible and voices != null:
			voices.inspect_selected()

func use_world_item(index: int) -> void:
	if mode != &"world":
		return
	capture_party_vitals()
	var record: CharacterRecord = PartyProgress.selected()
	var recipients: Array[TacticalUnit] = []
	if world_hero != null: recipients.append(world_hero)
	var used: Dictionary = PartyItemService.use_item(record,index,PartyProgress.records,recipients)
	if used["ok"]:
		if record == world_hero.character:
			world_hero.vitals.health = record.health
			world_hero.vitals.mana = record.mana
	else:
		message.emit(used["reason"])

func allocate_world_attribute(key: String, amount: int = 1) -> void:
	if mode == &"world":
		capture_party_vitals()
		PartyProgress.selected().allocate(key,amount)
func reset_world_attributes(persistent_id: String) -> bool:
	if mode!=&"world": return false
	var record: CharacterRecord = PartyProgress.selected()
	if record.persistent_id!=persistent_id:
		message.emit("選取角色已改變，請重新開啟配點確認。")
		return false
	# Unlike legacy exploration capture, respec must not raise a dead actor to 1 HP.
	for unit: TacticalUnit in units.values():
		if unit.character==record:
			record.health = maxf(0,unit.vitals.health)
			record.mana = unit.vitals.mana
	var refunded: int = record.reset_allocations()
	if refunded<=0: return false
	message.emit("%s：退還 %d 點，可重新配點；等級與裝備保留。" % [record.definition.display_name,refunded])
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		if battle_snapshot.is_empty():
			capture_party_vitals()
		WorldSession.save_exploration()

func unequip_world_item(slot: StringName) -> void:
	if mode == &"world":
		capture_party_vitals()
		var record: CharacterRecord = PartyProgress.selected()
		if not record.unequip(slot):
			message.emit(record.last_error)

class WorldMarker extends Node2D:
	var encounter: EncounterDefinition
	var logic_position: Vector2
	func _ready() -> void:
		var sprite: Sprite2D = Sprite2D.new()
		var texture: Texture2D = load(["res://features/units/art/beast.png", "res://features/units/art/elite.png", "res://features/units/art/boss.png"][encounter.terrain]) as Texture2D
		sprite.texture = texture
		sprite.region_enabled = true
		sprite.region_rect = Rect2(Vector2(0, texture.get_height() / 8.0 * 2), Vector2(texture.get_width() / 6.0, texture.get_height() / 8.0))
		sprite.scale = Vector2.ONE * 0.52
		sprite.position.y = -35
		add_child(sprite)
		var label: Label = Label.new()
		label.text = "%s\n建議 Lv.%d" % [encounter.display_name, encounter.level]
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(1, 0.84, 0.42))
		label.position = Vector2(-95, 8)
		label.size = Vector2(190, 50)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
		ScenerySorting.apply_item(self)
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.5))
		draw_arc(Vector2.ZERO, 35, 0, TAU, 48, Color(1, 0.66, 0.23, 0.65), 2.0)
