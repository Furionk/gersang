class_name GameHud
extends CanvasLayer
const GOLD: Color = Color(0.89, 0.76, 0.48)
const TEXT: Color = Color(0.92, 0.88, 0.74)
const DESIGN_SIZE: Vector2 = Vector2(1280, 720)
var director: GameDirector
var root: Control
var title: Label
var details: Label
var log_label: RichTextLabel
var sequence_label: Button
var mode_label: Label
var roster: Array[Button] = []
var roster_images: Array[TextureRect] = []
var log_lines: Array[String] = []
var mini: MiniMap
var world_mini: MiniMap
var countdown: Panel
var countdown_text: Label
var window: Panel
var result: Panel
var settings_panel: Panel
var sequence_panel: Panel
var binding_action: String = ""
var binding_button: Button
var next_refresh: float = 0.0
var disabled_sequence: Array[int] = []
var font: Font
var skill_grid: GridContainer
var skill_buttons: Dictionary = {}
var skill_status: Label
var progression: ProgressionPanels
var world_hud: WorldHud
var item_debug: ItemDebugPanel
var item_debug_launcher: Button
var quick_medicine: Button
var battle_layout: BattleHudLayout
var result_seconds: Label

func _ready() -> void:
	layer = 5
	font=load("res://art/fonts/NotoSansCJKtc-Regular.otf") as FontFile
	root = Control.new()
	root.name = "Interface"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme: Theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = _style(Color(0.11, 0.09, 0.055) if state == "normal" else Color(0.25, 0.21, 0.11) if state != "disabled" else Color(0.08, 0.08, 0.065))
		theme.set_stylebox(state, "Button", style)
	root.theme = theme
	_build()
	battle_layout = BattleHudLayout.new()
	battle_layout.name = "ClassicBattleLayout"
	root.add_child(battle_layout)
	battle_layout.initialize(self)
	var target_cursor:SkillTargetCursor=SkillTargetCursor.new();target_cursor.director=director
	root.add_child(target_cursor)
	world_hud = WorldHud.new()
	world_hud.hud = self
	world_hud.director = director
	root.add_child(world_hud)
	progression = ProgressionPanels.new()
	progression.initialize(self)
	GameSettings.changed.connect(_apply_font_scale)
	if DemoRules.tools_enabled():
		item_debug = ItemDebugPanel.new()
		item_debug.hud = self
		item_debug.service = ItemDebugService.new()
		item_debug.service.director = director
		root.add_child(item_debug)
		item_debug_launcher = _button(root,"隊伍與道具 [F2]",Vector2(156,8),Vector2(140,28),func() -> void: toggle_item_debug())
		item_debug_launcher.name = "OpenItemDebug"
		quick_medicine=_button(root,"使用大補丸",Vector2(304,8),Vector2(170,28),func()->void:
			var service: ItemDebugService=ItemDebugService.new(); service.director=director
			var used: Dictionary=service.perform(DemoRules.SETUP.quick_consumable,"use",service.selected_slot())
			director.message.emit(str(used.reason)))
		quick_medicine.name="UseQuickConsumable"
	director.mode_changed.connect(_mode_changed)

func _mode_changed(_mode: StringName) -> void:
	# Mode boundaries must not depend on the throttled vital/stat refresh timer.
	next_refresh = 0
	_process(0)

func toggle_item_debug() -> void:
	if item_debug == null: return
	if director.mode not in [&"world",&"battle"]:
		director.message.emit("請先返回行旅；倒數、載入及結算中不能修改物品。")
		return
	if not item_debug.visible:
		close_windows()
	item_debug.toggle()
	root.move_child(item_debug,root.get_child_count()-1)

func _exit_tree() -> void:
	if progression != null:
		progression.dispose()

func _style(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color(0.51, 0.43, 0.29)
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 7
	box.content_margin_right = 7
	return box

func _panel(name_text: String, rect: Rect2, color: Color = Color(0.055, 0.051, 0.038, 0.96)) -> Panel:
	var panel: Panel = Panel.new()
	panel.name = name_text
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(color))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	match name_text:
		"Header":
			_pin(panel, Vector2.ZERO, Vector2(1, 0), DESIGN_SIZE)
		"BattleDock":
			_pin(panel, Vector2(0, 1), Vector2.ONE, DESIGN_SIZE)
		"EncounterCountdown", "LiveBattleMenu", "BattleResult", "CombatFeelSettings", "ReservedSkillOrder":
			panel.set_anchors_preset(Control.PRESET_CENTER)
			panel.offset_left = -rect.size.x * 0.5
			panel.offset_top = -rect.size.y * 0.5
			panel.offset_right = rect.size.x * 0.5
			panel.offset_bottom = rect.size.y * 0.5
	return panel

func _pin(control: Control, start: Vector2, end: Vector2, design_parent: Vector2) -> void:
	# Preserve design margins while letting native anchors handle every resize.
	var rect: Rect2 = Rect2(control.position, control.size)
	control.anchor_left = start.x
	control.anchor_top = start.y
	control.anchor_right = end.x
	control.anchor_bottom = end.y
	control.offset_left = rect.position.x - design_parent.x * start.x
	control.offset_top = rect.position.y - design_parent.y * start.y
	control.offset_right = rect.end.x - design_parent.x * end.x
	control.offset_bottom = rect.end.y - design_parent.y * end.y

