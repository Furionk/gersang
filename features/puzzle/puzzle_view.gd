class_name PuzzleView
extends Control
const COLORS: Array[Color] = [Color("ef654d"),Color("4eb9ed"),Color("6bce91"),Color("f4d565"),Color("ed8fbb")]
const NAMES: Array[String] = ["火","水","草","電","心"]
const BOARD: Rect2 = Rect2(60,500,600,500)
const LOGICAL: Vector2 = Vector2(720,1040)
var controller: PuzzleController
var font: Font = preload("res://art/fonts/NotoSansCJKtc-Regular.otf")
var landmark: Texture2D
var backdrop: Texture2D = preload("res://features/puzzle/art/shrine-v1.png")
var monster: Texture2D = preload("res://features/puzzle/art/pearl-monster-v1.png")
var portraits: Array[Texture2D] = []
var factor: float = 1.0
var origin: Vector2 = Vector2.ZERO
var pointer_position: Vector2 = Vector2.ZERO
var touch_id: int = -1
var pulse: float = 0.0
var impact: PuzzleImpact = PuzzleImpact.new()
var status: String = "按住一珠，沿途換位；橫直三連消除"
var input_events: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if controller != null: controller.cue.connect(_cue)

func _cue(event: Dictionary) -> void:
	pulse = 0.24
	if event.kind == "attack": impact.record(event,controller.combat.friends[event.actor].element)
	match event.kind:
		"combo": status = "%d COMBO" % event.number
		"attack": status = "%s  −%d%s" % [controller.combat.friends[event.actor].name,ceili(event.amount),"  擊破！" if event.dead else ""]
		"heal": status = "體力回復  +%d" % floori(event.amount)
		"enemy_attack": status = "敵人攻擊  −%d" % ceili(event.amount)

func _process(delta: float) -> void:
	_update_layout()
	if controller != null and controller.focused:
		pulse = maxf(0,pulse-delta)
		impact.advance(delta)
	queue_redraw()

func _update_layout() -> void:
	factor = minf(size.x/LOGICAL.x,size.y/LOGICAL.y)
	origin = (size-LOGICAL*factor)*0.5

func logical_position(point: Vector2) -> Vector2:
	return (point-origin)/factor

func cell_at(point: Vector2) -> int:
	if not BOARD.has_point(point): return -1
	var cell: Vector2i = Vector2i((point-BOARD.position)/100.0)
	return cell.y*6+cell.x

func enemy_rect(index: int) -> Rect2:
	var count: int = controller.combat.enemies.size()
	if count == 1 and controller.combat.enemies[0].get("texture") != null:
		return Rect2(220,58,280,244)
	var columns: int = mini(6,count)
	var rows: int = ceili(float(count)/columns)
	var height: float = minf(200.0,224.0/rows)
	var width: float = minf(180.0,600.0/columns)
	return Rect2(Vector2(360-columns*width*0.5+(index%columns)*width,76+(index/columns)*height),Vector2(width,height))

func _gui_input(event: InputEvent) -> void:
	if controller == null: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and touch_id < 0:
		input_events += 1
		if event.pressed: _press(logical_position(event.position))
		else: controller.release()
		accept_event()
	elif event is InputEventMouseMotion and touch_id < 0:
		_drag_pointer(logical_position(event.position))
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed and touch_id < 0:
			touch_id = event.index
			_press(logical_position(event.position))
		elif not event.pressed and event.index == touch_id:
			controller.release()
			touch_id = -1
		accept_event()
	elif event is InputEventScreenDrag and event.index == touch_id:
		_drag_pointer(logical_position(event.position))
		accept_event()

func _drag_pointer(point: Vector2) -> void:
	if not controller.focused or controller.stage != "drag": return
	pointer_position = point
	controller.drag(cell_at(point))

func _press(point: Vector2) -> void:
	if not controller.focused or controller.stage != "ready": return
	for i: int in controller.combat.enemies.size():
		if enemy_rect(i).has_point(point) and controller.combat.enemies[i].hp > 0:
			controller.combat.target = i
			return
	pointer_position = point
	controller.press(cell_at(point))

