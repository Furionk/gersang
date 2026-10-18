class_name RainbowTempleMechanics
extends Node2D
## Authoritative encounter-only warnings and attacks. Coordinates remain logical XY.
var battle: RainbowActionBattle
var states: Dictionary = {}
var hazards: Array[Dictionary] = []
var serial: int = 0
var schedule = preload("res://features/rainbow/attack_schedule.gd").new()
var rng := RandomNumberGenerator.new()
var ritual_clock: float = 0
var priest_count: int = -1
var regroup_until: float = 0
var projectile_hits: Dictionary = {}
var ritual_positions: Dictionary = {}
var formation_ready: bool = false
var initial_priests: int = 0
var ritual_center: Vector2 = Vector2.ZERO
var max_schedule_us: int = 0
var schedule_checks: int = 0

func configure(owner_battle: RainbowActionBattle) -> void:
	battle = owner_battle
	rng.seed = battle.game.rng.seed ^ 55047
	for id: int in battle.actors:
		var actor: RainbowActionActor = battle.actors[id]
		if actor.enemy != null:
			if actor.enemy.boss_tier != null: rng.seed = battle.game.rng.seed ^ actor.enemy.boss_tier.seed
			states[id] = {"timer":3.0 + float(id % 3) * 0.3,"cycle":0,"phase":1,"pending":false,"exposure":0.0,"message":"觀察紅色預警；離開範圍再反擊"}
			states[id].previous = ""
			states[id].repeats = 0
			states[id].support_at = 2.0 + (id % 8)*0.45

func tick(delta: float) -> void:
	ritual_clock += delta
	var priests: Array[int] = living_priests()
	if not formation_ready and priests.size() > 1: arrange_priests(priests)
	if priest_count >= 0 and priest_count != priests.size():
		regroup_until = ritual_clock + 1.5
		for id: int in ritual_positions.keys():
			if id not in priests: ritual_positions.erase(id)
		for id: int in priests:
			states[id].timer = maxf(states[id].timer,1.5)
			states[id].message = "儀式重組 · 擊破的方位形成缺口"
			if ritual_positions.has(id):
				var offset: Vector2 = ritual_positions[id]-ritual_center
				var destination: Vector2 = ritual_center+offset.normalized()*minf(280,offset.length()+24)
				var actor: RainbowActionActor = battle.actors[id]
				ritual_positions[id] = NavigationServer2D.map_get_closest_point(actor.unit.agent.get_navigation_map(),destination)
	priest_count = priests.size()
	for id: int in states:
		var actor: RainbowActionActor = battle.actors[id]
		var state: Dictionary = states[id]
		if not actor.unit.alive():
			actor.mechanic_lock = false
			continue
		var ratio: float = actor.unit.vitals.health / actor.unit.vitals.max_health
		var next_phase: int = 3 if actor.enemy.pattern == "dragon" and ratio <= 0.35 else 2 if ratio <= 0.65 else 1
		if next_phase != state.phase and actor.enemy.boss_tier != null:
			state.message = "轉階 · 火焰正在重組"
			state.timer = maxf(state.timer, actor.enemy.boss_tier.transition_warning)
		state.phase = next_phase
		if state.exposure > 0:
			state.exposure = maxf(0, state.exposure - delta)
			if state.exposure <= 0:
				actor.exposed = false; actor.mechanic_lock = false
				state.message = "龍鱗恢復 · 留意下一輪" if actor.enemy.pattern == "dragon" else "祭火重燃 · 繼續走位"
			continue
		state.timer -= delta
		if state.pending:
			var waiting: bool = false
			for hazard: Dictionary in hazards:
				if hazard.source == id and not hazard.fired: waiting = true
			if not waiting:
				state.pending = false; actor.mechanic_lock = false
				if actor.enemy.boss and int(state.cycle) % (3 if actor.enemy.pattern == "dragon" else 2) == 0:
					state.exposure = actor.enemy.exposure_seconds
					actor.exposed = true; actor.mechanic_lock = true
					state.message = "破鱗！核心裸露 · 傷害 ×%.1f" % actor.enemy.exposed_damage_scale if actor.enemy.pattern == "dragon" else "祭司施法耗竭 · 集火反擊"
			elif actor.enemy.pattern == "dragon" and actor.enemy.boss_tier != null and actor.enemy.boss_tier.tier >= 2 and state.timer <= 0 and int(state.cycle) % 3 != 0:
				begin_special(actor)
			continue
		if state.timer <= 0 and actor.action == &"" and actor.stun <= 0:
			if actor.enemy.pattern == "priest" and not ritual_turn(id,priests): continue
			begin_special(actor)
	for i: int in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[i]
		var owner_actor: RainbowActionActor = battle.actors.get(hazard.source)
		if owner_actor == null or not owner_actor.unit.alive(): hazards.remove_at(i); continue
		if not hazard.fired:
			hazard.warning -= delta
			if hazard.warning <= 0:
				hazard.fired = true
				if hazard.has("charge_velocity"): owner_actor.impulse = hazard.charge_velocity
				owner_actor.swing_pose_left = 0.3
				owner_actor.unit.visual_action_started.emit("attack")
				for victim: RainbowActionActor in battle.actors.values():
					if victim.unit.team != 0 or not victim.unit.alive() or not contains(hazard, victim.unit.position): continue
					if hazard.has("projectile_group"):
						var group: int = hazard.projectile_group
						if not projectile_hits.has(group): projectile_hits[group] = {}
						if projectile_hits[group].has(victim.unit.unit_id): continue
						projectile_hits[group][victim.unit.unit_id] = true
					# Ground breath is blocked by solid scenery; falling meteors are not.
					if hazard.kind == "cone" and not battle.line_clear(hazard.center, victim.unit.position): continue
					var blocked_before: int = victim.blocked_hits
					var damage: float = victim.receive_hit(owner_actor.unit.position, hazard.power, 1.0, 0.18, 90)
					battle.feedback.impact(hazard.source, victim, damage, "bang", victim.blocked_hits > blocked_before)
		else:
			hazard.flash -= delta
			if hazard.flash <= 0: hazards.remove_at(i)
	for group: int in projectile_hits.keys():
		var active: bool = false
		for hazard: Dictionary in hazards:
			if hazard.get("projectile_group",-1) == group: active = true; break
		if not active: projectile_hits.erase(group)
	queue_redraw()

