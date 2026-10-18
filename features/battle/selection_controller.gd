class_name SelectionController
extends Node2D
signal selection_changed(ids: Array[int])
var director: GameDirector
var selected_ids: Array[int] = []
const GROUP_KEYS:Array[int]=[KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0,KEY_MINUS,KEY_EQUAL]
const GROUP_NAMES:Array[String]=["1","2","3","4","5","6","7","8","9","0","-","="]
var groups: Dictionary = {}
var armed: StringName = &""
var armed_skill_id: StringName = &""
var drag_origin: Vector2
var drag_current: Vector2
var dragging: bool = false
var repeat_target: Dictionary = {}
var sequence_slots: Array[int] = []
var sequence_entries: Array[Dictionary] = []
var sequence_index: int = 0
var reserve_armed: bool = false

func _ready() -> void:
	z_index = 4095

func visible_skills() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var by_id: Dictionary = {}
	for id: int in selected_ids:
		var unit: TacticalUnit = director.get_unit(id)
		if unit == null or not unit.alive():
			continue
		for skill: SkillDefinition in unit.available_skills():
			if skill == null:
				continue
			if not by_id.has(skill.id):
				var entry: Dictionary = {"skill":skill, "owners":[], "ready":0, "cooldown":0.0, "reason":"", "autocast":0}
				by_id[skill.id] = entry
				result.append(entry)
			var entry: Dictionary = by_id[skill.id]
			entry["owners"].append(id)
			if unit.abilities.autocast_enabled(skill): entry["autocast"] = int(entry["autocast"])+1
			entry["cooldown"] = maxf(float(entry["cooldown"]), float(unit.cooldowns.get(skill.id, 0)))
			if unit.abilities.available(skill):
				entry["ready"] = int(entry["ready"]) + 1
			else:
				entry["reason"] = unit.abilities.last_error
	return result

func _entry(skill_id: StringName) -> Dictionary:
	for entry: Dictionary in visible_skills():
		if (entry["skill"] as SkillDefinition).id == skill_id:
			return entry
	return {}
func _owned_skill(unit: TacticalUnit, skill_id: StringName) -> SkillDefinition:
	for skill: SkillDefinition in unit.available_skills():
		if skill.id==skill_id: return skill
	return null

func select_ids(ids: Array[int], additive: bool = false, player_issued: bool = false) -> void:
	if not additive:
		selected_ids.clear()
	for id: int in ids:
		var unit: TacticalUnit = director.get_unit(id)
		if unit != null and unit.team == 0 and unit.alive() and unit.definition.controllable:
			if additive and id in selected_ids:
				selected_ids.erase(id)
			elif id not in selected_ids:
				selected_ids.append(id)
	_sync_selection()
	if player_issued and director.voices != null: director.voices.acknowledge(selected_ids, &"select")

func _sync_selection() -> void:
	selected_ids = selected_ids.filter(func(id: int) -> bool: return director.get_unit(id) != null and director.get_unit(id).alive() and director.get_unit(id).definition.controllable)
	for unit: TacticalUnit in director.units.values():
		if unit.view != null:
			unit.view.selected = unit.unit_id in selected_ids
		if unit.unit_id not in selected_ids:
			unit.repeat_command.clear()
			if unit.active.has("repeat"):
				unit.active["repeat"] = false
	for id: int in repeat_target.keys():
		if id not in selected_ids:
			repeat_target.erase(id)
	if armed_skill_id != &"" and _entry(armed_skill_id).is_empty():
		cancel()
	selection_changed.emit(selected_ids)
	director.audio.play("select")

func restore_groups()->void:
	groups.clear()
	for index:int in GROUP_KEYS.size():
		var identities:Array=GameSettings.control_groups.get(str(index),[])
		var ids:Array[int]=[]
		for unit:TacticalUnit in director.units.values():
			if unit.team==0 and not unit.is_summon and unit.character!=null and unit.character.persistent_id in identities:ids.append(unit.unit_id)
		if not ids.is_empty():groups[index]=ids
	refresh_group_badges()
func refresh_group_badges()->void:
	for unit:TacticalUnit in director.units.values():
		if unit.view==null:continue
		var labels:PackedStringArray=[]
		for index:int in GROUP_KEYS.size():
			if unit.unit_id in groups.get(index,[]):labels.append(GROUP_NAMES[index])
		unit.view.group_label=" ".join(labels)
