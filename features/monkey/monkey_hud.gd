extends Control
## Presentation only: encounter vitals, equipment and clock remain owned by MonkeyGarden.
const ITEMS = preload("res://features/monkey/assets/ui/ae_items.png")
const FRAMES = preload("res://features/monkey/assets/ui/ae_icons.png")
const INPUTS = preload("res://features/monkey/assets/ui/ae_icons2.png")
const FONT = preload("res://art/fonts/NotoSansCJKtc-Regular.otf")
const NAVY = Color("10375f")
const CREAM = Color("fff3d6")
const DESCRIPTIONS = ["近距離擊暈猴子，再換網捕捉。", "停步由上往下落網，靠近猴子再出手。", "按住左鍵掃描，轉動鏡頭尋找訊號。", "按住左鍵升空；落地恢復飛行能量。", "按住左鍵蓄力加速，截住逃跑的猴子。"]
const ITEM_RECTS = [Rect2(30,45,405,405),Rect2(433,60,405,380),Rect2(880,45,355,405),Rect2(8,480,440,350),Rect2(444,480,410,345)]
var arena: MonkeyGarden
var wheel_open := false
var preview := 1
var countdown_text := ""
var factor := 1.0
var origin := Vector2.ZERO
var wheel_centers: Array[Vector2] = [Vector2(440,180),Vector2(635,325),Vector2(565,545),Vector2(310,545),Vector2(235,325)]

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	var toolbar_height: float=52.0 if OS.has_feature("web") else 0.0
	factor=minf(viewport_size.x/1280.0,(viewport_size.y-toolbar_height)/720.0)
	origin=(viewport_size-Vector2(1280,720)*factor)*0.5+Vector2(0,toolbar_height*0.5)
	queue_redraw()

func picture(texture: Texture2D, region: Rect2, target: Rect2, tint: Color=Color.WHITE) -> void:
	draw_texture_rect_region(texture,target,region,tint)

func words(value: String, at: Vector2, font_size: int, color: Color=CREAM, centered: bool=false) -> void:
	if centered: at.x-=FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5
	draw_string_outline(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,0 if color==NAVY else 3,NAVY)
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func badge(index: int, center: Vector2, diameter: float, selected: bool) -> void:
	var rect:=Rect2(center-Vector2.ONE*diameter*0.5,Vector2.ONE*diameter)
	picture(FRAMES,Rect2(440,64,378,366) if selected else Rect2(68,100,320,315),rect)
	var inner:=rect.grow(-diameter*0.18)
	var source: Rect2=ITEM_RECTS[index]
	var fit:=source.size*(minf(inner.size.x/source.size.x,inner.size.y/source.size.y))
	picture(ITEMS,source,Rect2(inner.get_center()-fit*0.5,fit))
	var key_rect:=Rect2(center+Vector2(-17,diameter*0.32),Vector2(34,34))
	picture(FRAMES,Rect2(916,140,258,246),key_rect)
	words(str(index+1),key_rect.position+Vector2(17,25),23,CREAM,true)