func living_priests() -> Array[int]:
	var ids: Array[int] = []
	for id: int in states:
		var actor: RainbowActionActor = battle.actors[id]
		if actor.enemy.pattern == "priest" and actor.unit.alive(): ids.append(id)
	ids.sort()
	return ids

func arrange_priests(ids: Array[int]) -> void:
	var first: RainbowActionActor = battle.actors[ids[0]]
	var map: RID = first.unit.agent.get_navigation_map()
	if NavigationServer2D.map_get_iteration_id(map) == 0: return
	var extent: Vector2 = Vector2(battle.game.ground.cells)*Iso.CELL
	var center: Vector2 = first.unit.position.clamp(Vector2.ONE*400,extent-Vector2.ONE*400)
	ritual_center = center
	for index: int in ids.size():
		var actor: RainbowActionActor = battle.actors[ids[index]]
		var desired: Vector2 = center + Vector2.from_angle(PI/4+index*TAU/ids.size()) * (220 if ids.size() > 2 else 150)
		var point: Vector2 = formation_point(actor,desired)
		actor.unit.position = point; actor.pose.reset(point)
		ritual_positions[ids[index]] = point
	initial_priests = ids.size(); formation_ready = true

func formation_point(actor: RainbowActionActor, desired: Vector2) -> Vector2:
	var map: RID = actor.unit.agent.get_navigation_map()
	var shape := CircleShape2D.new(); shape.radius = actor.body_radius + 4
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape; query.collision_mask = 5; query.collide_with_areas = false
	for index: int in 81:
		var sample: Vector2 = desired if index == 0 else desired + Vector2.from_angle(index*2.39996)*sqrt(index)*18
		var point: Vector2 = NavigationServer2D.map_get_closest_point(map,sample)
		query.transform = Transform2D(0,point)
		if not battle.game.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): continue
		var clear: bool = true
		for placed: Vector2 in ritual_positions.values():
			if point.distance_to(placed) < actor.body_radius*2+16: clear = false; break
		if clear: return point
	return actor.unit.position

