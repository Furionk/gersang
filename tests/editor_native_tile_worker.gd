@tool
extends Node
var passed: int = 0
var failures: int = 0
func _ready() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failures+=1

func run() -> void:
	await get_tree().create_timer(5).timeout
	var source: WorldMap2D = ResourceLoader.load("res://features/world/data/river_bay.tscn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate() as WorldMap2D
	source.name = "HumanEditorSandbox"
	source.set_meta("native_test_sandbox",true)
	var packed: PackedScene = PackedScene.new()
	var sandbox: String = "res://artifacts/world/editor-native-sandbox.tscn"
	check(packed.pack(source)==OK and ResourceSaver.save(packed,sandbox)==OK,"isolated native editor scene")
	source.free()
	EditorInterface.open_scene_from_path(sandbox)
	await get_tree().create_timer(1).timeout
	var map: WorldMap2D = EditorInterface.get_edited_scene_root() as WorldMap2D
	check(map!=null and bool(map.get_meta("native_test_sandbox",false)),"actual editor uses tagged sandbox")
	if map==null or not bool(map.get_meta("native_test_sandbox",false)): get_tree().quit(1); return
	var plugin: EditorPlugin
	for node: Node in get_tree().root.find_children("*","EditorPlugin",true,false):
		if node.get_script()!=null and node.get_script().resource_path=="res://addons/world_authoring/plugin.gd": plugin=node
	check(plugin!=null,"thin authoring plugin active")
	if plugin==null: get_tree().quit(1); return
	var tiles: WorldTileLayer = map.get_node("Ground/Obstacles_TileMap") as WorldTileLayer
	plugin.call("_select",tiles)
	for i: int in 3: await get_tree().process_frame
	check(EditorInterface.get_inspector().get_edited_object()==tiles,"native TileMap Inspector selected")
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var history: UndoRedo = undo.get_history_undo_redo(undo.get_object_history_id(map))
	var old_tiles: PackedByteArray = tiles.tile_map_data.duplicate()
	var old_cell: Array = [tiles.get_cell_source_id(Vector2i(8,8)),tiles.get_cell_atlas_coords(Vector2i(8,8)),tiles.get_cell_alternative_tile(Vector2i(8,8))]
	var old_count: int = tiles.get_used_cells().size()
	tiles.set_cell(Vector2i(8,8),0,Vector2i(4,15))
	var new_tiles: PackedByteArray = tiles.tile_map_data.duplicate()
	tiles.tile_map_data = old_tiles
	undo.create_action("Paint sandbox",UndoRedo.MERGE_DISABLE,map)
	undo.add_do_property(tiles,"tile_map_data",new_tiles)
	undo.add_undo_property(tiles,"tile_map_data",old_tiles)
	undo.commit_action()
	check(tiles.tile_map_data==new_tiles,"native tile edit committed")
	history.undo(); check(tiles.get_used_cells().size()==old_count and [tiles.get_cell_source_id(Vector2i(8,8)),tiles.get_cell_atlas_coords(Vector2i(8,8)),tiles.get_cell_alternative_tile(Vector2i(8,8))]==old_cell,"native tile Undo restores content (serialization order is not identity)")
	history.redo(); check(tiles.tile_map_data==new_tiles,"native tile Redo")
	history.undo()
	var region: WorldMonsterRegion = map.get_node("MonsterRegions/river") as WorldMonsterRegion
	plugin.call("_select",region)
	for i: int in 3: await get_tree().process_frame
	check(region.editor_selected and EditorInterface.get_inspector().get_edited_object()==region,"region selected in actual native Inspector")
	var scalar: EditorProperty
	for node: Node in EditorInterface.get_inspector().find_children("*","EditorProperty",true,false):
		if node.get_edited_property()==&"party_count": scalar=node
	check(scalar!=null,"human labelled population property present")
	if scalar!=null:
		var old_population: int = region.party_count
		scalar.emit_changed(&"party_count",9)
		for i: int in 3: await get_tree().process_frame
		check(region.party_count==9,"Inspector property command changes population")
		history.undo(); check(region.party_count==old_population,"Inspector Undo restores population")
	var shape: WorldRegionPolygon = region.get_node("SpawnArea") as WorldRegionPolygon
	plugin.call("select_shape",region,"SpawnArea")
	for i: int in 3: await get_tree().process_frame
	check(shape.editor_selected and EditorInterface.get_inspector().get_edited_object()==shape,"native Polygon2D vertex editor selection")
	var vertices: PackedVector2Array = shape.polygon.duplicate()
	var edited: PackedVector2Array = vertices.duplicate()
	edited[0]+=Vector2(16,8)
	undo.create_action("Polygon sandbox",UndoRedo.MERGE_DISABLE,map)
	undo.add_do_property(shape,"polygon",edited)
	undo.add_undo_property(shape,"polygon",vertices)
	undo.commit_action()
	check(shape.polygon==edited,"native polygon edit")
	history.undo(); check(shape.polygon==vertices,"native polygon Undo")
	history.redo(); check(shape.polygon==edited,"native polygon Redo")
	history.undo()
	var portal: WorldAuthorNode = map.get_node("Entrances/town_door") as WorldAuthorNode
	plugin.call("_select",portal)
	for i: int in 3: await get_tree().process_frame
	check(portal.has_node("Artwork") and portal.get_node("Artwork").owner==map and portal.coordinate_space==WorldAuthorNode.CoordinateSpace.CANVAS,"saved Sprite2D has true-position native transform")
	var target: EditorProperty
	for node: Node in EditorInterface.get_inspector().find_children("*","EditorProperty",true,false):
		if node.get_edited_property()==&"target_map_id": target=node
	check(target!=null,"portal destination dropdown present")
	var original_point: Vector2 = portal.position
	undo.create_action("Move sprite sandbox",UndoRedo.MERGE_DISABLE,map)
	undo.add_do_property(portal,"position",original_point+Vector2(80,40))
	undo.add_undo_property(portal,"position",original_point)
	undo.commit_action()
	check(WorldAuthoringSnapshot.compile(map).definition.portals[0].point.is_equal_approx(Iso.unproject(original_point)+Vector2(80,0)),"native sprite drag updates compiled portal")
	history.undo(); check(portal.position==original_point,"sprite drag Undo")
	plugin.call("_add_author",WorldAuthorNode.Kind.HABITAT)
	var author: WorldMonsterRegion = plugin.get("selected") as WorldMonsterRegion
	var author_parent: Node = author.get_parent()
	check(author!=null and author_parent==map.get_node("MonsterRegions") and author.owner==map and author.has_node("SpawnArea"),"new region template, named parent, native shape and owner")
	var identity: String = author.stable_id
	history.undo(); check(author.get_parent()==null,"template add Undo removes whole region")
	history.redo(); check(author.get_parent()==author_parent and author.stable_id==identity,"template add Redo retains stable ID")
	plugin.call("_select",author)
	plugin.call("_duplicate_selected")
	var clone: WorldMonsterRegion = plugin.get("selected") as WorldMonsterRegion
	check(clone!=null and clone.stable_id!=author.stable_id and not clone.stable_id.is_empty(),"native duplication assigns stable unique ID")
	plugin.call("_delete_selected")
	check(clone.get_parent()==null,"delete whole native region")
	history.undo(); check(clone.get_parent()==author_parent,"delete Undo restores region")
	history.undo(); history.undo() # duplicate and original add
	plugin.call("_select",region)
	check(not portal.editor_selected and shape.editor_selected and not map.get_node("MonsterRegions/farm/SpawnArea").editor_selected,"selection change shows selected region only, clears unrelated markers")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png("res://artifacts/workflow-2026-10-10/editor.png")
	packed = PackedScene.new()
	check(packed.pack(map)==OK and ResourceSaver.save(packed,sandbox)==OK,"sandbox save with grouped scene ownership")
	var reload: WorldMap2D = ResourceLoader.load(sandbox,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate() as WorldMap2D
	check(reload.has_node("MonsterRegions/river/SpawnArea") and reload.compile_definition().entries==map.compile_definition().entries,"grouped shapes and routes survive save/reopen")
	reload.free()
	undo.clear_history(undo.get_object_history_id(map),false)
	var output: FileAccess = FileAccess.open("res://artifacts/world/native-editor-results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":passed,"failed":failures,"manual_mouse_brush":"unverified","scope":"real editor APIs in isolated sandbox"},"\t")); output.close()
	print("NATIVE_EDITOR_RESULT passed=",passed," failures=",failures," manual_mouse_brush=unverified")
	get_tree().quit(0 if failures==0 else 1)
