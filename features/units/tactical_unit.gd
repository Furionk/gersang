class_name TacticalUnit
extends CharacterBody2D
signal command_finished(unit_id: int)
signal died(unit_id: int)
signal skill_released(unit_id: int, skill_id: StringName)
## Presentation events only: the combat simulation remains the sole damage/cast authority.
signal visual_action_started(action: String)
var unit_id: int = 0
var persistent_unit_id: String = ""
var team: int = 0
var definition: UnitDefinition
var combat_stats: Dictionary = {}
var character: CharacterRecord
var permanent_slot: int = -1
var director: GameDirector
var vitals: UnitVitals
var fsm: UnitStateMachine
var agent: NavigationAgent2D
var view: UnitView
var abilities: AbilityController
var statuses: StatusController
var active: Dictionary = {}
var queued: Array[Dictionary] = []
var facing: Vector2 = Vector2.DOWN
var cooldowns: Dictionary = {}
var attack_timer: float = 0.0
var attack_windup_left: float = -1.0
var locked_attack_id: int = -1
var cast_left: float = -1.0
var cast_visual_left: float = 0.0
var shake_left: float = 0.0
var control_left: float = 0.0
var think_left: float = 0.0
var enemy_scan_left: float = 3.0
var reacquire_left: float = 0.0
var repeat_command: Dictionary = {}
var shots: int = 0
var casts: int = 0
var desired_velocity: Vector2 = Vector2.ZERO
var nav_target: Vector2 = Vector2.ZERO
var repath_left: float = 0.0
var stuck_left: float = 0.0
var previous_position: Vector2
var navigation_blocked: bool = false
var navigation_wait_left: float = 0.0
var navigation_iteration: int = -1
var navigation_goal: Vector2
var held: bool = false
var initialized: bool = false
var is_summon: bool = false
var summon_left: float = -1.0
var summoner_id: int = -1
var charging: bool=false
var evolved: bool=false
var channeling:bool=false
var petrified_left:float=0

func initialize(data: UnitDefinition, owner_director: GameDirector, id_number: int, side: int, at: Vector2) -> void:
	definition = data
	director = owner_director
	unit_id = id_number
	team = side
	position = at
	previous_position = at
	collision_layer = 2
	collision_mask = 5 if data.movement_type == UnitDefinition.Movement.GROUND else 0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	vitals = UnitVitals.new()
	vitals.name = "Vitals"
	vitals.initialize(data)
	_refresh_stats()
	vitals.health = vitals.max_health
	vitals.mana = vitals.max_mana
	add_child(vitals)
	fsm = UnitStateMachine.new()
	fsm.name = "StateMachine"
	add_child(fsm)
	statuses = StatusController.new()
	statuses.name = "Statuses"
	add_child(statuses)
	abilities = AbilityController.new()
	abilities.name = "Abilities"
	abilities.initialize(self)
	abilities.cooldowns = cooldowns
	add_child(abilities)
	agent = NavigationAgent2D.new()
	agent.name = "NavigationAgent"
	agent.radius = GameSettings.profile.collision_radius
	agent.neighbor_distance = 65.0
	agent.max_neighbors = 8
	agent.path_desired_distance = 7.0
	agent.target_desired_distance = 9.0
	agent.max_speed = float(combat_stats["speed"]) * 2.5
	agent.avoidance_enabled = false
	add_child(agent)
	if data.movement_type == UnitDefinition.Movement.AIR:
		agent.set_navigation_map(director.ground.air_map)
	agent.velocity_computed.connect(_safe_velocity)
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = GameSettings.profile.collision_radius
	collision.shape = shape
	add_child(collision)
	vitals.died.connect(_die)
	think_left = float(id_number % 7) * 0.03
	initialized = true

func alive() -> bool:
	return vitals != null and vitals.health > 0.0

func stats_snapshot() -> Dictionary:
	var result: Dictionary=combat_stats.duplicate()
	if statuses!=null:
		for field: String in ["attack","attack_min","attack_max"]:
			result[field]=(float(result[field])+statuses.buff_sum("bonus"))*statuses.buff_product("attack")
	return result
func attack_range_now() -> float:
	return definition.attack_range+(statuses.buff_sum("range") if statuses!=null else 0.0)
func attack_interval_now() -> float:
	var haste: float=statuses.buff_product("haste") if statuses!=null else 1.0
	if is_summon and director!=null: haste*=director.summon_field_multiplier(self,position,true)
	return definition.attack_interval/haste