func ritual_turn(id: int, ids: Array[int]) -> bool:
	if ritual_clock < regroup_until: return false
	if ritual_rest(): return false
	if ids.size() <= 1: return true
	var slot: int = ids.find(id)
	var group: int = slot / 4
	if ids.size() > 4 and group != int(ritual_clock / 5.0) % 2: return false
	var active: int = 0
	for other: int in ids:
		if bool(states[other].pending): active += 1
	var limit: int = 1 if ids.size() <= 2 else 2
	if active >= limit: return false
	# Rotating leadership gives each survivor a turn without simultaneous opening casts.
	var leader: int = int(ritual_clock / 1.5) % ids.size()
	return slot == leader or (limit == 2 and slot == (leader+2)%ids.size())

func support_ready(id: int) -> bool:
	return not ritual_rest() and ritual_clock >= regroup_until and ritual_clock >= float(states[id].support_at)

func ritual_rest() -> bool:
	if initial_priests <= 1: return false
	# Shared recovery prevents independent casters from erasing every counter window.
	var active: float = 14.0 if initial_priests > 4 else 12.0 if initial_priests > 2 else 10.0
	var rest: float = 5.0 if initial_priests > 4 else 6.0
	var resting: bool = fmod(ritual_clock,active+rest) >= active
	if resting:
		for id: int in living_priests(): states[id].message = "儀式換息 · 把握空檔集火"
	return resting

func support_started(id: int) -> void:
	var count: int = living_priests().size()
	states[id].support_at = ritual_clock + (6.5 if count > 4 else 5.5 if count > 2 else 4.5)

func begin_special(actor: RainbowActionActor) -> void:
	var target: TacticalUnit = battle.game.nearest_enemy(actor.unit, 100000)
	if target == null: return
	var state: Dictionary = states[actor.unit.unit_id]
	var pattern: RainbowEnemyDefinition = actor.enemy
	state.cycle += 1
	state.timer = pattern.special_interval
	if pattern.pattern == "priest" and initial_priests > 1:
		state.timer *= maxf(0.6,float(living_priests().size())/initial_priests)
	state.pending = true
	actor.mechanic_lock = true
	actor.unit.facing = actor.unit.position.direction_to(target.position)
	actor.unit.velocity = Vector2.ZERO
	var phase: int = state.phase
	if pattern.boss_tier != null and pattern.pattern == "dragon":
		begin_dragon_combination(actor, target, state)
		return
	match pattern.pattern:
		"hound":
			add_hazard(actor,"cone",actor.unit.position,320,0,1.2,pattern.special_power,0.26)
			state.message = "火牙追擊 · 側移躲開直線"
		"pincer":
			var facing: Vector2 = actor.unit.facing
			for side: float in [-0.5,0.5]:
				actor.unit.facing = facing.rotated(side)
				add_hazard(actor,"cone",actor.unit.position,290,0,1.4,pattern.special_power,0.28)
			actor.unit.facing = facing
			state.message = "雙首夾擊 · 留意中央缺口"
		"troll":
			add_hazard(actor,"circle",target.position,150,0,1.8,pattern.special_power)
			state.message = "熔鎚破陣 · 重擊已鎖定"
		"bat":
			add_hazard(actor,"circle",target.position,60,0,1.2,pattern.special_power)
			state.message = "火羽落點 · 離開小圈"
		"slime":
			add_hazard(actor,"circle",target.position,75,0,1.4,pattern.special_power)
			state.message = "熔泡 · 離開腳下火圈"
		"beast":
			add_hazard(actor,"cone",actor.unit.position,260,0,pattern.warning_seconds,pattern.special_power,0.55)
			state.message = "裂地猛踏 · 繞到側後"
		"priest":
			var priests: Array[int] = living_priests()
			if int(state.cycle) % 2 == 1:
				marked_rain(actor,3 if phase == 1 else 5,95,pattern.warning_seconds,pattern.special_power)
				state.message = "祭火烙印 · 標記鎖定後散開"
			else:
				if priests.size() == 2:
					var other: RainbowActionActor = battle.actors[priests[1] if priests[0] == actor.unit.unit_id else priests[0]]
					actor.unit.facing = actor.unit.position.direction_to(other.unit.position)
					add_hazard(actor,"cone",actor.unit.position,actor.unit.position.distance_to(other.unit.position),0,1.6,pattern.special_power,0.12)
					state.message = "雙祭司連線 · 預警後燃燒，穿出連線"
				else:
					add_hazard(actor,"sector" if priests.size() >= 4 else "ring",actor.unit.position,370,145,1.8,pattern.special_power * 1.2,PI*0.65 if priests.size() >= 4 else PI)
					state.message = "封路儀式 · 留意安全缺口，擊殺祭司可拆陣"
		"dragon":
			match int(state.cycle) % 3:
				1:
					add_hazard(actor,"cone",actor.unit.position,620,0,pattern.warning_seconds,pattern.special_power,0.48 + phase * 0.09)
					state.message = "灼世吐息 · 紅色扇形鎖定後繞側"
				2:
					marked_rain(actor,2 + phase,115,1.8,pattern.special_power * 0.8)
					state.message = "熔星墜落 · 離開標記，不追蹤移動"
				0:
					add_hazard(actor,"ring",actor.unit.position,520,170,2.1,pattern.special_power * 1.3)
					state.message = "龍心爆燃 · 進入青圈，爆燃後破鱗反擊"

