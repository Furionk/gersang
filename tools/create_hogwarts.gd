extends SceneTree
## One-shot provenance. Refuses existing authored maps; never a boot hook.
const OUT:String="res://artifacts/hogwarts-2026-10-13/"
var units:Dictionary={}
var props:Array[WorldSceneryDefinition]=[]
func save(resource:Resource,path:String)->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var error:Error=ResourceSaver.save(resource,path)
	assert(error==OK,"Save failed "+path)
	resource.take_over_path(path)
func _initialize()->void: call_deferred("run")
func layout(id:String,file:String)->SpriteSheetLayout:
	var data:SpriteSheetLayout=SpriteSheetLayout.new(); data.source_texture=load(file)
	var image:Image=data.source_texture.get_image()
	data.source_size=image.get_size(); data.frame_size=Vector2i(256,256); data.foot_point=Vector2(128,224)
	for row:int in 8:
		for column:int in 6:
			var a:Vector2i=Vector2i(column*image.get_width()/6,row*image.get_height()/8)
			var b:Vector2i=Vector2i((column+1)*image.get_width()/6,(row+1)*image.get_height()/8)
			var crop:Rect2i=image.get_region(Rect2i(a,b-a)).get_used_rect()
			if crop.size==Vector2i.ZERO: crop=Rect2i(Vector2i.ZERO,b-a)
			data.frame_rects.append(Rect2i(a+crop.position,crop.size))
			data.source_pivots.append(Vector2(crop.size.x*0.5,crop.size.y-3))
	assert(data.valid_for(image.get_size()))
	save(data,"res://features/units/data/layouts/"+id+"_layout.tres"); return data
func unit(id:String,title:String,file:String,level:int,hp:float,damage:float,speed:float,scale:float)->UnitDefinition:
	var data:UnitDefinition=UnitDefinition.new(); data.id=StringName(id);data.display_name=title;data.level=level
	data.max_health=hp;data.max_mana=500;data.damage=damage;data.speed=speed;data.battle_sprite_scale=scale;data.world_sprite_scale=scale
	data.defense=20;data.intelligence=50;data.mana_regeneration=8;data.experience_reward=level*25
	data.base_power=level*90;data.level_power_growth=45
	data.sprite_layout=layout(id,"res://features/units/art/hogwarts/"+file+"-v1.png")
	var face:AtlasTexture=SpriteAtlas.frame(data.sprite_layout.source_texture,data.sprite_layout,2,0)
	data.portrait_texture=face;data.eyes_texture=face;data.standee_texture=face
	units[id]=data;return data
func skill(id:String,title:String,effect:int,formula:String,kind:int=-1)->SkillDefinition:
	var data:SkillDefinition=SkillDefinition.new();data.id=StringName(id);data.display_name=title;data.action=StringName("skill_"+id)
	data.effect=effect;data.damage_formula=formula;data.mana_cost=0;data.ai_enabled=true;data.ai_attempt_interval=5;data.ai_cast_chance=0.6;data.range=600
	if kind>=0: data.effect_data=SkillEffectDefinition.new();data.effect_data.kind=kind
	return data
func node(parent:Node,name:String)->Node2D:
	var result:Node2D=Node2D.new();result.name=name;parent.add_child(result);return result
func own(root:Node,branch:Node)->void:
	for child:Node in branch.get_children(): child.owner=root;own(root,child)
func sprite(parent:Node,index:int,point:Vector2,scale:float=1.0)->Sprite2D:
	var data:WorldSceneryDefinition=props[index]
	var picture:Sprite2D=Sprite2D.new();picture.name="SchoolProp_"+str(parent.get_child_count());picture.position=Iso.project(point)
	var texture:AtlasTexture=AtlasTexture.new();texture.atlas=data.texture;texture.region=data.atlas_region
	picture.texture=texture;picture.centered=false;picture.offset=-data.foot_anchor;picture.scale=Vector2.ONE*scale
	picture.set_meta("world_scenery_id","school_prop_"+str(point)+"_"+str(index));picture.set_meta("world_scenery_definition",data)
	parent.add_child(picture);return picture