func store_group(index:int)->void:
	if index<0 or index>=GROUP_KEYS.size():return
	groups[index]=selected_ids.duplicate()
	var identities:Array[String]=[]
	for id:int in selected_ids:
		var unit:TacticalUnit=director.get_unit(id)
		if unit!=null and not unit.is_summon and unit.character!=null:identities.append(unit.character.persistent_id)
	GameSettings.control_groups[str(index)]=identities
	GameSettings.save_settings()
	refresh_group_badges()
	director.audio.feedback("confirm")
	director.message.emit("編隊 %s：%d 人 · Ctrl+%s 覆寫；召喚物僅限當場"%[GROUP_NAMES[index],selected_ids.size(),GROUP_NAMES[index]])
func recall_group(index:int)->void:
	var ids:Array[int]=[];ids.assign(groups.get(index,[]))
	if ids.is_empty() and not GameSettings.control_groups.has(str(index)):
		var slot:int=DemoRules.slot_for_key(GROUP_KEYS[index])
		if slot>=0 and slot<director.roster_ids.size():ids.append(director.roster_ids[slot])
	if ids.is_empty():
		director.message.emit("編隊 %s 尚未設定；選取角色後按 Ctrl+%s"%[GROUP_NAMES[index],GROUP_NAMES[index]])
		director.audio.feedback("error");return
	select_ids(ids,false,true)
func conflicting_skills()->Dictionary:
	var keys:Dictionary={};var conflicts:Dictionary={}
	for entry:Dictionary in visible_skills():
		var skill:SkillDefinition=entry.skill
		if not skill.manual():continue
		var key:int=int(GameSettings.bindings.get(str(skill.action),0))
		if key==0:continue
		if not keys.has(key):keys[key]=[]
		keys[key].append(skill.id)
	for key:int in keys:
		var reserved:bool=key==KEY_X or key in GROUP_KEYS
		for action:String in ["command_move","command_attack","command_stop","command_hold","sequence_cast","select_all"]:
			reserved=reserved or key==int(GameSettings.bindings.get(action,0))
		if reserved or keys[key].size()>1:
			for id:StringName in keys[key]:conflicts[id]=true
	return conflicts
func select_box(rect: Rect2, additive: bool = false) -> void:
	var ids: Array[int] = []
	for unit: TacticalUnit in director.units.values():
		if unit.team == 0 and unit.alive() and unit.definition.controllable and rect.has_point(Iso.project(unit.position) + Vector2(0, -35)):
			ids.append(unit.unit_id)
	select_ids(ids, additive, true)

func activate_skill(skill_id: StringName, _reserve: bool = false, prepare_only: bool = false) -> bool:
	if director.mode!=&"battle": return false
	var entry: Dictionary = _entry(skill_id)
	if entry.is_empty():
		return false
	var skill: SkillDefinition = entry["skill"]
	if not skill.manual() or int(entry["ready"]) == 0:
		director.audio.feedback("error")
		var reason:String=str(entry.get("reason", "此技能為自動觸發"))
		director.message.emit(skill.display_name+"："+reason+("（需要 MP %.0f）"%skill.mana_cost if reason=="法力不足" else ""))
		var button:SkillCommandButton=director.hud.skill_buttons.get(skill.id)
		if button!=null:button.reject()
		return false
	director.audio.feedback("prepare")
	if skill.instant_self_activation and skill.target_mode==SkillDefinition.Target.SELF and not prepare_only:
		var success: bool = false
		for id: int in entry["owners"]:
			var caster: TacticalUnit = director.get_unit(id)
			var owned: SkillDefinition = _owned_skill(caster,skill.id)
			if caster.abilities.request(owned,caster.position): success = true
			else: director.message.emit(caster.abilities.last_error)
		if success: cancel()
		return success
	armed_skill_id = skill.id
	armed = skill.action
	reserve_armed = false
	repeat_target.clear()
	dragging = false
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if skill.target_mode in [SkillDefinition.Target.ALLY,SkillDefinition.Target.ENEMY] else Input.CURSOR_CROSS)
	director.message.emit("%s：左鍵指定%s，右鍵取消" % [skill.display_name, "友軍" if skill.target_mode == SkillDefinition.Target.ALLY else "敵人" if skill.target_mode == SkillDefinition.Target.ENEMY else "方向" if skill.target_mode == SkillDefinition.Target.DIRECTION else "地點"])
	queue_redraw()
	return true

