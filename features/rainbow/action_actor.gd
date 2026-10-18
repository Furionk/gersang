class_name RainbowActionActor
extends RefCounted
## Per-encounter state. Switching the input owner never resets this object.
var unit: TacticalUnit
var profile: RainbowActionProfile
var weapon: RainbowWeaponDefinition = RainbowWeaponDefinition.new()
var bp: float = 100.0
var action: StringName = &""
var windup: float = 0.0
var recovery: float = 0.0
var guard_left: float = 0.0
var stun: float = 0.0
var attack_facing: Vector2 = Vector2.DOWN
var impulse: Vector2 = Vector2.ZERO
var pose: WorldVisualPose = WorldVisualPose.new()
var hits: int = 0
var blocked_hits: int = 0
var hit_stop: float = 0.0
var hit_flash: float = 0.0
var combo: int = 0
var combo_left: float = 0.0
var swing_pose_left: float = 0.0
var enemy: RainbowEnemyDefinition
var exposed: bool = false
var mechanic_lock: bool = false
var evading: bool = false
var body_radius: float = 0.0
var original_mask: int
var original_layer: int
var original_shape: Shape2D
var body_shape: CollisionShape2D

func extra_radius() -> float:
	return maxf(0.0, body_radius - GameSettings.profile.collision_radius)

func restore_body() -> void:
	if not is_instance_valid(unit): return
	unit.collision_mask = original_mask if unit.alive() else 0
	unit.collision_layer = original_layer if unit.alive() else 0
	if is_instance_valid(body_shape): body_shape.shape = original_shape
	unit.agent.radius = GameSettings.profile.collision_radius

func setup(actor: TacticalUnit, settings: RainbowActionProfile) -> void:
	unit = actor
	profile = settings
	if unit.team == 0:
		for entry: RainbowWeaponDefinition in settings.weapons:
			if entry.unit_id == unit.definition.id:
				weapon = entry
				profile = weapon.apply_to(settings)
				if weapon.layout != null: unit.view.set_action_skin(weapon.layout, weapon.sprite_scale)
				break
	else:
		for entry: RainbowEnemyDefinition in settings.enemies:
			if entry.unit_id == unit.definition.id:
				enemy = entry
				weapon = entry.weapon
				profile = weapon.apply_to(settings)
				if weapon.layout != null: unit.view.set_action_skin(weapon.layout, weapon.sprite_scale)
				break
	bp = profile.bp_max
	body_radius = maxf(GameSettings.profile.collision_radius, enemy.body_radius if enemy != null else 0.0)
	original_mask = unit.collision_mask; original_layer = unit.collision_layer
	# Layer 8 is reserved locally for action-mode boss bodies; floor rays use mask 5.
	unit.collision_mask |= 8
	if enemy != null and enemy.body_radius > 0:
		unit.collision_layer |= 8
		unit.collision_mask |= 2
	for child: Node in unit.get_children():
		if child is CollisionShape2D:
			body_shape = child; original_shape = child.shape
			var shape := CircleShape2D.new(); shape.radius = body_radius
			child.shape = shape
			break
	unit.agent.radius = body_radius
	pose.reset(actor.position)
	unit.agent.avoidance_enabled = false

func request(kind: StringName) -> bool:
	if not unit.alive() or mechanic_lock or recovery > 0 or stun > 0 or hit_stop > 0 or action != &"": return false
	if kind == &"guard":
		if bp < 12: return false
		bp -= 12
		guard_left = profile.guard_duration
		recovery = profile.guard_duration + profile.guard_recovery
		unit.fsm.transition(&"hold")
		return true
	if kind not in [&"melee", &"ranged"]: return false
	if kind == &"ranged" and not unit.vitals.spend(weapon.mana_cost): return false
	action = kind
	if kind == &"melee":
		combo = combo % 3 + 1 if combo_left > 0 else 1
		combo_left = 1.1
	attack_facing = unit.facing
	windup = profile.melee_windup if kind == &"melee" else profile.ranged_windup
	# Heavy enemies visibly telegraph; player stats remain the existing resolved stats.
	if unit.team == 1: windup = maxf(windup, 0.9 if enemy != null and enemy.boss else 0.4)
	recovery = windup + (profile.melee_recovery if kind == &"melee" else profile.ranged_recovery)
	if unit.team == 1: recovery += 0.6
	unit.attack_windup_left = windup
	unit.fsm.transition(&"attack")
	unit.visual_action_started.emit("attack")
	return true