func available_skills() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = definition.skills.duplicate()
	var ids: Dictionary = {}
	for skill: SkillDefinition in result: ids[skill.id] = true
	if character != null:
		for skill: SkillDefinition in character.equipment_skills():
			if not ids.has(skill.id): result.append(skill); ids[skill.id] = true
	return result

func rules() -> CombatStatRules:
	return definition.stat_rules if definition.stat_rules != null else CombatStats.DEFAULT_RULES

func attach_character(record: CharacterRecord, slot: int) -> void:
	if character != null and character.changed.is_connected(_refresh_stats): character.changed.disconnect(_refresh_stats)
	character = record
	permanent_slot = slot
	record.changed.connect(_refresh_stats)
	_refresh_stats()
	vitals.health = clampf(record.health, 1, vitals.max_health)
	vitals.mana = clampf(record.mana, 0, vitals.max_mana)

func _refresh_stats() -> void:
	combat_stats = character.stats() if character != null else CombatStats.calculate(definition, {"strength":definition.strength, "agility":definition.agility, "intelligence":definition.intelligence, "luck":definition.luck, "vitality":definition.vitality}, definition.level)
	var old_max: float = vitals.max_health
	vitals.max_health = float(combat_stats["health"])
	vitals.max_mana = float(combat_stats["mana"])
	vitals.health = vitals.max_health if old_max <= 1 else minf(vitals.health, vitals.max_health)
	vitals.mana = minf(vitals.mana, vitals.max_mana)
	if agent != null:
		agent.max_speed = float(combat_stats["speed"]) * 2.5

func _exit_tree() -> void:
	if character != null and character.changed.is_connected(_refresh_stats):
		character.changed.disconnect(_refresh_stats)

func issue_command(command: Dictionary) -> void:
	if director!=null and director.mode==&"battle" and director.phases!=null and director.phases.frozen(): return
	if not alive() or not definition.controllable:
		return
	if bool(command.get("queued", false)) and not active.is_empty():
		queued.append(command.duplicate())
		return
	queued.clear()
	channeling=false
	active = command.duplicate()
	active["issued_usec"] = Time.get_ticks_usec()
	held = active.get("kind", "") == "hold"
	repeat_command.clear()
	cast_left = -1.0
	attack_windup_left = -1.0
	locked_attack_id = -1
	_reset_navigation()
	if active.get("kind", "") in ["stop", "hold"]:
		_stop_motion()
		if held:
			fsm.transition(&"hold")
		else:
			active.clear()
			reacquire_left = GameSettings.profile.stop_reacquire_delay
			fsm.transition(&"idle")

