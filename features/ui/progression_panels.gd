class_name ProgressionPanels
extends RefCounted
## One dossier owns artwork, equipment, bag, stats and skill review, never gameplay data.
const DESIGN: Vector2 = Vector2(1280,720)
const SLOT_CAPTIONS: Dictionary = {&"head":"頭盔",&"weapon":"武器",&"body":"衣甲",&"hands":"手套",&"belt":"腰帶",&"charm":"符咒",&"ring_left":"左戒指",&"feet":"鞋履",&"ring_right":"右戒指"}
var hud: GameHud
var director: GameDirector
var sheet: Panel
var canvas: Control
var stat_panel: Panel
var inventory_panel: Panel
var stat_title: Label
var inventory_title: Label
var portrait: TextureRect
var vitals_label: Label
var xp_label: Label
var xp_bar: ProgressBar
var point_label: Label
var attribute_labels: Dictionary = {}
var plus_buttons: Dictionary = {}
var derived_labels: Array[Label] = []
var equipment_buttons: Dictionary = {}
var bag_buttons: Array[Button] = []
var roster_buttons: Array[Button] = []
var weight_label: Label
var feedback: Label
var skill_grid: GridContainer
var skill_detail: RichTextLabel
var skill_calculation: RichTextLabel
var skill_scroll: ScrollContainer
var skill_buttons: Array[Button] = []
var skill_entries: Array[Dictionary] = []
var selected_skill: StringName = &""
var skill_signature: String = ""
var preview_fields: Dictionary = {}
var stats_tab: Button
var inventory_tab: Button
var respec_button: Button
var respec_panel: Panel
var respec_text: Label
var respec_yes: Button
var respec_no: Button
var respec_id: String = ""

func initialize(owner_hud: GameHud) -> void:
	hud = owner_hud
	director = hud.director
	sheet = hud._panel("CharacterDossier",Rect2(Vector2.ZERO,DESIGN),Color(0.025,0.022,0.018,0.98))
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.name = "DossierDesignCanvas"
	canvas.size = DESIGN
	canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	sheet.add_child(canvas)
	var frame: Panel = _section(canvas,Rect2(12,12,1256,696))
	frame.add_theme_stylebox_override("panel",ClassicSkin.panel_style())
	_section(canvas,Rect2(24,22,1228,57))
	inventory_title = hud._label(canvas,"",Vector2(180,24),Vector2(620,35),25,GameHud.GOLD)
	hud._label(canvas,"角色行囊 · 裝備與技能",Vector2(26,27),Vector2(145,25),14)
	stats_tab = hud._button(canvas,"能力 [S]",Vector2(882,24),Vector2(126,32),show_stats)
	inventory_tab = hud._button(canvas,"裝備 [I]",Vector2(1018,24),Vector2(126,32),show_inventory)
	hud._button(canvas,"關閉 [X]",Vector2(1154,24),Vector2(98,32),close)
	_build_roster()
	inventory_panel = _section(canvas,Rect2(170,94,656,608))
	inventory_panel.name = "CharacterInventory"
	inventory_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	_build_equipment()
	stat_panel = _section(canvas,Rect2(170,94,656,608))
	stat_panel.name = "CharacterStats"
	stat_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	_build_stats()
	var illustration_frame: Panel = _section(canvas,Rect2(346,94,304,526))
	illustration_frame.add_theme_stylebox_override("panel",ClassicSkin.panel_style())
	portrait = TextureRect.new()
	portrait.name = "FullBodyIllustration"	
	portrait.position = Vector2(16,17)
	portrait.size = Vector2(272,492)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	illustration_frame.add_child(portrait)
	vitals_label = hud._label(canvas,"",Vector2(346,62),Vector2(482,28),13,GameHud.GOLD)
	_build_skills()
	_build_bag()
	PartyProgress.changed.connect(refresh)
	hud.root.resized.connect(_layout)
	_layout()
	refresh(0)
	close()