func advance(delta: float) -> StringName:
	# The shared revive path restores ordinary RTS masks; reapply only while owned here.
	if unit.alive():
		unit.collision_mask |= 8
		if enemy != null and enemy.body_radius > 0:
			unit.collision_layer |= 8; unit.collision_mask |= 2
	hit_flash = maxf(0, hit_flash - delta)
	combo_left = maxf(0, combo_left - delta)
	if hit_stop > 0:
		hit_stop = maxf(0, hit_stop - delta)
		return &""
	guard_left = maxf(0, guard_left - delta)
	swing_pose_left = maxf(0, swing_pose_left - delta)
	recovery = maxf(0, recovery - delta)
	stun = maxf(0, stun - delta)
	unit.shake_left = maxf(0, unit.shake_left - delta)
	unit.vitals.regenerate(delta, unit.definition.mana_regeneration)
	if not unit.alive():
		action = &""
		return &""
	if action != &"":
		windup -= delta
		unit.attack_windup_left = maxf(0, windup)
		if windup <= 0:
			var released: StringName = action
			action = &""
			unit.attack_windup_left = -1
			unit.shots += 1
			swing_pose_left = 0.16
			return released
	return &""

func move(direction: Vector2, running: bool, delta: float) -> void:
	var before: Vector2 = unit.position
	if hit_stop > 0:
		pose.step(before, before)
		return
	if not unit.alive():
		unit._stop_motion()
		pose.step(before, before)
		return
	var strength: float = minf(1, direction.length())
	var desired: Vector2 = direction.limit_length()
	var boost: bool = running and bp > 1 and strength > 0 and recovery <= 0 and stun <= 0
	bp = clampf(bp + (-profile.bp_drain if boost else profile.bp_regen) * delta, 0, profile.bp_max)
	var speed: float = MovementFeel.speed(float(unit.combat_stats.speed), GameSettings.profile.movement_multiplier, 1.0)
	speed *= weapon.move_multiplier
	if boost: speed *= profile.run_multiplier
	if mechanic_lock or stun > 0 or guard_left > 0 or action != &"": desired = Vector2.ZERO
	elif recovery > 0: speed *= 0.45
	if desired.length_squared() > 0.01: unit.facing = desired.normalized()
	var target: Vector2 = desired * speed
	unit.velocity = unit.velocity.move_toward(target, (profile.acceleration if strength > 0 else profile.braking) * delta)
	impulse = impulse.move_toward(Vector2.ZERO, 600 * delta)
	unit.velocity += impulse
	unit.desired_velocity = unit.velocity
	unit.move_and_slide()
	unit.velocity -= impulse
	# Air units may ignore obstacles, but never leave the authored battlefield.
	var radius: float = body_radius
	var extent: Vector2 = Vector2(unit.director.ground.cells) * Iso.CELL
	unit.position = unit.position.clamp(Vector2.ONE * radius, extent - Vector2.ONE * radius)
	pose.step(before, unit.position)
	if action == &"" and guard_left <= 0:
		unit.fsm.transition(&"controlled" if stun > 0 else &"move" if unit.desired_velocity.length() > 2 else &"idle")

func receive_hit(from: Vector2, power: float, scale: float, stagger: float = -1.0, push: float = -1.0) -> float:
	if not unit.alive(): return 0
	var to_source: Vector2 = unit.position.direction_to(from)
	var guarded: bool = guard_left > 0 and unit.facing.dot(to_source) >= 0.0
	if guarded:
		blocked_hits += 1
		scale *= profile.guard_damage_scale
	elif enemy == null or not enemy.boss or exposed:
		stun = profile.hit_stun if stagger < 0 else stagger
		swing_pose_left = 0
		action = &""
		unit.attack_windup_left = -1
		impulse = -to_source * (profile.knockback if push < 0 else push)
		# A huge boss can flinch while exposed but must not be pinballed out of its core.
		if enemy != null and enemy.boss: impulse = Vector2.ZERO
	hits += 1
	if enemy != null:
		scale *= enemy.exposed_damage_scale if exposed else enemy.armored_damage_scale
	var dealt: float = unit.director.apply_damage(unit, power, false, CombatMath.Kind.PHYSICAL, false, scale)
	if dealt > 0:
		hit_flash = profile.impact_flash
		if enemy == null or not enemy.boss or exposed: hit_stop = profile.impact_pause
	return dealt
