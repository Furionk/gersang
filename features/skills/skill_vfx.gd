class_name SkillVfx
extends Node2D
var age: float = 0.0
var life: float = 1.0
var logical_radius: float = 80.0
var kind: SkillEffectDefinition.Kind = SkillEffectDefinition.Kind.INSTANT
var sprite: Sprite2D
var cell: Vector2
var base_scale: Vector2 = Vector2.ONE
var satellites: Array[Sprite2D] = []
var radial_offsets: Array[Vector2] = []
var radial_starts: Array[float] = []
var radial_sprites: Array[Sprite2D] = []
var radial_tick_interval: float = 0.2
func initialize(path: String, radius_value: float, duration_value: float, effect_kind: SkillEffectDefinition.Kind, tick_interval: float = 0.2, grounded: bool=false, foot_ratio: float=0.84) -> void:
	logical_radius = radius_value
	life = maxf(0.05, duration_value)
	kind = effect_kind
	radial_tick_interval = maxf(0.02,tick_interval)
	if path == "" or not ResourceLoader.exists(path):
		return
	var texture: Texture2D = load(path) as Texture2D
	cell = Vector2(texture.get_width() / 4.0, texture.get_height() / 2.0)
	sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_filter_clip_enabled = true
	# Trim atlas gutters at sampling time, leaving the original bitmap intact.
	sprite.region_rect = Rect2(Vector2(3, 3), cell - Vector2.ONE * 6)
	var scale_value: float = maxf(0.14, logical_radius * 2.0 * 1.414 / cell.x)
	base_scale = Vector2.ONE * scale_value
	sprite.scale = base_scale
	if kind == SkillEffectDefinition.Kind.BARRIER:
		sprite.position.y = -cell.y * 0.4 * scale_value
	elif grounded:
		sprite.position.y = -cell.y * (foot_ratio-0.5) * scale_value
	add_child(sprite)
	if kind == SkillEffectDefinition.Kind.RADIAL:
		var spacing: float = maxf(20,logical_radius/3)
		var reach: int = ceili(logical_radius/spacing)
		var spot_scale: float = spacing*1.4/cell.x
		base_scale = Vector2.ONE*spot_scale
		var radius_step: float = maxf(0.001,logical_radius*radial_tick_interval/life)
		for y: int in range(-reach,reach+1):
			for x: int in range(-reach,reach+1):
				var offset: Vector2 = Vector2(x,y)*spacing
				if offset.length()>logical_radius+0.001: continue
				var extra: Sprite2D = sprite if offset==Vector2.ZERO else Sprite2D.new()
				extra.texture = texture
				extra.region_enabled = true
				extra.region_filter_clip_enabled = true
				extra.region_rect = sprite.region_rect
				extra.scale = base_scale
				# Foot-anchored stationary sites, not sprites travelling along spokes.
				extra.position = Iso.project(offset)+Vector2(0,-cell.y*0.36*spot_scale)
				if extra!=sprite:
					add_child(extra)
					satellites.append(extra)
				radial_offsets.append(offset)
				radial_starts.append(maxf(0,ceilf(offset.length()/radius_step)-1)*radial_tick_interval)
				radial_sprites.append(extra)
		_process(0)
func _process(_delta: float) -> void:
	if sprite == null:
		return
	if kind==SkillEffectDefinition.Kind.RADIAL:
		for i: int in radial_sprites.size():
			var extra: Sprite2D = radial_sprites[i]
			var local_age: float = age-radial_starts[i]
			extra.visible = local_age>=-0.000001
			if not extra.visible: continue
			var frame: int = clampi(int(maxf(0,local_age)/maxf(0.05,life-radial_starts[i])*8),0,7)
			extra.region_rect = Rect2(Vector2(frame%4,frame/4)*cell+Vector2.ONE*3,cell-Vector2.ONE*6)
		modulate.a = minf(1,maxf(0,(life-age)/0.1))
		queue_redraw()
		return
	var frame: int = mini(7, int(age / life * 8.0))
	if kind in [SkillEffectDefinition.Kind.FOLLOW, SkillEffectDefinition.Kind.LINE]:
		frame = 2 + int(age * 12) % 4
	elif kind == SkillEffectDefinition.Kind.BARRIER:
		frame = mini(3, int(age * 12))
		if life - age < 0.4:
			frame = mini(7, 4 + int((0.4 - (life - age)) * 10))
	var rect: Rect2 = Rect2(Vector2(frame % 4, frame / 4) * cell + Vector2.ONE * 3, cell - Vector2.ONE * 6)
	sprite.region_rect = rect
	if kind == SkillEffectDefinition.Kind.FOLLOW:
		sprite.rotation = age * 2.0
	modulate.a = minf(1.0, maxf(0, (life - age) / 0.15))
func _draw() -> void:
	if kind!=SkillEffectDefinition.Kind.RADIAL: return
	var step: float = floorf(maxf(0,age)/radial_tick_interval)*radial_tick_interval
	var radius_now: float = logical_radius*minf(1,(step+radial_tick_interval)/life)
	draw_set_transform(Vector2.ZERO,0,Iso.CIRCLE_SCALE)
	draw_circle(Vector2.ZERO,radius_now,Color(1,0.48,0.06,0.06))
	draw_arc(Vector2.ZERO,radius_now,0,TAU,64,Color(1,0.69,0.22,0.6),1.4)
