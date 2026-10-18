extends SceneTree
const SKILLS: String="res://features/skills/data/"
const UNITS: String="res://features/units/data/monsters/"
func save_new(resource: Resource, path: String) -> void:
	assert(not FileAccess.file_exists(path),"Preserve authored resource: "+path)
	assert(ResourceSaver.save(resource,path)==OK)
func leech(id: String, ratio: float) -> SkillDefinition:
	var skill: SkillDefinition=SkillDefinition.new()
	skill.id=StringName(id); skill.display_name="湖血吞噬"; skill.effect=SkillDefinition.Effect.LIFE_STEAL
	skill.trigger=SkillDefinition.Trigger.ATTACK_HIT; skill.mana_cost=0; skill.proc_chance=1; skill.life_steal_ratio=ratio
	skill.damage_formula="0"; skill.action=StringName("skill_"+id)
	skill.description="按實際命中扣除HP的%.0f%%恢復自身體力；不吸取MISS或過量傷害。"%(ratio*100)
	save_new(skill,SKILLS+id+".tres"); return skill
func charge(id: String, multiplier: float, speed: float, distance: float, width: float, air: bool) -> SkillDefinition:
	var skill: SkillDefinition=SkillDefinition.new()
	skill.id=StringName(id); skill.display_name="真・衝鋒" if air else "千年疾衝"
	skill.effect=SkillDefinition.Effect.CHARGE; skill.target_mode=SkillDefinition.Target.ENEMY
	skill.ai_enabled=true; skill.ai_attempt_interval=5; skill.ai_cast_chance=0.8 if air else 0.65
	skill.mana_cost=0; skill.range=distance; skill.damage_formula="attack*"+str(multiplier)
	skill.damage_type=CombatMath.Kind.PHYSICAL; skill.tint=Color(0.15,0.85,1)
	skill.action=StringName("skill_"+id)
	skill.description="鎖定釋放時方向，實際衝向敵人，沿途每個敌人只受一次%.1f倍攻擊傷害。%s"%[multiplier,"飛行穿越地面阻擋。" if air else "地面阻擋／冰牆可中止衝鋒，僅命中地面敵軍。"]
	var data: SkillEffectDefinition=SkillEffectDefinition.new(); data.kind=SkillEffectDefinition.Kind.CHARGE
	data.speed=speed; data.distance=distance; data.width=width; data.ground_targets_only=not air; data.sprite_path=""
	skill.effect_data=data; save_new(skill,SKILLS+id+".tres"); return skill
func unit(id: String, name_text: String, hp: float, attack: float, defense: float, speed: float, range_value: float, interval: float, air: bool, reward: int, skills: Array[SkillDefinition]) -> UnitDefinition:
	var data: UnitDefinition=UnitDefinition.new()
	data.id=StringName(id); data.display_name=name_text; data.max_health=hp; data.damage=attack; data.defense=defense
	data.speed=speed; data.attack_range=range_value; data.attack_interval=interval
	data.movement_type=UnitDefinition.Movement.AIR if air else UnitDefinition.Movement.GROUND
	data.max_mana=0; data.controllable=false; data.role=9; data.detection_range=550; data.experience_reward=reward; data.base_power=450
	data.sprite_path="res://features/units/art/"+id+"-v1.png"
	data.sprite_layout=load("res://features/units/data/layouts/"+id+"_layout.tres")
	data.skills=skills
	return data
func _initialize() -> void:
	var vamp: SkillDefinition=leech("lake_worm_leech",0.25)
	var clone: UnitDefinition=unit("millennium_worm","千年蟲・分身",550,55,15,115,55,1.1,false,0,[vamp])
	clone.id=&"millennium_worm_clone"; clone.visual_scale=0.7
	save_new(clone,UNITS+"millennium_worm_clone.tres")
	var split: SkillDefinition=SkillDefinition.new(); split.id=&"lake_worm_split"; split.action=&"skill_lake_worm_split"
	split.display_name="蟲影分身"; split.effect=SkillDefinition.Effect.SUMMON; split.trigger=SkillDefinition.Trigger.ATTACK_HIT
	split.proc_chance=0.35; split.mana_cost=0; split.damage_formula="0"
	split.description="普攻命中35%機率產生一隻同級分身，最多同時2隻、18秒；分身吸血但不再分裂，無額外獎勵。"
	var split_data: SkillEffectDefinition=SkillEffectDefinition.new(); split_data.kind=SkillEffectDefinition.Kind.SUMMON
	split_data.duration=18; split_data.summon_definition=clone; split_data.summon_inherit_level=true; split_data.summon_limit=2; split_data.summon_controllable=false
	split_data.sprite_path="res://features/skills/art/summon.png"; split.effect_data=split_data
	save_new(split,SKILLS+"lake_worm_split.tres")
	var worm: UnitDefinition=unit("millennium_worm","千年蟲",1800,95,25,95,60,1.2,false,350,[split,vamp])
	save_new(worm,UNITS+"millennium_worm.tres")
	var flame: SkillDefinition=SkillDefinition.new(); flame.id=&"lake_bird_flame"; flame.action=&"skill_lake_bird_flame"
	flame.display_name="焚湖火羽"; flame.effect=SkillDefinition.Effect.ATTACK_FLAME; flame.trigger=SkillDefinition.Trigger.ATTACK_HIT
	flame.proc_chance=1; flame.mana_cost=0; flame.radius=100; flame.damage_formula="attack*0.6"
	flame.description="遠距普攻命中後，在目標位置留下1.6秒火焰，半徑100、每0.4秒造成攻擊×0.6法術傷害。"
	var fire: SkillEffectDefinition=SkillEffectDefinition.new(); fire.kind=SkillEffectDefinition.Kind.FLAME
	fire.duration=1.6; fire.tick_interval=0.4; fire.radius=100; fire.sprite_path="res://features/skills/art/fire-trail-v2.png"
	flame.effect_data=fire; save_new(flame,SKILLS+"lake_bird_flame.tres")
	var bird: UnitDefinition=unit("millennium_bird","千年鳥",1600,120,25,125,360,1.5,true,450,[flame])
	save_new(bird,UNITS+"millennium_bird.tres")
	var wolf_charge: SkillDefinition=charge("lake_wolf_charge",3.2,750,700,95,false)
	var wolf: UnitDefinition=unit("millennium_wolf","千年狼",2600,150,40,145,65,1.1,false,650,[wolf_charge])
	save_new(wolf,UNITS+"millennium_wolf.tres")
	var true_charge: SkillDefinition=charge("lake_lord_charge",4.2,1000,1100,150,true)
	var lord_vamp: SkillDefinition=leech("lake_lord_leech",0.45)
	var lord: UnitDefinition=unit("millennium_lord","千年湖主",22000,380,130,175,380,1.0,true,6000,[true_charge,lord_vamp])
	lord.level=99; lord.role=10; lord.base_power=5000; lord.visual_scale=1.25; lord.armor=0.35; lord.magic_resistance=0.25
	save_new(lord,UNITS+"millennium_lord.tres")
	quit()