func arm(action: StringName, reserve: bool = false) -> void:
	if String(action).begins_with("skill_"):
		for entry: Dictionary in visible_skills():
			var skill: SkillDefinition = entry["skill"]
			if skill.action == action:
				activate_skill(skill.id, reserve)
				return
		return
	cancel()
	armed = action
	director.message.emit("指令：%s — 左鍵指定目標" % GameSettings.ACTION_LABELS.get(String(action), String(action)))

func cancel() -> void:
	armed = &""
	armed_skill_id = &""
	reserve_armed = false
	dragging = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	queue_redraw()
func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
func toggle_autocast(skill_id: StringName) -> bool:
	var entry: Dictionary = _entry(skill_id)
	if entry.is_empty(): return false
	var skill: SkillDefinition = entry["skill"]
	if not skill.supports_autocast(): return false
	var enabled: bool = int(entry["autocast"]) != entry["owners"].size()
	for id: int in entry["owners"]:
		var owner: TacticalUnit = director.get_unit(id)
		owner.abilities.set_autocast(_owned_skill(owner,skill.id),enabled)
	director.audio.feedback("confirm")
	director.message.emit("%s：自動施法%s" % [skill.display_name,"開啟" if enabled else "關閉"])
	return true

func confirm_skill(point: Vector2, target_id: int = -1) -> bool:
	var entry: Dictionary = _entry(armed_skill_id)
	if entry.is_empty():
		return false
	var skill: SkillDefinition = entry["skill"]
	if skill.target_mode in [SkillDefinition.Target.ALLY, SkillDefinition.Target.ENEMY] and target_id < 0:
		var target: TacticalUnit = director.pick_unit(Iso.project(point), 0 if skill.target_mode == SkillDefinition.Target.ALLY else 1)
		if target != null:
			target_id = target.unit_id
			point = target.position
	var success: bool = false
	for id: int in entry["owners"]:
		var caster: TacticalUnit = director.get_unit(id)
		var owned: SkillDefinition = _owned_skill(caster,skill.id)
		var at: Vector2 = caster.position if owned.target_mode == SkillDefinition.Target.SELF else point
		if caster.abilities.request(owned, at, target_id):
			success = true
		else:
			director.message.emit(caster.abilities.last_error)
	if success:
		director.audio.feedback("confirm")
		if target_id >= 0:
			var target: TacticalUnit = director.get_unit(target_id)
			if target != null and target.view != null: target.view.confirm_target()
		cancel()
	else:director.audio.feedback("error")
	return success

func _cast_armed(point: Vector2) -> void:
	confirm_skill(point)

