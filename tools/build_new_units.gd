extends SceneTree
## One-shot content authoring. Refuses to replace existing designer Resources.
var failed: bool=false
func _initialize() -> void: call_deferred("run")
func save_new(resource: Resource, path: String) -> void:
	if FileAccess.file_exists(path): push_error("New content already exists; refusing overwrite: "+path); failed=true; return
	var error: Error=ResourceSaver.save(resource,path,ResourceSaver.FLAG_CHANGE_PATH)
	if error!=OK: push_error("Cannot save "+path); failed=true
func make_layout(id: String) -> SpriteSheetLayout:
	var path: String="res://features/units/art/"+id+".png"
	var image: Image=Image.load_from_file(ProjectSettings.globalize_path(path))
	var layout: SpriteSheetLayout=SpriteSheetLayout.new()
	layout.source_size=image.get_size()
	layout.frame_size=Vector2i(256,256)
	layout.foot_point=Vector2(128,224)
	for row: int in 8:
		var first: Rect2i=Rect2i(Vector2i(0,row*image.get_height()/8),Vector2i(image.get_width()/6,image.get_height()/8))
		var idle: Rect2i=image.get_region(first).get_used_rect()
		var foot_y: float=first.position.y+idle.end.y-2
		for column: int in 6:
			var start: Vector2i=Vector2i(column*image.get_width()/6,row*image.get_height()/8)
			var end: Vector2i=Vector2i((column+1)*image.get_width()/6,(row+1)*image.get_height()/8)
			var bounds: Rect2i=Rect2i(start,end-start)
			var used: Rect2i=image.get_region(bounds).get_used_rect()
			var rect: Rect2i=Rect2i(start+used.position,used.size)
			layout.frame_rects.append(rect)
			layout.source_pivots.append(Vector2(start.x+bounds.size.x*0.5,foot_y)-Vector2(rect.position))
	# Leftward art uses the intact right-facing source, including firing direction.
	if id in ["kohime","ninja","teppo"]:
		layout.direction_rows=[0,1,2,1,0,7,6,7]
		layout.mirrored_directions=[false,false,false,true,true,true,false,false]
	save_new(layout,"res://features/units/data/layouts/"+id+"_layout.tres")
	return layout
func unit(id: String, name_text: String, stats: Dictionary, layout: SpriteSheetLayout) -> UnitDefinition:
	var result: UnitDefinition=UnitDefinition.new()
	result.id=StringName(id); result.display_name=name_text
	result.sprite_path="res://features/units/art/"+id+".png"
	result.sprite_layout=layout
	for field: String in stats: result.set(field,stats[field])
	return result
func skill(id: String, name_text: String, effect: int, kind: int, target: int, key: int, formula: String, fields: Dictionary, detail: Dictionary, description: String) -> SkillDefinition:
	var result: SkillDefinition=SkillDefinition.new()
	result.id=StringName(id); result.display_name=name_text; result.description=description
	result.effect=effect; result.target_mode=target; result.default_key=key
	result.action=StringName("skill_"+id); result.damage_formula=formula
	result.cooldown=0; result.cast_time=0
	result.effect_data=SkillEffectDefinition.new(); result.effect_data.kind=kind
	for field: String in fields: result.set(field,fields[field])
	for field: String in detail: result.effect_data.set(field,detail[field])
	save_new(result,"res://features/skills/data/"+id+".tres")
	return result
