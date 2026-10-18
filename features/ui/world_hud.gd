class_name WorldHud
extends Control
const HEIGHT: float = 768.0
const FOOTER: float = 92.0
var hud: GameHud
var director: GameDirector
var canvas: Control
var roster_buttons: Array[Button] = []
var hp_bars: Array[ProgressBar] = []
var mp_bars: Array[ProgressBar] = []
var point_buttons: Array[Button] = []
var status_panel: Panel
var log_panel: Panel
var actions_panel: Panel
var hero_level: Label
var hero_name: Label
var experience_bar: ProgressBar
var battle_power: Label
var credit_level: Label
var silver: Label
var messages: RichTextLabel
var chat_input: LineEdit
var entries: Array[Dictionary] = []
var toolbar: Array[Button] = []
var minimap: CartographicMap
var map_panel: Panel
var map_view: CartographicMap
var map_source: WorldMapProjection
var map_title: Label
var map_status: Label
var map_places: VBoxContainer
var listed_map: WorldMapDefinition
var info_panel: Panel
var info_title: Label
var info_text: Label
var standee_panel: Panel
var standee: TextureRect
var standee_name: Label
var map_controls: Array[Button] = []
var map_travel: Button
var selected_portal: String=""
var side_buttons: Array[Button] = []
var clock_label: Label
var reference_width: float = 1024.0
var reference_height: float = 768.0
var peace: Button
var trade: Button
var panel_style: StyleBoxTexture
var button_style: StyleBoxTexture

func _ready() -> void:
	name = "ClassicWorldHUD"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas = Control.new()
	canvas.name = "ReferenceCanvas"
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	panel_style = ClassicSkin.panel_style()
	button_style = ClassicSkin.button_style()
	var world_theme: Theme = Theme.new()
	var scaled_font: Font = hud.font.duplicate() as Font
	scaled_font.set("multichannel_signed_distance_field",true)
	world_theme.default_font = scaled_font
	world_theme.default_font_size = 11
	for state: String in ["normal","pressed","hover","disabled","focus"]:
		world_theme.set_stylebox(state,"Button",button_style)
	world_theme.set_color("font_color","Button",Color(0.94,0.9,0.75))
	world_theme.set_stylebox("panel","Panel",panel_style)
	canvas.theme = world_theme
	_build_roster()
	_build_footer()
	map_source = WorldMapProjection.new()
	add_child(map_source)
	_build_minimap()
	_build_standee()
	_build_info()
	_build_map()
	get_viewport().size_changed.connect(_layout)
	PartyProgress.changed.connect(_party_changed)
	_layout()
	refresh()

func _panel(title: String, rect: Rect2) -> Panel:
	var panel: Panel = Panel.new()
	panel.name = title
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(panel)
	return panel
func _label(parent: Control, text: String, at: Vector2, extent: Vector2, font_size: int = 11, color: Color = Color(0.96,0.91,0.77)) -> Label:
	var label: Label = Label.new()
	label.position = at
	label.size = extent
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label
func _image(parent: Control, texture: Texture2D, at: Vector2, extent: Vector2) -> TextureRect:
	var image: TextureRect = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.position = at
	image.size = extent
	image.texture = texture
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image
func _button(parent: Control, text: String, at: Vector2, extent: Vector2, action: Callable) -> Button:
	var button: Button = Button.new()
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.position = at
	button.size = extent
	button.text = text
	button.add_theme_font_size_override("font_size",1 if text=="" else 11)
	parent.add_child(button)
	button.size = extent
	button.pressed.connect(action)
	if text!="":
		button.text = ""
		var caption: Label = _label(button,text,Vector2.ZERO,extent,11)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		button.set_meta("caption_label",caption)
	return button