func _section(parent: Control, rect: Rect2) -> Panel:
	var panel: Panel = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel",ClassicSkin.inset_style())
	parent.add_child(panel)
	return panel

func _build_roster() -> void:
	var scroll: ScrollContainer=ScrollContainer.new(); scroll.position=Vector2(20,94); scroll.size=Vector2(144,540); canvas.add_child(scroll)
	var roster: VBoxContainer=VBoxContainer.new(); roster.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(roster)
	for i: int in MercenaryRoster.ACTIVE_CAPACITY:
		var slot: int = i
		var button: Button = hud._button(roster,"",Vector2.ZERO,Vector2(126,68),func() -> void: director.select_world_slot(slot, true))
		button.custom_minimum_size=Vector2(126,68)
		var face: TextureRect = TextureRect.new()
		face.position = Vector2(6,6)
		face.size = Vector2(52,52)
		face.texture = CharacterArt.texture(PartyProgress.records[i].definition,"portrait") if i<PartyProgress.records.size() else null
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(face)
		var label: Label = hud._label(button,"",Vector2(62,9),Vector2(60,48),12)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.set_meta("label",label)
		button.set_meta("face",face)
		roster_buttons.append(button)
	hud._label(canvas,"切換兵種\n1–9 / 0 快捷選取",Vector2(28,646),Vector2(135,40),12,GameHud.GOLD)

func _build_equipment() -> void:
	var positions: Dictionary = {&"head":Vector2(4,54),&"weapon":Vector2(4,181),&"body":Vector2(4,308),&"hands":Vector2(496,54),&"belt":Vector2(496,181),&"charm":Vector2(496,308),&"ring_left":Vector2(4,536),&"feet":Vector2(218,536),&"ring_right":Vector2(432,536)}
	for slot: StringName in GearItemDefinition.SLOT_NAMES:
		var extent: Vector2 = Vector2(152,112) if slot not in [&"ring_left",&"feet",&"ring_right"] else Vector2(210,68)
		var button: Button = hud._button(inventory_panel,"",positions[slot],extent,func() -> void: director.unequip_world_item(slot))
		button.set_meta("caption",SLOT_CAPTIONS[slot])
		hud._label(button,SLOT_CAPTIONS[slot],Vector2(8,5),Vector2(extent.x-16,19),12,GameHud.GOLD)
		_make_item_slot(button,Vector2(46,46),Vector2((extent.x-46)/2,27) if extent.y>80 else Vector2(10,22),Vector2(6,85) if extent.y>80 else Vector2(62,32),Vector2(extent.x-12,21) if extent.y>80 else Vector2(extent.x-68,22))
		equipment_buttons[slot] = button

