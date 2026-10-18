class_name PuzzleController
extends Node
signal finished(outcome: String)
signal cue(event: Dictionary)
var board: PuzzleBoard = PuzzleBoard.new()
var combat: PuzzleCombat = PuzzleCombat.new()
var rules: PuzzleRules
var stage: String = "ready"
var focused: bool = true
var selected: int = -1
var moved: bool = false
var remaining: float = 6.0
var delay: float = 0.0
var attack_delay: float = 0.0
var groups: Array[Dictionary] = []
var wave: Array[Dictionary] = []
var action_queue: Array[Dictionary] = []
var highlighted: Array[int] = []
var combos: int = 0
var last_event: Dictionary = {}

func setup(allies: Array[Dictionary], foes: Array[Dictionary], config: PuzzleRules, seed_value: int) -> void:
	rules = config
	board.initialize(seed_value)
	combat.setup(allies,foes,config,seed_value+1)
	remaining = rules.move_seconds

func press(cell: int) -> void:
	if stage != "ready" or not focused or cell < 0 or cell >= 30: return
	selected = cell
	moved = false
	remaining = rules.move_seconds
	combos = 0
	last_event.clear()
	stage = "drag"

func drag(cell: int) -> void:
	if stage != "drag" or not focused or cell < 0 or cell >= 30: return
	for next: int in board.path_between(selected,cell):
		board.swap(selected,next)
		selected = next
		moved = true

func release() -> void:
	if stage != "drag" or not focused: return
	selected = -1
	if not moved:
		stage = "ready"
		return
	groups.clear()
	wave = board.matches()
	stage = "match"
	delay = 0.02

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: focused = true

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if rules == null or not focused or stage in ["done","blocked"]: return
	for event: Dictionary in combat.tick_enemies(delta):
		last_event = event
		cue.emit(event)
	if combat.health() <= 0:
		stage = "done"
		selected = -1
		action_queue.clear()
		finished.emit("defeat")
		return
	advance_attacks(delta)
	if stage == "done": return
	if stage == "ready": return
	if stage == "drag":
		if moved:
			remaining = maxf(0,remaining-delta)
			if remaining <= 0: release()
		return
	delay -= delta
	if delay > 0: return
	match stage:
		"match":
			if not wave.is_empty():
				var group: Dictionary = wave.pop_front()
				groups.append(group)
				highlighted.assign(group.cells)
				combos += 1
				cue.emit({"kind":"combo","number":combos})
				stage = "clear"
				delay = 0.05
			elif not highlighted.is_empty():
				highlighted.clear()
				board.refill()
				stage = "fall"
				delay = 0.06
			else:
				action_queue.append_array(combat.actions(groups))
				combat.turn += 1
				if not board.has_move(): board.initialize(board.rng.randi())
				stage = "ready"
				remaining = rules.move_seconds
		"clear":
			for i: int in highlighted: board.cells[i] = -1
			stage = "match"
			delay = 0.02
		"fall":
			wave = board.matches()
			stage = "match"
		"actions":
			# Compatibility for scripted completion; live play never waits here.
			stage = "ready"

func advance_attacks(delta: float) -> void:
	attack_delay -= delta
	if attack_delay <= 0 and not action_queue.is_empty():
		var action: Dictionary = action_queue.pop_front()
		last_event = combat.apply_action(action)
		attack_delay = 0.06
		if not last_event.is_empty(): cue.emit(last_event)
	var result: String = combat.outcome()
	if not result.is_empty():
		stage = "done"
		selected = -1
		action_queue.clear()
		finished.emit(result)
