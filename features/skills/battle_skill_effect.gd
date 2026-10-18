class_name BattleSkillEffect
extends RefCounted
var director: GameDirector
var id: int
var caster_id: int
var team: int
var skill: SkillDefinition
var data: SkillEffectDefinition
var snapshot: Dictionary
var origin: Vector2
var point: Vector2
var direction: Vector2
var target_id: int = -1
var age: float = 0.0
var next_tick: float = 0.0
var done: bool = false
var ticks: int = 0
var hit_counts: Dictionary = {}
var visuals: Array[SkillVfx] = []
var tiles: Array[Vector2i] = []
var power: float = 0.0
var advanced: AdvancedSkillRuntime
var charge_trail: Line2D
var affected_ids: Array[int] = []
var burst_lines: Array[Line2D] = []
var health_ratio: float = 0.0
var drain_beam:Line2D
var follow_reached:bool=false
var follow_clock:float=0.0
var storm_wave_index:int=0
var storm_sites:Array[Vector2]=[]
var blood_wave:BloodSwordWaveVisual

func initialize(owner: GameDirector, caster: TacticalUnit, definition: SkillDefinition, at: Vector2, target: int, effect_id: int) -> void:
	director = owner
	caster_id = caster.unit_id
	team = caster.team
	skill = definition
	data = definition.effect_data
	if data.use_skill_radius:
		data=data.duplicate() as SkillEffectDefinition
		data.radius=maxf(0,definition.radius)
	id = effect_id
	snapshot = caster.stats_snapshot()
	snapshot["damage_scale"]=caster.definition.outgoing_damage_scale
	power = float(skill.result(snapshot)["value"])
	origin = caster.position
	point = at
	target_id = target
	direction = origin.direction_to(at) if origin.distance_squared_to(at) > 0.01 else caster.facing
	if data.kind==SkillEffectDefinition.Kind.STORM:
		data=data.duplicate() as SkillEffectDefinition
		data.duration=maxf(data.duration,(data.storm_waves-1)*data.storm_interval+0.75)
		_storm_wave();next_tick=maxf(0.02,data.storm_interval)
		return
	if data.kind==SkillEffectDefinition.Kind.FOLLOW:
		point=origin if data.follow_speed>0 else at
		follow_reached=data.follow_speed<=0
	if data.kind==SkillEffectDefinition.Kind.TELEPORT:
		var teleport_target:TacticalUnit=director.get_unit(target_id)
		if teleport_target!=null and teleport_target.alive():
			for attempt:int in 32:
				var candidate:Vector2=teleport_target.position+Vector2.from_angle(TAU*attempt/32.0)*data.teleport_separation
				if director._spawn_is_free(candidate) and not director.ground._navigation_blocked(Vector2i(candidate/Iso.CELL)):
					director.spawn_flash(origin,data,50); caster.position=candidate; caster.previous_position=candidate; caster._reset_navigation(); caster._stop_motion(); director.spawn_flash(candidate,data,50);break
		done=true; return
	if data.kind==SkillEffectDefinition.Kind.SOUL_DRAIN:
		caster.channeling=true; caster.cast_visual_left=data.duration
		drain_beam=Line2D.new(); drain_beam.width=5;drain_beam.default_color=skill.tint;drain_beam.z_index=3500
		director.render_root.add_child(drain_beam)
		_drain_pulse(); next_tick=maxf(0.02,data.tick_interval)
		return
	if definition.battlefield_range and data.kind==SkillEffectDefinition.Kind.LINE:
		data=data.duplicate() as SkillEffectDefinition
		data.distance=Vector2(owner.ground.cells).length()*Iso.CELL
		data.duration=data.distance/maxf(1,data.speed)+data.trail_length/maxf(1,data.speed)
	if not data.duration_formula.is_empty():
		data=data.duplicate() as SkillEffectDefinition
		data.duration=maxf(0.05,float(data.resolved_duration(snapshot).value))
	if data.kind in [SkillEffectDefinition.Kind.CURSE,SkillEffectDefinition.Kind.HEALTH_BURST]:
		data=data.duplicate() as SkillEffectDefinition
		if data.kind==SkillEffectDefinition.Kind.CURSE:
			var slow: Dictionary=DamageFormula.evaluate(data.slow_percent_formula,snapshot)
			if not slow.valid: done=true; return
			data.slow_factor=1.0-clampf(float(slow.value),0.0,data.slow_percent_cap)
		else:
			var ratio: Dictionary=DamageFormula.evaluate(data.target_max_hp_ratio_formula,snapshot)
			if not ratio.valid: done=true; return
			health_ratio=maxf(0,float(ratio.value))
			if director.spell_flash!=null: director.spell_flash.play(data)
		for enemy: TacticalUnit in director.units.values():
			if not enemy.alive() or enemy.team==team or enemy.position.distance_to(point)>data.radius: continue
			affected_ids.append(enemy.unit_id)
			if data.kind==SkillEffectDefinition.Kind.CURSE:
				enemy.statuses.apply_slow(StringName("%s:%d"%[skill.id,caster_id]),data.slow_factor,data.duration)
			else:
				_visual(enemy.position,45)
				var bolt: Line2D=Line2D.new(); bolt.width=3; bolt.default_color=data.flash_color; bolt.z_index=3500
				var start: Vector2=Iso.project(origin)+Vector2(0,-30)
				var end: Vector2=Iso.project(enemy.position)+Vector2(0,-35)
				for step: int in 7:
					var bolt_point: Vector2=start.lerp(end,step/6.0)
					if step>0 and step<6: bolt_point+=Vector2(0,8 if step%2==0 else -8)
					bolt.add_point(bolt_point)
				director.render_root.add_child(bolt); burst_lines.append(bolt)
		_visual(point,data.radius)
		_curse_pulse(); next_tick=data.tick_interval
		return
	if data.kind in [SkillEffectDefinition.Kind.STAKES,SkillEffectDefinition.Kind.STEALTH,SkillEffectDefinition.Kind.FIRE_TRAIL,SkillEffectDefinition.Kind.CHAIN,SkillEffectDefinition.Kind.BUFF]:
		advanced=AdvancedSkillRuntime.new()
		advanced.initialize(self,caster)
		return
	if data.kind == SkillEffectDefinition.Kind.RADIAL:
		point = origin
	if data.kind==SkillEffectDefinition.Kind.LINE and data.blood_wave_visual:
		blood_wave=BloodSwordWaveVisual.new();blood_wave.direction=direction;blood_wave.width=data.width;director.render_root.add_child(blood_wave)
	if data.kind==SkillEffectDefinition.Kind.CHARGE:
		data=data.duplicate() as SkillEffectDefinition
		data.distance=minf(data.distance,maxf(80,origin.distance_to(at)+80))
		data.duration=data.distance/maxf(1,data.speed)+0.05
		point=origin
		caster.charging=true
		charge_trail=Line2D.new(); charge_trail.width=10; charge_trail.default_color=skill.tint
		charge_trail.default_color.a=0.55; charge_trail.z_index=3500; charge_trail.antialiased=true
		director.render_root.add_child(charge_trail); charge_trail.add_point(Iso.project(origin))
	if data.kind == SkillEffectDefinition.Kind.BARRIER:
		tiles = director.ground.wall_cells(point, direction, data.wall_length)
		director.ground.add_wall(id, tiles)
		for tile: Vector2i in tiles:
			var visual: SkillVfx = _visual((Vector2(tile) + Vector2.ONE * 0.5) * Iso.CELL, 35)
			ScenerySorting.apply_item(visual) # Physical ice-wall segments interleave at their foot.
	else:
		for index:int in (maxi(1,data.line_visual_count) if data.kind==SkillEffectDefinition.Kind.LINE else 1):
			_visual(point if data.kind != SkillEffectDefinition.Kind.LINE else origin, data.radius)
	if data.kind == SkillEffectDefinition.Kind.SUMMON:
		var count: int = data.summon_count_min
		if data.summon_count_max>count: count = director.rng.randi_range(count,data.summon_count_max)
		if caster.team==1: count = mini(count,60-director.living_ids(1).size())
		var group: Array[int] = []
		group.assign(caster.abilities.active_summon_groups.get(skill.id,[]))
		if data.summon_limit>0:
			var limit: int=maxi(data.summon_limit,data.summon_count_max)
			count=mini(count,limit-group.size())
		for index: int in count:
			var local: UnitDefinition = SummonScaling.resolve(data,snapshot)
			if data.summon_inherit_level: local.level = int(snapshot["level"])
			var offset: Vector2 = Vector2.from_angle(TAU*float(index)/float(count))*55.0 if count>1 else Vector2.ZERO
			var spirit: TacticalUnit = director.spawn_summon(local, caster, director._safe_spawn(point+offset), data.duration)
			group.append(spirit.unit_id)
		if not group.is_empty():
			caster.abilities.active_summons[skill.id] = group[0]
			caster.abilities.active_summon_groups[skill.id] = group
		# Summoning flash is short; the unit owns its twenty-second lifetime.
		for visual: SkillVfx in visuals:
			visual.life = 0.7
		data = data.duplicate() as SkillEffectDefinition
		data.duration = 0.7
	if data.kind in [SkillEffectDefinition.Kind.QUAKE, SkillEffectDefinition.Kind.RADIAL, SkillEffectDefinition.Kind.FOLLOW, SkillEffectDefinition.Kind.LINE, SkillEffectDefinition.Kind.FLAME]:
		_pulse(0.0)
		next_tick = data.tick_interval