func _build_stats() -> void:
	_section(stat_panel,Rect2(4,0,152,526))
	_section(stat_panel,Rect2(496,0,152,526))
	stat_title = hud._label(stat_panel,"",Vector2(14,12),Vector2(132,38),14,GameHud.GOLD)
	stat_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	xp_label = hud._label(stat_panel,"",Vector2(14,62),Vector2(132,70),11)
	xp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	xp_bar = ProgressBar.new()
	xp_bar.position = Vector2(14,140)
	xp_bar.size = Vector2(132,8)
	xp_bar.show_percentage = false
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_bar.add_theme_stylebox_override("background",hud._style(Color(0.07,0.06,0.04)))
	xp_bar.add_theme_stylebox_override("fill",hud._style(Color(0.39,0.58,0.37)))
	stat_panel.add_child(xp_bar)
	for i: int in CharacterRecord.ATTRIBUTES.size():
		var key: String = CharacterRecord.ATTRIBUTES[i]
		attribute_labels[key] = hud._label(stat_panel,"",Vector2(14,175+i*61),Vector2(101,26),15)
		plus_buttons[key] = hud._button(stat_panel,"＋",Vector2(117,175+i*61),Vector2(28,28),func() -> void: director.allocate_world_attribute(key,100 if Input.is_key_pressed(KEY_SHIFT) else 1))
		(plus_buttons[key] as Button).tooltip_text = "點擊：+1\nShift＋點擊：+100（不足時分配所有剩餘點數）"
	point_label = hud._label(stat_panel,"",Vector2(14,431),Vector2(132,30),14,GameHud.GOLD)
	hud._label(stat_panel,"點擊 +1\nShift＋點擊 +100\n不足時用餘下點數",Vector2(14,465),Vector2(132,57),12)
	hud._label(stat_panel,"戰鬥能力",Vector2(506,14),Vector2(132,25),17,GameHud.GOLD)
	for row: int in 10:
		var label: Label = hud._label(stat_panel,"",Vector2(506,60+row*43),Vector2(132,41),13)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		derived_labels.append(label)
	respec_button = hud._button(stat_panel,"重新配點",Vector2(218,535),Vector2(200,35),_request_respec)
	respec_button.tooltip_text = "免費退還所選角色已分配點數；保留等級、裝備與背包，不補滿HP／MP。"
	hud._label(stat_panel,"每級 4 點 · 配點與裝備即時參與公式計算",Vector2(30,579),Vector2(600,23),13,GameHud.GOLD)
	respec_panel = _section(canvas,Rect2(Vector2.ZERO,DESIGN))
	respec_panel.add_theme_stylebox_override("panel",hud._style(Color(0,0,0,0.8)))
	respec_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var card: Panel = _section(respec_panel,Rect2(415,249,450,210))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._label(card,"確認重新配點",Vector2(22,15),Vector2(400,30),22,GameHud.GOLD)
	respec_text = hud._label(card,"",Vector2(22,58),Vector2(406,82),15)
	respec_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	respec_yes = hud._button(card,"確認退還",Vector2(53,154),Vector2(156,34),_confirm_respec)
	respec_no = hud._button(card,"取消",Vector2(239,154),Vector2(156,34),func() -> void: respec_panel.hide())
	respec_panel.hide()
func _request_respec() -> void:
	var record: CharacterRecord = PartyProgress.selected()
	respec_id = record.persistent_id
	var spent: int = (record.level()-1)*4-record.points()
	respec_text.text = "%s：退還已分配的 %d 點。\n等級、裝備與背包保留；不回滿體力／法力。" % [record.definition.display_name,spent]
	canvas.move_child(respec_panel,canvas.get_child_count()-1)
	respec_panel.show()
func _confirm_respec() -> void:
	director.reset_world_attributes(respec_id)
	respec_panel.hide()

func _build_skills() -> void:
	_section(canvas,Rect2(838,94,416,416))
	hud._label(canvas,"擁有技能 · 點擊查看計算",Vector2(852,104),Vector2(380,26),18,GameHud.GOLD)
	skill_grid = GridContainer.new()
	skill_grid.columns = 4
	skill_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_grid.add_theme_constant_override("h_separation",8)
	skill_grid.add_theme_constant_override("v_separation",8)
	skill_scroll = ScrollContainer.new()
	skill_scroll.position = Vector2(852,140)
	skill_scroll.size = Vector2(384,68)
	skill_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	canvas.add_child(skill_scroll)
	skill_scroll.add_child(skill_grid)
	skill_detail = RichTextLabel.new()
	skill_detail.position = Vector2(852,210)
	skill_detail.size = Vector2(384,262)
	skill_detail.bbcode_enabled = false
	skill_detail.scroll_active = true
	skill_detail.add_theme_font_size_override("normal_font_size",14)
	skill_detail.add_theme_color_override("default_color",GameHud.TEXT)
	canvas.add_child(skill_detail)
	_section(canvas,Rect2(848,381,394,92))
	skill_calculation = RichTextLabel.new()
	skill_calculation.position = Vector2(856,386)
	skill_calculation.size = Vector2(378,80)
	skill_calculation.bbcode_enabled = false
	skill_calculation.add_theme_font_size_override("normal_font_size",14)
	skill_calculation.add_theme_color_override("default_color",GameHud.GOLD)
	canvas.add_child(skill_calculation)
	var labels: Dictionary = {"defense":"防禦", "armor":"物抗 %", "magic_resistance":"法抗 %"}
	for i: int in labels.size():
		var key: String = labels.keys()[i]
		var x: float = 852+i*130
		hud._label(canvas,labels[key],Vector2(x,480),Vector2(44,20),11)
		var input: SpinBox = SpinBox.new()
		input.position = Vector2(x+44,477)
		input.size = Vector2(82,26)
		input.max_value = 10000 if key=="defense" else 90
		input.step = 1
		input.add_theme_font_size_override("font_size",11)
		input.get_line_edit().add_theme_font_size_override("font_size",11)
		canvas.add_child(input)
		input.value_changed.connect(func(_value: float) -> void: _show_skill())
		preview_fields[key] = input