func tick(delta: float) -> void:
	if not initialized or not alive():
		return
	if is_summon:
		summon_left -= delta
		if summon_left <= 0:
			vitals.damage(999999)
			return
	if active.has("issued_usec"):
		director.command_latency_ms = maxf(director.command_latency_ms, (Time.get_ticks_usec() - int(active["issued_usec"])) / 1000.0)
		active.erase("issued_usec")
	attack_timer = maxf(0, attack_timer - delta)
	reacquire_left = maxf(0, reacquire_left - delta)
	cast_visual_left = maxf(0, cast_visual_left - delta)
	shake_left = maxf(0, shake_left - delta)
	repath_left -= delta
	navigation_wait_left = maxf(0.0, navigation_wait_left - delta)
	think_left -= delta
	enemy_scan_left -= delta
	abilities.tick(delta)
	statuses.tick(delta)
	petrified_left=maxf(0,petrified_left-delta)
	vitals.regenerate(delta, definition.mana_regeneration)
	if channeling:
		_stop_motion()
		if control_left>0: control_left=maxf(0,control_left-delta)
		return
	if charging:
		if control_left>0: control_left=maxf(0,control_left-delta)
		return
	if control_left > 0:
		control_left -= delta
		_stop_motion()
		fsm.transition(&"controlled")
		return
	if cast_left >= 0:
		cast_left -= delta
		_stop_motion()
		if cast_left <= 0:
			cast_left = -1.0
			_release_skill()
		return
	if attack_windup_left >= 0:
		attack_windup_left -= delta
		_stop_motion()
		if attack_windup_left <= 0:
			attack_windup_left = -1.0
			var target: TacticalUnit = director.get_unit(locked_attack_id)
			if target != null and target.alive() and not target.statuses.hidden() and position.distance_to(target.position) <= attack_range_now() + 18:
				shots += 1
				director.basic_attack(self, target, float(stats_snapshot()["attack"]))
				attack_timer = attack_interval_now()
		return
	# Obsolete saved/test repeat requests cannot bypass fresh click confirmation.
	repeat_command.clear()
	if definition.random_nearby_target:
		var autonomous_target: TacticalUnit=director.get_unit(locked_attack_id)
		if think_left<=0 or autonomous_target==null or not autonomous_target.alive() or autonomous_target.statuses.hidden():
			think_left=0.8
			var nearby: Array[TacticalUnit]=[]
			for candidate: TacticalUnit in director.units.values():
				if candidate.team!=team and candidate.alive() and not candidate.statuses.hidden() and position.distance_to(candidate.position)<=definition.detection_range: nearby.append(candidate)
			autonomous_target=nearby[director.rng.randi_range(0,nearby.size()-1)] if not nearby.is_empty() else null
			locked_attack_id=autonomous_target.unit_id if autonomous_target!=null else -1
		if autonomous_target!=null: _engage(autonomous_target,delta)
		else: _stop_motion()
		return
	var kind: String = str(active.get("kind", ""))
	if kind == "move":
		_move_to(active.get("point", position), delta)
		return
	if kind == "cast":
		_tick_cast(delta)
		return
	if kind in ["attack", "attack_move"]:
		# Support can pause an attack, then resume it; explicit travel is untouched.
		if team==0 and _auto_support(): return
		var target: TacticalUnit = director.get_unit(int(active.get("target", -1)))
		if kind == "attack_move" and (target == null or not target.alive()):
			target = director.nearest_enemy(self, definition.detection_range * GameSettings.profile.detection_multiplier)
			active["target"] = target.unit_id if target != null else -1
		if target != null and target.alive():
			_engage(target, delta)
		elif kind == "attack_move":
			_move_to(active.get("point", position), delta)
		else:
			_finish()
		return
	if team == 1:
		var target: TacticalUnit = director.get_unit(locked_attack_id)
		if enemy_scan_left <= 0.000001:
			enemy_scan_left = 3.0
			if target == null or not target.alive():
				target = director.nearest_enemy(self, 100000.0)
				locked_attack_id = target.unit_id if target != null else -1
		# A live but distant lock must not make an enemy ignore a unit in
		# striking range. This local reaction does not change the 3s global scan.
		if target != null and target.alive() and position.distance_to(target.position) > definition.attack_range and think_left <= 0:
			think_left = 0.24
			var nearby: TacticalUnit = director.nearest_enemy(self, definition.attack_range)
			if nearby != null:
				target = nearby
				_reset_navigation()
		if target != null and target.alive():
			if _auto_enemy_skill(target):
				return
			_engage(target, delta)
		else:
			_stop_motion()
		return
	if think_left <= 0:
		think_left = support_think_interval()
		if _auto_support():
			return
		if reacquire_left <= 0:
			var limit: float = definition.attack_range if held else definition.detection_range * GameSettings.profile.detection_multiplier
			var enemy: TacticalUnit = director.nearest_enemy(self, limit)
			if enemy != null:
				_engage(enemy, delta)
				return
		if not held:
			fsm.transition(&"idle")
		_stop_motion()
	elif fsm.current in [&"chase",&"attack"]:
		var target: TacticalUnit = director.get_unit(locked_attack_id)
		if target != null and target.alive():
			_engage(target, delta)

func can_cast(skill: SkillDefinition) -> bool:
	return abilities.available(skill) and cast_left < 0

func _tick_cast(delta: float) -> void:
	var skill: SkillDefinition = active.get("skill")
	if skill == null:
		_finish()
		return
	var point: Vector2 = active.get("point", position)
	var target_id: int = int(active.get("target", -1))
	if skill.target_mode == SkillDefinition.Target.SELF:
		point = position
	elif skill.target_mode in [SkillDefinition.Target.ALLY, SkillDefinition.Target.ENEMY]:
		var target: TacticalUnit = director.get_unit(target_id)
		if target == null or not target.alive():
			_finish()
			return
		point = target.position
	active["point"] = point
	if not can_cast(skill):
		_finish()
		return
	var error: String = director.validate_skill_target(self, skill, point, target_id)
	if error != "":
		director.message.emit(error)
		_finish()
		return
	if not skill.battlefield_range and skill.target_mode not in [SkillDefinition.Target.SELF, SkillDefinition.Target.DIRECTION] and position.distance_to(point) > skill.range:
		_navigate(point, delta)
		fsm.transition(&"blocked" if navigation_blocked else &"chase")
		return
	if vitals.spend(skill.mana_cost):
		# Casting breaks stealth; the stealth ability then applies its fresh state.
		statuses.reveal(false)
		if team == 1 and director.voices != null: director.voices.enemy_event(self, &"engage")
		active["paid"] = true
		_stop_motion()
		facing = position.direction_to(point) if point != position else facing
		fsm.transition(&"cast")
		visual_action_started.emit("cast")
		director.audio.play("cast")
		var windup: float = skill.cast_time * GameSettings.profile.cast_multiplier
		if team==1:windup=maxf(windup,definition.minimum_ai_cast_time)
		if windup <= 0:
			_release_skill()
		else:
			cast_left = windup

