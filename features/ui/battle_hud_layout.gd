class_name BattleHudLayout
extends Control
## Classic battle-only chrome; all input/skills still go through GameHud/SelectionController.
var hud: GameHud
var info: Panel
var face: TextureRect
var mini_frame: Panel
var commands_frame: Panel
var settings_button: Button
var menu_button: Button
var group_button: Button
var slots: Array[Panel] = []
var skill_scroll:ScrollContainer
var skill_heading:Label
var button_skin: StyleBoxFlat
func inset(parent: Panel) -> Panel:
	var panel: Panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 12
	panel.offset_top = 12
	panel.offset_right = -12
	panel.offset_bottom = -12
	var black: StyleBoxFlat = ClassicSkin.inset_style()
	black.bg_color = Color(0.018,0.021,0.018)
	panel.add_theme_stylebox_override("panel",black)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	parent.move_child(panel,0)
	return panel
func frame(parent: Control, name_text: String) -> Panel:
	var panel: Panel = Panel.new()
	panel.name = name_text
	panel.add_theme_stylebox_override("panel",ClassicSkin.panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	return panel
func initialize(owner: GameHud) -> void:
	hud = owner
	button_skin = ClassicSkin.inset_style()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dock: Panel = hud.root.get_node("BattleDock")
	dock.offset_top = -148
	dock.add_theme_stylebox_override("panel",ClassicSkin.inset_style())
	mini_frame = frame(dock,"BattleMiniFrame")
	mini_frame.position = Vector2.ZERO
	mini_frame.size = Vector2(256,148)
	hud.mini.reparent(mini_frame)
	hud.mini.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud.mini.position = Vector2(13,10)
	hud.mini.size = Vector2(230,124)
	var log_panel: Panel = hud.log_label.get_parent()
	log_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	log_panel.position = Vector2(260,0)
	log_panel.size = Vector2(644,148)
	log_panel.add_theme_stylebox_override("panel",ClassicSkin.panel_style())
	inset(log_panel)
	hud._pin(log_panel,Vector2.ZERO,Vector2(1,0),Vector2(1280,148))
	hud.log_label.position = Vector2(10,9)
	hud.log_label.size = Vector2(624,122)
	hud.log_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.log_label.offset_left = 10
	hud.log_label.offset_top = 10
	hud.log_label.offset_right = -10
	hud.log_label.offset_bottom = -16
	hud.log_label.add_theme_color_override("default_color",Color(0.74,0.76,0.61))
	for child: Node in log_panel.get_children():
		if child is Label: (child as Label).hide()
	commands_frame = frame(dock,"BattleCommandFrame")
	commands_frame.size = Vector2(370,148)
	hud._pin(commands_frame,Vector2(1,0),Vector2(1,0),Vector2(1280,148))
	commands_frame.offset_left = -370
	commands_frame.offset_right = 0
	dock.move_child(commands_frame,0)
	for child: Node in dock.get_children():
		if child is Label: (child as Label).hide()
		if child is Button and child.has_meta("action"):
			var button: Button = child as Button
			button.position.y = 7
			button.size.y = 25
			button.add_theme_stylebox_override("normal",button_skin)
			button.add_theme_font_size_override("font_size",12)
			button.set_meta("base_font_size",12)
	hud.skill_grid.position.y = 38
	hud.sequence_label.position.y = 125
	hud.sequence_label.size.y = 18
	hud.sequence_label.add_theme_font_size_override("font_size",10)
	hud.sequence_label.set_meta("base_font_size",10)
	hud.sequence_label.add_theme_stylebox_override("normal",button_skin)
	hud.skill_status.position.y = 56
	hud.skill_status.size.y = 40
	skill_heading=hud._label(commands_frame,"技能",Vector2(12,36),Vector2(520,20),12,GameHud.GOLD)
	skill_scroll=ScrollContainer.new();skill_scroll.name="SkillScroll";skill_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	skill_scroll.mouse_filter=Control.MOUSE_FILTER_STOP
	commands_frame.add_child(skill_scroll)
	hud.skill_grid.reparent(skill_scroll)
	hud.skill_grid.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud.skill_grid.position=Vector2.ZERO
	hud.sequence_label.reparent(commands_frame)
	hud.sequence_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud.skill_status.reparent(commands_frame)
	hud.skill_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for child:Node in dock.get_children():
		if child is Button and child.has_meta("action"):
			child.reparent(commands_frame)
			child.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	info = frame(self,"SelectedUnitInfo")
	info.size = Vector2(240,94)
	inset(info)
	hud.details.reparent(info)
	hud.details.show()
	hud.details.position = Vector2(14,14)
	hud.details.size = Vector2(158,66)
	hud.details.add_theme_font_size_override("font_size",11)
	hud.details.set_meta("base_font_size",11)
	hud.details.clip_text = true
	face = TextureRect.new()
	face.position = Vector2(176,11)
	face.size = Vector2(54,68)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(face)
	hud.title.reparent(self)
	hud.title.position = Vector2(70,10)
	hud.title.size = Vector2(540,19)
	hud.title.add_theme_font_size_override("font_size",12)
	hud.title.set_meta("base_font_size",12)
	hud.mode_label.reparent(self)
	hud.mode_label.position = Vector2(70,31)
	hud.mode_label.size = Vector2(490,17)
	hud.mode_label.add_theme_font_size_override("font_size",10)
	hud.mode_label.set_meta("base_font_size",10)
	group_button = hud._button(self,"",Vector2(12,12),Vector2(46,46),hud.toggle_menu)
	group_button.icon = CharacterArt.texture(Catalog.party()[0],"portrait")
	group_button.expand_icon = true
	group_button.tooltip_text = "行旅選單 [X]"
	group_button.add_theme_stylebox_override("normal",ClassicSkin.button_style())
	settings_button = hud._button(self,"⚙",Vector2.ZERO,Vector2(34,26),hud.show_settings)
	settings_button.name = "BattleSettings"
	settings_button.tooltip_text = "操作、快捷鍵與手感設定"
	menu_button = hud._button(self,"☰ X",Vector2.ZERO,Vector2(34,26),hud.toggle_menu)
	menu_button.tooltip_text="行旅選單 [X]"
	for button: Button in [settings_button,menu_button]: button.add_theme_stylebox_override("normal",ClassicSkin.button_style())
	hud.root.resized.connect(_layout)
	GameSettings.changed.connect(_layout)
	_layout()
func _layout() -> void:
	if info==null:return
	var extent:Vector2=get_viewport().get_visible_rect().size
	var ui:float=GameSettings.profile.ui_scale
	var grow:float=ceilf(maxf(0,ui-1)*14)
	var card:Vector2=Vector2(64*ui,44+grow)
	var width:float=minf(clampf(extent.x*0.54,380,680),extent.x-150)
	var columns:int=maxi(3,int((width-32)/(card.x+5)))
	var height:float=148+4*grow # Preserve the original battlefield viewport budget.
	var dock:Control=hud.root.get_node("BattleDock")
	dock.offset_top=-height
	commands_frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	commands_frame.position=Vector2(extent.x-width,0);commands_frame.size=Vector2(width,height)
	mini_frame.size=Vector2(minf(210,extent.x*0.19),height)
	hud.mini.position=Vector2(12,12);hud.mini.size=Vector2(mini_frame.size.x-24,minf(height-24,180))
	var log_panel:Control=hud.log_label.get_parent()
	log_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	log_panel.position=Vector2(mini_frame.size.x+3,0)
	log_panel.size=Vector2(maxf(0,extent.x-width-mini_frame.size.x-6),height)
	log_panel.visible=log_panel.size.x>150
	var command_index:int=0
	for child:Node in commands_frame.get_children():
		if child is Button and child.has_meta("action"):
			child.position=Vector2(10+command_index*(width-20)/4,6)
			child.size=Vector2((width-28)/4,23+grow)
			command_index+=1
	skill_heading.hide()
	skill_heading.text="技能 %d · 快捷鍵在左上 · 滾輪查看更多"%hud.skill_buttons.size()
	skill_scroll.tooltip_text="技能 %d · 滾輪查看更多"%hud.skill_buttons.size()
	skill_scroll.position=Vector2(12,32+grow);skill_scroll.size=Vector2(width-24,92+2*grow)
	hud.skill_grid.add_theme_constant_override("v_separation",4)
	hud.skill_grid.columns=columns
	for button:Button in hud.skill_buttons.values():
		button.custom_minimum_size=card
		var icon:TextureRect=button.get_meta("icon");icon.size=Vector2.ONE*(26+grow);icon.position=Vector2((card.x-icon.size.x)/2,1)
		var label:Label=button.get_meta("label");label.position=Vector2(0,27+grow);label.size=Vector2(card.x,16);label.add_theme_font_size_override("font_size",11)
		var badge:Label=button.get_meta("key");badge.position=Vector2(4,1);badge.add_theme_font_size_override("font_size",int(15*ui))
	hud.sequence_label.position=Vector2(12,125+3*grow);hud.sequence_label.size=Vector2(width-120,18+grow)
	hud.skill_status.position=Vector2(20,90)
	hud.details.position=Vector2(14,14)
	hud.details.size=Vector2(158*ui,maxf(72*ui,hud.details.get_combined_minimum_size().y))
	info.size=Vector2(240*ui,maxf(104*ui,hud.details.size.y+28))
	info.position=Vector2(extent.x-info.size.x-10,8)
	face.position=Vector2(176,11)*ui;face.size=Vector2(54,68)*ui
	settings_button.position=Vector2(extent.x-103,extent.y-27);settings_button.size=Vector2(34,23)
	menu_button.position=Vector2(extent.x-65,extent.y-27);menu_button.size=Vector2(60,23)
func _exit_tree() -> void:
	if GameSettings.changed.is_connected(_layout): GameSettings.changed.disconnect(_layout)
func refresh() -> void:
	visible = hud.director.mode in [&"battle",&"results"]
	var battle: bool = hud.director.mode==&"battle"
	for button: Button in [settings_button,menu_button,group_button]: button.disabled = not battle
	for i: int in slots.size(): slots[i].visible = i>=hud.skill_buttons.size()
	if hud.director.selection==null or hud.director.selection.selected_ids.is_empty():
		face.texture = null
		return
	var unit: TacticalUnit = hud.director.get_unit(hud.director.selection.selected_ids[0])
	if unit!=null: face.texture = CharacterArt.texture(unit.definition,"portrait")
