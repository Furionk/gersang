extends SceneTree
const Bounds: Script=preload("res://features/presentation/atlas_silhouette_bounds.gd")
func save_new(resource: Resource,path: String) -> void:
	assert(not FileAccess.file_exists(path),"Preserve existing artist Resource: "+path)
	assert(ResourceSaver.save(resource,path)==OK)
func crop(texture: Texture2D,rect: Rect2) -> AtlasTexture:
	var atlas: AtlasTexture=AtlasTexture.new(); atlas.atlas=texture; atlas.region=rect; atlas.filter_clip=true; return atlas
func _initialize() -> void:
	var texture: Texture2D=load("res://features/units/art/malfory-v1.png")
	var image: Image=texture.get_image()
	var layout: SpriteSheetLayout=SpriteSheetLayout.new(); layout.source_size=image.get_size(); layout.frame_size=Vector2i(256,256); layout.foot_point=Vector2(128,224)
	for row: int in 8:
		for column: int in 6:
			var begin: Vector2i=Vector2i(column*image.get_width()/6,row*image.get_height()/8)
			var end: Vector2i=Vector2i((column+1)*image.get_width()/6,(row+1)*image.get_height()/8)
			var used: Rect2i=Bounds.meaningful(image.get_region(Rect2i(begin,end-begin)),true)
			layout.frame_rects.append(Rect2i(begin+used.position,used.size))
			layout.source_pivots.append(Vector2((end.x-begin.x)*0.5-used.position.x,used.size.y-2))
	assert(layout.valid_for(image.get_size()))
	save_new(layout,"res://features/units/data/layouts/malfory_layout.tres")
	var curse: SkillDefinition=SkillDefinition.new(); curse.id=&"crucio"; curse.display_name="咒咒虐"; curse.description="Crucio：範圍敵人受到智慧持續傷害及減速。"; curse.effect=SkillDefinition.Effect.CURSE
	curse.action=&"skill_crucio"; curse.default_key=KEY_Q; curse.icon_index=9; curse.range=450; curse.radius=150; curse.mana_cost=20; curse.damage_formula="intelligence*1.5"
	curse.effect_data=SkillEffectDefinition.new(); curse.effect_data.kind=SkillEffectDefinition.Kind.CURSE; curse.effect_data.radius=150; curse.effect_data.duration_formula="10+intelligence*0.02"; curse.effect_data.duration=10; curse.effect_data.tick_interval=1
	curse.effect_data.sprite_path="res://features/skills/art/malfory-skull-v1.png"; curse.tint=Color(0.2,0.8,0.3)
	save_new(curse,"res://features/skills/data/crucio.tres")
	var burst: SkillDefinition=SkillDefinition.new(); burst.id=&"avada_kedavra"; burst.display_name="啊哇呾喀呾啦"; burst.description="Avada Kedavra：0.5秒施法，綠色骷髏閃電。目標最大HP×(50%＋智慧×0.5%)，可超過100%；法抗照常。"
	burst.effect=SkillDefinition.Effect.HEALTH_BURST; burst.action=&"skill_avada_kedavra"; burst.default_key=KEY_W; burst.icon_index=8; burst.range=500; burst.radius=130; burst.cast_time=0.5; burst.mana_cost=50; burst.damage_formula="0"
	burst.effect_data=SkillEffectDefinition.new(); burst.effect_data.kind=SkillEffectDefinition.Kind.HEALTH_BURST; burst.effect_data.radius=130; burst.effect_data.duration=0.65; burst.effect_data.sprite_path="res://features/skills/art/malfory-skull-v1.png"; burst.tint=Color(0.05,1,0.12)
	save_new(burst,"res://features/skills/data/avada_kedavra.tres")
	var art: Texture2D=load("res://features/units/art/malfory-standee-v1.png")
	var unit: UnitDefinition=UnitDefinition.new(); unit.id=&"malfory"; unit.display_name="女魔法師・Malfory"; unit.level=1; unit.role=3; unit.intelligence=70; unit.strength=12; unit.agility=25; unit.max_health=220; unit.max_mana=400; unit.damage=22; unit.attack_range=210; unit.attack_interval=1.5; unit.speed=125
	unit.sprite_path="res://features/units/art/malfory-v1.png"; unit.sprite_layout=layout; unit.skills=[curse,burst]; unit.standee_texture=crop(art,Rect2(Vector2.ZERO,art.get_size())); unit.portrait_texture=crop(art,Rect2(390,40,330,330)); unit.eyes_texture=crop(art,Rect2(450,115,230,95))
	save_new(unit,"res://features/units/data/mercenaries/malfory.tres")
	var registry: MercenaryCatalog=MercenaryCatalog.new()
	for id: String in ["kohime","ninja","teppo","malfory"]: registry.definitions.append(load("res://features/units/data/mercenaries/"+id+".tres"))
	save_new(registry,"res://features/progression/data/additional_mercenaries.tres")
	print("MALFORY_CREATED sizes=",image.get_size()," standee=",art.get_size()," alpha=",art.get_image().detect_alpha())
	quit()
