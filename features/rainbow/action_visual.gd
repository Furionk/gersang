class_name RainbowActionVisual
extends Node2D
## Read-only action cues. HP and collision never depend on these drawings.
var battle: RainbowActionBattle

func _draw() -> void:
	if is_instance_valid(battle.hud) and is_instance_valid(battle.hud.touch_router) and battle.controlled() != null:
		var aim: Vector2 = battle.hud.touch_router.aim
		if aim.length_squared() > 0.01:
			var start: Vector2 = Iso.project(battle.controlled().position) + Vector2(0,-22)
			draw_line(start, start + Iso.project(aim * 320), Color(1,0.86,0.5,0.8), 2, true)
	for shot: Dictionary in battle.projectiles:
		var at: Vector2 = Iso.project(shot.point) + Vector2(0, -25)
		var trail: Vector2 = Iso.project(shot.velocity.normalized() * 25)
		var weapon: RainbowWeaponDefinition = shot.weapon
		var color: Color = weapon.tint if shot.team == 0 else Color(1, 0.32, 0.12)
		if weapon.effect_texture != null:
			var size := Vector2(64, 44) if weapon.effect not in ["curse", "crescent", "seal"] else Vector2(76, 64)
			if weapon.effect == "needle": size.y = 15
			draw_set_transform(at, trail.angle())
			draw_texture_rect(weapon.effect_texture, Rect2(-size * Vector2(0.85,0.5), size), false)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_line(at - trail, at, color.darkened(0.25), 7, true)
			draw_circle(at, 6, color)
	for swing: Dictionary in battle.swings:
		var weapon: RainbowWeaponDefinition = swing.weapon
		var points: PackedVector2Array = []
		var angle: float = swing.facing.angle()
		var progress: float = 1.0 - swing.left / 0.18
		var reverse: float = -1.0 if swing.get("combo", 1) == 2 else 1.0
		var ribbon := PackedVector2Array()
		for step: int in 17:
			var arc: float = angle + reverse * (-swing.angle + progress * 0.5 + swing.angle * 1.6 * step / 16.0)
			points.append(Iso.project(swing.point + Vector2.from_angle(arc) * swing.range) + Vector2(0, -22))
			ribbon.append(points[-1])
		for step: int in range(16,-1,-1):
			var arc: float = angle + reverse * (-swing.angle + progress * 0.5 + swing.angle * 1.6 * step / 16.0)
			var thickness: float = 30 if weapon.effect in ["heavy", "crescent"] else 15
			ribbon.append(Iso.project(swing.point + Vector2.from_angle(arc) * (swing.range - thickness * sin(PI * step / 16.0))) + Vector2(0,-22))
		var tint: Color = weapon.tint if swing.team == 0 else Color(1,0.4,0.12)
		tint.a = swing.left / 0.18
		var center: Vector2 = Iso.project(swing.point) + Vector2(0,-22)
		var tip: Vector2 = Iso.project(swing.point + swing.facing * swing.range) + Vector2(0,-22)
		match weapon.effect:
			"rifle", "needle", "scatter":
				draw_line(center, tip, tint, 5 if weapon.effect == "scatter" else 2, true)
				draw_arc(tip, 10 + progress * 14, 0, TAU, 16, tint, 2, true)
			"seal", "curse":
				draw_set_transform(center, 0, Vector2(1,0.5))
				draw_arc(Vector2.ZERO, swing.range * (0.6 + progress * 0.4), 0, TAU, 32, tint, 4, true)
				draw_set_transform(Vector2.ZERO)
			_:
				draw_colored_polygon(ribbon, tint)
				draw_polyline(points, Color(1,0.98,0.83,tint.a), 3, true)
				if weapon.effect == "kunai": draw_polyline(points, tint, 2, true); draw_line(center,tip,tint,3,true)
				if weapon.effect == "lightning":
					for index: int in range(1, points.size()):
						draw_line(points[index-1], points[index] + Vector2(0, -8 if index % 2 else 8), tint, 3, true)
	if is_instance_valid(battle.feedback):
		for hit: Dictionary in battle.feedback.impacts:
			var t: float = 1 - hit.left / 0.26
			var at: Vector2 = Iso.project(hit.point) + Vector2(0,-30)
			var tint: Color = Color(0.45,0.85,1) if hit.kind == "guard" else hit.get("tint",Color(1,0.78,0.26))
			tint.a = 1-t
			var radius: float = (20 if hit.strong else 12) + 45 * t
			if hit.get("splash",0.0) > 0:
				draw_set_transform(at,0,Vector2(1,0.5))
				draw_arc(Vector2.ZERO,hit.splash*(0.35+t*0.65),0,TAU,40,tint,4,true)
				draw_set_transform(Vector2.ZERO)
			draw_arc(at, radius * 0.6, 0, TAU, 24, tint, 2, true)
			for ray: int in 8:
				var axis := Vector2.from_angle(ray * TAU / 8 + 0.2)
				draw_line(at + axis * radius * 0.4, at + axis * radius, tint, 3 if hit.strong else 2, true)
			if t < 0.3:
				draw_line(at-Vector2(17,23),at+Vector2(17,23),Color(1,1,0.9,1-t),5,true)
				draw_line(at-Vector2(-20,14),at+Vector2(-20,14),Color(1,1,0.9,1-t),4,true)
	for id: int in battle.actors:
		var actor: RainbowActionActor = battle.actors[id]
		if not actor.unit.alive(): continue
		var at: Vector2 = Iso.project(battle.sample_position(id))
		if id == battle.controlled_id:
			var direction: Vector2 = Iso.project(actor.unit.facing).normalized()
			var tip: Vector2 = at + direction * 42
			draw_colored_polygon(PackedVector2Array([tip,tip-direction.rotated(0.45)*12,tip-direction.rotated(-0.45)*12]),Color(0.6,0.95,1,0.9))
		if actor.guard_left > 0:
			draw_arc(at + Vector2(0, -25), 30, 0, TAU, 32, Color(0.4, 0.85, 1, 0.9), 3, true)
		if actor.unit.team == 1 and actor.action != &"":
			draw_circle(at + Vector2(0, -85), 7, Color(1, 0.3, 0.12))
