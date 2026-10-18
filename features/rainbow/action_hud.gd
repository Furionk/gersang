class_name RainbowActionHud
extends CanvasLayer
var battle: RainbowActionBattle
var root: Control
var status: Label
var members: HBoxContainer
var buttons: Dictionary = {}
var stick: RainbowActionStick
var run_held: bool = false
var roster_panel: PanelContainer
var roster_scroll: ScrollContainer
var notice: Label
var enemy_label: Label
var bars: Dictionary = {}
var action_buttons: Dictionary = {}
var member_bars: Dictionary = {}
var last_selected: int = -1
var action_labels: Dictionary = {}
var member_labels: Dictionary = {}
var boss_panel: PanelContainer
var boss_title: Label
var boss_hint: Label
var boss_life: ProgressBar
var actions: Control
var touch_mode: bool = false
var touch_scale: float = 1.0
var touch_router: Node
var touch_override: bool = false
var touch_toggle: Button
var status_panel: PanelContainer
var menu_row: HBoxContainer
var retreat_button: Button
var roster_hint: Label

func touch_safe_rect() -> Rect2:
	var full := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	if not OS.has_feature("mobile"): return full
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var scale_factor := full.size / Vector2(DisplayServer.window_get_size()).max(Vector2.ONE)
	safe.position = (safe.position - Vector2(DisplayServer.window_get_position())) * scale_factor
	safe.size *= scale_factor
	return full.intersection(safe) if safe.has_area() else full

func set_touch_mode(enabled: bool) -> void:
	if touch_mode == enabled: return
	touch_mode = enabled
	if is_instance_valid(touch_toggle): touch_toggle.set_pressed_no_signal(enabled)
	if is_instance_valid(touch_router): touch_router.reset()
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE if enabled else Control.MOUSE_FILTER_STOP
	stick.visible = not enabled
	if not enabled:
		stick.scale = Vector2.ONE
		stick.modulate.a = 1
		stick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		stick.offset_left = 20; stick.offset_right = 140
		stick.offset_top = -246; stick.offset_bottom = -126
	layout_actions(get_viewport().get_visible_rect().size.x >= 1200)

func layout_actions(wide: bool) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := Vector2(DisplayServer.window_get_size())
	var density := maxf(1.0, DisplayServer.screen_get_dpi() / 160.0)
	touch_scale = maxf(0.01, density * viewport_size.x / maxf(window_size.x, 1))
	if touch_mode:
		var safe := touch_safe_rect()
		var span := 232 * touch_scale
		var inset: Vector2 = viewport_size - safe.end + Vector2(16,16)
		actions.offset_left = -span - inset.x
		actions.offset_right = -inset.x
		actions.offset_top = -span - inset.y
		actions.offset_bottom = -inset.y
		roster_panel.offset_left = minf(150, viewport_size.x * 0.22)
		roster_panel.offset_left += safe.position.x
		roster_panel.offset_right = -span - 30 - (viewport_size.x-safe.end.x)
		roster_panel.offset_top = -100 - (viewport_size.y-safe.end.y)
		roster_panel.offset_bottom = -10 - (viewport_size.y-safe.end.y)
	else:
		actions.offset_left = -340; actions.offset_right = -16
		actions.offset_top = -96 if wide else -208
		actions.offset_bottom = -10 if wide else -114
		roster_panel.offset_left = 16
		roster_panel.offset_right = -366 if wide else -16
		roster_panel.offset_top = -100; roster_panel.offset_bottom = -10
	var slots := {&"ranged":Vector2(84,0), &"guard":Vector2(0,84), &"melee":Vector2(156,78), &"run":Vector2(84,168)}
	var index: int = 0
	for kind: StringName in action_buttons:
		var button: Button = action_buttons[kind]
		button.custom_minimum_size = Vector2.ZERO
		button.position = slots[kind] * touch_scale if touch_mode else Vector2(index * 82, 0)
		button.size = (Vector2.ONE * (76 if kind == &"melee" else 64) * touch_scale).ceil() if touch_mode else Vector2(74,86)
		var icon: TextureRect = button.get_child(0)
		icon.size = Vector2.ONE * button.size.x
		action_labels[kind].position.y = button.size.x * 0.73
		action_labels[kind].size.x = button.size.x
		index += 1