func _bar(parent: Control, at: Vector2, extent: Vector2, color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.add_theme_font_size_override("font_size",1)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill",fill)
	bar.add_theme_stylebox_override("background",ClassicSkin.inset_style())
	parent.add_child(bar)
	bar.position = at
	bar.size = extent
	return bar

func _build_roster() -> void:
	var strip: Panel = _panel("WorldMercenaryStrip",Rect2(0,0,85,532))
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.05,0.05,0.04,0.3)
	strip.add_theme_stylebox_override("panel",background)
	for i: int in 12:
		var slot: int = i
		var button: Button = _button(strip,"",Vector2(5,5+i*44),Vector2(78,40),func() -> void: _select(slot))
		button.name = "Portrait_%d" % i
		button.add_theme_stylebox_override("normal",ClassicSkin.inset_style())
		button.add_theme_stylebox_override("disabled",background)
		button.add_theme_stylebox_override("hover",ClassicSkin.inset_style())
		button.disabled = i >= PartyProgress.records.size()
		var portrait: TextureRect = _image(button,CharacterArt.texture(PartyProgress.records[i].definition,"eyes") if i<PartyProgress.records.size() else null,Vector2(1,1),Vector2(76,28))
		button.set_meta("portrait",portrait)
		var hp: ProgressBar = _bar(button,Vector2(1,30),Vector2(76,4),Color(0.15,0.71,0.59))
		var mp: ProgressBar = _bar(button,Vector2(1,35),Vector2(76,3),Color(0.34,0.65,0.79))
		var plus: Button = _button(strip,"",Vector2(68,5+i*44),Vector2(15,15),func() -> void: _stats(slot))
		plus.tooltip_text = "有剩餘能力點，開啟能力面板配點"
		_image(plus,ClassicSkin.icon(15),Vector2.ZERO,Vector2(15,15))
		roster_buttons.append(button)
		hp_bars.append(hp)
		mp_bars.append(mp)
		point_buttons.append(plus)
	_button(strip,"▸",Vector2(0,530),Vector2(12,58),func() -> void: show_info("傭兵編隊","主角固定，最多十人出戰。\nF2隊伍與道具可單獨存入、取出或交換傭兵。"))
func _select(slot: int) -> void:
	if slot < PartyProgress.records.size():
		director.select_world_slot(slot)
		show_standee()
func _stats(slot: int) -> void:
	if slot >= PartyProgress.records.size():
		return
	director.select_world_slot(slot)
	standee_panel.hide()
	hud.progression.show_stats()

