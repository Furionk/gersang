extends SceneTree
## Finish this request's initial native presets. Refuses any subsequent run.
func _initialize()->void:call_deferred("run")
func run()->void:
	const MARK:String="res://artifacts/combat-empower-2026-10-13/presets-complete.json"
	if FileAccess.file_exists(MARK):push_error("Preset completion already applied; refuses overwrite.");quit(1);return
	for name:String in DirAccess.get_files_at("res://features/units/data/monsters"):
		if not name.ends_with(".tres"):continue
		var unit:UnitDefinition=load("res://features/units/data/monsters/"+name);unit.minimum_ai_cast_time=0.4
		assert(ResourceSaver.save(unit,unit.resource_path)==OK)
	var seen:Dictionary={}
	for name:String in DirAccess.get_files_at("res://features/units/data/mercenaries"):
		if not name.ends_with(".tres"):continue
		var unit:UnitDefinition=load("res://features/units/data/mercenaries/"+name)
		for skill:SkillDefinition in unit.skills:
			if seen.has(skill.resource_path):continue
			seen[skill.resource_path]=true
			if skill.effect==SkillDefinition.Effect.CRITICAL:skill.proc_chance=maxf(skill.proc_chance,0.3)
			if skill.effect==SkillDefinition.Effect.LIFE_STEAL:skill.life_steal_ratio=minf(0.75,skill.life_steal_ratio*1.5);skill.proc_chance=maxf(skill.proc_chance,0.4)
			var data:SkillEffectDefinition=skill.effect_data
			if data!=null:
				if data.kind==SkillEffectDefinition.Kind.BUFF:
					data.attack_multiplier=maxf(1.0,data.attack_multiplier*1.3);data.attack_speed_multiplier=maxf(1.0,data.attack_speed_multiplier*1.3)
					data.attack_range_bonus*=1.4;data.attack_bonus*=1.5
				if data.kind==SkillEffectDefinition.Kind.STEALTH:
					data.reveal_attack_formula="("+data.reveal_attack_formula+")*1.75";data.movement_multiplier=minf(3.0,data.movement_multiplier*1.15)
				if data.kind==SkillEffectDefinition.Kind.BARRIER:data.wall_length*=1.25
			assert(ResourceSaver.save(skill,skill.resource_path)==OK)
	var file:FileAccess=FileAccess.open(MARK,FileAccess.WRITE);file.store_string(JSON.stringify({"finished":true,"minimum_enemy_windup":0.4,"player_immediate_skills_unchanged":true}));file.close();print("EMPOWER_PRESETS_COMPLETE");quit()
