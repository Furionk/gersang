class_name SupportVfx
extends Sprite2D
const SHEET:Texture2D=preload("res://features/skills/art/support/restoration-v1.png")
const FEEDBACK:UiFeedbackProfile=preload("res://features/ui/data/feedback.tres")
var target:TacticalUnit
var mana:bool=false
var age:float=0.0
func _ready()->void:
	texture=SHEET;hframes=4;vframes=2;z_index=3500
	scale=Vector2.ONE*FEEDBACK.support_width/(SHEET.get_width()/4.0)
	offset=Vector2(0,-SHEET.get_height()/2.0*0.29)
	_process(0)
func _process(delta:float)->void:
	age+=delta
	if not is_instance_valid(target) or not target.alive() or age>=FEEDBACK.support_duration:
		queue_free();return
	position=Iso.project(target.position)
	var t:float=age/FEEDBACK.support_duration
	frame=(4 if mana else 0)+mini(3,int(t*4))
	modulate.a=minf(1,t*10)*minf(1,(1-t)*5)*0.8