func marked_rain(actor: RainbowActionActor, count: int, radius: float, delay: float, power: float) -> void:
	var targets: Array[TacticalUnit] = []
	for victim: RainbowActionActor in battle.actors.values():
		if victim.unit.team == 0 and victim.unit.alive(): targets.append(victim.unit)
	# Player gets the first readable marker; no random unavoidable offscreen damage.
	targets.sort_custom(func(a: TacticalUnit, b: TacticalUnit) -> bool: return a.unit_id == battle.controlled_id or (b.unit_id != battle.controlled_id and a.unit_id < b.unit_id))
	var marked: Array[Vector2] = []
	for target: TacticalUnit in targets:
		if marked.size() >= count: break
		var crowded: bool = false
		for point: Vector2 in marked:
			if point.distance_to(target.position) < radius * 1.5: crowded = true
		if crowded: continue
		marked.append(target.position)
		add_hazard(actor,"circle",target.position,radius,0,delay,power)

func begin_dragon_combination(actor: RainbowActionActor, target: TacticalUnit, state: Dictionary) -> void:
	var tier: RainbowBossTier = actor.enemy.boss_tier
	var move: String = tier.choose(rng, state.previous, state.repeats)
	state.repeats = int(state.repeats) + 1 if move == state.previous else 1
	state.previous = move
	state.timer = tier.interval * (0.75 if tier.tier == 3 and state.phase == 3 else 1.0)
	var power: float = actor.enemy.special_power
	match move:
		"breath":
			add_hazard(actor,"cone",actor.unit.position,620,0,1.4,power,0.52)
			state.message = "吐息鎖定 · 繞側；留意第二次落星"
			add_hazard(actor,"circle",target.position,100,0,2.8,power * 0.7)
		"rain":
			marked_rain(actor, 2 + int(state.phase), 105, 1.8, power)
			state.message = "熔星標記已鎖定 · 持續走位"
		"ring":
			add_hazard(actor,"ring",actor.unit.position,520,175,2.1,power * 1.3)
			state.message = "龍心爆燃 · 進入青色安全內圈"
		"sweep":
			var facing: Vector2 = actor.unit.facing
			for step: int in 5:
				actor.unit.facing = facing.rotated(-0.8 + step * 0.4)
				add_hazard(actor,"cone",actor.unit.position,620,0,1.4 + step * 0.35,power * 0.65,0.22)
			actor.unit.facing = facing
			state.message = "順向掃焰 · 預警依次引爆，繞到龍背"
		"trail":
			var direction: Vector2 = actor.unit.position.direction_to(target.position)
			var start_index: int = hazards.size()
			for step: int in 6:
				add_hazard(actor,"circle",actor.unit.position + direction * (130 + step * 90),70,0,1.4 + step * 0.2,power * 0.8)
			if hazards.size() > start_index: hazards[start_index].charge_velocity = direction * sqrt(1200.0 * minf(430,actor.unit.position.distance_to(target.position)))
			state.message = "直線衝撞與熔痕 · 向兩側撤離"
		"fan":
			for ray: int in 5: add_projectile_path(actor,actor.unit.facing.rotated((ray-2)*0.22),0,1.3,power*0.55)
			state.message = "扇形火彈 · 沿預告軌跡間隙側移"
		"spiral":
			for ray: int in 8: add_projectile_path(actor,Vector2.from_angle(ray*TAU/8),0.75,1.4+ray*0.08,power*0.55)
			state.message = "螺旋彈道 · 預告路徑已鎖定"
		"expanding_ring":
			var facing: Vector2 = actor.unit.facing
			for wave: int in 3:
				actor.unit.facing = facing.rotated(wave*0.35)
				add_hazard(actor,"sector",actor.unit.position,260+wave*120,170+wave*120,1.4+wave*0.65,power*0.75,PI*0.78)
			actor.unit.facing = facing
			state.message = "擴散火環 · 青色缺口依預告方向轉動"