func _label(parent: Control, content: String, at: Vector2, extent: Vector2, font_size: int = 14, color: Color = TEXT) -> Label:
	var label: Label = Label.new()
	label.text = content
	label.position = at
	label.size = extent
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.set_meta("base_font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Control, content: String, at: Vector2, extent: Vector2, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.text = content
	button.position = at
	button.size = extent
	button.add_theme_font_size_override("font_size", 14)
	button.set_meta("base_font_size", 14)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func _build() -> void:
	var header: Panel = _panel("Header", Rect2(0, 0, 1280, 55), Color(0.075, 0.060, 0.038, 0.97))
	title = _label(header, "絲路商旅", Vector2(24, 5), Vector2(320, 29), 24, GOLD)
	mode_label = _label(header, "戰鬥手感試玩", Vector2(26, 33), Vector2(410, 20), 12)
	for i: int in 3:
		var index: int = i
		_button(header, ["草原", "山道", "洞窟"][i], Vector2(730 + i * 91, 10), Vector2(83, 34), func() -> void: director.start_battle.call_deferred(Catalog.encounters()[index]))
	_button(header, "壓力測試", Vector2(1007, 10), Vector2(105, 34), func() -> void: director.start_battle.call_deferred(Catalog.encounters()[0], true))
	_button(header, "設定", Vector2(1118, 10), Vector2(68, 34), show_settings)
	_button(header, "選單", Vector2(1192, 10), Vector2(73, 34), toggle_menu)
	var frame: Panel = _panel("MercenaryRoster", Rect2(12, 67, 118, 455))
	for i: int in MercenaryRoster.ACTIVE_CAPACITY:
		var slot: int = i
		var button: Button = _button(frame, "", Vector2(5, 6 + i * 44), Vector2(108, 42), func() -> void: _roster_select(slot))
		var image: TextureRect = TextureRect.new()
		image.position = Vector2(1, 1)
		image.size = Vector2(53, 57)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(image)
		var data: UnitDefinition = DemoRules.SETUP.active[i]
		image.texture = CharacterArt.texture(data,"portrait")
		_label(button, "%d\n%s" % [i + 1, data.display_name], Vector2(55, 6), Vector2(51, 48), 11, GOLD)
		roster.append(button)
		roster_images.append(image)
	var dock: Panel = _panel("BattleDock", Rect2(0, 530, 1280, 190), Color(0.095, 0.081, 0.054, 0.98))
	_label(dock, "行軍圖", Vector2(16, 3), Vector2(185, 18), 12, GOLD)
	mini = MiniMap.new()
	mini.director = director
	mini.position = Vector2(14, 25)
	mini.size = Vector2(185, 124)
	mini.located.connect(func(p: Vector2) -> void: director.camera.position = p)
	dock.add_child(mini)
	details = _label(dock, "正在準備商團……", Vector2(218, 16), Vector2(258, 135), 14)
	var log_panel: Panel = Panel.new()
	log_panel.position = Vector2(474, 10)
	log_panel.size = Vector2(423, 143)
	log_panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.027, 0.024, 0.9)))
	dock.add_child(log_panel)
	_label(log_panel, "行旅紀錄 / 戰鬥訊息", Vector2(10, 7), Vector2(400, 19), 12, GOLD)
	log_label = RichTextLabel.new()
	log_label.position = Vector2(10, 28)
	log_label.size = Vector2(400, 106)
	log_label.scroll_active = true
	log_label.scroll_following = true
	log_label.bbcode_enabled = false
	log_label.add_theme_font_override("normal_font", font)
	log_label.add_theme_font_size_override("normal_font_size", 12)
	log_label.add_theme_color_override("default_color", TEXT)
	log_label.set_meta("base_font_size", 12)
	log_panel.add_child(log_label)
	for i: int in 4:
		var action: StringName = [&"command_move", &"command_stop", &"command_attack", &"command_hold"][i]
		var kind: String = ["移動", "停止", "攻擊", "駐守"][i]
		var button: Button = _button(dock, "%s %s" % [GameSettings.key_label(action), kind], Vector2(910 + i * 88, 7), Vector2(81, 31), func() -> void: _command_button(action))
		button.set_meta("action", action)
		button.set_meta("caption", kind)
	skill_grid = GridContainer.new()
	skill_grid.name = "SelectedUnitSkills"
	skill_grid.columns = 6
	skill_grid.position = Vector2(910, 44)
	skill_grid.add_theme_constant_override("h_separation", 4)
	skill_grid.add_theme_constant_override("v_separation", 3)
	dock.add_child(skill_grid)
	skill_status = _label(dock, "選取單位查看技能", Vector2(914, 55), Vector2(338, 80), 14, GOLD)
	sequence_label = _button(dock, "E 預約 ▸", Vector2(910, 162), Vector2(345, 24), show_sequence)
	sequence_label.clip_text = true
	sequence_label.add_theme_font_size_override("font_size", 12)
	sequence_label.set_meta("base_font_size", 12)
	sequence_label.size = Vector2(345, 24)
	world_mini = MiniMap.new()
	world_mini.name = "CircularWorldMap"
	world_mini.director = director
	world_mini.circular = true
	world_mini.position = Vector2(1070, 68)
	world_mini.size = Vector2(192, 192)
	root.add_child(world_mini)
	_pin(world_mini, Vector2(1, 0), Vector2(1, 0), DESIGN_SIZE)
	for child: Node in header.get_children():
		if child is Button:
			_pin(child as Control, Vector2(1, 0), Vector2(1, 0), DESIGN_SIZE)
	for child: Node in dock.get_children():
		if child is Control and (child as Control).position.x >= 900:
			_pin(child as Control, Vector2(1, 0), Vector2(1, 0), Vector2(1280, 190))
	_pin(log_panel, Vector2.ZERO, Vector2(1, 0), Vector2(1280, 190))
	_pin(log_label, Vector2.ZERO, Vector2(1, 0), Vector2(423, 143))
	countdown = _panel("EncounterCountdown", Rect2(420, 16, 440, 86), Color(0.03, 0.025, 0.019, 0.78))
	countdown.set_anchors_preset(Control.PRESET_CENTER_TOP)
	countdown.offset_left = -220
	countdown.offset_right = 220
	countdown.offset_top = 16
	countdown.offset_bottom = 102
	countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_text = _label(countdown, "", Vector2(16, 8), Vector2(408, 70), 18, GOLD)
	countdown_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown.hide()

