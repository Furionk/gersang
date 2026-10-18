class_name BloodSwordWaveVisual
extends Node2D
var direction:Vector2
var width:float=240
var age:float=0
func _ready()->void:z_index=3501
func _draw()->void:
	var forward:Vector2=Iso.project(direction);var side:Vector2=Iso.project(direction.orthogonal())
	for echo:int in 3:
		var points:PackedVector2Array=PackedVector2Array()
		for index:int in 25:
			var t:float=index/24.0-0.5
			points.append(side*(t*width)+forward*((1-4*t*t)*72-echo*28))
		draw_polyline(points,Color(0.55,0.0,0.015,0.5-echo*0.12),18-echo*3,true)
		draw_polyline(points,Color(1,0.03,0.12,0.9-echo*0.2),6-echo,true)
		if echo==0:draw_polyline(points,Color(1,0.75,0.58),1.6,true)
	for i:int in 12:
		var t:float=float(i)/11-0.5
		var p:Vector2=side*t*width-forward*fmod(age*110+i*13,90)
		draw_circle(p,2,Color(0.9,0.05,0.08,0.5))