func add_projectile_path(actor: RainbowActionActor, direction: Vector2, turn: float, delay: float, power: float) -> void:
	if hazards.size() >= 152: return
	# A shared, locked polyline is both the warning and the sampled damage path.
	# Each projectile can hit each victim only once across all its path samples.
	var path: Array[Dictionary] = []
	serial += 1
	var group: int = serial
	var point: Vector2 = actor.unit.position + direction*110
	for step: int in 8:
		var next: Vector2 = point + direction.rotated(turn*step*0.2)*42
		if not battle.line_clear(point,next): break
		serial += 1
		path.append({"id":serial,"source":actor.unit.unit_id,"kind":"orb","center":next,"radius":32.0,"inner":0.0,"direction":direction,"angle":PI,"warning":delay+step*0.2,"total":delay+step*0.2,"power":power,"fired":false,"flash":0.18,"projectile_group":group,"previous":point})
		point = next
	if path.is_empty(): return
	for attempt: int in 4:
		var reservations: Array[Dictionary] = hazards.duplicate()
		reservations.append_array(path)
		if safe_schedule(reservations):
			hazards.append_array(path)
			return
		for segment: Dictionary in path:
			segment.warning += 0.5; segment.total += 0.5

func add_hazard(actor: RainbowActionActor, kind: String, center: Vector2, radius: float, inner: float, delay: float, power: float, angle: float = PI) -> void:
	if hazards.size() >= 160: return
	serial += 1
	var candidate: Dictionary = {"id":serial,"source":actor.unit.unit_id,"kind":kind,"center":center,"radius":radius,"inner":inner,"direction":actor.unit.facing,"angle":angle,"warning":delay,"total":delay,"power":power,"fired":false,"flash":0.4}
	if actor.enemy.boss_tier != null:
		var accepted: bool = false
		for attempt: int in 4:
			candidate.warning = maxf(1.2,delay) + attempt * 0.6
			candidate.total = candidate.warning
			var reservations: Array[Dictionary] = hazards.duplicate()
			reservations.append(candidate)
			if safe_schedule(reservations): accepted = true; break
		if not accepted: return
	hazards.append(candidate)
	queue_redraw()

func safe_schedule(reservations: Array[Dictionary]) -> bool:
	var unit: TacticalUnit = battle.controlled()
	if unit == null or not unit.alive(): return false
	var actor: RainbowActionActor = battle.actors[unit.unit_id]
	var speed: float = MovementFeel.speed(float(unit.combat_stats.speed), GameSettings.profile.movement_multiplier,1.0) * actor.weapon.move_multiplier
	var map: RID = unit.agent.get_navigation_map()
	if NavigationServer2D.map_get_iteration_id(map) == 0: return false
	var shape := CircleShape2D.new(); shape.radius = actor.body_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape; query.collision_mask = 5; query.collide_with_areas = false
	var space: PhysicsDirectSpaceState2D = battle.game.get_world_2d().direct_space_state
	var legal := func(from: Vector2, to: Vector2, radius: float) -> bool:
		if NavigationServer2D.map_get_closest_point(map,to).distance_to(to) > 2: return false
		query.transform = Transform2D(0,from)
		query.motion = to-from
		if not space.intersect_shape(query,1).is_empty(): return false
		var fractions: PackedFloat32Array = space.cast_motion(query)
		if fractions.size() < 2 or fractions[0] < 1.0: return false
		for other: RainbowActionActor in battle.actors.values():
			if other == actor or not other.unit.alive() or other.extra_radius() <= 0: continue
			var closest := Geometry2D.get_closest_point_to_segment(other.unit.position, from, to)
			if closest.distance_to(other.unit.position) < radius + other.body_radius: return false
		return true
	# Conservatively wait through the current action, then use normal walk speed.
	# Assuming permanent recovery slowdown wrongly rejects otherwise readable attacks.
	var delay: float = maxf(0.15,actor.windup + actor.recovery + actor.stun)
	var began: int = Time.get_ticks_usec()
	var result: bool = schedule.can_escape(unit.position,speed,actor.body_radius,reservations,legal,delay)
	max_schedule_us = maxi(max_schedule_us,Time.get_ticks_usec()-began); schedule_checks += 1
	if not result and "--trace-schedule" in OS.get_cmdline_user_args():
		print("SCHEDULE_REJECT ",unit.position," speed=",speed," legal_start=",legal.call(unit.position,unit.position,actor.body_radius)," hazards=",reservations.size())
	return result

