class_name RainbowActionBattle
extends Node
## The encounter owns this controller; existing RTS units and settlement retain identity.
var game: GameDirector
var profile: RainbowActionProfile
var actors: Dictionary = {}
var controlled_id: int = -1
var hud: RainbowActionHud
var visual: RainbowActionVisual
var projectiles: Array[Dictionary] = []
var swings: Array[Dictionary] = []
var movement: Vector2 = Vector2.ZERO
var boosting: bool = false
var input_override: bool = false # deterministic tests only; never enabled by gameplay
var shot_serial: int = 0
var feedback: RainbowActionFeedback
var buffered: StringName = &""
var buffer_left: float = 0.0
var held_action: StringName = &""
var last_target_id: int = -1
var mechanics: RainbowTempleMechanics
var original_camera_zoom: Vector2 = Vector2.ONE

static func eligible(choice: EncounterDefinition, snapshot: Dictionary) -> bool:
	return choice != null and choice.action_profile != null and not snapshot.is_empty() and str(snapshot.get("return_map_id", "")) in choice.action_profile.allowed_maps

func configure(owner_game: GameDirector, settings: RainbowActionProfile) -> void:
	game = owner_game
	original_camera_zoom = game.camera.zoom
	profile = settings
	for unit: TacticalUnit in game.units.values():
		var actor: RainbowActionActor = RainbowActionActor.new()
		actor.setup(unit, profile)
		actors[unit.unit_id] = actor
		unit.active.clear()
		unit.queued.clear()
		unit._stop_motion()
	game.selection.set_process_unhandled_input(false)
	game.selection.selection_changed.connect(_selection_changed)
	for id: int in game.roster_ids:
		if switch_to(id): break
	visual = RainbowActionVisual.new()
	visual.battle = self
	visual.z_index = 3500
	game.render_root.add_child(visual)
	feedback = RainbowActionFeedback.new()
	feedback.battle = self
	add_child(feedback)
	hud = RainbowActionHud.new()
	hud.battle = self
	add_child(hud)
	mechanics = RainbowTempleMechanics.new()
	mechanics.configure(self)
	# Warnings stay above the floor but below characters and hit effects.
	mechanics.z_index = -100
	game.render_root.add_child(mechanics)

func switch_to(id: int) -> bool:
	var unit: TacticalUnit = game.get_unit(id)
	if unit == null or not unit.alive() or unit.team != 0 or not unit.definition.controllable: return false
	controlled_id = id
	last_target_id = -1
	if is_instance_valid(hud) and is_instance_valid(hud.touch_router): hud.touch_router.reset()
	buffered = &""; buffer_left = 0; held_action = &""
	if is_instance_valid(feedback):
		feedback.voice.stop()
		feedback.note("接管  ·  " + unit.definition.display_name)
	if game.selection.selected_ids != [id]: game.selection.select_ids([id])
	return true

func _selection_changed(ids: Array[int]) -> void:
	if not ids.is_empty() and ids[0] != controlled_id: switch_to(ids[0])

func controlled() -> TacticalUnit:
	return game.get_unit(controlled_id)

func request(kind: StringName) -> bool:
	if game.mode != &"battle" or not actors.has(controlled_id): return false
	var actor: RainbowActionActor = actors[controlled_id]
	if is_instance_valid(hud) and not input_override:
		sample_input()
		if movement.length_squared() > 0.01 and actor.action == &"": actor.unit.facing = movement.normalized()
		if kind in [&"melee", &"ranged"] and hud.touch_mode: assist_aim(actor, kind)
	if actor.request(kind):
		buffered = &""; buffer_left = 0
		return true
	if actor.unit.alive() and actor.stun <= 0 and ((actor.recovery > 0 and actor.recovery <= profile.input_buffer) or actor.hit_stop > 0):
		buffered = kind; buffer_left = profile.input_buffer
	elif is_instance_valid(feedback):
		if kind == &"ranged" and actor.unit.vitals.mana < actor.weapon.mana_cost: feedback.note("MP 不足  ·  改用近攻")
		elif kind == &"guard" and actor.bp < 12: feedback.note("BP 不足  ·  鬆開加速恢復")
	return false

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		held_action = &""; buffered = &""; buffer_left = 0