func _build_bag() -> void:
	_section(canvas,Rect2(838,520,416,182))
	hud._label(canvas,"隨身物品 · 點擊裝備／使用",Vector2(852,526),Vector2(386,23),15,GameHud.GOLD)
	for i: int in CharacterRecord.BAG_SIZE:
		var cell: int = i
		var button: Button = hud._button(canvas,"",Vector2(852+(i%5)*78,553+(i/5)*66),Vector2(74,62),func() -> void: director.use_world_item(cell))
		_make_item_slot(button,Vector2(36,36),Vector2(19,3),Vector2(2,40),Vector2(70,20))
		bag_buttons.append(button)
	weight_label = hud._label(canvas,"",Vector2(852,684),Vector2(388,18),11)
	feedback = hud._label(canvas,"",Vector2(174,64),Vector2(164,25),11,GameHud.GOLD)
	feedback.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _make_item_slot(button: Button, extent: Vector2, at: Vector2, label_at: Vector2, label_size: Vector2) -> void:
	var glyph: ItemGlyph = ItemGlyph.new()
	glyph.position = at
	glyph.size = extent
	button.add_child(glyph)
	button.set_meta("glyph",glyph)
	var label: Label = hud._label(button,"",label_at,label_size,11)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.set_meta("label",label)

func refresh(_slot: int) -> void:
	if PartyProgress.selected_slot<roster_buttons.size():
		var parent: Node=roster_buttons[PartyProgress.selected_slot].get_parent().get_parent()
		if parent is ScrollContainer: parent.ensure_control_visible.call_deferred(roster_buttons[PartyProgress.selected_slot])
	var record: CharacterRecord = PartyProgress.selected()
	var stats: Dictionary = record.stats()
	inventory_title.text = "%s    Lv.%d" % [record.definition.display_name,record.level()]
	stat_title.text = record.definition.display_name + " · 能力"
	var next: int = CharacterRecord.CURVE.threshold(mini(100,record.level()+1))
	var current: int = CharacterRecord.CURVE.threshold(record.level())
	xp_label.text = "經驗\n%s / %s\n%s" % [_number(record.experience),_number(next),"Lv.100 已達上限" if record.level()==100 else "距升級 "+_number(next-record.experience)]
	xp_bar.value = 100 if record.level()==100 else 100.0*(record.experience-current)/maxi(1,next-current)
	for key: String in CharacterRecord.ATTRIBUTES:
		(attribute_labels[key] as Label).text = SkillDescription.NAMES[key]+"  "+str(int(stats[key]))
		(plus_buttons[key] as Button).disabled = record.points()<=0
	point_label.text = "剩餘點數  %d" % record.points()
	respec_button.disabled = record.points()==(record.level()-1)*4
	var rows: Array[String] = ["攻擊  %.1f–%.1f" % [stats["attack_min"],stats["attack_max"]],"防禦  %.1f–%.1f" % [stats["defense_min"],stats["defense_max"]],"命中  %.0f–%.0f" % [stats["accuracy_min"],stats["accuracy_max"]],"閃避  %.1f%%" % (stats["evasion"]*100),"暴擊  %.1f%%" % (stats["crit"]*100),"移速  %.1f" % stats["speed"],"體力  %.0f / %.0f" % [record.health,stats["health"]],"法力  %.0f / %.0f" % [record.mana,stats["mana"]],"法抗  %.1f%%" % (stats["magic_resistance"]*100),"物抗  %.1f%%" % (record.definition.armor*100)]
	for i: int in rows.size(): derived_labels[i].text = rows[i]
	portrait.texture = CharacterArt.texture(record.definition)
	for slot: StringName in equipment_buttons:
		_set_item(equipment_buttons[slot],record.equipment[slot],1,"未裝備")
	for i: int in bag_buttons.size(): _set_item(bag_buttons[i],record.bag[i]["item"],record.bag[i]["count"],"空格")
	for i: int in roster_buttons.size():
		roster_buttons[i].visible=i<PartyProgress.records.size()
		if i>=PartyProgress.records.size(): continue
		var member: CharacterRecord = PartyProgress.records[i]
		(roster_buttons[i].get_meta("face") as TextureRect).texture = CharacterArt.texture(member.definition,"portrait")
		(roster_buttons[i].get_meta("label") as Label).text = "%s\nLv.%d" % [member.definition.display_name,member.level()]
		roster_buttons[i].modulate = Color(1,0.87,0.56) if i==PartyProgress.selected_slot else Color(0.75,0.75,0.72)
	weight_label.text = "負重 %.1f / %.0f · 格數 %d" % [record.weight(),record.max_weight,record.bag.size()]
	feedback.text = PartyProgress.last_error
	feedback.tooltip_text = PartyProgress.last_error
	_rebuild_skills(record)
	update_vitals()