func _visual(at: Vector2, radius: float) -> SkillVfx:
	var visual: SkillVfx = SkillVfx.new()
	visual.position = Iso.project(at)
	visual.z_index = 3500
	visual.initialize(data.sprite_path, radius, data.duration, data.kind,data.tick_interval,data.sprite_grounded,data.sprite_foot_ratio)
	if skill.effect==SkillDefinition.Effect.SHOCKWAVE: visual.modulate=skill.tint
	director.render_root.add_child(visual)
	visuals.append(visual)
	return visual

func tick(delta: float) -> void:
	if done:
		return
	age += delta
	if data.kind==SkillEffectDefinition.Kind.STORM:
		while storm_wave_index<data.storm_waves and next_tick<=age:
			_storm_wave();next_tick+=maxf(0.02,data.storm_interval)
		if age>=data.duration:finish()
		return
	if data.kind==SkillEffectDefinition.Kind.SOUL_DRAIN:
		var caster:TacticalUnit=director.get_unit(caster_id); var target:TacticalUnit=director.get_unit(target_id)
		var limit:float=data.channel_break_range if data.channel_break_range>0 else skill.range
		if caster==null or target==null or not caster.alive() or not target.alive() or not caster.channeling or caster.control_left>0 or caster.position.distance_to(target.position)>limit:
			finish(); return
		drain_beam.points=PackedVector2Array([Iso.project(caster.position)+Vector2(0,-35),Iso.project(target.position)+Vector2(0,-35)])
		while next_tick<=age and next_tick<data.duration:
			_drain_pulse(); next_tick+=maxf(0.02,data.tick_interval)
		if age>=data.duration: finish()
		return
	if data.kind in [SkillEffectDefinition.Kind.CURSE,SkillEffectDefinition.Kind.HEALTH_BURST]:
		for visual: SkillVfx in visuals: visual.age=age
		if data.kind==SkillEffectDefinition.Kind.CURSE:
			while next_tick<=age+0.000001 and next_tick<data.duration-0.000001:
				_curse_pulse(); next_tick+=maxf(0.02,data.tick_interval)
		if age>=data.duration: finish()
		return
	if data.kind==SkillEffectDefinition.Kind.CHARGE:
		_charge_tick(delta)
		return
	if advanced!=null:
		advanced.tick(delta)
		if age>=data.duration-0.000001: finish()
		return
	if data.kind == SkillEffectDefinition.Kind.FOLLOW:
		var target: TacticalUnit = director.get_unit(target_id)
		if target == null or not target.alive():
			finish()
			return
		point = point.move_toward(target.position,data.follow_speed*delta) if data.follow_speed>0 else target.position
		if point.distance_to(target.position)<=maxf(8,data.radius*0.2):follow_reached=true
		if follow_reached:follow_clock+=delta
		elif data.follow_travel_timeout>0 and age>=data.follow_travel_timeout:finish();return
	elif data.kind == SkillEffectDefinition.Kind.LINE:
		point = origin + direction * minf(data.distance, data.speed * age)
		if is_instance_valid(blood_wave):blood_wave.position=Iso.project(point);blood_wave.age=age;blood_wave.queue_redraw()
	for index:int in visuals.size():
		var visual:SkillVfx=visuals[index]
		visual.age = age
		if data.kind==SkillEffectDefinition.Kind.FOLLOW and data.follow_speed>0 and data.follow_duration_after_arrival:
			visual.life=age+data.duration-follow_clock
		if data.kind != SkillEffectDefinition.Kind.BARRIER:
			visual.position = Iso.project(point)
			if data.kind == SkillEffectDefinition.Kind.LINE and visual.sprite != null:
				var projected_direction: Vector2 = Iso.project(direction)
				var offset:float=(float(index)/maxf(1,visuals.size()-1)-0.5)*data.width*data.line_visual_spread if visuals.size()>1 else 0.0
				visual.position=Iso.project(point+direction.orthogonal()*offset)
				visual.sprite.rotation = projected_direction.angle()
				visual.sprite.position = -projected_direction.normalized() * data.trail_length * 0.5
				visual.sprite.scale = Vector2(data.trail_length * 1.414 / visual.cell.x, data.width * 1.2 * data.line_sprite_cross_scale / maxf(1,visuals.size()) / visual.cell.y)
	var elapsed:float=follow_clock if data.kind==SkillEffectDefinition.Kind.FOLLOW and data.follow_speed>0 and data.follow_duration_after_arrival else age
	if data.kind in [SkillEffectDefinition.Kind.QUAKE, SkillEffectDefinition.Kind.RADIAL, SkillEffectDefinition.Kind.FOLLOW, SkillEffectDefinition.Kind.LINE, SkillEffectDefinition.Kind.FLAME]:
		while next_tick <= elapsed + 0.000001 and next_tick < data.duration - 0.000001:
			_pulse(next_tick)
			next_tick += maxf(0.02, data.tick_interval)
	if elapsed >= data.duration - 0.000001:
		if data.kind == SkillEffectDefinition.Kind.QUAKE:
			for target: TacticalUnit in director.units.values():
				if target.alive() and target.team != team and target.position.distance_to(point) <= data.radius:
					target.statuses.apply_slow(skill.id, data.slow_factor, data.slow_duration)
		finish()