func _roster_select(slot: int) -> void:
	if director.selection == null:
		director.select_world_slot(slot, true)
		return
	var ids: Array[int] = director.roster_ids
	if slot < ids.size():
		director.selection.select_ids([ids[slot]], Input.is_action_pressed("modifier_shift"), true)

func _command_button(action: StringName) -> void:
	if director.mode != &"battle" or director.selection == null:
		if director.mode == &"world" and progression != null:
			if action == &"command_stop":
				progression.toggle_stats()
			elif action == &"command_attack":
				progression.toggle_inventory()
			elif action == &"command_move":
				progression.close()
		return
	if action == &"command_stop":
		director.selection.dispatch("stop", Vector2.ZERO)
	elif action == &"command_hold":
		director.selection.dispatch("hold", Vector2.ZERO)
	else:
		director.selection.arm(action, Input.is_action_pressed("modifier_ctrl"))

func _process(_delta: float) -> void:
	root.visible = not (director.mode == &"battle" and is_instance_valid(director.action_battle))
	if not root.visible: return
	if result_seconds!=null and is_instance_valid(result_seconds) and director.result_flow.stage==BattleResultFlow.Stage.BANNER:
		result_seconds.text = "%d 秒後返回大地圖 · 左鍵立即返回" % director.result_flow.seconds_left()
	if item_debug_launcher != null:
		item_debug_launcher.position = Vector2(70,53) if director.mode==&"battle" else Vector2(156,8)
		item_debug_launcher.visible = director.mode in [&"world",&"battle"] and (world_hud == null or world_hud.map_panel == null or not world_hud.map_panel.visible)
		quick_medicine.visible=item_debug_launcher.visible
		quick_medicine.position=Vector2(70,90) if director.mode==&"battle" else Vector2(156,60)
	if Time.get_ticks_msec() * 0.001 < next_refresh:
		return
	next_refresh = Time.get_ticks_msec() * 0.001 + 0.12
	var in_world: bool = director.mode in [&"world", &"countdown"]
	world_hud.visible = in_world
	(root.get_node("Header") as Control).hide()
	(root.get_node("MercenaryRoster") as Control).hide()
	(root.get_node("BattleDock") as Control).visible = director.mode in [&"battle",&"results"]
	battle_layout.refresh()
	world_mini.hide()
	if in_world:
		world_hud.refresh()
		if progression != null: progression.update_vitals()
		return
	mini.queue_redraw()
	world_mini.queue_redraw()
	var in_battle: bool = director.mode == &"battle"
	sequence_label.visible = in_battle
	skill_status.text = "選取單位查看技能" if in_battle else "S 能力 · I 背包\n經驗、能力、裝備永久保存"
	for child: Node in root.get_node("BattleDock").get_children():
		if child is Button and child.has_meta("action"):
			var action: String = str(child.get_meta("action"))
			var button: Button = child as Button
			button.disabled = not in_battle and action == "command_hold"
			button.text = "%s %s" % [GameSettings.key_label(action),child.get_meta("caption")] if in_battle else {"command_move":"M 行旅","command_stop":"S 能力","command_attack":"I 背包","command_hold":"戰鬥限定"}.get(action,"")
	title.text = "絲路商旅   " + (director.encounter.display_name if in_battle and director.encounter != null else "青嶺道")
	mode_label.text = "戰鬥 %02d:%02d  友 %d / 敵 %d" % [int(director.time_in_battle) / 60, int(director.time_in_battle) % 60, director.living_ids(0).size(), director.living_ids(1).size()] if in_battle else "高清等角・左鍵行旅・點怪進戰"
	if in_battle and director.cursor_guard != null: mode_label.text += "  F1："+("鎖定" if director.cursor_guard.enabled else "自由")
	if director.selection != null:
		_update_skill_availability()
		var selected: Array[int] = director.selection.selected_ids
		if not selected.is_empty():
			var unit: TacticalUnit = director.get_unit(selected[0])
			if unit != null:
				var state_label: String = {"idle": "待命", "move": "移動", "chase": "追擊", "blocked": "受阻重試", "attack": "攻擊", "cast": "施法", "hold": "駐守", "controlled": "受制", "dead": "倒下"}.get(String(unit.fsm.current), String(unit.fsm.current))
				var live_stats: Dictionary=unit.stats_snapshot()
				details.text = "%s Lv.%d · %d人\nHP %d/%d\nMP %d/%d\n攻 %.0f–%.0f  防 %.0f–%.0f" % [unit.definition.display_name,live_stats["level"],selected.size(),unit.vitals.health,unit.vitals.max_health,unit.vitals.mana,unit.vitals.max_mana,live_stats["attack_min"],live_stats["attack_max"],live_stats["defense_min"],live_stats["defense_max"]]
				details.tooltip_text = "狀態："+state_label+"\nCtrl＋數字編隊 / Tab 全選"
		else:
			details.text = "尚未選兵\n左鍵單選 / 拖框多選\nShift 加選\n右鍵移動 / 指定攻擊"
		sequence_label.text = "%s 準備下一位：%s ▸" % [GameSettings.key_label("sequence_cast"), director.selection.next_sequence_label()]
		var ids: Array[int] = director.roster_ids
		for i: int in roster.size():
			roster[i].visible=i<ids.size()
			roster[i].modulate = Color.WHITE if i < ids.size() and director.get_unit(ids[i]).alive() else Color(0.35, 0.35, 0.35)
	else:
		if not skill_buttons.is_empty():
			on_skill_selection([])
		var member: CharacterRecord = PartyProgress.selected()
		details.text = "%s  Lv.%d\n經驗 %d\nS：能力 / I：背包\n左鍵移動 / 點怪進戰\n1–9／0 或肖像選兵" % [member.definition.display_name,member.level(),member.experience]
		for i: int in roster.size():
			roster[i].visible=i<PartyProgress.records.size()
			if i>=PartyProgress.records.size(): continue
			roster[i].modulate = Color(1.0,0.86,0.54) if i == PartyProgress.selected_slot else Color.WHITE
			roster_images[i].texture = CharacterArt.texture(PartyProgress.records[i].definition,"portrait")
			roster[i].tooltip_text = "%s Lv.%d" % [PartyProgress.records[i].definition.display_name,PartyProgress.records[i].level()]
	if progression != null:
		progression.update_vitals()