static func contains(hazard: Dictionary, point: Vector2, padding: float = 0.0) -> bool:
	var offset: Vector2 = point - Vector2(hazard.center)
	var distance: float = offset.length()
	if distance > float(hazard.radius) + padding: return false
	if hazard.kind in ["ring","sector"] and distance < float(hazard.inner) - padding: return false
	if hazard.kind in ["cone","sector"] and distance > 1 and Vector2(hazard.direction).dot(offset.normalized()) < cos(minf(PI,float(hazard.angle) + padding / maxf(distance,30))): return false
	return true

func safe_destination(actor: RainbowActionActor) -> Dictionary:
	var threats: Array[Dictionary] = []
	for hazard: Dictionary in hazards:
		if not hazard.fired and contains(hazard, actor.unit.position, 18): threats.append(hazard)
	if threats.is_empty(): return {}
	var best: Vector2 = actor.unit.position
	var best_distance: float = INF
	var fallback: Vector2 = actor.unit.position
	var fallback_cost: float = INF
	var speed: float = MovementFeel.speed(float(actor.unit.combat_stats.speed),GameSettings.profile.movement_multiplier,1.0) * actor.weapon.move_multiplier
	speed *= 0.45 if actor.recovery > 0 else actor.profile.run_multiplier if actor.bp > 1 else 1.0
	# Candidate points must be clear of ALL pending warnings and reachable on authored nav.
	for distance: float in [90.0,180.0,300.0,540.0]:
		for direction_index: int in 16:
			var candidate: Vector2 = actor.unit.position + Vector2.from_angle(TAU * direction_index / 16.0) * distance
			var map: RID = actor.unit.agent.get_navigation_map()
			if NavigationServer2D.map_get_iteration_id(map) == 0: continue
			var legal: Vector2 = NavigationServer2D.map_get_closest_point(map,candidate)
			if legal.distance_to(candidate) > 10 or not battle.line_clear(actor.unit.position, candidate): continue
			var safe: bool = true
			for other: RainbowActionActor in battle.actors.values():
				if other == actor or not other.unit.alive() or other.extra_radius() <= 0: continue
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(other.unit.position,actor.unit.position,candidate)
				if closest.distance_to(other.unit.position) < actor.body_radius + other.body_radius + 8:
					safe = false; break
			if not safe: continue
			var cost: float = distance * 0.001
			for hazard: Dictionary in hazards:
				if not hazard.fired:
					if contains(hazard,candidate,24): safe = false; cost += float(hazard.power)*0.1
					var at_impact: Vector2 = actor.unit.position.lerp(candidate,clampf(float(hazard.warning)*speed/distance,0,1))
					if contains(hazard,at_impact,actor.body_radius): safe = false; cost += float(hazard.power)
			if cost < fallback_cost: fallback = candidate; fallback_cost = cost
			if safe and distance < best_distance: best = candidate; best_distance = distance
	if not is_finite(best_distance): return {"point":fallback,"partial":true} if is_finite(fallback_cost) else {}
	return {"point":best}

