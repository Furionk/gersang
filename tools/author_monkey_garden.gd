extends SceneTree
## One-shot authoring. Never regenerate over artist edits.
var world: Node3D
func _initialize() -> void: call_deferred("run")
func own(root: Node, branch: Node) -> void:
	for child: Node in branch.get_children():
		child.owner=root
		if child.scene_file_path.is_empty(): own(root,child)
func save(resource: Resource,path: String) -> void:
	assert(ResourceSaver.save(resource,path)==OK); resource.take_over_path(path)
func box(parent: Node3D, name_: String, at: Vector3, size_: Vector3, color: Color, solid: bool=true) -> Node3D:
	var body: Node3D=StaticBody3D.new() if solid else Node3D.new(); body.name=name_; parent.add_child(body); body.position=at
	var mesh:=MeshInstance3D.new(); var cube:=BoxMesh.new(); cube.size=size_; mesh.mesh=cube
	var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mat.roughness=0.85; mesh.material_override=mat; body.add_child(mesh)
	if solid:
		var collision:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=size_; collision.shape=shape; body.add_child(collision)
	return body
func run() -> void:
	if FileAccess.file_exists("res://features/monkey/garden.tscn"): push_error("Garden exists; refusing overwrite"); quit(1); return
	world=Node3D.new(); world.name="MonkeyGarden"
	var region:=NavigationRegion3D.new(); region.name="GardenNavigation"; world.add_child(region)
	var nav:=NavigationMesh.new(); nav.agent_radius=0.45; nav.agent_height=1.7; nav.cell_size=0.25; nav.cell_height=0.2
	nav.geometry_parsed_geometry_type=NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS; region.navigation_mesh=nav
	box(region,"MainGarden",Vector3(0,-0.5,7),Vector3(48,1,34),Color("719b67"))
	box(region,"HedgeGarden",Vector3(-13,-0.5,-15),Vector3(22,1,10),Color("67965b"))
	box(region,"CentralPath",Vector3(0,0.025,8),Vector3(6,0.05,30),Color("d9c7a3"),false)
	box(region,"RacePath",Vector3(-13,0.03,0),Vector3(13,0.05,14),Color("c6ad83"),false)
	box(region,"RaceIsland",Vector3(-13,0.6,0),Vector3(4,1.2,4),Color("819d67"))
	for x: int in [-18,-8]: box(region,"Hedge%d"%x,Vector3(x,1,-12),Vector3(1,2,7),Color("315b45"))
	box(region,"HedgeBack",Vector3(-13,1,-17),Vector3(8,2,1),Color("315b45"))
	box(world,"River",Vector3(2,-2,-15),Vector3(8,0.2,20),Color("3e9eb3"),false)
	box(world,"Lava",Vector3(16,-2,-14),Vector3(18,0.2,20),Color("e45d32"),false)
	var steps: Array[Vector3]=[Vector3(5,0.5,-7),Vector3(7,1.5,-9),Vector3(10,2.5,-12),Vector3(15,3.5,-15),Vector3(18,2.5,-9)]
	for i: int in steps.size(): box(region,"Platform%d"%i,steps[i],Vector3(3.4,1,3.4),Color("bdad88"))
	for i: int in 2:
		var link:=NavigationLink3D.new(); link.name="MonkeyJump%d"%i; link.start_position=steps[i+2]+Vector3.UP*0.5; link.end_position=steps[i+3]+Vector3.UP*0.5; region.add_child(link)
	box(world,"Trap",Vector3(12,0.07,3),Vector3(2,0.12,2),Color("e3a655"),false)
	for x: int in [-25,25]: box(region,"BoundaryX%d"%x,Vector3(x,1,0),Vector3(1,3,50),Color("7a8a70"))
	for z: int in [-25,25]: box(region,"BoundaryZ%d"%z,Vector3(0,1,z),Vector3(50,3,1),Color("7a8a70"))
	for i: int in 16:
		var tree: Node3D=load("res://features/monkey/assets/tree.glb").instantiate(); tree.name="Tree%d"%i; region.add_child(tree)
		tree.position=Vector3(-22 if i<8 else 22,0,float(i%8)*5-16); tree.scale=Vector3.ONE*2
	for point: Vector3 in [Vector3(8,0,12),Vector3(-5,0,-7),Vector3(18,0,12)]:
		var rock: Node3D=load("res://features/monkey/assets/rock.glb").instantiate(); region.add_child(rock); rock.position=point; rock.scale=Vector3.ONE*1.4
	var environment:=WorldEnvironment.new(); environment.name="GardenEnvironment"; environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color("a4c8cf")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color("d7e3e5"); environment.environment.ambient_light_energy=0.7
	world.add_child(environment)
	var sun:=DirectionalLight3D.new(); sun.name="Sun"; sun.rotation_degrees=Vector3(-50,-25,0); sun.light_color=Color("ffe5b6"); sun.light_energy=1.2; sun.shadow_enabled=true; world.add_child(sun)
	root.add_child(world)
	await physics_frame
	var geometry:=NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav,geometry,region)
	NavigationServer3D.bake_from_source_geometry_data(nav,geometry)
	assert(nav.get_polygon_count()>0,"Navigation must bake")
	world.set_script(load("res://features/monkey/garden.gd"))
	own(world,world); var packed:=PackedScene.new(); assert(packed.pack(world)==OK); save(packed,"res://features/monkey/garden.tscn")
	# External native monster and arena resources use stable identities.
	var template:=PartyTemplate.new(); template.template_id="monkey_garden_five"; template.display_name="庭園猴子隊 · 3D捕猴"
	for i: int in 5:
		var unit:=UnitDefinition.new(); unit.id=StringName("garden_monkey_%d"%i); unit.display_name=["庭園猴","疾跑猴","反擊猴","飛躍猴","藏身猴"][i]
		unit.level=1; unit.experience_reward=20; unit.sprite_path="res://features/monkey/assets/monkey_world.png"; unit.world_sprite_scale=0.22
		save(unit,"res://features/monkey/data/monkey_%d.tres"%i)
		var member:=MemberRule.new(); member.definition=unit; template.members.append(member)
		if i==0: template.representative=unit
	var habitat:=WorldHabitat.new(); habitat.profile=SpawnProfile.new(); habitat.profile.templates.append(template)
	habitat.profile.rules.max_enemy_parties=1; habitat.profile.rules.reinforcement_chance=0
	save(habitat,"res://features/monkey/data/habitat.tres")
	var encounter:=EncounterDefinition.new(); encounter.id=&"monkey_garden"; encounter.display_name="庭園捕猴"; encounter.monkey_profile=load("res://features/monkey/data/default.tres")
	var arena:=ArenaDefinition.new(); arena.arena_id="monkey_garden"; arena.encounter=encounter; arena.enemy_capacity=5
	save(arena,"res://features/world/data/monkey_garden_arena.tres")
	print("MONKEY_AUTHOR_OK polygons=",nav.get_polygon_count()); quit()
