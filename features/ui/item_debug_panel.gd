class_name ItemDebugPanel
extends PanelContainer
var hud: GameHud
var service: ItemDebugService
var target: OptionButton
var category: OptionButton
var search: LineEdit
var list: ItemList
var preview: TextureRect
var description: RichTextLabel
var status: Label
var target_info: Label
var quantity: SpinBox
var bypass: CheckBox
var equip_button: Button
var use_button: Button
var displayed: Array[GearItemDefinition] = []
var selected: GearItemDefinition
var current_slot: int = -1
var previous_mode: StringName = &""
var categories: Array[String] = ["debug","armor","sword","staff","spear","axe","gun","food","all"]
var next_refresh: float = 0
var trial_buttons: Array[Button] = []
var trial_enemy: CheckBox
var storage: MercenaryStoragePanel
var tabs: TabContainer

func _ready() -> void:
	name = "ItemDebugPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",hud._style(Color(0.08,0.065,0.045,0.98)))
	var margin: MarginContainer = MarginContainer.new()
	for edge: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,16)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	margin.add_child(column)
	var top: HBoxContainer = HBoxContainer.new()
	column.add_child(top)
	var title: Label = Label.new(); title.text = "隊伍與道具 [F2]"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(title)
	target = OptionButton.new(); target.custom_minimum_size.x = 230; target.item_selected.connect(_select_target); top.add_child(target)
	var close: Button = Button.new(); close.text = "關閉 [X]"; close.pressed.connect(func() -> void: hide()); top.add_child(close)
	tabs=TabContainer.new(); tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL; column.add_child(tabs)
	column=VBoxContainer.new(); column.name="道具"; column.add_theme_constant_override("separation",10); tabs.add_child(column)
	storage=MercenaryStoragePanel.new(); storage.name="隊伍"; storage.director=service.director; tabs.add_child(storage)
	tabs.current_tab=1
	tabs.tab_changed.connect(func(index: int) -> void:
		target.visible=index==0
		if index==1: storage.refresh())
	target.visible=false
	target_info = Label.new(); target_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(target_info)
	var advanced_toggle: CheckButton=CheckButton.new(); advanced_toggle.text="進階測試"; column.add_child(advanced_toggle)
	var advanced: VBoxContainer=VBoxContainer.new(); column.add_child(advanced); advanced.hide()
	advanced_toggle.toggled.connect(func(value: bool)->void: advanced.visible=value)
	var trial_row: HBoxContainer=HBoxContainer.new(); advanced.add_child(trial_row)
	var trial_label: Label=Label.new(); trial_label.text="新兵試玩（僅本場）"; trial_row.add_child(trial_label)
	trial_enemy=CheckBox.new(); trial_enemy.text="加入敵方"; trial_row.add_child(trial_enemy)
	for entry:UnitTrialEntry in Catalog.trial_entries():
		if entry==null or entry.friendly==null: continue
		var id:String=String(entry.friendly.id)
		var trial: Button=Button.new()
		trial.name="Trial_"+id
		trial.text=entry.friendly.display_name
		trial.pressed.connect(func() -> void:
			var result: Dictionary=service.director.debug_trial_unit(id,trial_enemy.button_pressed)
			status.text=result.reason
			if result.ok: hide())
		trial_row.add_child(trial); trial_buttons.append(trial)
	var filters: HBoxContainer = HBoxContainer.new(); column.add_child(filters)
	category = OptionButton.new()
	for label: String in ["補給與升級","護甲","刀劍","拐杖","槍矛","斧","火槍","食品","全部"]: category.add_item(label)
	category.item_selected.connect(func(_index: int) -> void: rebuild_list()); filters.add_child(category)
	search = LineEdit.new(); search.placeholder_text = "搜尋物品名稱"; search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_text: String) -> void: rebuild_list()); filters.add_child(search)
	var body: HBoxContainer = HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(body)
	list = ItemList.new(); list.custom_minimum_size = Vector2(270,260); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.fixed_icon_size = Vector2i(40,40); list.item_selected.connect(_select_item); body.add_child(list)
	var details: VBoxContainer = VBoxContainer.new(); details.custom_minimum_size.x = 280; details.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_child(details)
	preview = TextureRect.new(); preview.custom_minimum_size = Vector2(96,96); preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; details.add_child(preview)
	description = RichTextLabel.new(); description.bbcode_enabled = false; description.size_flags_vertical = Control.SIZE_EXPAND_FILL; details.add_child(description)
	var path_button: Button = Button.new(); path_button.text = "複製 .tres 設定路徑"; path_button.pressed.connect(func() -> void:
		if selected != null: DisplayServer.clipboard_set(selected.resource_path)); advanced.add_child(path_button)
	var controls: HBoxContainer = HBoxContainer.new(); column.add_child(controls)
	quantity = SpinBox.new(); quantity.min_value = 1; quantity.max_value = 99; quantity.value = 1; controls.add_child(quantity)
	for count: int in [1,10,50]:
		var shortcut: Button=Button.new(); shortcut.text=str(count); shortcut.pressed.connect(func()->void: quantity.value=count); controls.add_child(shortcut)
	var grant: Button = Button.new(); grant.text = "取得至目標背包"; grant.pressed.connect(func() -> void: perform("grant")); controls.add_child(grant)
	equip_button = Button.new(); equip_button.text = "取得並立即裝備"; equip_button.pressed.connect(func() -> void: perform("equip")); controls.add_child(equip_button)
	use_button = Button.new(); use_button.text = "使用背包內道具"; use_button.pressed.connect(func() -> void: perform("use")); controls.add_child(use_button)
	bypass = CheckBox.new(); bypass.text = "忽略裝備等級（仍檢查負重／格數）"; bypass.button_pressed = false; advanced.add_child(bypass)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status.text = "選兵 → 選物品 → 取得或直裝；圖片與數值見來源資料。"; column.add_child(status)
	hide()
	rebuild_list()