func _release_skill() -> void:
	var skill: SkillDefinition = active.get("skill")
	if skill == null:
		_finish()
		return
	var point: Vector2 = active.get("point", position)
	var target_id: int = int(active.get("target", -1))
	var error: String = director.validate_skill_target(self, skill, point, target_id)
	if error != "":
		if bool(active.get("paid", false)):
			vitals.restore(skill.mana_cost)
		director.message.emit(error)
		_finish()
		return
	if abilities.commit(skill, point, target_id):
		casts += 1
		cast_visual_left = 0.25
		skill_released.emit(unit_id, skill.id)
	_finish()

func support_think_interval()->float:
	var interval:float=0.24
	if team!=0:return interval
	for skill:SkillDefinition in available_skills():
		if abilities.autocast_enabled(skill):interval=minf(interval,maxf(0.05,skill.support_interval))
	return interval

func _auto_support() -> bool:
	if abilities.auto_scan_left>0.000001: return false
	abilities.auto_scan_left = support_think_interval()
	for skill: SkillDefinition in available_skills():
		if not abilities.autocast_enabled(skill) or not can_cast(skill):
			continue
		var target: TacticalUnit = abilities.support_target(skill)
		if target != null:
			if active.get("kind","") in ["attack","attack_move"]: queued.push_front(active.duplicate())
			active = {"kind":"cast", "skill":skill, "target":target.unit_id, "point":target.position}
			return true
	return false

func _auto_enemy_skill(target: TacticalUnit) -> bool:
	for skill: SkillDefinition in available_skills():
		if not skill.ai_enabled or skill.trigger==SkillDefinition.Trigger.ATTACK_HIT or float(abilities.ai_attempts.get(skill.id,0.0))>0: continue
		var limit: float = skill.radius if skill.target_mode==SkillDefinition.Target.SELF and skill.effect!=SkillDefinition.Effect.SUMMON else skill.range
		if skill.effect_data!=null and skill.effect_data.kind in [SkillEffectDefinition.Kind.BUFF,SkillEffectDefinition.Kind.STEALTH,SkillEffectDefinition.Kind.FIRE_TRAIL]: limit=skill.range
		if not can_cast(skill) or position.distance_to(target.position)>limit: continue
		var point: Vector2 = position if skill.target_mode==SkillDefinition.Target.SELF else target.position
		var target_id: int = target.unit_id if skill.target_mode==SkillDefinition.Target.ENEMY else -1
		if director.validate_skill_target(self,skill,point,target_id)!="": continue
		abilities.ai_attempts[skill.id] = maxf(0.1,skill.ai_attempt_interval)
		if director.rng.randf()>=skill.ai_cast_chance: continue
		active = {"kind":"cast", "skill":skill, "point":point,"target":target_id}
		return true
	return false

func _engage(target: TacticalUnit, delta: float) -> void:
	if target.statuses.hidden():
		locked_attack_id=-1
		_finish()
		return
	if locked_attack_id != target.unit_id:
		_reset_navigation()
	locked_attack_id = target.unit_id
	if position.distance_to(target.position) > attack_range_now():
		if held:
			_stop_motion()
			return
		_navigate(target.position, delta)
		fsm.transition(&"blocked" if navigation_blocked else &"chase")
	else:
		if director.voices != null: director.voices.enemy_event(self, &"engage")
		_reset_navigation()
		_stop_motion()
		facing = position.direction_to(target.position)
		if attack_timer <= 0:
			var windup:float=definition.attack_windup_override if definition.attack_windup_override>=0 else GameSettings.profile.attack_windup
			attack_windup_left = windup/statuses.buff_product("haste")
			fsm.transition(&"attack")
			visual_action_started.emit("attack")