func on_skill_selection(_ids: Array[int]) -> void:
	if skill_grid == null:
		return
	for child: Node in skill_grid.get_children():
		skill_grid.remove_child(child)
		child.queue_free()
	skill_buttons.clear()
	var entries: Array[Dictionary] = []
	if director.selection != null:
		entries = director.selection.visible_skills()
	skill_status.visible = entries.is_empty()
	if director.mode not in [&"battle", &"loading"]:
		return
	var icons: Texture2D = load("res://features/skills/art/icons.png") as Texture2D
	var cell: Vector2 = Vector2(icons.get_width() / 6.0, icons.get_height() / 2.0)
	for entry: Dictionary in entries:
		var skill: SkillDefinition = entry["skill"]
		var button: SkillCommandButton = SkillCommandButton.new()
		button.name = "Skill_%s" % skill.id
		button.custom_minimum_size = Vector2(76, 64)
		button.clip_contents = true
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.add_theme_stylebox_override("normal",battle_layout.button_skin)
		skill_grid.add_child(button)
		var image: TextureRect = TextureRect.new()
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = icons
		atlas.region = Rect2(Vector2(skill.icon_index % 6, skill.icon_index / 6) * cell, cell)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture = atlas
		image.position = Vector2(18, 3)
		image.size = Vector2(40, 40)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(image)
		button.set_meta("icon",image)
		var label: Label = _label(button, "", Vector2(0, 46), Vector2(76, 18), 11, GOLD)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.set_meta("label", label)
		var badge:Label=_label(button,"",Vector2(4,1),Vector2(60,23),17,Color.WHITE)
		badge.add_theme_color_override("font_shadow_color",Color.BLACK)
		badge.add_theme_constant_override("shadow_offset_x",1);badge.add_theme_constant_override("shadow_offset_y",1)
		button.set_meta("key",badge)
		var id: StringName = skill.id
		button.pressed.connect(func() -> void: director.selection.activate_skill(id, Input.is_action_pressed("modifier_ctrl")))
		button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
				if director.selection.toggle_autocast(id): _update_skill_availability()
				button.accept_event())
		skill_buttons[id] = button
	_update_skill_availability()
	if battle_layout!=null:
		battle_layout._layout()
		battle_layout.refresh()