func _unhandled_input(event: InputEvent) -> void:
	if director.mode != &"battle" or (director.phases!=null and director.phases.frozen()):
		return
	if event is InputEventKey:
		var key: InputEventKey = event
		if not key.pressed or key.echo:
			return
		if director.hud.is_modal_open():return
		var code:int=key.physical_keycode if key.physical_keycode!=0 else key.keycode
		if code in GROUP_KEYS:
			var index:int=GROUP_KEYS.find(code)
			if key.ctrl_pressed:store_group(index)
			else:recall_group(index)
			get_viewport().set_input_as_handled();return
		var matching: Array[Dictionary] = []
		for entry: Dictionary in visible_skills():
			if entry.skill.manual() and event.is_action_pressed(String(entry.skill.action)): matching.append(entry)
		var command_conflict: bool = false
		for action: String in ["command_move","command_attack","command_stop","command_hold","sequence_cast","select_all"]:
			if not matching.is_empty() and event.is_action_pressed(action): command_conflict=true
		if matching.size()>1 or command_conflict:
			director.audio.feedback("error")
			director.message.emit("快捷鍵衝突："+OS.get_keycode_string(key.physical_keycode)+" 對應多個指令；請改鍵或點技能圖示。")
			get_viewport().set_input_as_handled()
			return
		if matching.size()==1:
			arm(matching[0].skill.action,key.ctrl_pressed)
			get_viewport().set_input_as_handled()
			return
		for action: StringName in [&"command_move", &"command_attack"]:
			if event.is_action_pressed(action):
				arm(action)
				return
		if event.is_action_pressed("command_stop"):
			dispatch("stop", Vector2.ZERO)
		elif event.is_action_pressed("command_hold"):
			dispatch("hold", Vector2.ZERO)
		elif event.is_action_pressed("select_all"):
			select_ids(director.living_ids(0), false, true)
		elif event.is_action_pressed("sequence_cast"):
			sequence_cast(director.mouse_ground())
	elif event is InputEventMouseButton and not director.hud.is_modal_open():
		var mouse: InputEventMouseButton = event
		# Use this event's position, not a later OS cursor snapshot (also works
		# with viewport-injected input and camera-transformed coordinates).
		var mouse_world: Vector2 = director.get_canvas_transform().affine_inverse() * mouse.position
		if mouse.button_index == MOUSE_BUTTON_RIGHT and mouse.pressed:
			if armed != &"":
				director.audio.feedback("cancel")
				cancel()
			else:
				var at: Vector2 = Iso.unproject(mouse_world)
				var target: TacticalUnit = director.pick_unit(mouse_world, 1)
				dispatch("attack" if target != null else "move", at, target.unit_id if target != null else -1, mouse.shift_pressed)
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				if armed_skill_id != &"":
					confirm_skill(Iso.unproject(mouse_world))
					return
				if armed != &"":
					var target: TacticalUnit = director.pick_unit(mouse_world, 1)
					dispatch("move" if armed == &"command_move" else "attack" if target != null else "attack_move", Iso.unproject(mouse_world), target.unit_id if target != null else -1, mouse.shift_pressed)
					cancel()
					return
				dragging = true
				drag_origin = mouse_world
				drag_current = drag_origin
			elif dragging:
				dragging = false
				var rect: Rect2 = Rect2(drag_origin, drag_current - drag_origin).abs()
				if drag_origin.distance_to(drag_current) > 8:
					select_box(rect, mouse.shift_pressed)
				else:
					var target: TacticalUnit = director.pick_unit(mouse_world, 0)
					var clicked_ids: Array[int] = []
					if target != null:
						clicked_ids.append(target.unit_id)
					select_ids(clicked_ids, mouse.shift_pressed, true)
				queue_redraw()
	elif event is InputEventMouseMotion:
		drag_current = director.get_canvas_transform().affine_inverse() * (event as InputEventMouseMotion).position
		queue_redraw()

func dispatch(kind: String, point: Vector2, target_id: int = -1, append: bool = false) -> void:
	if director.phases!=null and director.phases.frozen():return
	repeat_target.clear()
	var moving_ids: Array[int] = selected_ids.filter(func(id: int) -> bool: return director.get_unit(id) != null and director.get_unit(id).alive())
	var center: Vector2 = Vector2.ZERO
	for id: int in moving_ids:
		center += director.get_unit(id).position
	if not moving_ids.is_empty():
		center /= moving_ids.size()
	for id: int in moving_ids:
		var unit: TacticalUnit = director.get_unit(id)
		var offset: Vector2 = (unit.position - center).limit_length(90) if moving_ids.size() > 1 else Vector2.ZERO
		unit.issue_command({"kind":kind, "point":point + offset if kind in ["move", "attack_move"] else point, "target":target_id, "queued":append})
	if kind in ["move","attack_move"] and not moving_ids.is_empty():
		director.ground_click_feedback.play_at(Iso.project(point))
	if director.voices != null and kind in ["move", "attack", "attack_move"]:
		director.voices.acknowledge(moving_ids, &"move" if kind == "move" else &"attack")
	if kind=="attack" and not moving_ids.is_empty():
		var target: TacticalUnit = director.get_unit(target_id)
		if target != null and target.alive() and target.view != null: target.view.confirm_target()

func tick() -> void:
	# A held action is not a new target click, even with legacy settings enabled.
	repeat_target.clear()

func configure_sequence() -> void:
	sequence_entries.clear()
	sequence_slots.clear()
	for id: int in director.living_ids(0):
		for skill: SkillDefinition in director.get_unit(id).available_skills():
			if skill.manual():
				sequence_entries.append({"unit":id, "skill":skill})
				sequence_slots.append(id)
	sequence_index = 0

func _ensure_sequence() -> void:
	var current: Array[int] = []
	for entry: Dictionary in sequence_entries:
		current.append(int(entry["unit"]))
	if current == sequence_slots:
		return
	sequence_entries.clear()
	for id: int in sequence_slots:
		var unit: TacticalUnit = director.get_unit(id)
		if unit != null:
			for skill: SkillDefinition in unit.available_skills():
				if skill.manual():
					sequence_entries.append({"unit":id, "skill":skill})
					break
	sequence_index = 0