func _move_to(point: Vector2, delta: float) -> void:
	fsm.transition(&"move")
	if position.distance_to(point) < 14:
		_finish()
		return
	_navigate(point, delta)
	if navigation_blocked:
		# Explicit travel still stops at the last reachable location. Combat
		# and casting intentions instead stay alive and retry through _navigate.
		_finish()
		return
	if agent.is_navigation_finished():
		if position.distance_to(point) > 18:
			director.message.emit("目的地不可達，停在最近可達位置。")
		_finish()

func _navigate(point: Vector2, delta: float) -> void:
	var iteration: int = NavigationServer2D.map_get_iteration_id(agent.get_navigation_map())
	if iteration == 0:
		_stop_motion()
		return
	if iteration != navigation_iteration or point.distance_squared_to(navigation_goal) > 400.0:
		_reset_navigation()
		navigation_iteration = iteration
		navigation_goal = point
	if navigation_wait_left > 0:
		_stop_motion()
		return
	if repath_left <= 0:
		var closest: Vector2 = NavigationServer2D.map_get_closest_point(agent.get_navigation_map(), point)
		agent.target_position = closest
		nav_target = closest
		navigation_goal = point
		repath_left = 0.22 + float(unit_id % 5) * 0.01
	var next: Vector2 = agent.get_next_path_position()
	if agent.is_navigation_finished():
		if position.distance_to(point) > 14:
			_wait_for_navigation()
		else:
			_stop_motion()
		return
	var movement_speed: float = float(combat_stats["speed"]) if director.mode == &"battle" else definition.speed
	desired_velocity = position.direction_to(next) * MovementFeel.speed(movement_speed,GameSettings.profile.movement_multiplier,statuses.speed_multiplier())
	agent.radius = GameSettings.profile.collision_radius
	agent.avoidance_enabled = true
	agent.velocity = desired_velocity
	if position.distance_squared_to(previous_position) < 0.2:
		stuck_left += delta
	else:
		stuck_left = 0
		navigation_blocked = false
	previous_position = position
	if stuck_left > 2.0:
		_wait_for_navigation()

func _wait_for_navigation() -> void:
	if not navigation_blocked and team == 0:
		if fsm.current == &"move":
			director.message.emit("目的地不可達，停在最近可達位置。")
		else:
			director.message.emit("目的地被阻擋，等待重新尋路。")
	navigation_blocked = true
	navigation_wait_left = 0.75 + float(unit_id % 5) * 0.03
	stuck_left = 0.0
	repath_left = 0.0
	previous_position = position
	_stop_motion()
	fsm.transition(&"blocked")

func _reset_navigation() -> void:
	navigation_blocked = false
	navigation_wait_left = 0.0
	stuck_left = 0.0
	repath_left = 0.0
	previous_position = position

func _safe_velocity(safe_velocity: Vector2) -> void:
	if not alive() or desired_velocity.length_squared() < 0.1 or control_left > 0:
		return
	velocity = safe_velocity
	move_and_slide()
	if velocity.length_squared() > 4:
		facing = MovementFeel.turn_facing(facing,velocity,GameSettings.profile.turn_speed)

func _stop_motion() -> void:
	desired_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	if agent != null:
		agent.velocity = Vector2.ZERO
		agent.avoidance_enabled = false

func _finish() -> void:
	_stop_motion()
	_reset_navigation()
	active.clear()
	if not queued.is_empty():
		active = queued.pop_front()
	else:
		fsm.transition(&"idle")
	command_finished.emit(unit_id)

func _die() -> void:
	channeling=false
	if definition.death_phase!=null and director.mode==&"battle" and director.phases!=null:
		if director.phases.request_death(self): return
	if not evolved and definition.death_evolution is UnitDefinition and director.mode==&"battle":
		evolved=true
		director.evolve_unit(self,definition.death_evolution as UnitDefinition)
		return
	active.clear()
	queued.clear()
	repeat_command.clear()
	statuses.clear()
	cast_left = -1.0
	attack_windup_left = -1.0
	_stop_motion()
	fsm.transition(&"dead")
	collision_layer = 0
	collision_mask = 0
	died.emit(unit_id)

func revive_from_item(health: float, mana: float) -> void:
	if alive(): return
	vitals.health = clampf(health,1,vitals.max_health)
	vitals.mana = clampf(mana,0,vitals.max_mana)
	control_left = 0
	fsm.revive()
	collision_layer = 2
	collision_mask = 5 if definition.movement_type == UnitDefinition.Movement.GROUND else 0
	_reset_navigation()
	think_left = 0
	vitals.changed.emit()