func make_props()->void:
	var texture:Texture2D=load("res://art/terrain/hogwarts/school-props-v1.png")
	for i:int in 8:
		var a:Vector2i=Vector2i((i%4)*texture.get_width()/4,(i/4)*texture.get_height()/2)
		var b:Vector2i=Vector2i((i%4+1)*texture.get_width()/4,(i/4+1)*texture.get_height()/2)
		var data:WorldSceneryDefinition=WorldSceneryDefinition.new();data.texture=texture;data.atlas_region=Rect2(a,b-a)
		data.foot_anchor=Vector2((b.x-a.x)*0.5,b.y-a.y-15);data.display_name=["魔法學校城門","大禮堂","東向迴廊","西向迴廊","地窖石階","蛇妖石像","禁忌魔法書","血月祭壇"][i]
		data.sprite_scale=0.8;data.description="霍格愛茲：平行空間的魔法學校。";props.append(data)
		save(data,"res://features/world/data/scenery/hogwarts/prop_"+str(i)+".tres")
func battle(blood:bool)->PackedScene:
	var source:BattlefieldMap=load("res://features/battle/maps/shaolin_temple.tscn").instantiate()
	var texture_set:TileSet=source.find_child("Ground",true,false).tile_set
	# Source layer may have a folder name in future; find by role, never by artwork.
	for child:Node in WorldAuthorTree.nodes(source):
		if child is BattleTileLayer and child.role==BattleTileLayer.Role.GROUND: texture_set=child.tile_set;break
	var root:BattlefieldMap=BattlefieldMap.new();root.name="HogwartsBloodMoon" if blood else "HogwartsBattle";root.arena_id="hogwarts";root.battlefield_cells=Vector2i(56,44)
	for role:int in 3:
		var layer:BattleTileLayer=BattleTileLayer.new();layer.name=["Ground","Walkable","Blockers"][role];layer.role=role;layer.position=Vector2(-40,0);layer.tile_set=texture_set
		if role<2:
			for x:int in 56:
				for y:int in 44: layer.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
		root.add_child(layer)
		if role==0: layer.modulate=Color(0.6,0.12,0.16) if blood else Color(0.65,0.69,0.73)
	var scenery:Node2D=node(root,"Scenery")
	for x:int in range(120,2120,400):
		sprite(scenery,2,Vector2(x,80),0.85);sprite(scenery,2,Vector2(x,1660),0.85)
	for y:int in range(200,1600,400):
		sprite(scenery,3,Vector2(40,y),0.85);sprite(scenery,3,Vector2(2140,y),0.85)
	for point:Vector2 in [Vector2(1000,850),Vector2(1500,1250)]: sprite(scenery,7 if blood else 6,point,0.7)
	if blood:
		for i:int in 12: sprite(scenery,7,Vector2(200+(i%4)*520,300+(i/4)*520),0.35)
	var zones:Node2D=node(root,"SpawnZones")
	for point:Vector2 in [Vector2(400,360),Vector2(1780,360),Vector2(1780,1380),Vector2(400,1380),Vector2(1120,860)]:
		var zone:BattleSpawnZone=BattleSpawnZone.new();zone.name="Position_"+str(zones.get_child_count()+1);zone.position=Iso.project(point);zone.radius=260;zone.capacity=60;zones.add_child(zone)
	own(root,root)
	var compiled:Dictionary=BattlefieldCompiler.compile(root);assert(compiled.errors.is_empty(),str(compiled.errors))
	var packed:PackedScene=PackedScene.new();assert(packed.pack(root)==OK)
	save(packed,"res://features/battle/maps/"+("hogwarts_blood_moon" if blood else "hogwarts")+".tscn")
	root.free();source.free();return packed
func arrival(parent:Node,id:String,point:Vector2)->WorldAuthorNode:
	var entry:WorldAuthorNode=WorldAuthorNode.new();entry.name=id;entry.stable_id=id;entry.kind=WorldAuthorNode.Kind.ARRIVAL;entry.coordinate_space=WorldAuthorNode.CoordinateSpace.CANVAS;entry.position=Iso.project(point);parent.add_child(entry);return entry