func ornament(panel: PanelContainer) -> void:
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 22; empty.content_margin_right = 22
	empty.content_margin_top = 24; empty.content_margin_bottom = 34
	panel.add_theme_stylebox_override("panel", empty)
	var frame := TextureRect.new()
	frame.texture = preload("res://features/rainbow/art/hud-frame-v1.png")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Decoration follows its panel without participating in container minimum size.
	root.add_child(frame)
	root.move_child(frame, panel.get_index())
	panel.item_rect_changed.connect(func() -> void: frame.size = panel.size; frame.position = panel.position)
	panel.visibility_changed.connect(func() -> void: frame.visible = panel.visible)
	frame.size = panel.size; frame.position = panel.position
func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("19130fea"); style.border_color = Color("937042")
	style.set_border_width_all(1); style.set_corner_radius_all(0)
	style.border_width_top = 2
	style.shadow_color = Color(0, 0, 0, 0.6); style.shadow_size = 3
	style.content_margin_left = 12; style.content_margin_right = 12
	style.content_margin_top = 8; style.content_margin_bottom = 8
	return style
func meter(color: Color) -> ProgressBar:
	var item := ProgressBar.new()
	item.show_percentage = false; item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.custom_minimum_size = Vector2(100, 12)
	var bg := StyleBoxFlat.new(); bg.bg_color = Color("080e15"); bg.set_border_width_all(1); bg.border_color = Color("aa854c")
	var fill := StyleBoxFlat.new(); fill.bg_color = color; fill.border_width_top = 2; fill.border_color = color.lightened(0.4)
	item.add_theme_stylebox_override("background", bg); item.add_theme_stylebox_override("fill", fill)
	return item
func button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", panel_style())
	var hover := panel_style(); hover.border_color = Color("ffe1a1")
	button.add_theme_stylebox_override("hover", hover)
	var down := panel_style(); down.bg_color = Color("49381e"); down.border_color = Color("edc078")
	button.add_theme_stylebox_override("pressed", down)
	button.add_theme_stylebox_override("hover_pressed", down)
	var disabled := panel_style(); disabled.bg_color = Color("17130f"); disabled.border_color = Color("514939")
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_font_size_override("font_size", 14)