func boss_actor() -> RainbowActionActor:
	var best: RainbowActionActor
	var distance: float = INF
	for id: int in states:
		var actor: RainbowActionActor = battle.actors[id]
		if not actor.enemy.boss or not actor.unit.alive(): continue
		if id == battle.last_target_id: return actor
		var current: float = actor.unit.position.distance_squared_to(battle.controlled().position) if battle.controlled() != null else float(id)
		if current < distance: best = actor; distance = current
	return best

func _draw() -> void:
	for hazard: Dictionary in hazards:
		if hazard.kind == "orb":
			var at: Vector2 = Iso.project(hazard.center)
			draw_line(Iso.project(hazard.previous),at,Color(1,0.4,0.12,0.3),4,true)
			draw_set_transform(at,0,Vector2(1,0.5))
			draw_circle(Vector2.ZERO,hazard.radius,Color(1,0.3,0.05,0.2 if not hazard.fired else 0.7))
			if hazard.fired: draw_circle(Vector2.ZERO,12,Color("fff2a1"))
			draw_set_transform(Vector2.ZERO)
			continue
		var color := Color("ff673e") if not hazard.fired else Color("ffdf75")
		color.a = 0.22 if not hazard.fired else 0.7 * hazard.flash / 0.4
		var points := PackedVector2Array()
		var start: float = Vector2(hazard.direction).angle() - hazard.angle if hazard.kind in ["cone","sector"] else 0.0
		var span: float = hazard.angle * 2 if hazard.kind in ["cone","sector"] else TAU
		if hazard.kind == "cone": points.append(Iso.project(hazard.center))
		for i: int in 49:
			points.append(Iso.project(Vector2(hazard.center) + Vector2.from_angle(start + span * i / 48.0) * float(hazard.radius)))
		if hazard.kind in ["ring","sector"]:
			# Draw annular quads so the inner safe region is never painted dangerous.
			for i: int in 48:
				var a: Vector2 = Vector2.from_angle(start+span * i / 48.0)
				var b: Vector2 = Vector2.from_angle(start+span * (i+1) / 48.0)
				draw_colored_polygon(PackedVector2Array([Iso.project(hazard.center+a*hazard.inner),Iso.project(hazard.center+a*hazard.radius),Iso.project(hazard.center+b*hazard.radius),Iso.project(hazard.center+b*hazard.inner)]),color)
			var safe_ring := PackedVector2Array()
			for i: int in 49: safe_ring.append(Iso.project(Vector2(hazard.center)+Vector2.from_angle(TAU*i/48.0)*float(hazard.inner)))
			draw_polyline(safe_ring,Color("77f3db"),3,true)
		else:
			# A coincident link has zero area; skip it instead of submitting an invalid polygon.
			if float(hazard.radius) > 0.5 and Geometry2D.triangulate_polygon(points).size() > 0:
				draw_colored_polygon(points,color)
		points.append(points[0]); color.a = 0.9
		draw_polyline(points,color,2,true)
		if hazard.fired:
			var progress: float = 1.0 - float(hazard.flash) / 0.4
			for spark: int in 24:
				var angle: float = start + span * float(spark) / 23.0
				var axis: Vector2 = Vector2.from_angle(angle)
				var distance: float = lerpf(hazard.inner, hazard.radius, 0.2 + progress * 0.75)
				var foot: Vector2 = Iso.project(Vector2(hazard.center) + axis * distance)
				var tip: Vector2 = foot + Vector2(sin(spark * 2.3) * 15, -30 - 65 * sin(PI * progress))
				var flame := Color(1,0.32+float(spark%3)*0.16,0.05,1-progress)
				draw_line(foot,tip,flame,8,true)
				draw_line(foot,foot.lerp(tip,0.65),Color(1,0.95,0.55,1-progress),3,true)
		if not hazard.fired:
			var font: Font = ThemeDB.fallback_font
			draw_string(font,Iso.project(hazard.center)+Vector2(-16,-12),"%.1f" % maxf(0,hazard.warning),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
	for id: int in states:
		var actor: RainbowActionActor = battle.actors[id]
		if actor.exposed and actor.unit.alive():
			var outline := PackedVector2Array()
			for i: int in 49: outline.append(Iso.project(actor.unit.position+Vector2.from_angle(TAU*i/48.0)*85))
			draw_polyline(outline,Color("75ffe0"),4,true)