func portal(parent:Node,id:String,point:Vector2,target:String,entry:String)->WorldAuthorNode:
	var door:WorldAuthorNode=WorldAuthorNode.new();door.name=id;door.stable_id=id;door.kind=WorldAuthorNode.Kind.PORTAL;door.coordinate_space=WorldAuthorNode.CoordinateSpace.CANVAS;door.position=Iso.project(point)
	door.target_map_id=target;door.target_entry_id=entry;door.display_name="霍格愛茲・平行空間入口" if target=="hogwarts" else "返回青嶺河灣"
	door.sprite_definition=props[0];door.trigger_radius=90;parent.add_child(door)
	var picture:Sprite2D=Sprite2D.new();picture.name="Artwork";picture.texture=AtlasTexture.new();picture.texture.atlas=props[0].texture;picture.texture.region=props[0].atlas_region
	picture.centered=false;picture.offset=-props[0].foot_anchor;picture.scale=Vector2.ONE*0.9;door.add_child(picture);return door
func region(parent:Node,id:String,unit_id:String,rect:Rect2,count:int,minimum:int,maximum:int,size_min:int=2,size_max:int=4)->void:
	var area:WorldMonsterRegion=WorldMonsterRegion.new();area.name=id;area.stable_id=id;area.display_name=units[unit_id].display_name
	area.monster=units[unit_id];area.party_count=count;area.minimum_level=minimum;area.maximum_level=maximum;area.minimum_units=size_min;area.maximum_units=size_max;area.aggressive=true;area.battlefields=PackedStringArray(["hogwarts"])
	parent.add_child(area)
	for i:int in 3:
		var polygon:WorldRegionPolygon=WorldRegionPolygon.new();polygon.name=["SpawnArea","RoamingArea","PursuitArea"][i]
		var shape:Rect2=rect.grow(-48) if i==0 else rect
		var vertices:PackedVector2Array=PackedVector2Array()
		for p:Vector2 in [shape.position,Vector2(shape.end.x,shape.position.y),shape.end,Vector2(shape.position.x,shape.end.y)]: vertices.append(Iso.project(p))
		polygon.polygon=vertices
		area.add_child(polygon)