func _build_footer() -> void:
	status_panel = _panel("WorldHeroStatus",Rect2(0,HEIGHT-FOOTER,256,FOOTER))
	var badge: Panel = Panel.new()
	badge.position = Vector2(10,10)
	badge.size = Vector2(36,38)
	badge.add_theme_stylebox_override("panel",ClassicSkin.inset_style())
	status_panel.add_child(badge)
	hero_level = _label(badge,"LV.\n1",Vector2(3,1),Vector2(32,34),11)
	hero_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	experience_bar = _bar(status_panel,Vector2(62,12),Vector2(178,9),Color(0.33,0.61,0.60))
	_image(status_panel,ClassicSkin.icon(14),Vector2(51,7),Vector2(18,18))
	hero_name = _label(status_panel,"行旅商人",Vector2(62,29),Vector2(178,19),11)
	_image(status_panel,ClassicSkin.icon(12),Vector2(10,53),Vector2(25,20))
	battle_power = _label(status_panel,"戰鬥力 —",Vector2(38,54),Vector2(100,19),11)
	battle_power.tooltip_text = "戰鬥力算法待你提供，沒有代算或捏造数值。"
	_image(status_panel,ClassicSkin.icon(13),Vector2(140,53),Vector2(22,20))
	credit_level = _label(status_panel,"信用 —",Vector2(166,54),Vector2(78,19),11)
	credit_level.tooltip_text = "信用等級算法待提供。"
	_image(status_panel,ClassicSkin.icon(14),Vector2(10,74),Vector2(25,15))
	silver = _label(status_panel,"銀兩 —",Vector2(38,73),Vector2(197,18),11)
	silver.tooltip_text = "經濟／銀兩系統尚未接入。"
	log_panel = _panel("WorldMessageLog",Rect2(258,HEIGHT-FOOTER,510,FOOTER))
	var tabs: Array[String] = ["一般","商團","組隊","小商團","社團","設定"]
	for i: int in tabs.size():
		var caption: String = tabs[i]
		var button: Button = _button(log_panel,caption,Vector2(9+i*50,-17),Vector2(49,19),func() -> void:
			if caption=="設定": hud.show_settings()
			elif caption!="一般": show_info(caption,"目前是本機試玩。多人頻道尚未連線，沒有發送任何網路訊息。"))
		button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		button.add_theme_color_override("font_color",Color(1,0.91,0.17) if i==0 else Color(0.62,0.62,0.6))
	messages = RichTextLabel.new()
	messages.position = Vector2(8,7)
	messages.size = Vector2(493,57)
	messages.bbcode_enabled = false
	messages.scroll_following = true
	messages.add_theme_font_size_override("normal_font_size",11)
	messages.add_theme_color_override("default_color",Color(0.28,0.93,0.22))
	messages.add_theme_stylebox_override("normal",ClassicSkin.inset_style())
	log_panel.add_child(messages)
	chat_input = LineEdit.new()
	chat_input.name = "LocalChatInput"
	chat_input.position = Vector2(8,68)
	chat_input.size = Vector2(493,18)
	chat_input.max_length = 500
	chat_input.placeholder_text = "本機訊息（尚未連線）"
	chat_input.add_theme_font_size_override("font_size",11)
	chat_input.add_theme_stylebox_override("normal",ClassicSkin.inset_style())
	chat_input.add_theme_stylebox_override("focus",ClassicSkin.inset_style())
	log_panel.add_child(chat_input)
	chat_input.size = Vector2(493,18)
	chat_input.text_submitted.connect(func(text: String) -> void:
		if text.strip_edges()!="": append_message("[本機] "+text,Color(0.94,0.9,0.78))
		chat_input.clear())
	actions_panel = _panel("WorldWindowButtons",Rect2(770,HEIGHT-FOOTER,254,FOOTER))
	var tips: Array[String] = ["背包 I","能力 S","裝備 I","大地圖 M","操作說明","商團資料","朋友資料","行旅選單 [X]"]
	var icons: Array[int] = [4,5,6,11,9,7,8,10]
	for i: int in tips.size():
		var index: int = i
		var button: Button = _button(actions_panel,"",Vector2(9+i*30,11),Vector2(27,30),func() -> void: _toolbar(index))
		button.tooltip_text = tips[i]
		_image(button,ClassicSkin.icon(icons[i]),Vector2(3,3),Vector2(21,24))
		toolbar.append(button)
	peace = _button(actions_panel,"和平模式",Vector2(54,46),Vector2(77,21),func() -> void: show_info("和平模式","目前為本機試玩，沒有玩家對戰或PVP服務。"))
	trade = _button(actions_panel,"同意交易",Vector2(135,46),Vector2(77,21),func() -> void: show_info("交易","交易系統及多人服務尚未接入。"))
	clock_label = _label(actions_panel,"單機行旅",Vector2(20,72),Vector2(216,15),11)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(actions_panel,"[離線]",Vector2(8,-17),Vector2(60,18),11,Color(1,0.89,0.2))
	for icon_id: int in [6,13]:
		var index: int = side_buttons.size()
		var button: Button = _button(canvas,"",Vector2(978,568+index*48),Vector2(40,42),func() -> void: show_info("記事簿" if index==0 else "行旅記事","固定試玩編隊與三處戰場已開放。\n正式任務、商團和信用系統待後續接入。"))
		_image(button,ClassicSkin.icon(icon_id),Vector2(3,3),Vector2(34,36))
		side_buttons.append(button)
func _toolbar(index: int) -> void:
	match index:
		0,2:
			standee_panel.hide()
			hud.progression.toggle_inventory()
		1: _stats(PartyProgress.selected_slot)
		3: toggle_map()
		4: show_info("操作說明","左鍵行旅／點怪進戰\n肖像或1–9／0選兵，S能力，I背包\n點肖像：右側立繪\nM大地圖，X關閉視窗\n戰鬥中沿用原有控兵／技能鍵。")
		5: show_info("商團資料","尚未加入商團\n\n本機試玩尚無商團伺服器。\n成員、等級、資金和貢獻資料待多人階段接入。")
		6: show_info("朋友資料","朋友列表：空\n\n目前未連線。好友、在線狀態和私訊服務尚未實作。")
		7: hud.toggle_menu()

