class_name OrbitLightningVisual
extends Node2D
## Presentation only: schedules and damage live in AdvancedSkillRuntime.
var data:SkillEffectDefinition
var orbs:Array[Dictionary]=[]
var age:float=0
var texture:Texture2D=preload("res://features/skills/art/lightning-v2.png")
func _ready()->void:z_index=3500
func _draw()->void:
	var cell:Vector2=texture.get_size()/Vector2(4,2)
	var frame:int=int(age*18)%8
	for orb:Dictionary in orbs:
		var p:Vector2=orb.point
		draw_circle(p,18,Color(0.05,0.6,1,0.12));draw_circle(p,10,Color(0.3,0.8,1,0.35));draw_circle(p,4,Color(0.8,1,1))
		draw_texture_rect_region(texture,Rect2(p-Vector2(16,25),Vector2(32,38)),Rect2(Vector2(frame%4,int(frame/4))*cell,cell),Color(0.5,0.9,1,0.85))
		if orb.flash:
			var points:PackedVector2Array=PackedVector2Array([p])
			var perpendicular:Vector2=(orb.target-p).normalized().orthogonal()
			for i:int in range(1,7):
				var point:Vector2=p.lerp(orb.target,i/6.0)
				if i<6:point+=perpendicular*sin(age*43+i*7.7)*10*sin(PI*i/6.0)
				points.append(point)
			draw_polyline(points,Color(0.1,0.65,1,0.2),13,true);draw_polyline(points,Color(0.2,0.75,1,0.8),4,true);draw_polyline(points,Color(0.85,1,1),1.5,true)
