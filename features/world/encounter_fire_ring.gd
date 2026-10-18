class_name EncounterFireRing
extends Node2D
## Presentation-only flame crown. Positions come from the existing visual pose.
var director: GameDirector
var animation_time: float = 0.0
func _process(delta: float) -> void:
	animation_time += delta
	queue_redraw()
func _draw() -> void:
	if director==null or director.world_context==null: return
	var session: Dictionary = director.world_context.state["active_encounter"]
	if session.is_empty() or session.get("state","")!="COUNTDOWN": return
	var number: int = ceili(maxf(0.0,float(session["deadline_ms"]-director.world_context.state["world_time_ms"])/1000.0))
	var point: Vector2 = Iso.project(director.world_visual_position())
	_ring(point,0.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font,point+Vector2(-9,-88),str(number),HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color(0.08,0.02,0.0))
	draw_string(font,point+Vector2(-11,-90),str(number),HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color(1.0,0.78,0.2))
	for id: String in session.get("enemy_ids",[session.get("enemy_id","")]):
		var party: Dictionary = director.world_context.party(id)
		if not party.is_empty(): _ring(Iso.project(party["position"]),float(id.hash()%31))
	for id: String in session.get("approaching_ids",[]):
		var party: Dictionary = director.world_context.party(id)
		if party.is_empty(): continue
		var p: Vector2 = Iso.project(party["position"])+Vector2(0,-90)
		draw_circle(p,16,Color(1,0.96,0.83))
		draw_string(font,p+Vector2(-5,9),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color(0.85,0.08,0.04))
func _ring(center: Vector2, phase: float) -> void:
	for i: int in 28:
		var angle: float = TAU*float(i)/28.0
		var base: Vector2 = center+Vector2(cos(angle)*28,sin(angle)*14)
		var height: float = 12.0+8.0*(0.5+0.5*sin(animation_time*14.0+i*2.3+phase))
		var lean: float = sin(animation_time*9.0+i)*4.0
		draw_colored_polygon(PackedVector2Array([base+Vector2(-4,2),base+Vector2(lean,-height),base+Vector2(5,2)]),Color(1,0.32,0.03,0.9))
		draw_colored_polygon(PackedVector2Array([base+Vector2(-2,2),base+Vector2(lean*0.5,-height*0.65),base+Vector2(3,2)]),Color(1,0.87,0.27,0.95))
