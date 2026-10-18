extends SceneTree
## One-shot initial composition only. Never restore this over an Artist's edits.
const PATH:String="res://features/world/data/hogwarts.tscn"
func _initialize()->void:call_deferred("run")
func own(node:Node,root:Node)->void:
	for child:Node in node.get_children():child.owner=root;own(child,root)
func prop(parent:Node,index:int,point:Vector2,size:float)->void:
	var sprite:Sprite2D=Sprite2D.new();sprite.name="SchoolDetail_"+str(parent.get_child_count())
	var data:WorldSceneryDefinition=load("res://features/world/data/scenery/hogwarts/prop_"+str(index)+".tres")
	sprite.set_meta("world_scenery_definition",data);sprite.set_meta("world_scenery_id","school_detail_"+str(parent.get_child_count()))
	var atlas:AtlasTexture=AtlasTexture.new();atlas.atlas=data.texture;atlas.region=data.atlas_region
	sprite.texture=atlas;sprite.centered=false;sprite.offset=-data.foot_anchor;sprite.position=Iso.project(point);sprite.scale=Vector2.ONE*size
	parent.add_child(sprite);ScenerySorting.apply_item(sprite)
func run()->void:
	WorldCatalog.initialize()
	var root:WorldMap2D=load(PATH).instantiate()
	if root.has_meta("initial_school_polish"):push_error("School composition already authored; refuses rerun.");root.free();quit(1);return
	var details:Node2D=Node2D.new();details.name="CourtsAndCorridors";root.get_node("Scenery").add_child(details)
	# Repeated arcades frame rooms; leave broad crossing gates at y1056 and y1696.
	for x:float in [1056.0,2112.0]:
		for y:float in [448.0,768.0,1408.0,2048.0,2368.0]:prop(details,3,Vector2(x,y),0.8)
	for y:float in [1088.0,1760.0]:
		for x:float in [480.0,896.0,2528.0,2944.0]:prop(details,2,Vector2(x,y),0.8)
	for p:Vector2 in [Vector2(288,384),Vector2(832,960),Vector2(2336,320),Vector2(2848,960)]:prop(details,5,p,0.55)
	for p:Vector2 in [Vector2(288,1280),Vector2(832,1632),Vector2(1248,1312),Vector2(1920,1440),Vector2(2560,1536),Vector2(2784,2016)]:prop(details,6,p,0.5)
	prop(details,4,Vector2(1520,2048),0.9);prop(details,4,Vector2(512,1024),0.75)
	# Native low-contrast runner tiles, separately editable; decorative only.
	var ground:WorldTileLayer=root.get_node("Ground/Ground_TileMap")
	var runner:WorldTileLayer=WorldTileLayer.new();runner.name="CorridorRunner";runner.role=WorldTileLayer.Role.GROUND;runner.tile_set=ground.tile_set;runner.position=Vector2(-32,0);runner.modulate=Color(0.5,0.48,0.42)
	for x:int in range(29,36):
		for y:int in range(7,77):runner.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
	for x:int in range(7,94):
		for y:int in range(32,37):runner.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
	root.get_node("Ground").add_child(runner)
	root.set_meta("initial_school_polish",true);own(root,root)
	var definition:WorldMapDefinition=root.compile_definition();var registry:Dictionary=WorldCatalog.definitions.duplicate();registry.hogwarts=definition
	var errors:Array=WorldValidator.validate(definition,registry)
	if not errors.is_empty():push_error(str(errors));root.free();quit(1);return
	var packed:PackedScene=PackedScene.new();assert(packed.pack(root)==OK);assert(ResourceSaver.save(packed,PATH)==OK);root.free()
	print("HOGWARTS_COMPOSITION_SAVED native_details_and_runner");quit()