func _build_minimap() -> void:
	minimap = CartographicMap.new()
	minimap.director = director
	minimap.source = map_source
	minimap.position = Vector2(822,3)
	minimap.size = Vector2(196,196)
	canvas.add_child(minimap)
	minimap.place_selected.connect(func(_point: Vector2) -> void: toggle_map())
	var rim: TextureRect = _image(minimap,ClassicSkin.icon(2),Vector2.ZERO,Vector2(196,196))
	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){vec2 p=(UV-vec2(0.5,0.0))*4.0; vec2 d=p-vec2(0.5); float r=length(d); if(r<0.438 || r>0.49){discard;} float s=mix(0.28,0.49,(r-0.438)/0.052); vec2 q=vec2(0.5)+normalize(d)*s; COLOR=texture(TEXTURE,vec2(0.5,0.0)+q/4.0);}"
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	rim.material = material
	for i: int in 4:
		var index: int = i
		var button: Button = _button(minimap,["◎","＋","−","×"][i],Vector2(112+i*17,165-i*12),Vector2(23,23),func() -> void:
			if index==0: toggle_map()
			elif index==1: minimap.zoom = minf(4,minimap.zoom+0.5)
			elif index==2: minimap.zoom = maxf(1,minimap.zoom-0.5)
			else: minimap.visible = false)
		button.tooltip_text = ["大地圖","放大","縮小","關閉小地圖（M可重開）"][i]
		map_controls.append(button)

func _build_standee() -> void:
	standee_panel = _panel("SelectedCharacterIllustration",Rect2(806,218,210,385))
	standee_panel.hide()
	standee_name = _label(standee_panel,"",Vector2(10,9),Vector2(190,22),13)
	standee_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	standee = _image(standee_panel,CharacterArt.texture(Catalog.party()[0]),Vector2(12,32),Vector2(186,315))
	_button(standee_panel,"關閉立繪 [X]",Vector2(54,352),Vector2(100,23),func() -> void: standee_panel.hide())
func show_standee() -> void:
	if director.mode==&"world":
		# Portrait clicks use the same dossier as I, never a competing window.
		standee_panel.hide()
		hud.progression.show_inventory()
func _build_info() -> void:
	info_panel = _panel("WorldInformation",Rect2(282,190,460,320))
	info_panel.hide()
	info_title = _label(info_panel,"",Vector2(22,16),Vector2(420,28),20)
	info_text = _label(info_panel,"",Vector2(22,60),Vector2(415,206),15)
	info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(info_panel,"關閉視窗 [X]",Vector2(174,278),Vector2(112,26),func() -> void: info_panel.hide())
func show_info(title: String, content: String) -> void:
	if hud.progression != null: hud.progression.close()
	standee_panel.hide()
	info_title.text = title
	info_text.text = content
	info_panel.show()
	canvas.move_child(info_panel,canvas.get_child_count()-1)
func _build_map() -> void:
	map_panel = _panel("ExpandedWorldMap",Rect2(2,2,1020,662))
	map_panel.hide()
	map_title = _label(map_panel,"地圖全貌",Vector2(22,14),Vector2(500,24),17)
	map_view = CartographicMap.new()
	map_view.director = director
	map_view.source = map_source
	map_view.circular = false
	map_view.zoom = 1.0
	map_panel.add_child(map_view)
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.offset_left = 22
	map_view.offset_top = 52
	map_view.offset_right = -252
	map_view.offset_bottom = -54
	map_view.place_selected.connect(func(point: Vector2) -> void:
		map_status.text = "%s\n座標 %.0f, %.0f" % [map_view.selected_name,point.x,point.y])
	var side: Control = Control.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(side)
	side.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -232
	side.offset_right = -22
	side.offset_top = 52
	side.offset_bottom = -54
	_label(side,"出入口與地點",Vector2.ZERO,Vector2(210,24),14)
	var scroll: ScrollContainer = ScrollContainer.new()
	side.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 32
	scroll.offset_bottom = -128
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_places = VBoxContainer.new()
	map_places.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_places.add_theme_constant_override("separation",6)
	scroll.add_child(map_places)
	map_status = _label(side,"點選地點以定位",Vector2.ZERO,Vector2(210,42),12)
	map_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	map_status.offset_top = -118
	map_status.offset_bottom = -72
	map_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var legend: Label = _label(side,"綠點：玩家　◇：出入口\n金點：地標　淺綠：到達點",Vector2.ZERO,Vector2(210,42),11)
	legend.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	legend.offset_top = -55
	legend.offset_bottom = -10
	var help: Label = _label(map_panel,"滾輪縮放 · 右鍵拖曳 · 左鍵定位",Vector2.ZERO,Vector2(400,20),12)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 22
	help.offset_right = 422
	help.offset_top = -36
	help.offset_bottom = -16
	var overview_button: Button = _button(map_panel,"全貌",Vector2.ZERO,Vector2(66,27),func() -> void:
		map_view.overview()
		map_status.text = "點選地點以定位")
	overview_button.name = "MapOverview"
	overview_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	overview_button.offset_left = -362
	overview_button.offset_right = -296
	overview_button.offset_top = -38
	overview_button.offset_bottom = -11
	var player_button: Button = _button(map_panel,"我的位置",Vector2.ZERO,Vector2(88,27),func() -> void:
		map_view.locate(director.world_hero.position,"你的位置")
		map_status.text = "你的位置\n座標 %.0f, %.0f" % [director.world_hero.position.x,director.world_hero.position.y])
	player_button.name = "MapPlayerLocation"
	player_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	player_button.offset_left = -284
	player_button.offset_right = -196
	player_button.offset_top = -38
	player_button.offset_bottom = -11
	var close_button: Button = _button(map_panel,"關閉 [X / M]",Vector2.ZERO,Vector2(160,27),func() -> void: map_panel.hide())
	close_button.name = "MapClose"
	close_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	close_button.offset_left = -182
	close_button.offset_right = -22
	close_button.offset_top = -38
	close_button.offset_bottom = -11