func _pulse(at_time: float) -> void:
	if data.kind==SkillEffectDefinition.Kind.FOLLOW and data.follow_speed>0 and data.follow_duration_after_arrival and not follow_reached:return
	ticks += 1
	var head: Vector2 = origin + direction * minf(data.distance, data.speed * at_time)
	var tail: Vector2 = origin + direction * maxf(0.0, minf(data.distance, data.speed * at_time) - data.trail_length)
	for target: TacticalUnit in director.units.values():
		if target.team == team or not target.alive():
			continue
		var inside: bool = false
		if data.kind == SkillEffectDefinition.Kind.LINE:
			inside = Geometry2D.get_closest_point_to_segment(target.position, tail, head).distance_to(target.position) <= data.width * 0.5
		elif data.kind == SkillEffectDefinition.Kind.RADIAL:
			var radius_now: float = data.radius * minf(1, (at_time + data.tick_interval) / data.duration)
			inside = target.position.distance_to(origin) <= radius_now and not hit_counts.has(target.unit_id)
		else:
			inside = target.position.distance_to(point) <= data.radius
		if inside:
			hit_counts[target.unit_id] = int(hit_counts.get(target.unit_id, 0)) + 1
			director.apply_damage(target, power, false, skill.damage_type,true,float(snapshot.get("damage_scale",1.0)))
			if data.kind == SkillEffectDefinition.Kind.QUAKE:
				target.shake_left = 0.2