func _update_skill_availability() -> void:
	if director.selection == null:
		return
	var conflicts:Dictionary=director.selection.conflicting_skills()
	var short_names: Dictionary = {"critical":"一擊", "quake":"地震", "blast":"暴雷", "wheel":"車輪", "dragon":"火龍", "summon":"箭魂", "ice_wall":"冰牆", "lightning":"雷擊", "heal":"恢復", "supply":"補給", "control":"縛魂", "earth_stakes":"地樁", "earth_claw":"魔爪", "ninja_stealth":"迷蹤", "ninja_fire_trail":"火徑", "ninja_chain":"導雷", "teppo_sniper":"狙擊", "teppo_comrades":"鐵眾", "teppo_triple":"三段"}
	for entry: Dictionary in director.selection.visible_skills():
		var skill: SkillDefinition = entry["skill"]
		var button: SkillCommandButton = skill_buttons.get(skill.id)
		if button == null:
			continue
		# Unavailable manual skills stay clickable so attempts receive an explanation.
		button.disabled = not skill.manual()
		var label: Label = button.get_meta("label")
		var suffix: String = GameSettings.key_label(String(skill.action)) if skill.manual() else "自動" if skill.trigger == SkillDefinition.Trigger.AUTO_SUPPORT else "被動"
		if skill.manual() and int(entry["ready"]) == 0 and float(entry["cooldown"]) > 0:
			suffix = "%.1fs" % float(entry["cooldown"])
		label.text = str(short_names.get(String(skill.id), skill.display_name.left(2)))
		var badge:Label=button.get_meta("key")
		badge.text=suffix if skill.manual() else ""
		button.conflicted=conflicts.has(skill.id)
		badge.add_theme_color_override("font_color",Color(1,0.25,0.23) if button.conflicted else Color.WHITE)
		button.armed=director.selection.armed_skill_id==skill.id
		button.auto_mode=0
		button.add_theme_stylebox_override("normal",_style(Color(0.26,0.07,0.05)) if button.conflicted else battle_layout.button_skin)
		if skill.supports_autocast():
			var count: int = int(entry["autocast"])
			var state: String = "自動" if count==entry["owners"].size() else "混合" if count>0 else "手動"
			label.text = "%s %s" % [short_names.get(String(skill.id),skill.display_name.left(2)),state]
			button.auto_mode=2 if count==entry["owners"].size() else 1 if count>0 else 0
		var lacks_mana:bool=int(entry["ready"])==0 and str(entry["reason"])=="法力不足"
		if lacks_mana:label.text="法力不足"
		label.add_theme_color_override("font_color",Color(1,0.45,0.3) if lacks_mana else GOLD)
		(button.get_meta("icon") as TextureRect).modulate=Color(0.6,0.65,0.8) if lacks_mana else Color.WHITE
		button.tooltip_text = "%s\nMP %.0f | 冷卻 %.2fs\n可用 %d/%d 人\n公式：(%s) × %.2f\n%s\n%s" % [skill.display_name, skill.mana_cost, skill.cooldown, entry["ready"], entry["owners"].size(), skill.damage_formula,skill.formula_multiplier,skill.description, str(entry["reason"]) if int(entry["ready"]) == 0 else "點擊或快捷鍵使用"]
		if button.conflicted:button.tooltip_text="快捷鍵衝突：請到使用者設定變更；仍可點此圖示使用。\n"+button.tooltip_text
		button.queue_redraw()
		if skill.trigger == SkillDefinition.Trigger.ATTACK_HIT:
			button.tooltip_text += "\n普攻觸發機率 %.0f%%" % (skill.proc_chance * 100.0)
		if skill.manual(): button.tooltip_text += "\n快捷鍵："+GameSettings.key_label(String(skill.action))+("：立即施放（自身）" if skill.instant_self_activation and skill.target_mode==SkillDefinition.Target.SELF else " → 左鍵確認")
		if skill.supports_autocast(): button.tooltip_text += "\n左鍵準備指定友軍；右鍵切換自動施法（僅周遭友軍）"

func log_message(content: String) -> void:
	log_lines.append(content)
	if log_lines.size() > 5:
		log_lines.pop_front()
	if log_label != null:
		log_label.text = "\n".join(log_lines)
	if world_hud != null:
		world_hud.append_message(content)

func show_countdown(seconds: int, encounter_name: String) -> void:
	if not countdown.visible:
		# A world encounter may begin while reviewing a full-screen character.
		# Yield modal ownership once, not on every fixed countdown update.
		close_windows()
		root.move_child(countdown,root.get_child_count()-1)
	countdown.show()
	countdown_text.text = "%s · %d 秒後進戰" % [encounter_name, maxi(1, seconds)]
func hide_countdown() -> void:
	countdown.hide()
func is_modal_open() -> bool:
	return (progression != null and progression.sheet.visible) or (item_debug != null and item_debug.visible) or (window != null and window.visible) or (settings_panel != null and settings_panel.visible) or (sequence_panel != null and sequence_panel.visible) or (result != null and result.visible) or (world_hud != null and world_hud.is_modal())
## Close only dismissible UI, in its actual scene-tree drawing order.
func close_top_window() -> bool:
	var panels: Array[Control] = [window, settings_panel, sequence_panel, item_debug]
	if progression != null:
		panels.append(progression.sheet)
		panels.append(progression.respec_panel)
	if world_hud != null:
		panels.append_array([world_hud.map_panel, world_hud.info_panel, world_hud.standee_panel])
	var top: Control = null
	for panel: Control in panels:
		if is_instance_valid(panel) and panel.is_visible_in_tree():
			if top == null or panel.is_greater_than(top):
				top = panel
	if top == null: return false
	if top == settings_panel:
		GameSettings.save_settings()
		binding_action = ""
	if progression != null and top == progression.sheet:
		progression.close()
	else:
		top.hide()
	return true