func text_at(point: Vector2, text: String, size_value: int = 20, color: Color = Color("ece7d5")) -> void:
	draw_string(font,point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,color)

func bar(rect: Rect2, value: float, maximum: float, color: Color) -> void:
	draw_rect(rect,Color("131b25"))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(value/maxf(1,maximum),0,1),rect.size.y)),color)
	draw_rect(rect,Color("bba46d"),false,1.5)

func orb_symbol(center: Vector2, element: int) -> void:
	var shapes: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-18,8),Vector2(-15,-8),Vector2(-7,-1),Vector2(-3,-24),Vector2(9,-13),Vector2(12,-1),Vector2(18,-8),Vector2(21,9),Vector2(12,20),Vector2(-10,20)]),
		PackedVector2Array([Vector2(0,-25),Vector2(14,-6),Vector2(20,7),Vector2(16,18),Vector2(6,23),Vector2(-7,23),Vector2(-17,17),Vector2(-20,6),Vector2(-13,-8)]),
		PackedVector2Array([Vector2(-19,20),Vector2(-20,1),Vector2(-11,-15),Vector2(24,-24),Vector2(19,9),Vector2(5,21)]),
		PackedVector2Array([Vector2(2,-25),Vector2(20,-25),Vector2(5,-4),Vector2(19,-4),Vector2(-12,27),Vector2(-5,5),Vector2(-21,5)]),
		PackedVector2Array([Vector2(0,23),Vector2(-22,1),Vector2(-23,-10),Vector2(-17,-19),Vector2(-8,-20),Vector2(0,-12),Vector2(8,-20),Vector2(17,-19),Vector2(23,-10),Vector2(22,1)])
	]
	var shape: PackedVector2Array = shapes[element].duplicate()
	for i: int in shape.size(): shape[i] += center
	draw_colored_polygon(shape,Color("fff5de"))
	if element == 2: draw_line(center+Vector2(-12,12),center+Vector2(12,-12),COLORS[element].darkened(0.35),3,true)

func draw_orb(center: Vector2, element: int) -> void:
	var color: Color = COLORS[element]
	draw_circle(center+Vector2(1,4),43,Color(0.01,0.02,0.03,0.8))
	draw_circle(center,41,color.darkened(0.4))
	for layer_index: int in range(7,0,-1):
		draw_circle(center-Vector2(0,3+(7-layer_index)*1.0),float(layer_index)*5.3,color.darkened(float(layer_index)*0.035))
	draw_arc(center,39,0,TAU,40,color.lightened(0.5),2)
	draw_circle(center+Vector2(-12,-19),13,Color(1,1,1,0.18))
	orb_symbol(center-Vector2(0,2),element)

