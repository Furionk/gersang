extends SceneTree
## One-time new-content linking. Touches only Hogwarts references, never rerolls saved parties.
func save(resource:Resource)->void:
	assert(not resource.resource_path.is_empty())
	assert(ResourceSaver.save(resource,resource.resource_path)==OK)
func _initialize()->void: call_deferred("run")
func run()->void:
	var existing:SpriteSheetLayout=load("res://features/units/data/layouts/school_dementor_layout.tres")
	if existing.has_meta("initial_silhouette_review"):
		push_error("Hogwarts initial linking already finalized; refuses overwrite of Artist resources.");quit(1);return
	var cast:SpriteAnimationClip=SpriteAnimationClip.new();cast.action=3;cast.columns=PackedInt32Array([4]);cast.loop=true;cast.fps=3
	var spirit_layout:SpriteSheetLayout=load("res://features/units/data/layouts/school_dementor_layout.tres");spirit_layout.animations=[cast];save(spirit_layout)
	var wave:SkillDefinition=load("res://features/skills/data/school_stone_wave.tres");wave.effect_data.sprite_path="res://features/skills/art/dragon.png";save(wave)
	var moon:SkillDefinition=load("res://features/skills/data/blood_moon_wave.tres");moon.effect_data.sprite_path="res://features/skills/art/dragon.png";save(moon)
	var teleport:SkillDefinition=load("res://features/skills/data/school_teleport.tres");teleport.effect_data.sprite_path="res://features/skills/art/control.png";teleport.effect_data.duration=0.5;save(teleport)
	var assignments:Dictionary={"school_dementor":"school_soul_drain","school_dark_elf":"school_teleport","school_gatekeeper":"school_stone_wave","school_basilisk":"school_petrify","school_cerberus":"school_red_charge","voldemort_illusion":"illusion_avada","ganondorf_phantom":"blood_moon_wave","ganondorf_echo":"blood_moon_wave"}
	var units:Dictionary={}
	for id:String in assignments:
		var data:UnitDefinition=load("res://features/units/data/monsters/"+id+".tres")
		data.sprite_layout=load("res://features/units/data/layouts/"+("ganondorf_phantom" if id=="ganondorf_echo" else id)+"_layout.tres")
		data.skills=[load("res://features/skills/data/"+assignments[id]+".tres")]
		data.portrait_texture=SpriteAtlas.frame(data.sprite_layout.source_texture,data.sprite_layout,2,0);data.standee_texture=data.portrait_texture;data.eyes_texture=data.portrait_texture
		units[id]=data
	units.ganondorf_echo.damage=units.ganondorf_phantom.damage;units.ganondorf_echo.stat_rules=null;units.ganondorf_echo.outgoing_damage_scale=0.5;units.ganondorf_echo.death_phase=null;save(units.ganondorf_echo)
	var final:MonsterPhaseDefinition=load("res://features/units/data/phases/ganondorf_final.tres");final.final_spawn=units.ganondorf_echo;save(final)
	units.ganondorf_phantom.death_phase=final;save(units.ganondorf_phantom)
	var phase:MonsterPhaseDefinition=load("res://features/units/data/phases/voldemort_blood_moon.tres");phase.next_form=units.ganondorf_phantom;phase.battlefield=load("res://features/battle/maps/hogwarts_blood_moon.tscn");save(phase)
	units.voldemort_illusion.death_phase=phase
	for id:String in units: save(units[id])
	var school:WorldMap2D=load("res://features/world/data/hogwarts.tscn").instantiate()
	for node:Node in WorldAuthorTree.nodes(school):
		if node is WorldMonsterRegion: node.monster=units[str(node.monster.id)]
		if node is WorldAuthorNode and node.kind==WorldAuthorNode.Kind.PORTAL: node.sprite_definition=load("res://features/world/data/scenery/hogwarts/prop_0.tres")
	var packed:PackedScene=PackedScene.new();assert(packed.pack(school)==OK);assert(ResourceSaver.save(packed,"res://features/world/data/hogwarts.tscn")==OK);school.free()
	print("HOGWARTS_NATIVE_REFERENCES_LINKED")
	quit()