func _set_item(button: Button, id: StringName, count: int, empty_caption: String) -> void:
	var glyph: ItemGlyph = button.get_meta("glyph")
	glyph.item_id = id
	glyph.queue_redraw()
	var label: Label = button.get_meta("label")
	var item: GearItemDefinition = ItemCatalog.get_item(id)
	label.text = empty_caption if item==null else item.display_name+("×%d" % count if count>1 else "")
	button.tooltip_text = "空裝備欄位" if item==null else item.tooltip()
	button.disabled = item==null

func _rebuild_skills(record: CharacterRecord) -> void:
	skill_entries = SkillDescription.owned(record)
	var signature: String = record.persistent_id
	for entry: Dictionary in skill_entries: signature += "|"+str(entry["skill"].id)+str(entry["origin"])
	if signature != skill_signature:
		skill_signature = signature
		for button: Button in skill_buttons:
			skill_grid.remove_child(button)
			button.queue_free()
		skill_buttons.clear()
		var found: bool = false
		for entry: Dictionary in skill_entries:
			var skill: SkillDefinition = entry["skill"]
			found = found or skill.id==selected_skill
			var button: Button = Button.new()
			button.custom_minimum_size = Vector2(84,60)
			button.text = skill.display_name
			button.icon = _skill_icon(skill.icon_index)
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.add_theme_constant_override("icon_max_width",38)
			button.add_theme_font_size_override("font_size",10)
			button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
			button.tooltip_text = "查看技能說明（此畫面不施法）"
			button.set_meta("skill_id",skill.id)
			button.pressed.connect(func() -> void: selected_skill=skill.id; skill_detail.scroll_to_line(0); _show_skill())
			skill_grid.add_child(button)
			skill_buttons.append(button)
		if not found: selected_skill = skill_entries[0]["skill"].id if not skill_entries.is_empty() else &""
		var rows: int = maxi(1,ceili(skill_entries.size()/4.0))
		skill_scroll.size.y = mini(rows,2)*68
		skill_detail.position.y = 140+mini(rows,2)*68+8
		skill_detail.size.y = 374-skill_detail.position.y
	_show_skill()

