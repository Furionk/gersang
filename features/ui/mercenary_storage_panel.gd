class_name MercenaryStoragePanel
extends HBoxContainer
var director: GameDirector
var recruits: ItemList
var reserves: ItemList
var slots: OptionButton
var standee: TextureRect
var detail: Label
var feedback: Label
var recruit_button: Button
var exchange_button: Button
var deposit_button: Button
var withdraw_button: Button
var definitions: Array[UnitDefinition] = []
var reserve_ids: Array[String] = []
var shown: UnitDefinition
var selected_active_slot: int=1

func _ready() -> void:
	add_theme_constant_override("separation",14)
	var left: VBoxContainer=VBoxContainer.new(); left.custom_minimum_size.x=200; add_child(left)
	var title: Label=Label.new(); title.text="出戰隊伍（主角固定）"; left.add_child(title)
	recruits=ItemList.new(); recruits.name="RecruitList"; recruits.fixed_icon_size=Vector2i(48,48); recruits.size_flags_vertical=SIZE_EXPAND_FILL; left.add_child(recruits)
	recruits.item_selected.connect(func(index: int) -> void:
		selected_active_slot=index
		if index<PartyProgress.records.size(): show_definition(PartyProgress.records[index].definition,PartyProgress.records[index])
		for i: int in slots.item_count:
			if slots.get_item_id(i)==index: slots.select(i)
		update_availability())
	recruit_button=Button.new(); recruit_button.hide(); recruit_button.disabled=true; left.add_child(recruit_button)
	var center: VBoxContainer=VBoxContainer.new(); center.size_flags_horizontal=SIZE_EXPAND_FILL; center.custom_minimum_size.x=210; add_child(center)
	var label: Label=Label.new(); label.text="傭兵倉庫 · 選擇候補後交換"; center.add_child(label)
	reserves=ItemList.new(); reserves.name="ReserveList"; reserves.fixed_icon_size=Vector2i(48,48); reserves.size_flags_vertical=SIZE_EXPAND_FILL; center.add_child(reserves)
	reserves.item_selected.connect(func(index: int) -> void:
		if index<PartyProgress.reserves.size(): show_definition(PartyProgress.reserves[index].definition,PartyProgress.reserves[index]))
	slots=OptionButton.new(); slots.name="DeploymentSlot"; center.add_child(slots)
	slots.item_selected.connect(func(index: int)->void: selected_active_slot=slots.get_item_id(index); recruits.select(selected_active_slot); update_availability())
	exchange_button=Button.new(); exchange_button.name="ExchangeMercenary"; exchange_button.text="與選定出戰位交換"; exchange_button.pressed.connect(exchange_selected); center.add_child(exchange_button)
	var actions: HBoxContainer=HBoxContainer.new(); center.add_child(actions)
	deposit_button=Button.new(); deposit_button.name="DepositMercenary"; deposit_button.text="選定出戰兵入庫"; deposit_button.size_flags_horizontal=SIZE_EXPAND_FILL; deposit_button.pressed.connect(deposit_selected); actions.add_child(deposit_button)
	withdraw_button=Button.new(); withdraw_button.name="WithdrawMercenary"; withdraw_button.text="候補取出出戰"; withdraw_button.size_flags_horizontal=SIZE_EXPAND_FILL; withdraw_button.pressed.connect(withdraw_selected); actions.add_child(withdraw_button)
	var note: Label=Label.new(); note.text="主角固定；最多10人出戰。\n選倉庫兵＋出戰位，再按交換。\n換兵保留裝備、物品與經驗，不會補貨。"; note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; center.add_child(note)
	feedback=Label.new(); feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; center.add_child(feedback)
	var right: VBoxContainer=VBoxContainer.new(); right.custom_minimum_size.x=250; right.size_flags_horizontal=SIZE_EXPAND_FILL; add_child(right)
	standee=TextureRect.new(); standee.name="MercenaryStandee"; standee.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; standee.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; standee.size_flags_vertical=SIZE_EXPAND_FILL; right.add_child(standee)
	detail=Label.new(); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; right.add_child(detail)
	PartyProgress.changed.connect(refresh)
	refresh()
	if not definitions.is_empty():
		recruits.select(0)
		for record: CharacterRecord in PartyProgress.records+PartyProgress.reserves:
			if record.definition.resource_path==definitions[0].resource_path: show_definition(record.definition,record); break