func _refresh_map_places() -> void:
	if listed_map == map_view.definition: return
	selected_portal=""
	if map_travel==null:
		map_travel=_button(map_panel,"前往入口",Vector2.ZERO,Vector2(120,27),func()->void:
			if selected_portal.is_empty() or director.mode!=&"world": return
			director.world_context.refresh_player(PartyProgress.serialize())
			var route: Dictionary=director.world_context.approach_portal(selected_portal)
			if route.ok:
				map_panel.hide()
				director.message.emit("正在前往入口；到達後自動進入。")
			else: map_status.text="無法前往："+str(route.reason))
		map_travel.name="MapTravelEntrance"
		map_travel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		map_travel.offset_left=22; map_travel.offset_right=142
		map_travel.offset_top=-72; map_travel.offset_bottom=-45
	map_travel.disabled=true
	listed_map = map_view.definition
	map_title.text = "地圖全貌 · "+listed_map.display_name
	map_status.text = "點選地點以定位"
	for child: Node in map_places.get_children():
		map_places.remove_child(child)
		child.queue_free()
	for place: Dictionary in map_view.locations():
		var button: Button = Button.new()
		button.name = "MapLocation_"+str(map_places.get_child_count())
		button.custom_minimum_size = Vector2(0,48)
		button.tooltip_text = "%s\n%s\n座標 %.0f, %.0f" % [place["name"],place["detail"],place["point"].x,place["point"].y]
		map_places.add_child(button)
		var title: Label = _label(button,("◇ " if place["kind"]=="portal" else "· ")+str(place["name"]),Vector2(10,4),Vector2(180,20),12)
		title.clip_text = true
		var detail: Label = _label(button,str(place["detail"]),Vector2(10,25),Vector2(180,18),10,Color(0.72,0.76,0.7))
		detail.clip_text = true
		button.pressed.connect(func() -> void:
			selected_portal=str(place.get("portal_id",""))
			map_travel.disabled=selected_portal.is_empty()
			map_view.locate(place["point"],place["name"])
			map_status.text = "%s\n座標 %.0f, %.0f" % [place["name"],place["point"].x,place["point"].y])
func toggle_map() -> void:
	if director.mode != &"world":
		return
	hud.progression.close()
	standee_panel.hide()
	minimap.show()
	map_panel.visible = not map_panel.visible
	map_view.refresh()
	if map_panel.visible:
		map_view.overview()
		_refresh_map_places()
func close_top_window() -> bool:
	for panel: Panel in [info_panel,map_panel,standee_panel]:
		if panel.visible:
			panel.hide()
			return true
	return false
func is_modal() -> bool:
	return map_panel.visible or info_panel.visible
