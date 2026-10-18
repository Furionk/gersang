class_name SkillDescription
extends RefCounted
const NAMES: Dictionary = {"strength":"力量","agility":"敏捷","intelligence":"智力","luck":"幸運","vitality":"體質","level":"等級","attack":"攻擊力"}
const EFFECTS: Dictionary = {
	SkillDefinition.Effect.BLAST:"以施放位置為中心向外連續爆雷；每個敵人每次施放最多命中一次。",
	SkillDefinition.Effect.LIGHTNING:"指定地面範圍雷擊，命中範圍內敵人。",
	SkillDefinition.Effect.SUPPLY:"指定友軍補充法力；不能超過目標法力上限。",
	SkillDefinition.Effect.CONTROL:"指定範圍造成傷害並控制敵人，暫停其行動。",
	SkillDefinition.Effect.HEAL:"指定友軍恢復體力；可右鍵技能圖示開關周遭友軍自動治療，不能超過上限。",
	SkillDefinition.Effect.CRITICAL:"普攻命中時依機率觸發，以公式結果取代該次普通攻擊傷害。",
	SkillDefinition.Effect.QUAKE:"指定地面震動、持續傷害；結束時對範圍內敵人施加減速。",
	SkillDefinition.Effect.WHEEL:"指定敵人，車輪跟隨目標並持續切割範圍內敵人；目標死亡時結束。",
	SkillDefinition.Effect.DRAGON:"向指定方向射出火龍；火龍與拖尾範圍持續造成傷害。",
	SkillDefinition.Effect.SUMMON:"召喚可控制、自動射箭的箭魂；每名施法者最多一隻。",
	SkillDefinition.Effect.ICE_WALL:"在地點建立垂直於施法方向的冰牆，阻擋地面單位；不造成傷害。"
}

static func owned(record: CharacterRecord) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var ids: Dictionary = {}
	for skill: SkillDefinition in record.definition.skills:
		if skill == null or ids.has(skill.id): continue
		ids[skill.id] = true
		entries.append({"skill":skill,"origin":"兵種技能"})
	for slot: StringName in record.equipment:
		var item: GearItemDefinition = ItemCatalog.get_item(record.equipment[slot])
		if item == null: continue
		for skill: SkillDefinition in item.granted_skills:
			if skill == null or ids.has(skill.id): continue
			ids[skill.id] = true
			entries.append({"skill":skill,"origin":"裝備 · "+item.display_name})
	return entries

static func formula_values(skill: SkillDefinition, stats: Dictionary) -> String:
	var text: String = DamageFormula.normalize(skill.damage_formula)
	var regex: RegEx = RegEx.new()
	regex.compile("[A-Za-z_][A-Za-z_0-9]*")
	var found: Array[RegExMatch] = regex.search_all(text)
	for i: int in range(found.size()-1,-1,-1):
		var token: RegExMatch = found[i]
		if stats.has(token.get_string()):
			var value: float = snappedf(float(stats[token.get_string()]),0.01)
			var number: String = str(int(value)) if is_equal_approx(value,roundf(value)) else str(value)
			text = text.substr(0,token.get_start())+number+text.substr(token.get_end())
	return text