func next_sequence_label() -> String:
	_ensure_sequence()
	if sequence_entries.is_empty():
		return "尚未設定"
	var entry: Dictionary = sequence_entries[sequence_index % sequence_entries.size()]
	var unit: TacticalUnit = director.get_unit(int(entry["unit"]))
	return "%s·%s" % [unit.definition.display_name, (entry["skill"] as SkillDefinition).display_name] if unit != null else "跳過失效單位"

func sequence_cast(_point: Vector2) -> int:
	_ensure_sequence()
	if not GameSettings.profile.sequence_enabled or sequence_entries.is_empty():
		return -1
	for attempt: int in sequence_entries.size():
		var entry: Dictionary = sequence_entries[sequence_index % sequence_entries.size()]
		sequence_index = (sequence_index + 1) % sequence_entries.size()
		var unit: TacticalUnit = director.get_unit(int(entry["unit"]))
		var skill: SkillDefinition = entry["skill"]
		if unit == null or not unit.can_cast(skill):
			continue
		# E prepares the next caster, but never casts at an old cursor target.
		select_ids([unit.unit_id])
		if activate_skill(skill.id,false,true):
			return unit.unit_id
	director.message.emit("沒有可用的預約技能：請確認 MP、冷卻及目標。")
	return -1

func preview_kind() -> StringName:
	var entry: Dictionary = _entry(armed_skill_id)
	if entry.is_empty(): return &"none"
	var skill: SkillDefinition = entry["skill"]
	if skill.target_mode in [SkillDefinition.Target.ALLY,SkillDefinition.Target.ENEMY,SkillDefinition.Target.SELF]: return &"none"
	return &"wall" if skill.effect==SkillDefinition.Effect.ICE_WALL else &"lane" if skill.target_mode==SkillDefinition.Target.DIRECTION else &"area"
func _draw() -> void:
	if dragging and drag_origin.distance_to(drag_current) > 8:
		var rect: Rect2 = Rect2(drag_origin, drag_current - drag_origin).abs()
		draw_rect(rect, Color(0.72, 0.81, 0.48, 0.12))
		draw_rect(rect, Color(0.86, 0.84, 0.5), false, 1.5)
	var entry: Dictionary = _entry(armed_skill_id)
	if entry.is_empty():
		return
	var skill: SkillDefinition = entry["skill"]
	if preview_kind()==&"none": return
	var caster: TacticalUnit = director.get_unit(int(entry["owners"][0]))
	var center: Vector2 = director.get_global_mouse_position()
	if skill.effect == SkillDefinition.Effect.ICE_WALL and skill.effect_data != null:
		var point: Vector2 = director.mouse_ground()
		var valid: bool = director.validate_skill_target(caster, skill, point, -1) == ""
		for tile: Vector2i in director.ground.wall_cells(point, caster.position.direction_to(point), skill.effect_data.wall_length):
			var corners: PackedVector2Array = PackedVector2Array()
			for offset: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2.ONE, Vector2(0, 1)]:
				corners.append(Iso.project((Vector2(tile) + offset) * Iso.CELL))
			draw_colored_polygon(corners, Color(0.5, 0.8, 1, 0.4) if valid else Color(1, 0.2, 0.15, 0.4))
	elif skill.target_mode == SkillDefinition.Target.DIRECTION:
		var direction: Vector2 = caster.position.direction_to(director.mouse_ground())
		var length: float = skill.effect_data.distance
		if skill.battlefield_range: length=Vector2(director.ground.cells).length()*Iso.CELL
		var side: Vector2 = direction.orthogonal() * skill.effect_data.width * 0.5
		var corners: PackedVector2Array = PackedVector2Array([Iso.project(caster.position + side), Iso.project(caster.position + direction * length + side), Iso.project(caster.position + direction * length - side), Iso.project(caster.position - side)])
		draw_colored_polygon(corners, Color(1, 0.6, 0.15, 0.2))
	else:
		draw_set_transform(Iso.project(caster.position), 0, Iso.CIRCLE_SCALE)
		draw_arc(Vector2.ZERO, skill.range, 0, TAU, 64, Color(0.73, 0.75, 0.44, 0.30), 1)
		draw_set_transform(center, 0, Iso.CIRCLE_SCALE)
		draw_arc(Vector2.ZERO, maxf(18, skill.radius), 0, TAU, 48, Color(0.95, 0.84, 0.44, 0.8), 2)
		draw_set_transform(Vector2.ZERO)