func _ready() -> void:
	layer = 6
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = battle.game.hud.root.theme
	add_child(root)
	var top: PanelContainer = PanelContainer.new()
	status_panel = top
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	top.offset_left = 16; top.offset_right = 326; top.offset_top = 12
	top.add_theme_stylebox_override("panel", panel_style())
	root.add_child(top)
	ornament(top)
	var column: VBoxContainer = VBoxContainer.new()
	top.add_child(column)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 16)
	column.add_child(status)
	var hint: Label = Label.new()
	hint.text = "◆ 火 龍 神 殿 ◆"
	hint.hide()
	hint.modulate = Color("edc078")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	var vitals := VBoxContainer.new(); column.add_child(vitals)
	vitals.add_theme_constant_override("separation", 2)
	for key: String in ["HP", "MP", "BP"]:
		var col := HBoxContainer.new(); vitals.add_child(col)
		var value := Label.new(); col.add_child(value); value.name = key; value.custom_minimum_size.x = 104
		value.add_theme_font_size_override("font_size", 12)
		var gauge := meter(Color("c63933") if key == "HP" else Color("8adaef") if key == "MP" else Color("edc078"))
		gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL; col.add_child(gauge); bars[key] = [gauge,value]
	roster_panel = PanelContainer.new(); root.add_child(roster_panel)
	roster_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	roster_panel.offset_left = 16; roster_panel.offset_right = -16
	roster_panel.offset_top = -100; roster_panel.offset_bottom = -10
	roster_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var roster_column := VBoxContainer.new(); roster_panel.add_child(roster_column)
	roster_hint = Label.new(); roster_hint.text = "◆ 編隊  1–0 / Tab"
	roster_hint.add_theme_font_size_override("font_size", 12); roster_column.add_child(roster_hint)
	var scroll: ScrollContainer = ScrollContainer.new()
	roster_scroll = scroll
	scroll.custom_minimum_size.y = 68
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	roster_column.add_child(scroll)
	members = HBoxContainer.new()
	scroll.add_child(members)
	for id: int in battle.game.roster_ids:
		var unit: TacticalUnit = battle.game.get_unit(id)
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(68, 62)
		button_style(button)
		button.focus_mode = Control.FOCUS_NONE
		var skin: SpriteSheetLayout = (battle.actors[id] as RainbowActionActor).weapon.layout
		if skin != null:
			var portrait := AtlasTexture.new()
			portrait.atlas = skin.source_texture
			var crop := Rect2(skin.frame_rects[0])
			crop.size.y *= 0.50
			portrait.region = crop
			button.icon = portrait
		else: button.icon = CharacterArt.texture(unit.definition, "portrait")
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 44)
		button.pressed.connect(func() -> void: battle.switch_to(id))
		members.add_child(button)
		buttons[id] = button
		var badge := Label.new(); button.add_child(badge); badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(5, 1); badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_outline_color", Color.BLACK); badge.add_theme_constant_override("outline_size", 5)
		member_labels[id] = badge
		var life := meter(Color("82df9f")); button.add_child(life); life.custom_minimum_size = Vector2.ZERO
		life.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		life.offset_left = 7; life.offset_right = -7; life.offset_top = -5; life.offset_bottom = -2
		member_bars[id] = life
	stick = RainbowActionStick.new()
	root.add_child(stick)
	stick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	stick.offset_left = 20; stick.offset_top = -246
	stick.offset_right = 140; stick.offset_bottom = -126
	actions = Control.new()
	root.add_child(actions)
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.offset_left = -340; actions.offset_top = -208; actions.offset_right = -16; actions.offset_bottom = -114
	for entry: Array in [["S\n近攻", &"melee"], ["D\n遠攻", &"ranged"], ["空白\n防禦", &"guard"], ["A\n加速", &"run"]]:
		var button: Button = Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(74, 86)
		button_style(button)
		actions.add_child(button)
		var kind: StringName = entry[1]
		action_buttons[kind] = button
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		var icon := TextureRect.new(); button.add_child(icon)
		var atlas := AtlasTexture.new(); atlas.atlas = preload("res://features/rainbow/art/hud-abilities-v1.png")
		var index: int = [&"melee", &"ranged", &"guard", &"run"].find(kind)
		var cell: Vector2 = atlas.atlas.get_size() / 2.0
		atlas.region = Rect2(Vector2(index % 2, index / 2) * cell, cell)
		icon.texture = atlas; icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.position = Vector2(0, 0); icon.size = Vector2(74, 74); icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new(); button.add_child(label); label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = Vector2(0, 54); label.size.x = 74; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12); label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6); action_labels[kind] = label
		button.mouse_entered.connect(func() -> void: icon.modulate = Color(1.3,1.2,1.05))
		button.mouse_exited.connect(func() -> void: icon.modulate = Color.WHITE)
		button.button_down.connect(func() -> void: icon.modulate = Color(0.65,0.65,0.65))
		button.button_up.connect(func() -> void: icon.modulate = Color.WHITE)
		if kind == &"run":
			button.button_down.connect(func() -> void: run_held = true)
			button.button_up.connect(func() -> void: run_held = false)
		else:
			button.button_down.connect(func() -> void:
				battle.request(kind)
				if kind != &"guard": battle.held_action = kind)
			button.button_up.connect(func() -> void:
				if battle.held_action == kind: battle.held_action = &"")
		button.tooltip_text = {&"melee":"按住連斬；收招末段可以預輸入下一擊", &"ranged":"沿面向射擊，每發消耗 3 MP", &"guard":"短按正面防禦，消耗 12 BP", &"run":"按住加速，鬆開恢復 BP"}[kind]
	var retreat: Button = Button.new()
	retreat_button = retreat
	retreat.text = "撤退 [Esc]"
	retreat.focus_mode = Control.FOCUS_NONE
	root.add_child(retreat)
	retreat.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	retreat.offset_top = 58
	button_style(retreat)
	retreat.offset_left = -136; retreat.offset_right = -16
	retreat.pressed.connect(func() -> void: battle.game.retreat())
	enemy_label = Label.new(); root.add_child(enemy_label)
	enemy_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	enemy_label.offset_left = -280; enemy_label.offset_right = -16; enemy_label.offset_top = 18
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_label.add_theme_font_size_override("font_size", 20)
	var options := HBoxContainer.new(); root.add_child(options)
	menu_row = options
	options.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	options.offset_left = -420; options.offset_right = -145; options.offset_top = 58
	for option: String in ["擬聲", "震動"]:
		var toggle := Button.new(); toggle.text = option + " 開"; toggle.toggle_mode = true; toggle.button_pressed = true
		toggle.focus_mode = Control.FOCUS_NONE; button_style(toggle); options.add_child(toggle)
		toggle.toggled.connect(func(enabled: bool) -> void:
			toggle.text = option + (" 開" if enabled else " 關")
			if option == "擬聲": battle.feedback.voice_enabled = enabled
			else: battle.feedback.shake_enabled = enabled)
	notice = Label.new(); root.add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_left = -230; notice.offset_right = 230; notice.offset_top = 145
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.add_theme_font_size_override("font_size", 20); notice.modulate = Color("ffe4ad")
	notice.add_theme_color_override("font_shadow_color", Color.BLACK)
	notice.add_theme_constant_override("shadow_offset_y", 2)
	boss_panel = PanelContainer.new(); root.add_child(boss_panel)
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boss_panel.offset_left = 16; boss_panel.offset_right = -16
	boss_panel.offset_top = 120
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament(boss_panel)
	var boss_frame := boss_panel.get_theme_stylebox("panel")
	boss_frame.content_margin_top = 16; boss_frame.content_margin_bottom = 20
	var boss_column := VBoxContainer.new(); boss_panel.add_child(boss_column)
	boss_title = Label.new(); boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; boss_column.add_child(boss_title)
	boss_life = meter(Color("f17b54")); boss_column.add_child(boss_life)
	boss_hint = Label.new(); boss_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; boss_column.add_child(boss_hint)
	boss_hint.modulate = Color("ffdf9b"); boss_panel.hide()
	boss_hint.add_theme_font_size_override("font_size", 13)
	touch_router = preload("res://features/rainbow/touch_router.gd").new()
	touch_router.hud = self
	add_child(touch_router)
	get_viewport().size_changed.connect(touch_router.reset)
	touch_toggle = Button.new()
	touch_toggle.text = "觸控配置"; touch_toggle.toggle_mode = true
	touch_toggle.focus_mode = Control.FOCUS_NONE
	button_style(touch_toggle); options.add_child(touch_toggle)
	touch_toggle.toggled.connect(func(enabled: bool) -> void:
		touch_override = true
		set_touch_mode(enabled))
	set_touch_mode(DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"))

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT]: run_held = false