func toggle() -> void:
	if not DemoRules.tools_enabled(): return
	visible = not visible
	if visible:
		previous_mode = &""
		refresh_target(true)
		_layout()

func _layout() -> void:
	var extent: Vector2 = get_viewport().get_visible_rect().size
	list.custom_minimum_size.y = 120 if extent.y < 600 else 260
	preview.custom_minimum_size.y = 64 if extent.y < 600 else 96
	size = Vector2(minf(900,extent.x-32),minf(620,extent.y-32))
	position = (extent-size)*0.5

func _process(delta: float) -> void:
	if not visible: return
	next_refresh -= delta
	if next_refresh <= 0:
		next_refresh = 0.15
		refresh_target()
		storage.update_availability()
		_layout()

func refresh_target(force: bool = false) -> void:
	var mode: StringName = service.director.mode
	for button: Button in trial_buttons: button.disabled=mode!=&"battle"
	var records: Array[CharacterRecord] = service.records()
	if force or previous_mode != mode or target.item_count != records.size():
		previous_mode = mode
		target.clear()
		for i: int in records.size(): target.add_item("%d · %s" % [i+1,records[i].definition.display_name])
		current_slot = clampi(service.selected_slot(),0,records.size()-1)
		target.select(current_slot)
	if current_slot < 0 or current_slot >= records.size(): return
	for i: int in records.size(): target.set_item_text(i,"%d · %s"%[i+1,records[i].definition.display_name])
	var record: CharacterRecord = records[current_slot]
	var hp: float = record.health
	var mp: float = record.mana
	for actor: TacticalUnit in service.actors():
		if actor.character == record: hp = actor.vitals.health; mp = actor.vitals.mana; break
	target_info.text = "%s Lv.%d · HP %.0f / %.0f · MP %.0f / %.0f · 負重 %.1f / %.1f\n%s" % [record.definition.display_name,record.level(),hp,record.stats()["health"],mp,record.stats()["mana"],record.weight(),record.max_weight,"戰鬥中只改本場副本；回圖不保留 Debug 裝備／升級。" if mode == &"battle" else "大世界改動可保存至此兵；一般食品只有資料，沒有食用效果。"]

func _select_target(index: int) -> void:
	current_slot = index
	if service.director.mode == &"world": service.director.select_world_slot(index)
	elif service.director.selection != null:
		for actor: TacticalUnit in service.actors():
			if actor.permanent_slot == index and actor.alive(): service.director.selection.select_ids([actor.unit_id]); break
	refresh_target()

func rebuild_list() -> void:
	list.clear(); displayed.clear()
	var filter: String = categories[category.selected]
	for item: GearItemDefinition in ItemCatalog.all_items():
		if filter != "all" and item.category != filter: continue
		if search.text != "" and not item.display_name.contains(search.text) and not String(item.id).contains(search.text): continue
		displayed.append(item)
	displayed.sort_custom(func(a: GearItemDefinition,b: GearItemDefinition) -> bool: return a.required_level < b.required_level if a.required_level != b.required_level else String(a.id)<String(b.id))
	for item: GearItemDefinition in displayed: list.add_item("%s · Lv.%d · %.1f重" % [item.display_name,item.required_level,item.weight],item.icon)
	if not displayed.is_empty(): list.select(0); _select_item(0)
	else: selected = null; description.text = "沒有符合條件的物品。"; preview.texture = null

func _select_item(index: int) -> void:
	if index < 0 or index >= displayed.size(): return
	selected = displayed[index]
	show_details()

func show_details() -> void:
	preview.texture = selected.icon
	description.text = selected.tooltip()+"\nID: "+String(selected.id)+"\n設定: "+selected.resource_path
	if selected.source_url != "": description.text += "\n來源: "+selected.source_url
	equip_button.disabled = selected.kind != GearItemDefinition.Kind.EQUIPMENT
	use_button.disabled = selected.effect() == GearItemDefinition.Effect.NONE or selected.kind == GearItemDefinition.Kind.EQUIPMENT

func perform(operation: String) -> void:
	if selected == null: return
	var result: Dictionary = service.perform(selected.id,operation,current_slot,int(quantity.value),bypass.button_pressed)
	status.text = str(result["reason"])
	service.director.message.emit(status.text)
	refresh_target()
