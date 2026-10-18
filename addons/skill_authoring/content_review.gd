@tool
extends RefCounted
## Read-only diagnostics. Never writes definitions, IDs, saves or maps.
static func unit_issues(data: UnitDefinition) -> PackedStringArray:
	var result: PackedStringArray=PackedStringArray()
	if data.id==&"": result.append("兵種ID不可留空；新種類需獨立ID。")
	if data.display_name.is_empty(): result.append("顯示名稱未設定。")
	for field: String in ["max_health","max_mana","damage","attack_range","attack_interval","speed","strength","agility","intelligence","luck","vitality"]:
		var value: float=float(data.get(field))
		if not is_finite(value) or value<0 or (field in ["max_health","attack_interval","speed"] and value<=0): result.append(field+"需要合法非負數值（HP／間隔／速度必須大於0）。")
	var texture: Texture2D=SpriteAtlas.texture_for(data)
	if texture==null: result.append("未找到角色Sprite原圖；可設Sprite Layout → Source Texture。")
	elif data.sprite_layout!=null: result.append_array(data.sprite_layout.issues_for(Vector2i(texture.get_size())))
	else: result.append("未設定Sprite Layout：目前沿用舊6×8等分。新素材建議建立切图Resource。")
	var ids: Dictionary={}; var keys: Dictionary={}; var actions: Dictionary={}
	for skill: SkillDefinition in data.skills:
		if skill==null: result.append("Skills有空資源。"); continue
		if ids.has(skill.id): result.append("Skills重複ID："+str(skill.id))
		ids[skill.id]=true
		if skill.manual():
			if skill.action==&"" or actions.has(skill.action): result.append("手動技能Action留空／重複："+str(skill.action))
			actions[skill.action]=true
			if skill.default_key!=KEY_NONE and keys.has(skill.default_key): result.append("同兵快捷鍵衝突："+OS.get_keycode_string(skill.default_key))
			keys[skill.default_key]=true
		var formula: Dictionary=skill.result(template_stats(data,data.level))
		if not formula.valid: result.append(skill.display_name+"公式錯誤："+str(formula.error))
	return result
static func template_stats(data: UnitDefinition,level: int) -> Dictionary:
	return CombatStats.calculate(data,{"strength":data.strength,"agility":data.agility,"vitality":data.vitality,"intelligence":data.intelligence,"luck":data.luck},level)
static func item_issues(item: GearItemDefinition) -> PackedStringArray:
	var result: PackedStringArray=PackedStringArray()
	if item.id==&"": result.append("物品ID不可留空。")
	if item.max_stack<=0 or not is_finite(item.weight) or item.weight<0: result.append("堆疊上限／重量無效。")
	if item.kind==GearItemDefinition.Kind.EQUIPMENT and item.equipment_slot not in range(GearItemDefinition.SLOT_NAMES.size()): result.append("裝備欄位無效。")
	if item.icon==null: result.append("未設定圖示。")
	return result