static func calculation(skill: SkillDefinition, stats: Dictionary, preview: Dictionary) -> String:
	if skill.effect_data!=null and skill.effect_data.kind==SkillEffectDefinition.Kind.HEALTH_BURST:
		var ratio: Dictionary=DamageFormula.evaluate(skill.effect_data.target_max_hp_ratio_formula,stats)
		if not ratio.valid: return "最大HP倍率公式無效"
		return "每目標最大HP × %.1f%%\n倍率公式：%s\n法抗照常套用；暴擊呈現不額外乘兩次。"%[float(ratio.value)*100,skill.effect_data.target_max_hp_ratio_formula]
	if skill.effect_data!=null and skill.effect_data.kind==SkillEffectDefinition.Kind.CURSE:
		var slow: Dictionary=DamageFormula.evaluate(skill.effect_data.slow_percent_formula,stats)
		var duration: Dictionary=skill.effect_data.resolved_duration(stats)
		if not slow.valid or not duration.valid: return "詛咒公式無效"
		return "每%.1f秒傷害：%s\n減速 %.1f%%；持續 %.1f秒\n命中時附著敵人，離開原範圍仍持續；同技能重施刷新、不疊減速。"%[skill.effect_data.tick_interval,skill.damage_formula,clampf(float(slow.value),0,skill.effect_data.slow_percent_cap)*100,duration.value]
	if skill.effect==SkillDefinition.Effect.ICE_WALL: return "冰牆：阻擋地面移動，不造成傷害。"
	if skill.effect==SkillDefinition.Effect.SUMMON:
		var summon: Dictionary = SummonScaling.preview_stats(skill.effect_data,stats)
		if summon.is_empty(): return "召喚加成公式無效。"
		var name_text: String=(skill.effect_data.summon_definition as UnitDefinition).display_name
		return "%s體力 %.0f、防禦 %.1f–%.1f\n攻擊 %.1f–%.1f\n命中 %.0f–%.0f（對抗敵人閃避）\n攻擊加成：%s\n智慧加成：%s\n體力加成：%s\n防禦加成：%s\n召喚上限：%s\n使用釋放時能力快照；魔爪刺擊依自身技能公式。" % [name_text,summon.health,summon.defense_min,summon.defense_max,summon["attack_min"],summon["attack_max"],summon["accuracy_min"],summon["accuracy_max"],skill.effect_data.summon_attack_bonus_formula,skill.effect_data.summon_intelligence_bonus_formula,skill.effect_data.summon_health_bonus_formula,skill.effect_data.summon_defense_bonus_formula,"無上限" if skill.effect_data.summon_limit==0 else str(skill.effect_data.summon_limit)]
	if skill.effect_data!=null and skill.effect_data.kind in [SkillEffectDefinition.Kind.BUFF,SkillEffectDefinition.Kind.STEALTH]:
		var duration: Dictionary=skill.effect_data.resolved_duration(stats)
		if not duration.valid: return "持續公式無效："+str(duration.error)
		if skill.effect_data.kind==SkillEffectDefinition.Kind.STEALTH: return "隱身 %.1f秒；現身首擊額外公式：%s" % [duration.value,skill.effect_data.reveal_attack_formula]
		return "持續 %.1f秒\n攻擊：(%s + %.0f) × %.2f\n攻速 × %.2f、射程 +%.0f\n同技能重施刷新，不疊乘。" % [duration.value,str(stats.get("attack",0)),skill.effect_data.attack_bonus,skill.effect_data.attack_multiplier,skill.effect_data.attack_speed_multiplier,skill.effect_data.attack_range_bonus]
	var result: Dictionary = skill.result(stats)
	if not result["valid"]: return "公式無效："+str(result["error"])
	var base: float = result["value"]
	var restore: bool = skill.effect in [SkillDefinition.Effect.HEAL,SkillDefinition.Effect.SUPPLY]
	var text: String = "%s：%s\n代入 %s = %.2f\n" % ["回復公式" if restore else "每次命中／tick",skill.damage_formula if skill.damage_formula!="" else str(skill.power),formula_values(skill,stats) if skill.damage_formula!="" else str(skill.power),base]
	if restore: return text+"回復最多至目標上限，不套用減傷。"
	if skill.damage_type==CombatMath.Kind.MAGIC:
		var resist: float = clampf(float(preview.get("magic_resistance",0)),0,0.9)
		return text+"法抗 %.0f%% → 傷害 %.2f" % [resist*100,base*(1-resist)]
	var defense: float = maxf(0,float(preview.get("defense",0)))
	var armor: float = clampf(float(preview.get("armor",0)),0,0.9)
	return text+"防禦 %.0f／物抗 %.0f%% → %.2f" % [defense,armor*100,DamageFormula.mitigate(maxf(0,base-defense),armor)]