func _skill_icon(index: int) -> AtlasTexture:
	var atlas: Texture2D = preload("res://features/skills/art/icons.png")
	var icon: AtlasTexture = AtlasTexture.new()
	icon.atlas = atlas
	var cell: Vector2 = Vector2(atlas.get_width()/6.0,atlas.get_height()/2.0)
	icon.region = Rect2(Vector2(index%6,index/6)*cell,cell)
	return icon

func _show_skill() -> void:
	var preview: Dictionary = {"defense":(preview_fields["defense"] as SpinBox).value,"armor":(preview_fields["armor"] as SpinBox).value/100,"magic_resistance":(preview_fields["magic_resistance"] as SpinBox).value/100}
	skill_detail.text = "這名兵種目前沒有技能。"
	skill_calculation.text = "沒有可計算的技能。"
	for entry: Dictionary in skill_entries:
		var skill: SkillDefinition = entry["skill"]
		if skill.id==selected_skill:
			skill_detail.text = SkillDescription.describe(skill,PartyProgress.selected().stats(),entry["origin"],preview)
			skill_calculation.text = SkillDescription.calculation(skill,PartyProgress.selected().stats(),preview)
	for button: Button in skill_buttons: button.modulate = Color(1,0.85,0.5) if button.get_meta("skill_id")==selected_skill else Color.WHITE

func update_vitals() -> void:
	if not sheet.visible: return
	var record: CharacterRecord = PartyProgress.selected()
	var values: Dictionary = record.stats()
	var hp: float = record.health
	var mp: float = record.mana
	if director.world_hero != null and record==director.world_hero.character:
		hp = director.world_hero.vitals.health
		mp = director.world_hero.vitals.mana
	vitals_label.text = "HP %.0f / %.0f       MP %.0f / %.0f" % [hp,values["health"],mp,values["mana"]]
	derived_labels[6].text = "體力  %.0f / %.0f" % [hp,values["health"]]
	derived_labels[7].text = "法力  %.0f / %.0f" % [mp,values["mana"]]

func _open(stats: bool) -> void:
	if director.mode!=&"world": return
	# Close competing windows first; close() has no open/reentrant side effects.
	hud.close_windows()
	stat_panel.visible = stats
	inventory_panel.visible = not stats
	stats_tab.modulate = Color(1,0.85,0.5) if stats else Color.WHITE
	inventory_tab.modulate = Color.WHITE if stats else Color(1,0.85,0.5)
	hud.root.move_child(sheet,hud.root.get_child_count()-1)
	sheet.show()
	refresh(PartyProgress.selected_slot)
	if director.voices != null: director.voices.inspect_selected()

func show_stats() -> void: _open(true)
func show_inventory() -> void: _open(false)
func toggle_stats() -> void:
	if sheet.visible and stat_panel.visible: close()
	else: show_stats()
func toggle_inventory() -> void:
	if sheet.visible and inventory_panel.visible: close()
	else: show_inventory()
func close() -> void:
	respec_panel.hide()
	sheet.hide()
	stat_panel.hide()
	inventory_panel.hide()
func _layout() -> void:
	var extent: Vector2 = hud.root.get_viewport().get_visible_rect().size
	var factor: float = minf(extent.x/DESIGN.x,extent.y/DESIGN.y)
	canvas.scale = Vector2.ONE*factor
	canvas.position = (extent-DESIGN*factor)*0.5
func dispose() -> void:
	if PartyProgress.changed.is_connected(refresh): PartyProgress.changed.disconnect(refresh)
	if hud.root.resized.is_connected(_layout): hud.root.resized.disconnect(_layout)
func _number(value: int) -> String:
	var text: String = str(value)
	var result: String = ""
	for i: int in text.length():
		if i>0 and (text.length()-i)%3==0: result += ","
		result += text[i]
	return result