func world()->void:
	var source:WorldMap2D=load("res://features/world/data/shaolin_temple.tscn").instantiate()
	var root:WorldMap2D=WorldMap2D.new();root.name="Hogwarts";root.native_tiles_enabled=true
	root.definition=WorldMapDefinition.new();root.definition.map_id="hogwarts";root.definition.display_name="魔法學校・霍格愛茲";root.definition.kind=WorldMapDefinition.Kind.DUNGEON;root.definition.extent=Vector2(3200,2560)
	root.definition.safe_return_map_id="river_bay";root.definition.safe_return_entry_id="school_return"
	var ground:Node2D=node(root,"Ground")
	for role:int in [WorldTileLayer.Role.GROUND,WorldTileLayer.Role.WALKABLE,WorldTileLayer.Role.OBSTACLES]:
		var layer:WorldTileLayer=WorldTileLayer.new();layer.name={0:"Ground_TileMap",2:"Walkable_Mask",1:"Obstacles_TileMap"}[role];layer.role=role;layer.position=Vector2(-32,0)
		layer.tile_set=source.get_node("Ground/Ground_TileMap").tile_set if role==0 else source.get_node("Ground/Walkable_Mask").tile_set
		if role!=WorldTileLayer.Role.OBSTACLES:
			for x:int in 100:
				for y:int in 80: layer.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
		ground.add_child(layer)
		if role==0: layer.modulate=Color(0.7,0.72,0.76)
	var scenery:Node2D=node(root,"Scenery")
	for x:int in range(64,3100,500): sprite(scenery,2,Vector2(x,64),1.1);sprite(scenery,2,Vector2(x,2496),1.1)
	for y:int in range(256,2400,500): sprite(scenery,3,Vector2(64,y),1.1);sprite(scenery,3,Vector2(3136,y),1.1)
	sprite(scenery,1,Vector2(1600,352),1.65);sprite(scenery,4,Vector2(2400,864),1.15)
	sprite(scenery,5,Vector2(2656,448),0.85)
	for p:Vector2 in [Vector2(512,1440),Vector2(1472,1200),Vector2(2496,1888),Vector2(832,2080)]: sprite(scenery,6,p,0.7)
	var entrances:Node2D=node(root,"Entrances");arrival(entrances,"entrance",Vector2(480,2416));portal(entrances,"school_exit",Vector2(480,2496),"river_bay","school_return")
	var safe:WorldAuthorNode=WorldAuthorNode.new();safe.name="EntrySafety";safe.kind=WorldAuthorNode.Kind.SAFE_AREA;safe.coordinate_space=WorldAuthorNode.CoordinateSpace.CANVAS;safe.domain=PolygonDomain.rectangle(Rect2(0,2256,1024,304));ground.add_child(safe)
	var monsters:Node2D=node(root,"MonsterRegions")
	region(monsters,"west_dementors","school_dementor",Rect2(128,256,768,704),4,50,62)
	region(monsters,"east_dementors","school_dementor",Rect2(2208,1312,800,864),4,63,75)
	region(monsters,"classroom_elves","school_dark_elf",Rect2(128,1216,800,544),5,40,50)
	region(monsters,"courtyard_elves","school_dark_elf",Rect2(128,1840,800,384),5,51,60)
	region(monsters,"stone_gatekeepers","school_gatekeeper",Rect2(1184,1024,800,512),4,50,70)
	region(monsters,"forbidden_basilisks","school_basilisk",Rect2(2208,256,800,768),3,80,80,1,1)
	region(monsters,"cerberus_corridor","school_cerberus",Rect2(1216,1728,736,640),4,75,75,1,1)
	region(monsters,"dark_lord","voldemort_illusion",Rect2(1184,256,736,640),1,90,90,1,1)
	var labels:Node2D=node(root,"MapLabels")
	for value:Array in [["魔法庭院",Vector2(560,2000)],["幽魂迴廊",Vector2(512,768)],["禁忌地窖",Vector2(2560,800)],["黑魔法大禮堂",Vector2(1536,576)]]:
		var label:WorldAuthorNode=WorldAuthorNode.new();label.name="Label_"+str(labels.get_child_count());label.kind=WorldAuthorNode.Kind.LANDMARK;label.coordinate_space=WorldAuthorNode.CoordinateSpace.CANVAS;label.stable_id=label.name;label.display_name=value[0];label.position=Iso.project(value[1]);labels.add_child(label)
	own(root,root);var packed:PackedScene=PackedScene.new();assert(packed.pack(root)==OK);save(packed,"res://features/world/data/hogwarts.tscn")
	root.free();source.free()