func _draw() -> void:
	if controller == null: return
	_update_layout()
	draw_texture_rect(backdrop,Rect2(Vector2.ZERO,size),false)
	if landmark != null:
		var height: float = minf(size.y * 0.9, 900.0)
		var extent: Vector2 = landmark.get_size() * (height / landmark.get_height())
		draw_texture_rect(landmark,Rect2(Vector2((size.x-extent.x)*0.5,-height*0.05),extent),false)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.025,0.05,0.30))
	draw_set_transform(origin,0,Vector2.ONE*factor)
	draw_rect(Rect2(38,0,644,1040),Color(0.025,0.04,0.06,0.67))
	draw_line(Vector2(38,0),Vector2(38,1040),Color("786746"),2)
	draw_line(Vector2(682,0),Vector2(682,1040),Color("786746"),2)
	text_at(Vector2(62,35),"轉 珠 世 界",27,Color("e6ce93"))
	text_at(Vector2(500,34),"第 %02d 回合"%controller.combat.turn,20)
	for i: int in controller.combat.enemies.size():
		var foe: Dictionary = controller.combat.enemies[i]
		var rect: Rect2 = enemy_rect(i)
		var tint: Color = Color("21172d") if foe.get("dark",false) else COLORS[foe.element]
		var artwork: Texture2D = foe.get("texture")
		if artwork != null: tint = Color.WHITE
		if foe.hp <= 0:
			tint.a = 0.13
			if controller.last_event.get("kind","")=="attack" and controller.last_event.get("target",-1)==i:
				tint.a = maxf(0.13,pulse/0.24)
		var side: float = minf(rect.size.x-8,rect.size.y-32)
		var image_rect: Rect2 = Rect2(rect.get_center()-Vector2(side,side)*0.5,Vector2(side,side))
		image_rect.position += impact.offset(i)
		if foe.get("dark",false):
			draw_arc(image_rect.get_center(),side*0.46,0,TAU,32,Color(0.55,0.36,0.75,0.65*tint.a),1.5,true)
		var hit_tint: Color = tint.lerp(Color(6,6,6,tint.a),impact.flash(i)*0.9)
		if artwork != null: draw_texture_rect(artwork,image_rect,false,hit_tint)
		else: draw_texture_rect_region(monster,image_rect,Rect2(310,345,620,610),hit_tint)
		if String(foe.name).contains("王"):
			var crown: Vector2=image_rect.position+Vector2(side*0.5,12)
			draw_colored_polygon(PackedVector2Array([crown+Vector2(-22,10),crown+Vector2(-27,-12),crown+Vector2(-10,-2),crown+Vector2(0,-22),crown+Vector2(10,-2),crown+Vector2(27,-12),crown+Vector2(22,10)]),Color(1,0.8,0.25,tint.a))
		if foe.has("level"):
			text_at(rect.position+Vector2(10,rect.size.y-24),"Lv%d %s"%[foe.level,"黑暗" if foe.get("dark",false) and artwork == null else foe.name],12,Color(1,0.9,0.65,tint.a))
		if foe.hp > 0:
			bar(Rect2(rect.position+Vector2(8,rect.size.y-18),Vector2(rect.size.x-16,6)),foe.hp,foe.max_hp,Color("9671bd") if foe.get("dark",false) else tint)
			text_at(rect.position+Vector2(10,15),"%s %.1fs"%["闇" if foe.get("dark",false) else NAMES[foe.element],maxf(0,foe.cooldown)],17,Color("ff7660") if foe.cooldown <= 2.0 else Color("b39ccc") if foe.get("dark",false) else tint)
			if controller.combat.live_target() == i:
				draw_arc(rect.get_center(),minf(rect.size.x,rect.size.y)*0.4,0,TAU,40,Color("ffdc8a"),2)
	var friends: Array[Dictionary] = controller.combat.friends
	var columns: int = mini(6,maxi(1,friends.size()))
	var tile_width: float = 600.0/columns
	for i: int in friends.size():
		var ally: Dictionary = friends[i]
		var rect: Rect2 = Rect2(60+(i%columns)*tile_width,308+(i/columns)*66,tile_width-4,62)
		var tint: Color = COLORS[ally.element]
		var alpha: float = 1.0 if ally.hp > 0 else 0.25
		draw_rect(rect,Color(0.06,0.07,0.1,0.95))
		if i < portraits.size() and portraits[i] != null:
			draw_texture_rect(portraits[i],Rect2(rect.position,Vector2(58,58)),false,Color(1,1,1,alpha))
		draw_rect(rect,Color(tint,alpha),false,2)
		text_at(rect.position+Vector2(rect.size.x-24,23),NAMES[ally.element],18,Color(tint,alpha))
		bar(Rect2(rect.position+Vector2(2,57),Vector2(rect.size.x-4,4)),ally.hp,ally.max_hp,tint)
	draw_impacts(columns,tile_width)
	if controller.combos > 0:
		text_at(Vector2(280,290),"%d COMBO"%controller.combos,28,Color("f1d598"))
	bar(Rect2(60,451,600,21),controller.combat.health(),controller.combat.maximum_health,Color("db78a0"))
	text_at(Vector2(68,468),"體力  %d / %d"%[ceili(controller.combat.health()),ceili(controller.combat.maximum_health)],16)
	text_at(Vector2(60,494),status,18,Color("ffe3a7") if pulse > 0 else Color("ddd5bd"))
	for i: int in 30:
		var at: Vector2 = BOARD.position+Vector2((i%6)*100,(i/6)*100)
		draw_rect(Rect2(at,Vector2(100,100)),Color("34434c") if (i+i/6)%2==0 else Color("202e38"))
		var element: int = controller.board.cells[i]
		if element < 0: continue
		var center: Vector2 = at+Vector2(50,50)
		if controller.stage == "fall": center.y -= 24*clampf(controller.delay/0.24,0,1)
		if controller.stage == "drag" and i == controller.selected:
			draw_arc(center,43,0,TAU,40,Color(COLORS[element],0.45),3)
			continue
		draw_orb(center,element)
		if i == controller.selected or (controller.stage == "clear" and i in controller.highlighted):
			draw_arc(center,46,0,TAU,40,Color("fff1c2"),4)
	draw_rect(BOARD,Color("bda778"),false,3)
	if controller.stage == "drag" and controller.selected >= 0:
		draw_circle(pointer_position+Vector2(4,9),48,Color(0,0,0,0.35))
		draw_orb(pointer_position,controller.board.cells[controller.selected])
		draw_arc(pointer_position,46,0,TAU,40,Color("fff1c2"),3)
	bar(Rect2(60,1008,600,5),controller.remaining,controller.rules.move_seconds,Color("a9dddc"))
	text_at(Vector2(60,1034),"拖曳換位 · %.1f 秒"%controller.remaining,17)
	text_at(Vector2(477,1034),"%02d COMBO"%controller.combos,21,Color("f1d598"))
	if not controller.focused:
		draw_rect(Rect2(Vector2.ZERO,LOGICAL),Color(0,0,0,0.7))
		text_at(Vector2(245,480),"已暫停 · 返回視窗繼續",22)