func _process(_delta: float) -> void:
	visible = battle.game.mode == &"battle"
	if not visible:
		if is_instance_valid(touch_router): touch_router.reset()
		return
	var boss: RainbowActionActor = battle.mechanics.boss_actor() if is_instance_valid(battle.mechanics) else null
	boss_panel.visible = boss != null
	var wide: bool = get_viewport().get_visible_rect().size.x >= 1200
	layout_actions(wide)
	roster_hint.text = "◆ 編隊 · 滑動／點選接管" if touch_mode else "◆ 編隊  1–0 / Tab"
	retreat_button.text = "撤退" if touch_mode else "撤退 [Esc]"
	boss_panel.offset_left = 342
	boss_panel.offset_right = -340 if wide else -16
	boss_panel.offset_top = 12 if wide else 100
	var safe: Rect2 = touch_safe_rect() if touch_mode else Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size)
	var right_inset: float = get_viewport().get_visible_rect().size.x - safe.end.x
	status_panel.offset_left = 16 + safe.position.x
	status_panel.offset_right = status_panel.offset_left + (minf(310,safe.size.x*0.36) if touch_mode else 310)
	status_panel.offset_top = 12 + safe.position.y
	menu_row.offset_left = -420-right_inset; menu_row.offset_right = -145-right_inset; menu_row.offset_top = 58+safe.position.y
	retreat_button.offset_left = -136-right_inset; retreat_button.offset_right = -16-right_inset; retreat_button.offset_top = 58+safe.position.y
	enemy_label.offset_right = -16-right_inset; enemy_label.offset_top = 18+safe.position.y
	boss_panel.offset_left += safe.position.x; boss_panel.offset_right -= right_inset; boss_panel.offset_top += safe.position.y
	notice.offset_top = 224 if boss != null and not wide else 174
	if boss != null:
		var state: Dictionary = battle.mechanics.states[boss.unit.unit_id]
		boss_title.text = "%s  ·  階段 %d  ·  %d / %d" % [boss.unit.definition.display_name,state.phase,boss.unit.vitals.health,boss.unit.vitals.max_health]
		var priests: Array[int] = battle.mechanics.living_priests()
		if priests.size() > 1 or (boss.enemy.pattern == "priest" and battle.mechanics.initial_priests > 1):
			boss_title.text = "祭司儀式 · 存活 %d/%d · 目標 %d / %d" % [priests.size(),maxi(priests.size(),battle.mechanics.initial_priests),boss.unit.vitals.health,boss.unit.vitals.max_health]
		boss_life.value = 100 * boss.unit.vitals.health / boss.unit.vitals.max_health
		boss_hint.text = state.message + ("  %.1f秒" % state.exposure if state.exposure > 0 else "")
	var unit: TacticalUnit = battle.controlled()
	if unit == null: return
	var actor: RainbowActionActor = battle.actors[unit.unit_id]
	status.text = unit.definition.display_name
	status.tooltip_text = actor.weapon.specialty
	var data: Dictionary = {"HP":[unit.vitals.health,unit.vitals.max_health],"MP":[unit.vitals.mana,unit.vitals.max_mana],"BP":[actor.bp,battle.profile.bp_max]}
	for key: String in data:
		bars[key][0].value = 100.0 * data[key][0] / maxf(1,data[key][1])
		bars[key][1].text = "%s  %d/%d" % [key,data[key][0],data[key][1]]
	var remaining: int = battle.game.living_ids(1).size()
	enemy_label.text = "敵軍全滅 · 即將結算" if remaining == 0 else "剩餘敵軍  %02d" % remaining
	notice.text = battle.feedback.last_text if battle.feedback.notice_left > 0 else ""
	if last_selected != unit.unit_id:
		last_selected = unit.unit_id
		roster_scroll.ensure_control_visible.call_deferred(buttons[last_selected])
	for kind: StringName in action_buttons:
		var caption: String = {&"melee":"S  近攻",&"ranged":"D  遠攻",&"guard":"空白  防禦",&"run":"A  加速"}[kind]
		if kind == &"melee": caption = "S  " + actor.weapon.melee_name
		elif kind == &"ranged": caption = "D  " + actor.weapon.ranged_name
		if touch_mode:
			caption = actor.weapon.melee_name if kind == &"melee" else actor.weapon.ranged_name if kind == &"ranged" else "防禦" if kind == &"guard" else "加速"
		var state: String = "按住連擊" if kind in [&"melee",&"ranged"] else "正面格擋" if kind == &"guard" else "按住衝刺"
		if kind == &"ranged" and unit.vitals.mana < actor.weapon.mana_cost: state = "MP 不足"
		elif kind == &"guard" and actor.bp < 12: state = "BP 不足"
		elif actor.recovery > 0 and kind != &"run": state = "%.1fs" % actor.recovery
		action_buttons[kind].text = ""
		action_labels[kind].text = caption + ("\n" + state if state in ["MP 不足", "BP 不足"] or actor.recovery > 0 and kind != &"run" else "")
		if kind == &"ranged": action_buttons[kind].tooltip_text = "%s · %.0f MP · %.2fs 起手 / %.2fs 收招" % [actor.weapon.ranged_name, actor.weapon.mana_cost, actor.profile.ranged_windup, actor.profile.ranged_recovery]
		elif kind == &"melee": action_buttons[kind].tooltip_text = "%s · 範圍 %.0f · %.2fs 起手 / %.2fs 收招" % [actor.weapon.melee_name, actor.profile.melee_range, actor.profile.melee_windup, actor.profile.melee_recovery]
	for id: int in buttons:
		var member: TacticalUnit = battle.game.get_unit(id)
		var button: Button = buttons[id]
		button.text = ""
		member_labels[id].text = "%d%s" % [(battle.game.roster_ids.find(id)+1)%10, " ◆" if id == unit.unit_id else " ×" if not member.alive() else ""]
		button.tooltip_text = "%s · %d/%d HP · %s" % [member.definition.display_name, member.vitals.health, member.vitals.max_health, "操控中" if id == unit.unit_id else "AI 跟隨作戰" if member.alive() else "已倒下"]
		member_bars[id].value = member.vitals.health / maxf(1,member.vitals.max_health) * 100
		button.disabled = not member.alive()
		button.modulate = Color(0.42, 0.42, 0.42) if not member.alive() else Color.WHITE
		if button.get_meta("selected", false) != (id == unit.unit_id):
			button.set_meta("selected", id == unit.unit_id)
			var frame := panel_style()
			if id == unit.unit_id:
				frame.border_color = Color("ffe09c"); frame.set_border_width_all(2)
				frame.shadow_color = Color(0.95, 0.56, 0.15, 0.4); frame.shadow_size = 4
			button.add_theme_stylebox_override("normal", frame)