static func describe(skill: SkillDefinition, stats: Dictionary, origin: String, preview: Dictionary) -> String:
	var manual: String = "手動施放" if skill.manual() else "被動 · 普攻觸發" if skill.trigger == SkillDefinition.Trigger.ATTACK_HIT else "自動支援"
	var target: String = ["點地面","即時自身技","指定友軍","指定敵人","指定方向"][skill.target_mode]
	if skill.target_mode==SkillDefinition.Target.SELF: target = "按鍵／圖示立即施放，以自身為中心" if skill.instant_self_activation else "左鍵確認，以自身為中心"
	var text: String = "%s\n%s · %s\n來源：%s\n\n%s\n\nMP %.0f  冷卻 %.2f 秒\n射程 %.0f  範圍 %.0f\n" % [skill.display_name,manual,target,origin,skill.description if skill.description != "" else EFFECTS.get(skill.effect,""),skill.mana_cost,skill.cooldown,skill.range,skill.radius]
	var data: SkillEffectDefinition = skill.effect_data
	if skill.battlefield_range: text=text.replace("射程 %.0f"%skill.range,"射程 全戰場")
	if skill.supports_autocast(): text += "右鍵戰鬥圖示：切換自動施法；左鍵仍可手動指定。\n"
	if data != null:
		var actual_duration: Dictionary=data.resolved_duration(stats)
		text += "效果 %.2f 秒" % float(actual_duration.value) if actual_duration.valid else "持續公式無效"
		if data.kind in [SkillEffectDefinition.Kind.QUAKE,SkillEffectDefinition.Kind.FOLLOW,SkillEffectDefinition.Kind.LINE,SkillEffectDefinition.Kind.STAKES,SkillEffectDefinition.Kind.FIRE_TRAIL,SkillEffectDefinition.Kind.CHAIN]: text += " · 每 %.2f 秒一跳" % data.tick_interval
		text += "\n"
		if data.kind == SkillEffectDefinition.Kind.QUAKE: text += "減速 %.0f%%，持續 %.1f 秒\n" % [(1-data.slow_factor)*100,data.slow_duration]
		if data.kind == SkillEffectDefinition.Kind.BARRIER: return text+"牆長 %.0f；不造成傷害。\n藍色範圍與實際阻擋格依放置是否合法決定。" % data.wall_length
		if data.kind == SkillEffectDefinition.Kind.SUMMON:
			var definition: UnitDefinition = data.summon_definition as UnitDefinition
			return text+("%s ×%d–%d，%s，HP %.0f、射程 %.0f。\n攻擊加成：%s\n命中加成：%s\n%s\n一般召喚物走普通攻擊／命中／防禦流程；魔爪刺擊使用其Skills中的智慧範圍公式。" % [definition.display_name,data.summon_count_min,data.summon_count_max,"可選控" if data.summon_controllable else "自主／不能選控",definition.max_health,definition.attack_range,data.summon_attack_bonus_formula,data.summon_accuracy_bonus_formula,calculation(skill,stats,preview)] if definition != null else "召喚資料未設定。")
		if data.kind in [SkillEffectDefinition.Kind.BUFF,SkillEffectDefinition.Kind.STEALTH]: return text+calculation(skill,stats,preview)
	var result: Dictionary = skill.result(stats)
	var is_restore: bool = skill.effect in [SkillDefinition.Effect.HEAL,SkillDefinition.Effect.SUPPLY]
	text += "\n%s公式：%s\n" % ["回復" if is_restore else "基礎傷害",skill.damage_formula if skill.damage_formula != "" else str(skill.power)]
	if not result["valid"]: return text+"公式無效："+str(result["error"])
	var power: float = result["value"]
	text += "目前代入：%s = %.2f\n" % [formula_values(skill,stats) if skill.damage_formula != "" else str(skill.power),power]
	if is_restore: return text+"對合法友軍回復，最多至其 HP／MP 上限，不套用敵方減傷。"
	if skill.trigger == SkillDefinition.Trigger.ATTACK_HIT: text += "觸發機率 %.1f%%；取代該次傷害，不再額外加倍。\n" % (skill.proc_chance*100)
	if skill.damage_type == CombatMath.Kind.MAGIC:
		var resistance: float = clampf(float(preview.get("magic_resistance",0)),0,0.9)
		text += "法術：基礎 × (1 − 敵方法抗)\n試算 %.0f%% 法抗 → %.2f / 每次命中\n" % [resistance*100,power*(1-resistance)]
	else:
		var defense: float = maxf(0,float(preview.get("defense",0)))
		var armor: float = clampf(float(preview.get("armor",0)),0,0.9)
		text += "物理：max(0,基礎 − 隨機防禦) × (1 − 物抗)\n試算防禦 %.0f、物抗 %.0f%% → %.2f\n" % [defense,armor*100,DamageFormula.mitigate(maxf(0,power-defense),armor)]
	text += "傷害以每次命中／tick 計，不是整段技能總傷害。"
	return text