func assist_aim(actor: RainbowActionActor, kind: StringName) -> void:
	if kind == &"ranged" and hud.touch_router.aim.length_squared() > 0.01:
		actor.unit.facing = hud.touch_router.aim
		return
	var reach: float = actor.profile.melee_range if kind == &"melee" else actor.profile.projectile_speed * actor.profile.projectile_lifetime
	var best_angle: float = PI / 4
	var best_distance: float = INF
	var direction: Vector2 = actor.unit.facing
	for candidate: RainbowActionActor in actors.values():
		if not candidate.unit.alive() or candidate.unit.team == actor.unit.team: continue
		var offset: Vector2 = candidate.unit.position - actor.unit.position
		var distance: float = offset.length()
		var angle: float = absf(actor.unit.facing.angle_to(offset))
		if distance > reach + candidate.extra_radius() or angle > best_angle: continue
		if is_equal_approx(angle, best_angle) and distance >= best_distance: continue
		if not line_clear(actor.unit.position, candidate.unit.position): continue
		best_angle = angle; best_distance = distance; direction = offset.normalized()
		last_target_id = candidate.unit.unit_id
	actor.unit.facing = direction

func handle_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode else event.keycode
		match key:
			KEY_S: request(&"melee")
			KEY_D: request(&"ranged")
			KEY_SPACE: request(&"guard")
			KEY_ESCAPE: game.retreat()
			KEY_TAB: cycle()
			_:
				var slot: int = DemoRules.slot_for_key(key)
				if slot >= 0 and slot < game.roster_ids.size(): switch_to(game.roster_ids[slot])
		game.get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A: request(&"melee")
			JOY_BUTTON_X: request(&"ranged")
			JOY_BUTTON_B: request(&"guard")
			JOY_BUTTON_RIGHT_SHOULDER: cycle()
		game.get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = game.get_canvas_transform().affine_inverse() * event.position
		var unit: TacticalUnit = game.pick_unit(point, 0)
		if unit != null: switch_to(unit.unit_id)
		game.get_viewport().set_input_as_handled()

func cycle() -> void:
	var start: int = game.roster_ids.find(controlled_id)
	for offset: int in range(1, game.roster_ids.size() + 1):
		if switch_to(game.roster_ids[(start + offset) % game.roster_ids.size()]): return

func sample_input() -> void:
	if input_override: return
	var screen_direction: Vector2 = Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)))
	boosting = Input.is_physical_key_pressed(KEY_A) or hud.run_held
	if not Input.get_connected_joypads().is_empty():
		var device: int = Input.get_connected_joypads()[0]
		var stick: Vector2 = Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if stick.length() > 0.2: screen_direction += stick.normalized() * clampf((stick.length() - 0.2) / 0.8, 0, 1)
		boosting = boosting or Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER)
	screen_direction += hud.stick.value
	screen_direction = screen_direction.limit_length()
	movement = Iso.unproject(screen_direction).normalized() * screen_direction.length()

func tick(delta: float) -> void:
	if controlled() == null or not controlled().alive(): cycle()
	sample_input()
	if is_instance_valid(mechanics): mechanics.tick(delta)
	for id: int in actors:
		var actor: RainbowActionActor = actors[id]
		var released: StringName = actor.advance(delta)
		if released != &"": release(actor, released)
	buffer_left = maxf(0, buffer_left - delta)
	if buffer_left <= 0: buffered = &""
	if buffered != &"":
		if not input_override and hud.touch_mode and buffered in [&"melee",&"ranged"]:
			assist_aim(actors[controlled_id],buffered)
		if (actors[controlled_id] as RainbowActionActor).request(buffered): buffered = &""
	elif controlled() != null and controlled().alive() and (actors[controlled_id] as RainbowActionActor).recovery <= 0:
		var repeat_action: StringName = held_action
		if not input_override:
			if Input.is_physical_key_pressed(KEY_S): repeat_action = &"melee"
			elif Input.is_physical_key_pressed(KEY_D): repeat_action = &"ranged"
		if repeat_action != &"": request(repeat_action)
	for id: int in actors:
		var actor: RainbowActionActor = actors[id]
		if id == controlled_id: actor.move(movement, boosting, delta)
		else:
			var direction: Vector2 = ai_direction(actor)
			actor.move(direction, actor.evading, delta)
	tick_projectiles(delta)
	for i: int in range(swings.size() - 1, -1, -1):
		swings[i].left -= delta
		if swings[i].left <= 0: swings.remove_at(i)
	visual.queue_redraw()

