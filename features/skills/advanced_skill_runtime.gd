class_name AdvancedSkillRuntime
extends RefCounted
## Battle-scoped mechanics. Data remains immutable; all hits use director damage.
var effect: BattleSkillEffect
var visual: AdvancedSkillVisual
var trail: Array[Dictionary] = []
var last_trail: Vector2
var pulse_at: float = 0.0
var orbs:Array[Dictionary]=[]
var orb_visual:OrbitLightningVisual
var orb_events:Array[Dictionary]=[]

func initialize(owner: BattleSkillEffect, caster: TacticalUnit) -> void:
	effect=owner
	var data: SkillEffectDefinition=effect.data
	if data.kind==SkillEffectDefinition.Kind.BUFF:
		caster.statuses.apply_buff(effect.skill.id,data,data.duration)
	elif data.kind==SkillEffectDefinition.Kind.STEALTH:
		var bonus: Dictionary=DamageFormula.evaluate(data.reveal_attack_formula,effect.snapshot)
		caster.statuses.apply_stealth(data.duration,data.movement_multiplier,float(bonus.value))
	visual=AdvancedSkillVisual.new()
	visual.kind=data.kind
	visual.life=data.duration
	effect.director.render_root.add_child(visual)
	if data.kind==SkillEffectDefinition.Kind.CHAIN and data.chain_orbs>0:
		orb_visual=OrbitLightningVisual.new();orb_visual.data=data;effect.director.render_root.add_child(orb_visual)
		_create_orbs();return
	if data.kind==SkillEffectDefinition.Kind.STAKES:
		visual.create_stakes(data.sprite_path,effect.point,data.radius)
	elif data.kind==SkillEffectDefinition.Kind.FIRE_TRAIL:
		visual.configure_fire(data.sprite_path,data.radius)
		last_trail=caster.position
		trail.append({"point":last_trail,"born":0.0})
		visual.update_fire(trail,0,data.trail_point_lifetime)
	_pulse()
	pulse_at=maxf(0.02,data.tick_interval)

func tick(_delta: float) -> void:
	if effect.data.kind==SkillEffectDefinition.Kind.CHAIN and effect.data.chain_orbs>0:
		_tick_orbs();return
	var caster: TacticalUnit=effect.director.get_unit(effect.caster_id)
	if effect.data.kind==SkillEffectDefinition.Kind.FIRE_TRAIL:
		if caster!=null and caster.alive() and caster.position.distance_to(last_trail)>=effect.data.trail_spacing:
			last_trail=caster.position
			trail.append({"point":last_trail,"born":effect.age})
		for i: int in range(trail.size()-1,-1,-1):
			if effect.age-float(trail[i].born)>=effect.data.trail_point_lifetime: trail.remove_at(i)
		visual.points.clear()
		for entry: Dictionary in trail: visual.points.append(Iso.project(entry.point))
		visual.update_fire(trail,effect.age,effect.data.trail_point_lifetime)
	while pulse_at<=effect.age+0.000001 and pulse_at<effect.data.duration-0.000001:
		_pulse()
		if effect.done: return
		pulse_at+=maxf(0.02,effect.data.tick_interval)
	visual.age=effect.age
	if effect.data.kind in [SkillEffectDefinition.Kind.BUFF,SkillEffectDefinition.Kind.STEALTH] and caster!=null:
		visual.position=Iso.project(caster.position)
	visual.queue_redraw()

func _pulse() -> void:
	var kind: int=effect.data.kind
	if kind not in [SkillEffectDefinition.Kind.STAKES,SkillEffectDefinition.Kind.FIRE_TRAIL,SkillEffectDefinition.Kind.CHAIN]: return
	effect.ticks+=1
	if kind==SkillEffectDefinition.Kind.CHAIN:
		_chain()
		return
	for target: TacticalUnit in effect.director.units.values():
		if not target.alive() or target.team==effect.team or target.definition.movement_type!=UnitDefinition.Movement.GROUND: continue
		var inside: bool=target.position.distance_to(effect.point)<=effect.data.radius
		if kind==SkillEffectDefinition.Kind.FIRE_TRAIL:
			inside=false
			for entry: Dictionary in trail:
				if target.position.distance_to(entry.point)<=effect.data.radius: inside=true; break
		if inside: _hit(target,effect.power)