func close_windows() -> void:
	if item_debug != null: item_debug.hide()
	if world_hud != null: world_hud.close_windows()
	if progression != null:
		progression.close()
	for panel: Panel in [window, result, settings_panel, sequence_panel]:
		if panel != null:
			panel.hide()
	binding_action = ""
	hide_countdown()

func toggle_menu() -> void:
	if window != null:
		window.visible = not window.visible
		return
	window = _panel("LiveBattleMenu", Rect2(478, 125, 326, 450))
	_label(window, "行旅選單", Vector2(20, 14), Vector2(286, 31), 23, GOLD)
	_label(window, "選單開啟時戰鬥仍會繼續", Vector2(20, 52), Vector2(286, 24), 13)
	_button(window, "繼續 [X]", Vector2(20, 90), Vector2(286, 38), func() -> void: window.hide())
	_button(window, "手感 / 快捷鍵設定", Vector2(20, 137), Vector2(286, 38), func() -> void: window.hide(); show_settings())
	_button(window, "預約技能順序", Vector2(20, 184), Vector2(286, 38), func() -> void: window.hide(); show_sequence())
	_button(window, "撤退", Vector2(20, 231), Vector2(286, 38), func() -> void: director.retreat(); window.hide())
	_button(window, "返回行旅地圖", Vector2(20, 278), Vector2(286, 38), func() -> void: director.start_world.call_deferred())
	_label(window,"測試戰場（不使用正式遭遇快照）",Vector2(20,326),Vector2(286,20),12)
	for i: int in 3:
		var index: int = i
		var arena_button: Button = _button(window,["草原","山道","洞窟"][i],Vector2(20+i*96,355),Vector2(90,30),func() -> void: director.start_battle.call_deferred(Catalog.encounters()[index]))
		arena_button.disabled = not director.battle_snapshot.is_empty()
	var stress_button: Button = _button(window,"12 對 60 壓力測試",Vector2(20,395),Vector2(286,30),func() -> void: director.start_battle.call_deferred(Catalog.encounters()[0],true))
	stress_button.disabled = not director.battle_snapshot.is_empty()

func show_result(outcome: String) -> void:
	close_windows()
	if result != null:
		root.remove_child(result)
		result.queue_free()
	var pending: bool = not director.battle_snapshot.is_empty() and director.world_context.state["active_encounter"].get("state","") == "SETTLING"
	if outcome=="victory" and not pending:
		result = _panel("BattleResult",Rect2(460,238,360,152),Color(0,0,0,0))
		result.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		var scroll: VictoryScroll = VictoryScroll.new()
		scroll.position = Vector2(10,0)
		scroll.size = Vector2(340,96)
		result.add_child(scroll)
		var reward: Label = _label(result,"每名隊員約獲得 %d 經驗" % director.reward_each if not director.stress else "壓力測試不發放經驗",Vector2(0,102),Vector2(360,20),12)
		reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result_seconds = _label(result,"3 秒後返回大地圖 · 左鍵立即返回",Vector2(0,128),Vector2(360,22),13,GOLD)
		result_seconds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return
	result = _panel("BattleResult", Rect2(420, 168, 440, 306))
	_label(result, {"victory": "戰鬥勝利", "defeat": "商團戰敗", "retreat": "商團撤退"}.get(outcome, outcome), Vector2(26, 21), Vector2(388, 42), 30, GOLD)
	_label(result, "結算未保存；尚未領取獎勵。\n請重試保存，或保留 checkpoint 下次恢復。" if pending else "Lv.100 養成試玩 · 結算已完成\n%s" % ("每名隊員約獲得 %d 經驗" % director.reward_each if outcome == "victory" and not director.stress else "壓力測試／失敗／撤退不給經驗"), Vector2(26, 86), Vector2(388, 60), 15)
	_button(result, "重試保存" if pending else "返回後再接戰" if not director.battle_snapshot.is_empty() else "重新挑戰", Vector2(26, 172), Vector2(186, 50), func() -> void:
		if not director.battle_snapshot.is_empty(): director.start_world.call_deferred()
		else: director.start_battle.call_deferred(director.encounter, director.stress))
	_button(result, "返回行旅", Vector2(228, 172), Vector2(186, 50), func() -> void: director.start_world.call_deferred())