func run()->void:
	if "--finish-portal" in OS.get_cmdline_user_args():
		for i:int in 8: props.append(load("res://features/world/data/scenery/hogwarts/prop_"+str(i)+".tres"))
		finish_portal(); return
	if FileAccess.file_exists("res://features/world/data/hogwarts.tscn"): push_error("Hogwarts already authored; builder refuses overwrite.");quit(1);return
	make_props();var arena:PackedScene=battle(false);var blood:PackedScene=battle(true)
	var drain:SkillDefinition=skill("school_soul_drain","吸魂",SkillDefinition.Effect.SOUL_DRAIN,"attack*0.7",SkillEffectDefinition.Kind.SOUL_DRAIN)
	drain.target_mode=SkillDefinition.Target.ENEMY;drain.range=360;drain.mana_cost=25;drain.ai_attempt_interval=6;drain.effect_data.duration=4;drain.effect_data.tick_interval=0.5;drain.effect_data.channel_break_range=440;drain.tint=Color(0.2,0.8,0.65);save(drain,"res://features/skills/data/school_soul_drain.tres")
	var teleport:SkillDefinition=skill("school_teleport","傳送術",SkillDefinition.Effect.TELEPORT,"0",SkillEffectDefinition.Kind.TELEPORT)
	teleport.target_mode=SkillDefinition.Target.ENEMY;teleport.range=800;teleport.ai_attempt_interval=6;save(teleport,"res://features/skills/data/school_teleport.tres")
	var wave:SkillDefinition=skill("school_stone_wave","守門衝擊波",SkillDefinition.Effect.SHOCKWAVE,"attack*1.5",SkillEffectDefinition.Kind.LINE)
	wave.trigger=SkillDefinition.Trigger.ATTACK_HIT;wave.proc_chance=1;wave.ai_enabled=false;wave.range=900;wave.damage_type=CombatMath.Kind.PHYSICAL;wave.effect_data.distance=900;wave.effect_data.width=95;wave.effect_data.speed=650;wave.effect_data.duration=1.6;wave.tint=Color(1,0.7,0.35);save(wave,"res://features/skills/data/school_stone_wave.tres")
	var moon:SkillDefinition=wave.duplicate(true);moon.id=&"blood_moon_wave";moon.display_name="血月劍波";moon.damage_formula="attack*1.5";moon.effect_data.width=140;moon.tint=Color(1,0.08,0.15);save(moon,"res://features/skills/data/blood_moon_wave.tres")
	var petrify:SkillDefinition=skill("school_petrify","石化",SkillDefinition.Effect.PETRIFY,"0")
	petrify.range=380;petrify.radius=170;petrify.duration=4;petrify.cast_time=1;petrify.ai_attempt_interval=7;petrify.tint=Color(0.6,0.7,0.6);save(petrify,"res://features/skills/data/school_petrify.tres")
	var charge:SkillDefinition=load("res://features/skills/data/lake_wolf_charge.tres").duplicate(true)
	charge.id=&"school_red_charge";charge.display_name="三頭狂襲";charge.tint=Color(1,0.05,0.08);charge.effect_data.width=150;save(charge,"res://features/skills/data/school_red_charge.tres")
	var curse:SkillDefinition=load("res://features/skills/data/avada_kedavra.tres").duplicate(true)
	curse.id=&"illusion_avada";curse.display_name="幻象・啊哇呾喀呾啦";curse.effect_data.target_max_hp_ratio_formula="(0.5+intelligence*0.005)*0.25";curse.ai_enabled=true;curse.ai_attempt_interval=5;curse.ai_cast_chance=0.5;save(curse,"res://features/skills/data/illusion_avada.tres")
	var dementor:UnitDefinition=unit("school_dementor","催狂魔","school-dementor",50,1250,40,230,0.6);dementor.movement_type=UnitDefinition.Movement.AIR;dementor.attack_range=180;dementor.skills=[drain]
	var elf:UnitDefinition=unit("school_dark_elf","黑暗妖靈","school-dark-elf",40,1000,40,160,0.4);elf.attack_range=280;elf.skills=[teleport]
	var guardian:UnitDefinition=unit("school_gatekeeper","石像守門人","school-gatekeeper",50,3400,60,85,0.75);guardian.skills=[wave];guardian.defense=55
	var serpent:UnitDefinition=unit("school_basilisk","蛇妖","school-basilisk",80,7000,100,120,0.95);serpent.skills=[petrify]
	var dog:UnitDefinition=unit("school_cerberus","三頭犬","school-cerberus",75,5800,95,170,0.9);dog.skills=[charge]
	var phantom:UnitDefinition=unit("ganondorf_phantom","加儂多夫的幻影","ganondorf-phantom",90,9000,165,180,0.8);phantom.skills=[moon];phantom.attack_range=90;phantom.strength=40;phantom.magic_resistance=0.3;phantom.experience_reward=30000
	var echo:UnitDefinition=phantom.duplicate();echo.id=&"ganondorf_echo";echo.display_name="血月加儂幻影";echo.max_health=3200;echo.outgoing_damage_scale=0.5;echo.experience_reward=0;echo.sprite_tint=Color(1,0.6,0.6,0.85);units["ganondorf_echo"]=echo
	var final:MonsterPhaseDefinition=MonsterPhaseDefinition.new();final.final_spawn=echo;final.final_spawn_count=5;final.pause_seconds=0;final.title="五重血月幻影";phantom.death_phase=final
	save(echo,"res://features/units/data/monsters/ganondorf_echo.tres");save(final,"res://features/units/data/phases/ganondorf_final.tres");save(phantom,"res://features/units/data/monsters/ganondorf_phantom.tres")
	var lord:UnitDefinition=unit("voldemort_illusion","佛地魔的幻象","voldemort-illusion",90,7200,85,155,0.65);lord.attack_range=370;lord.intelligence=120;lord.skills=[curse];lord.experience_reward=30000
	var phase:MonsterPhaseDefinition=MonsterPhaseDefinition.new();phase.next_form=phantom;phase.battlefield=blood;phase.title="恐怖之王・血月變身";phase.hazard_enabled=true;lord.death_phase=phase;save(phase,"res://features/units/data/phases/voldemort_blood_moon.tres")
	for id:String in units: save(units[id],"res://features/units/data/monsters/"+id+".tres")
	var encounter:EncounterDefinition=EncounterDefinition.new();encounter.id=&"hogwarts";encounter.display_name="霍格愛茲・魔法試煉";encounter.battlefield_scene="res://features/battle/maps/hogwarts.tscn";encounter.melee_count=0;encounter.ranged_count=3;encounter.elite_count=0
	var config:ArenaDefinition=ArenaDefinition.new();config.arena_id="hogwarts";config.encounter=encounter;save(config,"res://features/world/data/hogwarts_arena.tres")
	world();finish_portal()
