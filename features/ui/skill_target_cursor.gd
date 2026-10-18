class_name SkillTargetCursor
extends Control
var director:GameDirector
var caption:String=""
var valid_target:bool=false
var tint:Color=Color(1,0.83,0.35)
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(_delta:float)->void:
	visible=false
	if director.mode!=&"battle" or director.selection==null or director.hud.is_modal_open():return
	var entry:Dictionary=director.selection._entry(director.selection.armed_skill_id)
	if entry.is_empty():return
	if get_viewport().gui_get_hovered_control()!=null:return
	var skill:SkillDefinition=entry.skill
	if skill.target_mode not in [SkillDefinition.Target.ENEMY,SkillDefinition.Target.ALLY]:return
	visible=true
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	var team:int=0 if skill.target_mode==SkillDefinition.Target.ALLY else 1
	var target:TacticalUnit=director.pick_unit(director.get_global_mouse_position(),team)
	valid_target=target!=null and target.alive()
	tint=Color(0.5,1,0.65) if valid_target else Color(1,0.82,0.35)
	caption=skill.display_name+"\n"+("左鍵："+target.definition.display_name if valid_target else "請點選"+("友軍" if team==0 else "敵人"))+" · 右鍵取消"
	queue_redraw()
func _draw()->void:
	var at:Vector2=get_viewport().get_mouse_position()
	for sx:float in [-1.0,1.0]:
		for sy:float in [-1.0,1.0]:
			var p:Vector2=at+Vector2(sx,sy)*12
			draw_line(p,p-Vector2(sx*6,0),tint,2)
			draw_line(p,p-Vector2(0,sy*6),tint,2)
	var origin:Vector2=Vector2(clampf(at.x+22,4,size.x-310),clampf(at.y+20,4,size.y-56))
	draw_style_box(director.hud._style(Color(0.025,0.035,0.04,0.95)),Rect2(origin,Vector2(304,52)))
	var lines:PackedStringArray=caption.split("\n")
	for i:int in lines.size():draw_string(director.hud.font,origin+Vector2(8,19+i*21),lines[i],HORIZONTAL_ALIGNMENT_LEFT,290,14,tint)