func close_windows() -> void:
	for panel: Panel in [map_panel,info_panel,standee_panel]:
		panel.hide()

func append_message(text: String, color: Color = Color(0.28,0.93,0.22)) -> void:
	entries.append({"text":text,"color":color})
	if entries.size()>200:
		entries.pop_front()
	if messages != null:
		messages.clear()
		for entry: Dictionary in entries:
			messages.push_color(entry["color"])
			messages.add_text(entry["text"]+"\n")
			messages.pop()
func _party_changed(_slot: int) -> void:
	refresh()
func refresh() -> void:
	if not is_node_ready():
		return
	var hero: CharacterRecord = PartyProgress.records[0]
	if director.world_context != null:
		battle_power.text = "戰力 %d" % PowerCalculator.make_summary(director.world_context.state["player_party"])["power"]
		battle_power.tooltip_text = "authored_rating_v1：上陣永久配置評分，非傷害；不受受傷或臨時召喚影響。"
	hero_level.text = "LV.\n%d" % hero.level()
	hero_name.text = hero.definition.display_name
	var from: int = CharacterRecord.CURVE.threshold(hero.level())
	var to: int = CharacterRecord.CURVE.threshold(mini(100,hero.level()+1))
	experience_bar.value = 100 if hero.level()==100 else 100.0*(hero.experience-from)/maxi(1,to-from)
	experience_bar.tooltip_text = "主角經驗 %d / %d" % [hero.experience,to]
	for i: int in roster_buttons.size():
		roster_buttons[i].visible=i<PartyProgress.records.size()
		roster_buttons[i].disabled=i>=PartyProgress.records.size()
		if i>=PartyProgress.records.size():
			point_buttons[i].hide()
			hp_bars[i].value = 0
			mp_bars[i].value = 0
			hp_bars[i].hide()
			mp_bars[i].hide()
			continue
		var record: CharacterRecord = PartyProgress.records[i]
		hp_bars[i].show()
		mp_bars[i].show()
		(roster_buttons[i].get_meta("portrait") as TextureRect).texture = CharacterArt.texture(record.definition,"eyes")
		var stats: Dictionary = record.stats()
		var hp: float = record.health
		var mp: float = record.mana
		if i==0 and director.world_hero != null:
			hp = director.world_hero.vitals.health
			mp = director.world_hero.vitals.mana
		hp_bars[i].value = 100.0*hp/maxf(1,stats["health"])
		mp_bars[i].value = 100.0*mp/maxf(1,stats["mana"])
		point_buttons[i].visible = record.points()>0
		roster_buttons[i].tooltip_text = "%s Lv.%d\n體力 %.0f / %.0f\n法力 %.0f / %.0f\n剩餘配點 %d\n點擊查看立繪" % [record.definition.display_name,record.level(),hp,stats["health"],mp,stats["mana"],record.points()]
		roster_buttons[i].modulate = Color(1,0.95,0.78) if i==PartyProgress.selected_slot else Color.WHITE
	minimap.refresh()
	if map_panel.visible:
		map_view.refresh()
		_refresh_map_places()
func _layout() -> void:
	var extent: Vector2 = get_viewport().get_visible_rect().size
	var factor: float = minf(extent.y/HEIGHT,extent.x/1024.0)
	canvas.scale = Vector2.ONE*factor
	reference_width = extent.x/factor
	reference_height = extent.y/factor
	canvas.size = Vector2(reference_width,reference_height)
	status_panel.position = Vector2(0,reference_height-FOOTER)
	log_panel.position = Vector2(258,reference_height-FOOTER)
	log_panel.size = Vector2(reference_width-514,FOOTER)
	messages.size.x = log_panel.size.x-16
	chat_input.size.x = log_panel.size.x-16
	actions_panel.position = Vector2(reference_width-254,reference_height-FOOTER)
	minimap.position.x = reference_width-202
	standee_panel.position.x = reference_width-218
	for button: Button in side_buttons:
		button.position.x = reference_width-46
		button.position.y = reference_height-200+side_buttons.find(button)*48
	map_panel.size.x = reference_width-4
	map_panel.size.y = reference_height-FOOTER-24
	map_panel.position.x = 2
	info_panel.position.x = (reference_width-info_panel.size.x)*0.5
