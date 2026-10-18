class_name PuzzleBattle
extends CanvasLayer
signal completed(outcome: String)
var game: GameDirector
var controller: PuzzleController
var view: PuzzleView
var cover: ColorRect
var phase: String = "enter_out"
var elapsed: float = 0.0
var result: String = ""
var serial: int = -1
var previous_modes: Dictionary = {}
var voice_manager: UnitVoiceManager
var voice_profiles: Array[UnitVoiceProfile] = []
var pending_voices: Array[int] = []

func _ready() -> void:
	call_deferred("_standalone_preview")

func _standalone_preview() -> void:
	if game != null: return
	# F6 preview is an isolated model, never edits PartyProgress or WorldSession.
	layer = 90
	controller = PuzzleController.new()
	var config: PuzzleRules = load("res://features/puzzle/data/default_rules.tres")
	var allies: Array[Dictionary] = []
	var foes: Array[Dictionary] = []
	voice_manager = UnitVoiceManager.new()
	add_child(voice_manager)
	controller.cue.connect(_attack_voice)
	var definitions: Array[UnitDefinition] = Catalog.party()
	definitions.append_array(Catalog.additional_mercenaries())
	for definition: UnitDefinition in definitions:
		voice_profiles.append(definition.voice_profile)
		var stats: Dictionary = CombatStats.calculate(definition,{"strength":definition.strength,"agility":definition.agility,"intelligence":definition.intelligence,"vitality":definition.vitality,"luck":definition.luck},25)
		allies.append({"id":allies.size(),"name":definition.display_name,"hp":stats.health,"max_hp":stats.health,"attack":stats.attack,"element":definition.puzzle_element})
	for element: int in 4:
		foes.append({"id":element,"name":"轉珠怪","hp":config.monster_health(),"max_hp":config.monster_health(),"attack":0.0,"element":element})
	controller.setup(allies,foes,config,714)
	add_child(controller)
	view = PuzzleView.new()
	view.controller = controller
	for definition: UnitDefinition in definitions: view.portraits.append(CharacterArt.texture(definition,"portrait"))
	add_child(view)
	controller.finished.connect(func(outcome: String) -> void: view.status = "勝利！轉珠怪全部擊破" if outcome=="victory" else "戰敗 · 體力耗盡")

func configure(director: GameDirector, config: PuzzleRules) -> bool:
	game = director
	serial = game.level_serial
	layer = 90
	controller = PuzzleController.new()
	var allies: Array[Dictionary] = []
	var foes: Array[Dictionary] = []
	for unit: TacticalUnit in game.units.values():
		if unit.is_summon: continue
		var record: Dictionary = {"id":unit.unit_id,"name":unit.definition.display_name,"hp":unit.vitals.health,"max_hp":unit.vitals.max_health,"attack":unit.stats_snapshot().attack,"element":unit.definition.puzzle_element}
		if unit.team == 0:
			allies.append(record)
			voice_profiles.append(unit.definition.voice_profile)
		elif unit.alive() and unit.definition.puzzle_monster != null:
			record["rules"] = unit.definition.puzzle_monster
			record["texture"] = unit.definition.puzzle_monster.enemy_texture
			record["dark"] = unit.definition.puzzle_monster.dark_monster
			record["level"] = unit.stats_snapshot().level
			foes.append(record)
	if allies.is_empty() or foes.is_empty():
		controller.free()
		controller = null
		return false
	controller.setup(allies,foes,config,game.rng.randi())
	controller.stage = "blocked"
	add_child(controller)
	controller.finished.connect(_finished)
	voice_manager = game.voices
	controller.cue.connect(_attack_voice)
	controller.cue.connect(func(event: Dictionary) -> void:
		if event.kind in ["attack","enemy_attack"]: game.audio.play("attack")
	)
	view = PuzzleView.new()
	view.controller = controller
	if game.world_context != null and game.world_context.state.player.map_id == "shenchao_tower":
		view.backdrop = preload("res://art/terrain/shenchao_tower/cloud-sea-v1.png")
		view.landmark = preload("res://art/terrain/shenchao_tower/celestial-tower-v1.png")
	if game.world_context != null and game.world_context.state.player.map_id == "shenchao_abyss":
		view.backdrop = preload("res://art/terrain/shenchao_abyss/abyss-v1.png")
	for ally: Dictionary in allies: view.portraits.append(CharacterArt.texture(game.get_unit(ally.id).definition,"portrait"))
	add_child(view)
	view.hide()
	cover = ColorRect.new()
	cover.color = Color(0,0,0,0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cover)
	for node: Node in [game.simulation,game.render_root,game.selection,game.spell_flash]:
		if node != null:
			previous_modes[node] = node.process_mode
			node.process_mode = Node.PROCESS_MODE_DISABLED
	game.hud.hide()
	game.cursor_guard.release(false)
	return true

func _attack_voice(event: Dictionary) -> void:
	if event.kind != "attack" or voice_manager == null: return
	if GameSettings.unit_voice_muted or GameSettings.unit_voice_volume <= 0: return
	var index: int = event.actor
	if index < 0 or index >= voice_profiles.size(): return
	if index not in pending_voices: pending_voices.append(index)
	_play_next_voice()

func _play_next_voice() -> void:
	if GameSettings.unit_voice_muted or GameSettings.unit_voice_volume <= 0:
		pending_voices.clear()
		return
	if voice_manager == null or voice_manager.player == null or not controller.focused: return
	if voice_manager.player.playing: return
	while not pending_voices.is_empty():
		var index: int = pending_voices.pop_front()
		if controller.combat.friends[index].hp <= 0: continue
		if voice_manager.puzzle_attack(voice_profiles[index]) > 0: break

func _process(delta: float) -> void:
	if controller != null: _play_next_voice()
	if voice_manager != null and voice_manager.player != null and controller != null:
		voice_manager.player.stream_paused = not controller.focused
	if game == null or controller == null: return
	if game.level_serial != serial:
		cancel()
		return
	if not controller.focused: return
	if phase == "play": return
	elapsed += delta
	var fraction: float = clampf(elapsed/controller.rules.fade_seconds,0,1)
	cover.color.a = fraction if phase.ends_with("out") else 1.0-fraction
	if fraction < 1: return
	elapsed = 0
	match phase:
		"enter_out":
			view.show()
			phase = "enter_in"
		"enter_in":
			cover.hide()
			controller.stage = "ready"
			phase = "play"
			if controller.combat.health() <= 0:
				controller.stage = "done"
				_finished("defeat")
		"exit_out":
			_commit()
			view.hide()
			game.hud.show()
			phase = "exit_in"
		"exit_in":
			_restore()
			completed.emit(result)
			queue_free()

func _finished(outcome: String) -> void:
	if phase != "play": return
	result = outcome
	phase = "exit_out"
	elapsed = 0
	cover.show()

func _commit() -> void:
	for record: Dictionary in controller.combat.friends+controller.combat.enemies:
		var unit: TacticalUnit = game.get_unit(record.id)
		if unit == null: continue
		var difference: float = record.hp-unit.vitals.health
		if difference < 0: unit.vitals.damage_resolved(-difference)
		elif difference > 0: unit.vitals.heal(difference)

func _restore() -> void:
	pending_voices.clear()
	if voice_manager != null:
		voice_manager.stop()
		if voice_manager.player != null: voice_manager.player.stream_paused = false
	for node: Node in previous_modes:
		if is_instance_valid(node): node.process_mode = previous_modes[node]
	previous_modes.clear()

func cancel() -> void:
	_restore()
	queue_free()

func _exit_tree() -> void:
	_restore()
