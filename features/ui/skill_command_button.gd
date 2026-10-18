class_name SkillCommandButton
extends Button
var auto_mode:int=0 # 0 manual, 1 mixed, 2 all owners automatic
var armed:bool=false
var conflicted:bool=false
const ORBIT_LIGHTS:int=4
var rejected_left:float=0.0
var phase:float=0.0
func reject()->void:
	rejected_left=0.45;queue_redraw()
func _ready()->void:
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func _process(delta:float)->void:
	if auto_mode>0 or armed or rejected_left>0:
		rejected_left=maxf(0,rejected_left-delta)
		phase=fmod(phase+delta*0.55,1.0);queue_redraw()
func edge_point(t:float)->Vector2:
	var icon:Control=get_meta("icon")
	var rect:Rect2=Rect2(icon.position-Vector2(2,2),icon.size+Vector2(4,4))
	var distance:float=fposmod(t,1.0)*2*(rect.size.x+rect.size.y)
	if distance<rect.size.x:return rect.position+Vector2(distance,0)
	distance-=rect.size.x
	if distance<rect.size.y:return rect.position+Vector2(rect.size.x,distance)
	distance-=rect.size.y
	if distance<rect.size.x:return rect.end-Vector2(distance,0)
	return rect.position+Vector2(0,rect.size.y-(distance-rect.size.x))
func _draw()->void:
	if rejected_left>0:draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),Color(1,0.25,0.15,rejected_left/0.45),false,3)
	if armed:draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),Color(1,0.88,0.42),false,2)
	if auto_mode>0:
		var color:Color=Color(0.4,1,0.64) if auto_mode==2 else Color(1,0.8,0.35)
		for light:int in ORBIT_LIGHTS:
			var head:float=phase+float(light)/ORBIT_LIGHTS
			for i:int in 24:
				color.a=(1.0-float(i)/24)*0.9
				draw_line(edge_point(head-i*0.006),edge_point(head-(i+1)*0.006),color,2,true)
			color.a=1;draw_circle(edge_point(head),1.8,color)