func show_settings() -> void:
	if settings_panel != null:
		root.remove_child(settings_panel)
		settings_panel.queue_free()
	settings_panel = _panel("CombatFeelSettings", Rect2(272, 76, 738, 544))
	_label(settings_panel, "操作與手感設定", Vector2(19, 14), Vector2(500, 34), 25, GOLD)
	_label(settings_panel, "以下為可調測試值；尚未量測原作時序。", Vector2(19, 51), Vector2(660, 24), 13)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(18, 90)
	scroll.size = Vector2(412, 385)
	settings_panel.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size.x = 394
	column.add_theme_constant_override("separation", 9)
	scroll.add_child(column)
	var labels: Array[String] = ["移速倍率", "轉向速度", "索敵倍率", "攻擊前搖", "施法倍率", "連射間隔", "碰撞半徑", "鏡頭速度", "停止後索敵", "GUI 字體倍率"]
	var mins: Array[float] = [0.4, 2.0, 0.25, 0.08, 0.15, 0.1, 5.0, 100.0, 0.05, 0.8]
	var maxs: Array[float] = [2.5, 30.0, 2.0, 0.9, 2.0, 1.5, 22.0, 1400.0, 2.0, 1.4]
	for i: int in 10:
		var field: String = GameSettings.PROFILE_FIELDS[i]
		if field=="repeat_interval": continue # obsolete, never an artificial skill CD
		var row: HBoxContainer = HBoxContainer.new()
		row.custom_minimum_size.y = 29
		column.add_child(row)
		var label: Label = Label.new()
		label.text = labels[i]
		label.custom_minimum_size.x = 118
		row.add_child(label)
		var slider: HSlider = HSlider.new()
		slider.min_value = mins[i]
		slider.max_value = maxs[i]
		slider.step = 0.01 if maxs[i] < 3.0 else 0.5
		slider.value = float(GameSettings.profile.get(field))
		slider.custom_minimum_size.x = 190
		row.add_child(slider)
		var value_label: Label = Label.new()
		value_label.text = "%.2f" % slider.value
		value_label.custom_minimum_size.x = 66
		row.add_child(value_label)
		slider.value_changed.connect(func(value: float) -> void: GameSettings.set_feel(field, value); value_label.text = "%.2f" % value)
	for field: String in ["sequence_enabled"]:
		var check: CheckButton = CheckButton.new()
		check.text = "E 依序準備技能（仍需左鍵確認）"
		check.button_pressed = bool(GameSettings.profile.get(field))
		column.add_child(check)
		check.toggled.connect(func(enabled: bool) -> void: GameSettings.set_feel(field, enabled))
	var voice_label: Label = Label.new()
	voice_label.text = "兵種語音音量"
	column.add_child(voice_label)
	var voice_slider: HSlider = HSlider.new()
	voice_slider.name = "UnitVoiceVolume"
	voice_slider.min_value = 0.0
	voice_slider.max_value = 1.0
	voice_slider.step = 0.01
	voice_slider.value = GameSettings.unit_voice_volume
	column.add_child(voice_slider)
	voice_slider.value_changed.connect(func(value: float) -> void: GameSettings.set_unit_voice(value, GameSettings.unit_voice_muted))
	var voice_mute: CheckButton = CheckButton.new()
	voice_mute.name = "UnitVoiceMute"
	voice_mute.text = "兵種語音靜音"
	voice_mute.button_pressed = GameSettings.unit_voice_muted
	column.add_child(voice_mute)
	voice_mute.toggled.connect(func(value: bool) -> void: GameSettings.set_unit_voice(GameSettings.unit_voice_volume, value))
	var ui_label:Label=Label.new();ui_label.text="技能操作回饋音量";column.add_child(ui_label)
	var ui_volume:HSlider=HSlider.new();ui_volume.min_value=0;ui_volume.max_value=1;ui_volume.step=0.01;ui_volume.value=GameSettings.ui_feedback_volume;column.add_child(ui_volume)
	ui_volume.value_changed.connect(func(value:float)->void:GameSettings.set_ui_audio(value,GameSettings.ui_feedback_muted))
	var ui_mute:CheckButton=CheckButton.new();ui_mute.text="技能操作回饋靜音";ui_mute.button_pressed=GameSettings.ui_feedback_muted;column.add_child(ui_mute)
	ui_mute.toggled.connect(func(value:bool)->void:GameSettings.set_ui_audio(GameSettings.ui_feedback_volume,value))
	var trials_label: Label = Label.new()
	trials_label.text = "試玩入口（設定列表下方）"
	column.add_child(trials_label)
	var trials: HBoxContainer = HBoxContainer.new()
	column.add_child(trials)
	for i: int in 3:
		var index: int = i
		var trial: Button = Button.new()
		trial.name = "WorldTrial_%d" % i
		trial.text = ["草原","山道","洞窟"][i]
		trial.custom_minimum_size = Vector2(119,30)
		trials.add_child(trial)
		trial.pressed.connect(func() -> void: director.start_battle.call_deferred(Catalog.encounters()[index]))
	var stress_trial: Button = Button.new()
	stress_trial.name = "WorldTrial_Stress"
	stress_trial.text = "十二對六十壓力測試（不保存養成獎勵）"
	column.add_child(stress_trial)
	stress_trial.pressed.connect(func() -> void: director.start_battle.call_deferred(Catalog.encounters()[0],true))
	var keys: Array[String] = ["command_move", "command_attack", "command_stop", "command_hold", "sequence_cast", "select_all"]
	for key: String in GameSettings.skill_labels:
		keys.append(key)
	var key_scroll: ScrollContainer = ScrollContainer.new()
	key_scroll.position = Vector2(449, 88)
	key_scroll.size = Vector2(270, 385)
	settings_panel.add_child(key_scroll)
	var key_body: Control = Control.new()
	key_body.custom_minimum_size = Vector2(250, keys.size() * 37)
	key_scroll.add_child(key_body)
	for i: int in keys.size():
		var action: String = keys[i]
		var caption: String = str(GameSettings.skill_labels.get(action, GameSettings.ACTION_LABELS.get(action, "預約" if action == "sequence_cast" else "全選")))
		var button: Button = _button(key_body, "%s : %s" % [caption, GameSettings.key_label(action)], Vector2(0, i * 37), Vector2(250, 32), func() -> void: _request_binding(action))
		button.set_meta("binding", action)
		if GameSettings.skill_defaults.has(action):
			var reset: Button = _button(key_body,"跟隨資源",Vector2(170,i*37),Vector2(80,32),func() -> void: GameSettings.reset_skill_binding(action); show_settings())
			button.size.x=164
			reset.tooltip_text="取消此技能的玩家自訂鍵，重新使用技能 .tres 的 Default Key。"
	_button(settings_panel, "恢復預設", Vector2(20, 492), Vector2(150, 34), func() -> void: GameSettings.reset_defaults(); show_settings())
	_button(settings_panel, "儲存並關閉 [X]", Vector2(557, 492), Vector2(162, 34), func() -> void: GameSettings.save_settings(); settings_panel.hide(); binding_action = "")
	_apply_font_scale()