func ai_direction(actor: RainbowActionActor) -> Vector2:
	var unit: TacticalUnit = actor.unit
	actor.evading = false
	if not unit.alive() or actor.stun > 0: return Vector2.ZERO
	var leader: TacticalUnit = controlled()
	var target: TacticalUnit = game.nearest_enemy(unit, 100000 if unit.team == 1 else profile.ally_leash)
	var destination: Vector2 = unit.position
	var evade: Dictionary = mechanics.safe_destination(actor) if unit.team == 0 and is_instance_valid(mechanics) else {}
	if not evade.is_empty():
		actor.evading = true
		actor.action = &""; unit.attack_windup_left = -1
		return path_direction(actor,evade.point)
	if actor.mechanic_lock: return Vector2.ZERO
	var ranged_type: bool = actor.enemy.pattern in ["priest", "bat"] if actor.enemy != null else unit.definition.attack_range > 100
	var use_ranged: bool = ranged_type and unit.vitals.mana >= actor.weapon.mana_cost
	if unit.team == 0 and leader != null and unit.position.distance_to(leader.position) > profile.ally_leash:
		target = null
	if target != null and unit.team == 0 and leader != null and target.position.distance_to(leader.position) > profile.ally_leash:
		target = null
	if target != null:
		var distance: float = unit.position.distance_to(target.position)
		var reach: float = actor.profile.projectile_speed * actor.profile.projectile_lifetime * 0.7 if use_ranged else actor.profile.melee_range * 0.86
		reach += (actors[target.unit_id] as RainbowActionActor).extra_radius()
		if distance <= reach and line_clear(unit.position, target.position):
			if actor.action == &"" and actor.recovery <= 0:
				var ritual_support: bool = actor.enemy != null and actor.enemy.pattern == "priest" and mechanics.initial_priests > 1
				if not ritual_support or mechanics.support_ready(unit.unit_id):
					unit.facing = unit.position.direction_to(target.position)
					if actor.request(&"ranged" if use_ranged else &"melee") and ritual_support: mechanics.support_started(unit.unit_id)
			if actor.enemy != null and actor.enemy.pattern == "bat" and actor.recovery > 0:
				var orbit: Vector2 = target.position + (unit.position-target.position).rotated(0.3 if unit.unit_id%2 == 0 else -0.3).normalized()*260
				return path_direction(actor,orbit)
			return Vector2.ZERO
		destination = mechanics.ritual_positions.get(unit.unit_id,target.position) if actor.enemy != null and actor.enemy.pattern == "priest" else target.position
		if actor.enemy != null and actor.enemy.pattern == "pincer" and distance > actor.profile.melee_range*1.3:
			var side: Vector2 = target.facing.orthogonal().normalized() * (110 if unit.unit_id%2 == 0 else -110)
			destination = target.position + side
	elif unit.team == 0 and leader != null:
		var slot: int = maxi(0, game.roster_ids.find(unit.unit_id))
		var offset: Vector2 = Vector2.from_angle(float(slot) * 2.39996) * (profile.follow_distance + 12 * sqrt(float(slot)))
		destination = leader.position + offset
		if unit.position.distance_to(destination) < 28: return Vector2.ZERO
	else: return Vector2.ZERO
	return path_direction(actor,destination)