func _hit(target: TacticalUnit, damage: float) -> void:
	effect.hit_counts[target.unit_id]=int(effect.hit_counts.get(target.unit_id,0))+1
	effect.director.apply_damage(target,damage,false,effect.skill.damage_type,true,float(effect.snapshot.get("damage_scale",1.0)))
	if effect.data.hit_control_duration>0: target.control_left=maxf(target.control_left,effect.data.hit_control_duration)

func _chain() -> void:
	var current: TacticalUnit=effect.director.get_unit(effect.target_id)
	if current==null or not current.alive() or current.statuses.hidden(): effect.finish(); return
	var visited: Dictionary={}
	var damage: float=effect.power
	visual.points.clear()
	visual.points.append(Iso.project(effect.origin)+Vector2(0,-28))
	for jump: int in effect.data.chain_targets:
		visited[current.unit_id]=true
		visual.points.append(Iso.project(current.position)+Vector2(0,-28))
		_hit(current,damage)
		damage*=effect.data.chain_damage_multiplier
		var next: TacticalUnit
		var closest: float=effect.data.chain_jump_range
		for enemy: TacticalUnit in effect.director.units.values():
			if enemy.team==effect.team or not enemy.alive() or enemy.statuses.hidden() or visited.has(enemy.unit_id): continue
			var distance: float=current.position.distance_to(enemy.position)
			if distance<closest: closest=distance; next=enemy
		if next==null: break
		current=next
	visual.flash_at=effect.age

func finish() -> void:
	if is_instance_valid(visual): visual.queue_free()
	if is_instance_valid(orb_visual):orb_visual.queue_free()
	orbs.clear()
	trail.clear()

func _orb_interval(random:RandomNumberGenerator=null)->float:
	var base:float=maxf(0.02,effect.data.tick_interval)
	var jitter:float=minf(effect.data.chain_interval_jitter,base*0.45)
	return maxf(0.02,base+(random if random!=null else effect.director.rng).randf_range(-jitter,jitter))
func _create_orbs()->void:
	var current:TacticalUnit=effect.director.get_unit(effect.target_id)
	var visited:Dictionary={};var damage:float=effect.power
	for jump:int in effect.data.chain_targets:
		if current==null or not current.alive():break
		visited[current.unit_id]=true
		for index:int in effect.data.chain_orbs:
			var random:RandomNumberGenerator=RandomNumberGenerator.new();random.seed=effect.director.rng.randi()
			orbs.append({"target":current.unit_id,"next":_orb_interval(random),"random":random,"power":damage,"angle":TAU*index/effect.data.chain_orbs,"flash_until":-1.0})
		damage*=effect.data.chain_damage_multiplier
		var next:TacticalUnit;var closest:float=effect.data.chain_jump_range
		for enemy:TacticalUnit in effect.director.units.values():
			if enemy.team==effect.team or not enemy.alive() or visited.has(enemy.unit_id) or enemy.statuses.hidden():continue
			var distance:float=current.position.distance_to(enemy.position)
			if distance<closest:closest=distance;next=enemy
		current=next
	_tick_orbs()
func _tick_orbs()->void:
	var drawings:Array[Dictionary]=[]
	for orb:Dictionary in orbs:
		var target:TacticalUnit=effect.director.get_unit(orb.target)
		if target==null or not target.alive() or target.statuses.hidden():continue
		while orb.next<=effect.age and orb.next<effect.data.duration:
			_hit(target,orb.power);effect.ticks+=1
			orb_events.append({"time":orb.next,"target":target.unit_id,"angle":orb.angle})
			orb.flash_until=effect.age+0.10;orb.next+=_orb_interval(orb.random)
			if not target.alive():break
		var at:Vector2=target.position+Vector2.from_angle(orb.angle+effect.age*effect.data.chain_orbit_speed)*effect.data.chain_orbit_radius
		drawings.append({"point":Iso.project(at)+Vector2(0,-32),"target":Iso.project(target.position)+Vector2(0,-30),"flash":effect.age<orb.flash_until})
	orb_visual.orbs=drawings;orb_visual.age=effect.age;orb_visual.queue_redraw()
	if drawings.is_empty():effect.finish()