func _draw() -> void:
	if arena==null: return
	draw_set_transform(origin,0,Vector2.ONE*factor)
	picture(FRAMES,Rect2(12,953,438,140),Rect2(20,61,290,65))
	var capacity:=maxf(arena.max_hp/10.0,0.1)
	var group_size:=maxf(1,ceil(capacity/5.0))
	var count:=mini(5,int(ceil(capacity/group_size)))
	for i in count:
		var rect:=Rect2(25+i*53,26,60,60)
		picture(ITEMS,Rect2(40,885,345,330),rect)
		var remaining:=clampf((arena.hp/10.0-i*group_size)/minf(group_size,capacity-i*group_size),0,1)
		if remaining>0:
			picture(ITEMS,Rect2(890,503,325*remaining,320),Rect2(rect.position,Vector2(60*remaining,60)))
	words("體力 %.1f / %.1f"%[arena.hp/10,capacity],Vector2(34,142),19)
	if group_size>1: words("每枚最多 %d 心"%int(group_size),Vector2(34,165),14)
	picture(FRAMES,Rect2(20,574,415,151),Rect2(435,20,225,65))
	var seconds:=int(ceil(arena.time_left))
	words("%02d:%02d"%[seconds/60,seconds%60],Vector2(547,64),32,Color("ff6655") if seconds<=15 else Color("ffdb48"),true)
	words(arena.profile.zone_name,Vector2(547,105),18,CREAM,true)
	for i in 5: badge(i,Vector2(800+i*100,65),110 if i==arena.gadget else 90,i==arena.gadget)
	words(arena.TOOL_NAMES[arena.gadget],Vector2(800+arena.gadget*100,154),19,CREAM,true)
	picture(FRAMES,Rect2(835,564,405,169),Rect2(969,625,285,75))
	picture(ITEMS,Rect2(833,891,407,300),Rect2(977,628,85,63))
	words("剩餘 %d 隻"%(arena.target_count-arena.captured_ids.size()),Vector2(1070,675),25,Color("ffe24d"))
	picture(FRAMES,Rect2(20,574,415,151),Rect2(22,642,225,54))
	words("Q  道具選擇",Vector2(134,678),23,CREAM,true)
	words(("點擊畫面啟用滑鼠鏡頭" if not arena.drag_camera and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED else "WASD 移動 · 右鍵拖曳鏡頭 · 左鍵使用" if arena.drag_camera else "WASD 移動 · 滑鼠鏡頭 · 右鍵朝向 · 左鍵使用"),Vector2(270,675),17)
	words("Space 二段跳   Ctrl 潛行   1–5／滾輪換裝   Esc 暫停",Vector2(28,622),16)
	if wheel_open: draw_wheel()
	if not countdown_text.is_empty():
		words(countdown_text,Vector2(640,370),100,Color("ffde55"),true)
		words("準備捕捉全部 %d 隻猴子"%arena.target_count,Vector2(640,425),22,CREAM,true)

func draw_wheel() -> void:
	draw_rect(Rect2(-origin/factor,get_viewport_rect().size/factor),Color(0.015,0.045,0.09,0.78))
	picture(FRAMES,Rect2(20,574,415,151),Rect2(35,25,310,85))
	words("道具選擇",Vector2(190,82),35,CREAM,true)
	picture(FRAMES,Rect2(456,824,337,331),Rect2(205,170,455,450))
	for i in 5: badge(i,wheel_centers[i],210 if preview==i else 180,preview==i)
	picture(INPUTS,Rect2(145,103,255,343),Rect2(407,340,60,80))
	picture(FRAMES,Rect2(885,791,322,416),Rect2(815,92,395,530))
	words(arena.TOOL_NAMES[preview],Vector2(1012,167),32,NAVY,true)
	var source: Rect2=ITEM_RECTS[preview]
	var fit:=source.size*minf(260/source.size.x,260/source.size.y)
	picture(ITEMS,source,Rect2(Vector2(1012,320)-fit*0.5,fit))
	words(DESCRIPTIONS[preview],Vector2(1012,476),17,NAVY,true)
	picture(FRAMES,Rect2(447,572,362,152),Rect2(858,505,305,86))
	words("裝 備",Vector2(1010,562),35,NAVY,true)
	words("×",Vector2(1158,151),28,CREAM,true)
	words("1–5 選擇  ·  滾輪切換  ·  Enter 裝備  ·  Q 返回",Vector2(640,685),23,CREAM,true)
	words("選單開啟時，戰鬥與倒數暫停",Vector2(445,99),16)

func local_point(screen: Vector2) -> Vector2:
	return (screen-origin)/factor

func hud_hit(screen: Vector2) -> int:
	var point:=local_point(screen)
	for i in 5:
		if point.distance_to(Vector2(800+i*100,65))<48: return i
	if Rect2(22,642,225,54).has_point(point): return 5
	return -1

func wheel_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_Q,KEY_ESCAPE]: arena.close_wheel(false)
		elif event.physical_keycode in [KEY_ENTER,KEY_KP_ENTER]: arena.close_wheel(true)
		elif event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_5: preview=event.physical_keycode-KEY_1
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: preview=(preview+1)%5
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: preview=(preview+4)%5
		elif event.button_index==MOUSE_BUTTON_LEFT:
			var point:=local_point(event.position)
			for i in 5:
				if point.distance_to(wheel_centers[i])<95: preview=i
			if Rect2(858,505,305,86).has_point(point): arena.close_wheel(true)
			elif Rect2(1125,100,75,80).has_point(point): arena.close_wheel(false)