func _storm_wave()->void:
	storm_wave_index+=1;ticks+=1
	for strike:int in data.storm_strikes:
		var radius:float=sqrt(director.rng.randf())*maxf(0,skill.radius-data.storm_impact_radius)
		var at:Vector2=point+Vector2.from_angle(director.rng.randf()*TAU)*radius
		storm_sites.append(at)
		var flash:SkillEffectDefinition=data.duplicate() as SkillEffectDefinition;flash.duration=0.55
		director.spawn_flash(at,flash,data.storm_impact_radius)
		for target:TacticalUnit in director.units.values():
			if target.alive() and target.team!=team and target.position.distance_to(at)<=data.storm_impact_radius:
				hit_counts[target.unit_id]=int(hit_counts.get(target.unit_id,0))+1
				director.apply_damage(target,power,false,skill.damage_type,true,float(snapshot.get("damage_scale",1.0)))

func finish() -> void:
	if data!=null and data.kind==SkillEffectDefinition.Kind.SOUL_DRAIN:
		var caster:TacticalUnit=director.get_unit(caster_id)
		if caster!=null: caster.channeling=false;caster.cast_visual_left=0
		if is_instance_valid(drain_beam): drain_beam.queue_free()
	if done:
		return
	done = true

	for bolt: Line2D in burst_lines:
		if is_instance_valid(bolt): bolt.queue_free()
	burst_lines.clear()
	if is_instance_valid(charge_trail): charge_trail.queue_free()
	if is_instance_valid(blood_wave):blood_wave.queue_free()
	if data.kind==SkillEffectDefinition.Kind.CHARGE:
		var caster: TacticalUnit=director.get_unit(caster_id)
		if caster!=null:
			caster.charging=false; caster._stop_motion()
	if advanced!=null: advanced.finish()
	if data.kind == SkillEffectDefinition.Kind.BARRIER and is_instance_valid(director.ground):
		director.ground.remove_wall(id)
	for visual: SkillVfx in visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	visuals.clear()