func draw_impacts(columns: int, tile_width: float) -> void:
	for hit: Dictionary in impact.hits:
		var age: float=hit.age
		var power: float=hit.strength
		var color: Color=COLORS[hit.element]
		var center: Vector2=enemy_rect(hit.target).get_center()
		var start: Vector2=Vector2(60+(int(hit.actor)%columns)*tile_width+tile_width*0.5,308+(int(hit.actor)/columns)*66)
		if age<0.24:
			var fade: float=1.0-age/0.24
			# Layered elemental trail: soft outer color, bright inner core.
			draw_line(start,center,Color(color,fade*0.18),14*power,true)
			draw_line(start,center,Color(color.lightened(0.25),fade*0.8),3*power,true)
			draw_line(start,center,Color(1,0.98,0.85,fade),1.5,true)
			var radius: float=(12+age*130)*power
			draw_arc(center,radius,0,TAU,36,Color(color,fade),2*power,true)
			if power>=1.7: draw_arc(center,radius*0.68,0,TAU,32,Color(1,0.92,0.65,fade*0.7),2,true)
			var rays: int=8+int((power-1)*10)
			for ray: int in rays:
				var angle: float=TAU*ray/rays+float(hit.serial)*0.7
				var direction: Vector2=Vector2.from_angle(angle)
				draw_line(center+direction*radius*0.55,center+direction*radius,Color(color.lightened(0.5),fade),1.5*power,true)
		# Alternate lanes keep simultaneous damage numbers readable.
		var lane: int=int(hit.serial)%3
		var number_at: Vector2=center+Vector2((lane-1)*24,-12-lane*18-age*48)
		number_at.y=maxf(62,number_at.y)
		var alpha: float=clampf((0.85-age)/0.28,0,1)
		var label: String=str(ceili(hit.amount))
		var font_size: int=22+int(power*5)+int(5*maxf(0,1-age/0.12))
		number_at.x=clampf(number_at.x-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5,46,580)
		draw_string_outline(font,number_at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,5,Color(0.02,0.025,0.04,alpha))
		draw_string(font,number_at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(color.lightened(0.65),alpha))
		if hit.get("combos",1)>=5:
			draw_string_outline(font,number_at+Vector2(0,-font_size),"%d COMBO"%hit.combos,HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color(0,0,0,alpha))
			text_at(number_at+Vector2(0,-font_size),"%d COMBO"%hit.combos,14,Color(1,0.85,0.4,alpha))