func _request_binding(action: String) -> void:
	binding_action = action
	for child: Node in settings_panel.find_children("*", "Button", true, false):
		if child is Button and child.get_meta("binding", "") == action:
			binding_button = child as Button
			binding_button.text = "請按新鍵（X 取消）"

func _input(event: InputEvent) -> void:
	if director.mode == &"battle" and is_instance_valid(director.action_battle): return
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if event.pressed and not event.echo and code in [KEY_X, KEY_ESCAPE]:
			if binding_action != "":
				binding_button.text = "%s : %s" % [binding_action, GameSettings.key_label(binding_action)]
				binding_action = ""
				get_viewport().set_input_as_handled()
				return
			if close_top_window():
				director.audio.feedback("cancel")
				get_viewport().set_input_as_handled()
				return
			var focus:Control=get_viewport().gui_get_focus_owner()
			if code==KEY_X and director.mode in [&"world",&"battle"] and not (focus is LineEdit or focus is TextEdit):
				if director.selection!=null:director.selection.cancel()
				toggle_menu();director.audio.feedback("confirm")
				get_viewport().set_input_as_handled();return
	if director.mode==&"results" and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and director.result_flow.stage in [BattleResultFlow.Stage.HOLD,BattleResultFlow.Stage.BANNER,BattleResultFlow.Stage.RETURNING]:
		director.result_flow.request_return()
		get_viewport().set_input_as_handled()
		return
	if binding_action == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: InputEventKey = event
	if key.physical_keycode != KEY_ESCAPE:
		if not GameSettings.rebind(binding_action, key.physical_keycode):
			log_message("數字、方向鍵與修飾鍵保留給編隊／鏡頭，請選另一個鍵。")
	binding_button.text = "%s : %s" % [binding_action, GameSettings.key_label(binding_action)]
	binding_action = ""
	get_viewport().set_input_as_handled()

func _apply_font_scale() -> void:
	_scale_children(root)
func _scale_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is Control and child.has_meta("base_font_size"):
			child.add_theme_font_size_override("normal_font_size" if child is RichTextLabel else "font_size", int(float(child.get_meta("base_font_size")) * GameSettings.profile.ui_scale))
		if child is Button and child.has_meta("action"):
			child.text = "%s %s" % [GameSettings.key_label(String(child.get_meta("action"))), child.get_meta("caption")]
		_scale_children(child)

func show_sequence() -> void:
	if director.selection == null:
		log_message("請先進入戰場再設定預約技能。")
		return
	if sequence_panel != null:
		root.remove_child(sequence_panel)
		sequence_panel.queue_free()
	director.selection._ensure_sequence()
	sequence_panel = _panel("ReservedSkillOrder", Rect2(415, 100, 470, 495))
	_label(sequence_panel, "E 技能準備順序", Vector2(20, 16), Vector2(420, 32), 24, GOLD)
	_label(sequence_panel, "按 E 準備下一位，再左鍵確認施法。", Vector2(20, 55), Vector2(420, 25), 14)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(20, 90)
	scroll.size = Vector2(430, 330)
	sequence_panel.add_child(scroll)
	var slots: Array[Dictionary] = director.selection.sequence_entries
	var body: Control = Control.new()
	body.custom_minimum_size = Vector2(412, slots.size() * 42)
	scroll.add_child(body)
	for i: int in slots.size():
		var entry: Dictionary = slots[i]
		var unit: TacticalUnit = director.get_unit(int(entry["unit"]))
		var slot: int = i
		var skill: SkillDefinition = entry["skill"]
		_label(body, "%d. %s·%s" % [i + 1, unit.definition.display_name if unit != null else "失效", skill.display_name], Vector2(0, i * 42), Vector2(302, 35), 13)
		_button(body, "↑", Vector2(310, i * 42), Vector2(44, 35), func() -> void: _move_sequence(slot, -1))
		_button(body, "↓", Vector2(364, i * 42), Vector2(44, 35), func() -> void: _move_sequence(slot, 1))
	_button(sequence_panel, "關閉 [X]", Vector2(328, 442), Vector2(120, 38), func() -> void: sequence_panel.hide())
func _move_sequence(index: int, direction: int) -> void:
	var slots: Array[Dictionary] = director.selection.sequence_entries
	var target: int = clampi(index + direction, 0, slots.size() - 1)
	var old: Dictionary = slots[index]
	slots[index] = slots[target]
	slots[target] = old
	director.selection.sequence_slots.clear()
	for entry: Dictionary in slots:
		director.selection.sequence_slots.append(int(entry["unit"]))
	director.selection.sequence_index = 0
	show_sequence()
