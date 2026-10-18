class_name AdvancedSkillVisual
extends Node2D
## Pure presentation; planar positions are projected once. No damage here.
var kind: SkillEffectDefinition.Kind
var points: Array[Vector2] = []
var stakes: Array[Sprite2D] = []
var cell: Vector2
var age: float=0.0
var life: float=1.0
var flash_at: float=0.0
var flames: Array[Sprite2D] = []
var fire_texture: Texture2D
var fire_radius: float=42.0
func _ready() -> void:
	z_index=3500
func create_stakes(path: String, center: Vector2, radius: float, visual_scale: float=0.13) -> void:
	z_index=0
	y_sort_enabled=true
	var texture: Texture2D=load(path) as Texture2D
	cell=Vector2(texture.get_width()/4.0,texture.get_height()/2.0)
	var spacing: float=48.0
	var reach: int=ceili(radius/spacing)
	for y: int in range(-reach,reach+1):
		for x: int in range(-reach,reach+1):
			var offset: Vector2=Vector2(x,y)*spacing
			if offset.length()>radius: continue
			var sprite: Sprite2D=Sprite2D.new()
			sprite.texture=texture
			sprite.region_enabled=true
			sprite.region_filter_clip_enabled=true
			sprite.scale=Vector2.ONE*visual_scale
			sprite.offset=Vector2(0,-cell.y*0.30)
			sprite.position=Iso.project(center+offset)
			add_child(sprite)
			stakes.append(sprite)
	update_stakes()
func update_stakes() -> void:
	var frame: int=mini(3,int(age*8)) if age<0.5 else 4+int(age*5)%2
	if life-age<0.4: frame=6 if life-age>0.2 else 7
	for sprite: Sprite2D in stakes:
		sprite.region_rect=Rect2(Vector2(frame%4,frame/4)*cell+Vector2.ONE*3,cell-Vector2.ONE*6)
		sprite.modulate.a=clampf((life-age)/0.15,0,1)
func _process(_delta: float) -> void:
	if kind==SkillEffectDefinition.Kind.STAKES: update_stakes()

func configure_fire(path: String, radius: float) -> void:
	fire_texture=load("res://features/skills/art/fire-trail-v2.png" if path.is_empty() else path) as Texture2D
	fire_radius=radius
	cell=Vector2(fire_texture.get_width()/4.0,fire_texture.get_height()/2.0)

func update_fire(entries: Array[Dictionary], now: float, lifetime: float) -> void:
	while flames.size()>entries.size(): flames.pop_back().queue_free()
	while flames.size()<entries.size():
		var sprite: Sprite2D=Sprite2D.new()
		sprite.texture=fire_texture
		sprite.region_enabled=true
		sprite.region_filter_clip_enabled=true
		sprite.scale=Vector2.ONE*(fire_radius*2.0*1.414/cell.x)
		sprite.offset=Vector2(0,-cell.y*0.39)
		add_child(sprite); flames.append(sprite)
	for i: int in entries.size():
		var elapsed: float=now-float(entries[i].born)
		var remaining: float=minf(lifetime-elapsed,life-now)
		var frame: int=mini(2,int(elapsed*10)) if elapsed<0.3 else 2+(int(elapsed*11)+i)%4
		if remaining<0.4: frame=6 if remaining>0.2 else 7
		flames[i].region_rect=Rect2(Vector2(frame%4,frame/4)*cell+Vector2.ONE*3,cell-Vector2.ONE*6)
		flames[i].position=Iso.project(entries[i].point)
		flames[i].modulate.a=clampf(remaining/0.2,0,1)
func _draw() -> void:
	if kind==SkillEffectDefinition.Kind.CHAIN:
		var alpha: float=clampf(1-(age-flash_at)/0.45,0,1)
		for i: int in range(1,points.size()):
			var path: PackedVector2Array=[]
			var a: Vector2=points[i-1]; var b: Vector2=points[i]
			var perpendicular: Vector2=(b-a).orthogonal().normalized()
			for step: int in 9:
				path.append(a.lerp(b,float(step)/8)+perpendicular*(sin(float(step)*5.7+age*47)*7 if step in range(1,8) else 0.0))
			draw_polyline(path,Color(0.15,0.55,1,alpha*0.5),8,true)
			draw_polyline(path,Color(0.5,0.9,1,alpha),3,true)
			draw_polyline(path,Color(1,1,1,alpha),1,true)
	elif kind==SkillEffectDefinition.Kind.BUFF and age<0.7:
		draw_set_transform(Vector2.ZERO,0,Iso.CIRCLE_SCALE)
		draw_arc(Vector2.ZERO,34,0,TAU,36,Color(1,0.75,0.2,1-age/0.7),3,true)
func draw_ellipse_glow(point: Vector2) -> void:
	draw_set_transform(point,0,Iso.CIRCLE_SCALE)
	draw_circle(Vector2.ZERO,24,Color(1,0.25,0.02,0.2))
	draw_set_transform(Vector2.ZERO)