func refresh(_slot: int=-1) -> void:
	if reserves==null: return
	recruits.clear(); definitions.clear()
	for record: CharacterRecord in PartyProgress.records:
		definitions.append(record.definition)
		recruits.add_item("%s · Lv%d%s"%[record.definition.display_name,record.level(),"（固定）" if record==PartyProgress.records[0] else ""],CharacterArt.texture(record.definition,"portrait"))
	if not definitions.is_empty(): recruits.select(clampi(selected_active_slot,0,definitions.size()-1))
	var selected_id: String=""
	if not reserves.get_selected_items().is_empty():
		var i: int=reserves.get_selected_items()[0]
		if i<reserve_ids.size(): selected_id=reserve_ids[i]
	reserves.clear(); reserve_ids.clear()
	for record: CharacterRecord in PartyProgress.reserves:
		reserve_ids.append(record.persistent_id)
		reserves.add_item("%s · Lv%d"%[record.definition.display_name,record.level()],CharacterArt.texture(record.definition,"portrait"))
	var chosen: int=reserve_ids.find(selected_id)
	if not reserve_ids.is_empty(): reserves.select(maxi(0,chosen))
	var previous: int=slots.selected
	slots.clear()
	for i: int in range(1,PartyProgress.records.size()): slots.add_item("出戰 %d · %s Lv%d"%[i+1,PartyProgress.records[i].definition.display_name,PartyProgress.records[i].level()],i)
	if slots.item_count>0: slots.select(clampi(previous,0,slots.item_count-1))
	update_availability()

func update_availability() -> void:
	if recruit_button==null or exchange_button==null: return
	var available: bool=director.mode==&"world" and WorldSession.context.state.mode=="EXPLORING" and not WorldSession.context.paused
	recruit_button.disabled=true
	exchange_button.disabled=not available or selected_active_slot==0 or reserve_ids.is_empty() or slots.item_count==0
	deposit_button.disabled=not available or selected_active_slot==0 or slots.item_count==0 or PartyProgress.reserves.size()>=MercenaryRoster.CAPACITY
	withdraw_button.disabled=not available or reserve_ids.is_empty() or PartyProgress.records.size()>=MercenaryRoster.ACTIVE_CAPACITY

func show_definition(definition: UnitDefinition, record: CharacterRecord) -> void:
	shown=definition
	standee.texture=CharacterArt.texture(definition,"standee")
	var names: PackedStringArray=[]
	for skill: SkillDefinition in definition.skills: names.append(skill.display_name)
	detail.text="%s · Lv%d\n%s"%[definition.display_name,1 if record==null else record.level(),"／".join(names)]
	if record!=null: detail.text+="\n經驗 %d · 負重 %.1f / %.1f"%[record.experience,record.weight(),record.max_weight]

func recruit_selected() -> void:
	if director.mode!=&"world":
		feedback.text="請回到大地圖後招募正式傭兵。"
		return
	if recruits.get_selected_items().is_empty(): return
	var definition: UnitDefinition=definitions[recruits.get_selected_items()[0]]
	var result: Dictionary=WorldSession.change_mercenary_roster("recruit",definition.resource_path)
	feedback.text=result.reason
	if result.ok:
		_refresh_leader()
		reserves.select(reserves.item_count-1)
		show_definition(definition,PartyProgress.reserves.back())

func exchange_selected() -> void:
	if director.mode!=&"world":
		feedback.text="請回到大地圖後交換出戰傭兵。"
		return
	if reserves.get_selected_items().is_empty(): return
	var id: String=reserve_ids[reserves.get_selected_items()[0]]
	var result: Dictionary=WorldSession.change_mercenary_roster("exchange",id,slots.get_selected_id())
	feedback.text=result.reason
	if result.ok:
		_refresh_leader()
		if not PartyProgress.reserves.is_empty(): show_definition(PartyProgress.reserves[reserves.get_selected_items()[0]].definition,PartyProgress.reserves[reserves.get_selected_items()[0]])

func _refresh_leader() -> void:
	if is_instance_valid(director.world_hero): director.world_hero.attach_character(PartyProgress.records[0],0)

func deposit_selected() -> void:
	if director.mode!=&"world" or slots.item_count==0: return
	var result: Dictionary=WorldSession.change_mercenary_roster("deposit","",slots.get_selected_id())
	feedback.text=result.reason
	if result.ok:
		_refresh_leader()
		reserves.select(reserves.item_count-1)
		show_definition(PartyProgress.reserves.back().definition,PartyProgress.reserves.back())

func withdraw_selected() -> void:
	if director.mode!=&"world" or reserves.get_selected_items().is_empty(): return
	var id: String=reserve_ids[reserves.get_selected_items()[0]]
	var result: Dictionary=WorldSession.change_mercenary_roster("withdraw",id)
	feedback.text=result.reason
	if result.ok:
		_refresh_leader()
		show_definition(PartyProgress.selected().definition,PartyProgress.selected())

func _exit_tree() -> void:
	if PartyProgress.changed.is_connected(refresh): PartyProgress.changed.disconnect(refresh)