func path_direction(actor: RainbowActionActor, destination: Vector2) -> Vector2:
	var unit: TacticalUnit = actor.unit
	var map: RID = unit.agent.get_navigation_map()
	if NavigationServer2D.map_get_iteration_id(map) == 0: return Vector2.ZERO
	# Keep routing on the existing authored navigation, with no parallel walkability mask.
	unit.agent.target_position = NavigationServer2D.map_get_closest_point(map, destination)
	var next: Vector2 = unit.agent.get_next_path_position()
	if unit.agent.is_navigation_finished(): return Vector2.ZERO
	var direction: Vector2 = unit.position.direction_to(next)
	var separation: Vector2 = Vector2.ZERO
	for other_id: int in actors:
		var other: TacticalUnit = (actors[other_id] as RainbowActionActor).unit
		var distance: float = unit.position.distance_to(other.position)
		var clearance: float = 34.0 + actor.extra_radius() + (actors[other_id] as RainbowActionActor).extra_radius()
		if other != unit and other.alive() and distance < clearance:
			separation += other.position.direction_to(unit.position) * (1.0 - distance / clearance)
	return (direction + separation * 0.6).limit_length()

func line_clear(from: Vector2, to: Vector2) -> bool:
	return game.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, 5)).is_empty()

func release(actor: RainbowActionActor, kind: StringName) -> void:
	var unit: TacticalUnit = actor.unit
	feedback.play("swing", unit.unit_id == controlled_id)
	var power: float = float(unit.stats_snapshot().attack)
	if kind == &"melee":
		swings.append({"point":unit.position,"facing":actor.attack_facing,"left":0.18,"team":unit.team,"combo":actor.combo,"weapon":actor.weapon,"range":actor.profile.melee_range,"angle":actor.profile.melee_half_angle})
		for other_id: int in actors:
			var other: RainbowActionActor = actors[other_id]
			var offset: Vector2 = other.unit.position - unit.position
			if other.unit.team == unit.team or not other.unit.alive() or offset.length() > actor.profile.melee_range + other.extra_radius(): continue
			var edge_angle: float = asin(clampf(other.extra_radius() / maxf(offset.length(), 1.0), 0.0, 1.0))
			if offset.length() > 1 and actor.attack_facing.dot(offset.normalized()) < cos(minf(PI, actor.profile.melee_half_angle + edge_angle)): continue
			if line_clear(unit.position, other.unit.position):
				var was_blocked: int = other.blocked_hits
				var damage: float = other.receive_hit(unit.position, power * actor.weapon.melee_power, unit.definition.outgoing_damage_scale, actor.weapon.stagger, actor.weapon.knockback)
				if unit.unit_id == controlled_id and damage > 0: last_target_id = other.unit.unit_id
				var cue: String = "break" if actor.combo == 3 else "cleave" if actor.combo == 2 else "cut"
				if actor.weapon.effect in ["heavy", "crescent"]: cue = "cleave"
				elif actor.weapon.effect in ["rifle", "scatter"]: cue = "bang"
				feedback.impact(unit.unit_id, other, damage, cue, other.blocked_hits > was_blocked)
	else:
		for index: int in actor.weapon.projectile_count:
			shot_serial += 1
			var angle: float = (index - (actor.weapon.projectile_count - 1) * 0.5) * actor.weapon.spread
			projectiles.append({"id":shot_serial,"source_id":unit.unit_id,"point":unit.position,"velocity":actor.attack_facing.rotated(angle) * actor.profile.projectile_speed,"left":actor.profile.projectile_lifetime,"team":unit.team,"power":power * actor.profile.ranged_power,"scale":unit.definition.outgoing_damage_scale,"weapon":actor.weapon,"hit_ids":[],"pierce":actor.weapon.pierce})