func _drain_pulse()->void:
	var caster:TacticalUnit=director.get_unit(caster_id); var target:TacticalUnit=director.get_unit(target_id)
	if caster==null or target==null or not caster.alive() or not target.alive(): return
	var actual:float=director.apply_damage(target,power,false,skill.damage_type,true,float(snapshot.get("damage_scale",1.0)))
	caster.vitals.heal(actual*data.drain_heal_ratio)
	ticks+=1

func _curse_pulse() -> void:
	ticks+=1
	for unit_id: int in affected_ids:
		var target: TacticalUnit=director.get_unit(unit_id)
		if target==null or not target.alive(): continue
		hit_counts[unit_id]=int(hit_counts.get(unit_id,0))+1
		var value: float=target.vitals.max_health*health_ratio if data.kind==SkillEffectDefinition.Kind.HEALTH_BURST else power
		director.apply_damage(target,value,data.kind==SkillEffectDefinition.Kind.HEALTH_BURST,skill.damage_type,data.kind!=SkillEffectDefinition.Kind.HEALTH_BURST,float(snapshot.get("damage_scale",1.0)))

func _charge_tick(delta: float) -> void:
	var caster: TacticalUnit=director.get_unit(caster_id)
	if caster==null or not caster.alive() or caster.control_left>0: finish(); return
	var previous: Vector2=caster.position
	var remaining: float=maxf(0,data.distance-origin.distance_to(previous))
	var step: Vector2=direction*minf(data.speed*delta,remaining)
	var next: Vector2=previous+step
	if next.x<0 or next.y<0 or next.x>=director.ground.cells.x*Iso.CELL or next.y>=director.ground.cells.y*Iso.CELL:
		finish(); return
	if caster.definition.movement_type==UnitDefinition.Movement.GROUND:
		for sample: int in range(1,maxi(1,ceili(step.length()/6.0))+1):
			var at: Vector2=previous.lerp(next,float(sample)/float(maxi(1,ceili(step.length()/6.0))))
			var radius: float=GameSettings.profile.collision_radius
			for offset: Vector2 in [Vector2.ZERO,Vector2(radius,radius),Vector2(-radius,radius),Vector2(radius,-radius),Vector2(-radius,-radius)]:
				if director.ground._navigation_blocked(Vector2i((at+offset)/Iso.CELL)): finish(); return
	caster.facing=direction; caster.velocity=step/maxf(0.00001,delta); caster.desired_velocity=caster.velocity
	caster.move_and_slide(); point=caster.position
	charge_trail.add_point(Iso.project(point))
	if charge_trail.get_point_count()>12: charge_trail.remove_point(0)
	for target: TacticalUnit in director.units.values():
		if not target.alive() or target.team==team or hit_counts.has(target.unit_id): continue
		if data.ground_targets_only and target.definition.movement_type!=UnitDefinition.Movement.GROUND: continue
		if Geometry2D.get_closest_point_to_segment(target.position,previous,point).distance_to(target.position)>data.width*0.5: continue
		hit_counts[target.unit_id]=1
		var actual: float=director.apply_damage(target,power,false,skill.damage_type,true,float(snapshot.get("damage_scale",1.0)))
		caster.abilities.on_basic_damage_landed(actual,target)
	for visual: SkillVfx in visuals:
		visual.position=Iso.project(point); visual.age=age
	if remaining<=step.length()+0.01 or point.distance_to(previous)<0.1 or age>=data.duration: finish()
