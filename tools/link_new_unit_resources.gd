extends SceneTree
## Complete this batch's canonical Resource links; never touch older content.
var failed: bool=false
const DIRECTORY: String="res://artifacts/new-units-2026-10-11/"
func _initialize() -> void: call_deferred("run")
func save_resource(resource: Resource, path: String) -> void:
	if ResourceSaver.save(resource,path,ResourceSaver.FLAG_CHANGE_PATH)!=OK: failed=true; push_error("Cannot save canonical link: "+path)
func run() -> void:
	if FileAccess.file_exists(DIRECTORY+"links-completed.json"):
		push_error("Canonical links already authored; edit Resources directly."); quit(1); return
	var layouts: Dictionary={}
	for id: String in ["kohime","ninja","teppo","earth_claw"]:
		layouts[id]=load("res://features/units/data/layouts/"+id+"_layout.tres")
	var skill_ids: Dictionary={"kohime":["earth_stakes","earth_claw"],"ninja":["ninja_stealth","ninja_fire_trail","ninja_chain"],"teppo":["teppo_sniper","teppo_comrades","teppo_triple"]}
	var skills: Dictionary={}
	for list: Array in skill_ids.values():
		for id: String in list: skills[id]=load("res://features/skills/data/"+id+".tres")
	var stab: SkillDefinition=load("res://features/skills/data/claw_strike.tres")
	var claw: UnitDefinition=load("res://features/units/data/summons/earth_claw.tres")
	claw.sprite_layout=layouts.earth_claw; claw.skills=[stab]
	save_resource(claw,claw.resource_path)
	var companion: UnitDefinition=load("res://features/units/data/summons/teppo_companion.tres")
	companion.sprite_layout=layouts.teppo
	save_resource(companion,companion.resource_path)
	skills.earth_claw.effect_data.summon_definition=claw
	skills.teppo_comrades.effect_data.summon_definition=companion
	for id: String in skills: save_resource(skills[id],"res://features/skills/data/"+id+".tres")
	for id: String in skill_ids:
		var ally: UnitDefinition=load("res://features/units/data/mercenaries/"+id+".tres")
		ally.sprite_layout=layouts[id]; ally.skills.clear()
		for skill_id: String in skill_ids[id]: ally.skills.append(skills[skill_id])
		save_resource(ally,ally.resource_path)
		var enemy: UnitDefinition=load("res://features/units/data/monsters/"+id+"_enemy.tres")
		enemy.sprite_layout=layouts[id]; enemy.skills.clear()
		for skill_id: String in skill_ids[id]:
			var npc_skill: SkillDefinition=skills[skill_id].duplicate() as SkillDefinition
			npc_skill.id=StringName("enemy_"+skill_id)
			npc_skill.ai_enabled=true; npc_skill.ai_cast_chance=0.4; npc_skill.ai_attempt_interval=5.0
			save_resource(npc_skill,"res://features/skills/data/enemy_"+skill_id+".tres")
			enemy.skills.append(npc_skill)
		save_resource(enemy,enemy.resource_path)
	var wild: UnitDefinition=load("res://features/units/data/monsters/earth_claw_enemy.tres")
	wild.sprite_layout=layouts.earth_claw; wild.skills=[stab]
	save_resource(wild,wild.resource_path)
	if not failed:
		var report: FileAccess=FileAccess.open(DIRECTORY+"links-completed.json",FileAccess.WRITE)
		report.store_string(JSON.stringify({"canonical_external_links":true,"enemy_skill_resources":8})); report.close()
	print("NEW_UNIT_LINKS_RESULT ok=",not failed)
	quit(1 if failed else 0)