func run() -> void:
	var target: String="res://features/units/data/mercenaries/kohime.tres"
	if FileAccess.file_exists(target): push_error("Authoring already done. Edit the native Resources; do not rerun builder."); quit(1); return
	var kohime_layout: SpriteSheetLayout=make_layout("kohime")
	var ninja_layout: SpriteSheetLayout=make_layout("ninja")
	var teppo_layout: SpriteSheetLayout=make_layout("teppo")
	var claw_layout: SpriteSheetLayout=make_layout("earth_claw")
	var stab: SkillDefinition=skill("claw_strike","大地刺擊",SkillDefinition.Effect.CLAW_STRIKE,SkillEffectDefinition.Kind.INSTANT,SkillDefinition.Target.ENEMY,KEY_NONE,"15+intelligence*1.4",{"trigger":SkillDefinition.Trigger.ATTACK_HIT,"mana_cost":0.0,"radius":70.0,"proc_chance":1.0,"icon_index":6},{"sprite_path":"res://features/skills/art/quake.png","duration":0.35},"大地魔爪每次普通刺擊，以目標為中心對地面敵軍造成智慧範圍傷害；不額外再加一次普通傷害。")
	var claw: UnitDefinition=unit("earth_claw","大地魔爪",{"max_health":420.0,"max_mana":0.0,"intelligence":0.0,"damage":0.0,"attack_range":65.0,"attack_interval":1.2,"speed":90.0,"detection_range":350.0,"controllable":false,"random_nearby_target":true},claw_layout)
	claw.skills=[stab]
	save_new(claw,"res://features/units/data/summons/earth_claw.tres")
	var teppo_companion: UnitDefinition=unit("teppo","鐵炮群眾",{"max_health":260.0,"max_mana":0.0,"damage":20.0,"attack_range":270.0,"attack_interval":1.25,"speed":124.0},teppo_layout)
	teppo_companion.id=&"teppo_companion"
	save_new(teppo_companion,"res://features/units/data/summons/teppo_companion.tres")
	var stakes: SkillDefinition=skill("earth_stakes","地樁突襲",SkillDefinition.Effect.STAKES,SkillEffectDefinition.Kind.STAKES,SkillDefinition.Target.GROUND,KEY_Z,"12+intelligence*0.35",{"mana_cost":55.0,"range":300.0,"radius":120.0,"duration":10.0,"icon_index":6},{"duration":10.0,"tick_interval":0.5,"radius":120.0,"sprite_path":"res://features/skills/art/earth_stakes.png"},"指定地面範圍召喚地樁，持續10秒。每0.5秒對範圍內地面敵軍造成12+智慧×0.35法術傷害；飛行單位不受影響。")
	var summon_claw: SkillDefinition=skill("earth_claw","大地魔爪",SkillDefinition.Effect.SUMMON,SkillEffectDefinition.Kind.SUMMON,SkillDefinition.Target.SELF,KEY_X,"0",{"mana_cost":70.0,"radius":350.0,"instant_self_activation":true,"icon_index":5},{"summon_definition":claw,"summon_intelligence_bonus_formula":"intelligence","summon_controllable":false,"summon_limit":1,"duration":30.0,"sprite_path":"res://features/skills/art/summon.png"},"按X／圖示立即召喚一隻不能控制的大地魔爪，持續30秒。隨機尋找周遭敵人刺擊，每次刺擊對地面敵軍造成15+釋放時智慧×1.4範圍傷害。同一施法者最多一隻。")
	var stealth: SkillDefinition=skill("ninja_stealth","迷蹤步",SkillDefinition.Effect.STEALTH,SkillEffectDefinition.Kind.STEALTH,SkillDefinition.Target.SELF,KEY_J,"0",{"mana_cost":45.0,"radius":0.0,"icon_index":3},{"duration":20.0,"movement_multiplier":1.2,"reveal_attack_formula":"90+agility*1.5"},"進入隱身最多20秒，移速+20%。攻擊或施法現身；攻擊現身的第一擊額外造成90+敏捷×1.5普通傷害。隱身不可被敵人重新選為攻擊目標；範圍技能仍可命中。")
	var trail: SkillDefinition=skill("ninja_fire_trail","忍法．熾烈之徑",SkillDefinition.Effect.FIRE_TRAIL,SkillEffectDefinition.Kind.FIRE_TRAIL,SkillDefinition.Target.SELF,KEY_K,"20+agility*0.4",{"mana_cost":55.0,"radius":42.0,"icon_index":8},{"duration":15.0,"tick_interval":1.0,"radius":42.0,"trail_spacing":32.0,"trail_point_lifetime":3.0},"啟用15秒，經過的地方留下3秒火焰。每秒對碰到火路的地面敵軍造成20+敏捷×0.4法術傷害；同一施放的重疊火点只計一次。")
	var chain: SkillDefinition=skill("ninja_chain","忍法密傳．四方導雷",SkillDefinition.Effect.CHAIN_LIGHTNING,SkillEffectDefinition.Kind.CHAIN,SkillDefinition.Target.ENEMY,KEY_L,"35+agility*1.2+intelligence*0.5",{"mana_cost":75.0,"range":300.0,"radius":0.0,"icon_index":9},{"duration":4.0,"tick_interval":1.0,"chain_targets":4,"chain_jump_range":180.0,"chain_damage_multiplier":0.85,"hit_control_duration":0.35},"指定敵軍，每秒放出一輪串連閃電，共4輪。每輪最多串連4個不同敵人，跳距180，基礎傷害35+敏捷×1.2+智慧×0.5，每跳保留85%，每次命中控制0.35秒。主目標死亡則結束。")
	var sniper: SkillDefinition=skill("teppo_sniper","狙擊模式",SkillDefinition.Effect.BUFF,SkillEffectDefinition.Kind.BUFF,SkillDefinition.Target.SELF,KEY_N,"0",{"mana_cost":35.0,"icon_index":2},{"duration":8.0,"attack_range_bonus":180.0,"attack_bonus":30.0},"進入8秒狙擊狀態，普通攻擊距離+180、攻擊力+30；仍可正常走位。重施刷新持續時間，不疊加。")
	var comrades: SkillDefinition=skill("teppo_comrades","召喚鐵炮群眾",SkillDefinition.Effect.SUMMON,SkillEffectDefinition.Kind.SUMMON,SkillDefinition.Target.GROUND,KEY_O,"0",{"mana_cost":70.0,"range":240.0,"radius":40.0,"icon_index":5},{"duration":30.0,"summon_definition":teppo_companion,"summon_count_min":2,"summon_count_max":2,"summon_limit":2,"summon_controllable":true,"summon_attack_bonus_formula":"agility*0.8+strength*0.8","summon_accuracy_bonus_formula":"agility*1.2","sprite_path":"res://features/skills/art/summon.png"},"召喚2隻可控制的鐵炮手，持續30秒。攻擊加成為釋放時敏捷×0.8+力量×0.8；命中加成為敏捷×1.2。同一施法者最多2隻。")
	var triple: SkillDefinition=skill("teppo_triple","三段",SkillDefinition.Effect.BUFF,SkillEffectDefinition.Kind.BUFF,SkillDefinition.Target.SELF,KEY_P,"0",{"mana_cost":65.0,"icon_index":7},{"duration":10.0,"duration_formula":"10+(agility+strength)*0.05","attack_multiplier":3.0,"attack_speed_multiplier":1.5},"攻擊力增加200%（总值×3）、攻速增加50%（間隔÷1.5）。持續10+(敏捷+力量)×0.05秒。重施刷新，不疊乘；狙擊加成先加再乘三段。")
	var kohime: UnitDefinition=unit("kohime","妖術師・湖衣姬",{"strength":18.0,"agility":26.0,"intelligence":65.0,"max_health":210.0,"max_mana":300.0,"damage":18.0,"attack_range":200.0,"attack_interval":1.4,"speed":122.0,"base_power":220},kohime_layout)
	kohime.skills=[stakes,summon_claw]
	var ninja: UnitDefinition=unit("ninja","忍者",{"strength":30.0,"agility":70.0,"intelligence":26.0,"max_health":230.0,"max_mana":240.0,"damage":28.0,"attack_range":55.0,"attack_interval":0.85,"speed":140.0,"base_power":230},ninja_layout)
	ninja.skills=[stealth,trail,chain]
	var teppo: UnitDefinition=unit("teppo","鐵炮手",{"strength":48.0,"agility":52.0,"intelligence":20.0,"max_health":240.0,"max_mana":220.0,"damage":34.0,"attack_range":280.0,"attack_interval":1.25,"speed":122.0,"base_power":240},teppo_layout)
	teppo.skills=[sniper,comrades,triple]
	for data: UnitDefinition in [kohime,ninja,teppo]:
		save_new(data,"res://features/units/data/mercenaries/"+str(data.id)+".tres")
		var enemy: UnitDefinition=data.duplicate(true) as UnitDefinition
		enemy.id=StringName(str(data.id)+"_enemy")
		enemy.display_name={"kohime":"湖衣妖姬","ninja":"湖畔影忍","teppo":"流亡鐵炮兵"}[str(data.id)]
		enemy.level=20; enemy.experience_reward=70
		for ability: SkillDefinition in enemy.skills:
			ability.ai_enabled=true; ability.ai_attempt_interval=5.0; ability.ai_cast_chance=0.4
		save_new(enemy,"res://features/units/data/monsters/"+str(enemy.id)+".tres")
	var wild_claw: UnitDefinition=claw.duplicate(true) as UnitDefinition
	wild_claw.id=&"earth_claw_enemy"; wild_claw.display_name="湖底石魔爪"; wild_claw.intelligence=60; wild_claw.level=20
	save_new(wild_claw,"res://features/units/data/monsters/earth_claw_enemy.tres")
	print("NEW_UNITS_AUTHORING_RESULT ok=",not failed)
	quit(1 if failed else 0)