func geometry(map:WorldMapDefinition)->PackedByteArray:
	var shapes:Array=[]
	for collection:Array[PolygonDomain] in [map.walkable,map.blockers]:
		var domains:Array=[]
		for domain:PolygonDomain in collection: domains.append([domain.outer,domain.holes,domain.visual_kind])
		shapes.append(domains)
	return var_to_bytes(shapes)
func finish_portal()->void:
	WorldCatalog.definitions.clear();WorldCatalog.arenas.clear();WorldCatalog.initialize()
	var school:WorldMap2D=load("res://features/world/data/hogwarts.tscn").instantiate()
	var entry:WorldAuthorNode=school.get_node("Entrances/entrance")
	if entry.position.is_equal_approx(Iso.project(Vector2(480,2416))): entry.position=Iso.project(Vector2(480,2344))
	var safe:WorldAuthorNode=school.find_child("EntrySafety",true,false);safe.stable_id="school_safe"
	var school_definition:WorldMapDefinition=school.compile_definition()
	var river:WorldMap2D=load("res://features/world/data/river_bay.tscn").instantiate();var before:WorldMapDefinition=river.compile_definition()
	if river.find_child("school_door",true,false)!=null: river.free();print("HOGWARTS_PORTAL_ALREADY_EXISTS");quit();return
	var nav:WorldNavigationService=WorldNavigationService.new();nav.register_map(before)
	var desired:Vector2=Vector2(5580,2940);var route:Dictionary=nav.find_portal_approach(before.map_id,before.entries.start.point,desired,90,16)
	assert(route.ok,"New entrance must be reachable without changing Walkable")
	var point:Vector2=route.points[-1]
	portal(river.get_node("Entrances"),"school_door",point,"hogwarts","entrance");arrival(river.get_node("Entrances"),"school_return",point+Vector2(128,0))
	own(river,river);var compiled:WorldMapDefinition=river.compile_definition()
	if geometry(compiled)!=geometry(before): push_error("Navigation changed; entrance NOT saved.");river.free();quit(1);return
	var registry:Dictionary=WorldCatalog.definitions.duplicate();registry.river_bay=compiled;registry.hogwarts=school_definition
	var errors:Array[String]=WorldValidator.validate(school_definition,registry,school)
	errors.append_array(WorldValidator.validate(compiled,registry,river))
	if not errors.is_empty(): push_error(str(errors));school.free();river.free();quit(1);return
	own(school,school);var school_packed:PackedScene=PackedScene.new();assert(school_packed.pack(school)==OK);save(school_packed,"res://features/world/data/hogwarts.tscn");school.free()
	var packed:PackedScene=PackedScene.new();assert(packed.pack(river)==OK);save(packed,"res://features/world/data/river_bay.tscn");river.free()
	print("HOGWARTS_CREATED native_world_and_battle scenes=3 parties=30 species=8")
	quit()
