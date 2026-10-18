extends SceneTree
var passed: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	print("PASS | " if ok else "FAIL | ",title)
	if ok: passed+=1
	else: failures+=1
func run() -> void:
	await create_timer(5.0).timeout
	WorldCatalog.initialize()
	var source: WorldMap2D = load("res://features/world/data/river_bay.tscn").instantiate() as WorldMap2D
	var original: WorldMapDefinition = source.compile_definition()
	var script: Script = load("res://tests/placeholder_world_fixture.gd") as Script
	check(not script.is_tool() and not script.can_instantiate(),"fixture is non-executable editor script")
	var placeholder: Node2D = Node2D.new()
	placeholder.set_script(script)
	placeholder.set("definition",source.definition)
	placeholder.set("native_tiles_enabled",source.native_tiles_enabled)
	for child: Node in source.get_children():
		var clone: Node = child.duplicate()
		placeholder.add_child(clone)
		clone.owner = placeholder
		for descendant: Node in WorldAuthorTree.nodes(clone,true): descendant.owner = placeholder
	check(placeholder is WorldMap2D and placeholder.has_method("compile_definition"),"placeholder advertises WorldMap2D method despite being non-executable")
	var snapshot: Dictionary = WorldAuthoringSnapshot.compile(placeholder,WorldCatalog.definitions)
	if not snapshot["errors"].is_empty(): print("PLACEHOLDER_VALIDATION_ERRORS ",snapshot["errors"])
	check(snapshot["ok"] and snapshot["errors"].is_empty(),"actual placeholder compiles and validates via detached canonical snapshot")
	var compiled: WorldMapDefinition = snapshot["definition"]
	check(compiled.portals==original.portals and compiled.entries==original.entries,"snapshot preserves all portal and arrival fields")
	var layer: WorldTileLayer = placeholder.find_child("Walkable_Mask",true,false) as WorldTileLayer
	var data_before: PackedByteArray = layer.tile_map_data.duplicate()
	layer.erase_cell(Vector2i(5,5))
	var edited: Dictionary = WorldAuthoringSnapshot.compile(placeholder)
	var erased: bool = true
	for domain: PolygonDomain in edited["definition"].walkable: erased = erased and not domain.contains(Vector2(176,176))
	check(erased,"snapshot includes unsaved brush edits, not last file on disk")
	check(layer.get_cell_source_id(Vector2i(5,5))==-1 and layer.tile_map_data!=data_before,"validation does not overwrite edited scene data")
	var root_script: Script = source.get_script()
	var packed: PackedScene = PackedScene.new()
	placeholder.name = "PlaceholderBuildSandbox"
	placeholder.set_meta("placeholder_test_sandbox",true)
	check(packed.pack(placeholder)==OK,"placeholder sandbox packs without touching formal map")
	var path: String = "res://artifacts/world/placeholder-build-sandbox.tscn"
	check(ResourceSaver.save(packed,path,ResourceSaver.FLAG_CHANGE_PATH)==OK,"isolated placeholder scene saved")
	EditorInterface.open_scene_from_path(path)
	await create_timer(1.0).timeout
	var current: Node = EditorInterface.get_edited_scene_root()
	check(current!=null and current.get_meta("placeholder_test_sandbox",false),"actual editor tab is placeholder sandbox")
	if current==null or not current.get_meta("placeholder_test_sandbox",false):
		placeholder.free(); source.free(); quit(1); return
	var plugin: EditorPlugin
	for candidate: Node in root.find_children("*","EditorPlugin",true,false):
		if candidate.get_script()!=null and candidate.get_script().resource_path=="res://addons/world_authoring/plugin.gd": plugin=candidate
	check(plugin!=null,"actual World Authoring plugin found")
	if plugin!=null:
		plugin.set("root_map",source) # Deliberately stale cached tab.
		check(plugin.call("_build"),"real build callback validates placeholder without calling its method")
		check(plugin.get("root_map")==current,"build callback uses current editor tab instead of cached root")
		var current_layer: WorldTileLayer = current.find_child("Walkable_Mask",true,false) as WorldTileLayer
		var old: PackedByteArray = current_layer.tile_map_data.duplicate()
		current_layer.clear()
		check(not plugin.call("_build"),"invalid unsaved placeholder map still blocks play, validation is not skipped")
		current_layer.tile_map_data = old
		check(plugin.call("_build"),"corrected placeholder draft can build again")
	check(source.get_script()==root_script and source.find_child("Walkable_Mask",true,false).get_cell_source_id(Vector2i(5,5))!=-1,"live source script and brush data remain untouched")
	for id: String in WorldCatalog.definitions:
		var scene_path: String = WorldCatalog.definitions[id].scene_path
		if scene_path.is_empty(): continue
		var normal: WorldMap2D = load(scene_path).instantiate() as WorldMap2D
		var canonical: Dictionary = WorldAuthoringSnapshot.compile(normal)
		var direct: WorldMapDefinition = normal.compile_definition()
		check(canonical["ok"] and canonical["definition"].portals==direct.portals and canonical["definition"].entries==direct.entries and canonical["definition"].habitats.size()==direct.habitats.size(),"normal map snapshot parity "+id)
		normal.free()
	placeholder.free()
	source.free()
	var file: FileAccess = FileAccess.open("res://artifacts/world/placeholder-build-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failures,"scope":"actual editor placeholder and sandbox build callbacks; no formal saves"},"\t")); file.close()
	print("PLACEHOLDER_BUILD_RESULT passed=",passed," failed=",failures)
	quit(0 if failures==0 else 1)