func tick_projectiles(delta: float) -> void:
	for i: int in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		var from: Vector2 = shot.point
		var to: Vector2 = from + shot.velocity * minf(delta, shot.left)
		var wall: Dictionary = game.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, 5))
		if not wall.is_empty(): to = wall.position
		var candidates: Array[Dictionary] = []
		for id: int in actors:
			var actor: RainbowActionActor = actors[id]
			if actor.unit.team == shot.team or not actor.unit.alive() or id in shot.hit_ids: continue
			var point: Vector2 = Geometry2D.get_closest_point_to_segment(actor.unit.position, from, to)
			if point.distance_to(actor.unit.position) <= actor.body_radius + 7:
				candidates.append({"actor":actor, "distance":from.distance_to(point)})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
		for candidate: Dictionary in candidates:
			if shot.pierce <= 0: break
			var victim: RainbowActionActor = candidate.actor
			if victim.unit.unit_id in shot.hit_ids: continue
			projectile_hit(shot, victim, from, 1.0)
			shot.pierce -= 1
			var weapon: RainbowWeaponDefinition = shot.weapon
			if weapon.splash > 0:
				for id: int in actors:
					var other: RainbowActionActor = actors[id]
					if id in shot.hit_ids or other.unit.team == shot.team or not other.unit.alive(): continue
					if other.unit.position.distance_to(victim.unit.position) <= weapon.splash + other.extra_radius() and line_clear(victim.unit.position, other.unit.position):
						projectile_hit(shot, other, victim.unit.position, 0.55)
		shot.point = to
		shot.left -= delta
		if shot.pierce <= 0 or not wall.is_empty() or shot.left <= 0: projectiles.remove_at(i)

func projectile_hit(shot: Dictionary, victim: RainbowActionActor, origin: Vector2, multiplier: float) -> void:
	shot.hit_ids.append(victim.unit.unit_id)
	var weapon: RainbowWeaponDefinition = shot.weapon
	var was_blocked: int = victim.blocked_hits
	var damage: float = victim.receive_hit(origin, shot.power * multiplier, shot.scale, weapon.stagger, weapon.knockback)
	if shot.source_id == controlled_id and damage > 0: last_target_id = victim.unit.unit_id
	feedback.impact(shot.source_id, victim, damage, "bang", victim.blocked_hits > was_blocked)

func sample_position(id: int) -> Vector2:
	if actors.has(id): return (actors[id] as RainbowActionActor).pose.sample(Engine.get_physics_interpolation_fraction())
	var unit: TacticalUnit = game.get_unit(id)
	return unit.position if unit != null else Vector2.ZERO

func follow_camera(delta: float) -> void:
	if controlled() != null:
		var target: Vector2 = Iso.project(sample_position(controlled_id))
		var zoom_target: Vector2 = original_camera_zoom
		var boss: RainbowActionActor = mechanics.boss_actor() if is_instance_valid(mechanics) else null
		if boss != null and controlled().position.distance_to(boss.unit.position) < 700:
			var dragon: bool = boss.enemy.pattern == "dragon"
			var height: float = boss.weapon.layout.frame_rects[0].size.y * boss.weapon.sprite_scale
			var boss_center: Vector2 = Iso.project(boss.unit.position) - Vector2(0, height * 0.5)
			target = target.lerp(boss_center, 0.35 if dragon else 0.2)
			zoom_target *= 0.82 if dragon else 0.78 if mechanics.living_priests().size() >= 4 else 0.94
		game.camera.zoom = game.camera.zoom.lerp(zoom_target, MovementFeel.follow_alpha(delta))
		game.camera.position = game.camera.position.lerp(target, MovementFeel.follow_alpha(delta))

func dispose() -> void:
	if is_instance_valid(game.camera): game.camera.zoom = original_camera_zoom
	for actor: RainbowActionActor in actors.values(): actor.restore_body()
	if is_instance_valid(mechanics): mechanics.hazards.clear(); mechanics.queue_free()
	if is_instance_valid(feedback): feedback.shutdown()
	if is_instance_valid(visual): visual.queue_free()
	if is_instance_valid(hud): hud.hide()
	projectiles.clear()
	swings.clear()
