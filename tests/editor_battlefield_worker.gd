@tool
extends Node
var passed: int = 0
var failed: int = 0
func _ready() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failed+=1
func run() -> void:
	await get_tree().create_timer(5).timeout
	var original: String = "res://features/battle/maps/shaolin_temple.tscn"
	var hash_before: String = FileAccess.get_sha256(original)
	var source: Node = load(original).instantiate()
	var packed: PackedScene = PackedScene.new()
	var sandbox: String = "res://artifacts/battlefield-scenes-2026-10-11/editor-sandbox.tscn"
	check(packed.pack(source)==OK and ResourceSaver.save(packed,sandbox)==OK,"native battlefield sandbox")
	source.free()
	EditorInterface.open_scene_from_path(sandbox)
	await get_tree().create_timer(2).timeout
	var map: BattlefieldMap = EditorInterface.get_edited_scene_root()
	check(map!=null,"actual editor opens BattlefieldMap scene")
	if map==null: get_tree().quit(1); return
	var plugin: EditorPlugin
	for node: Node in get_tree().root.find_children("*","EditorPlugin",true,false):
		if node.get_script()!=null and node.get_script().resource_path=="res://addons/world_authoring/plugin.gd": plugin=node
	check(plugin!=null and plugin.call("_build"),"real build callback accepts native battle scene")
	var selection: EditorSelection = EditorInterface.get_selection()
	var ground: BattleTileLayer = map.get_node("Terrain/Ground")
	var walkable: BattleTileLayer = map.get_node("Terrain/Walkable")
	selection.clear(); selection.add_node(walkable)
	for i: int in 3: await get_tree().process_frame
	check(walkable.visible and walkable.self_modulate.a<0.3,"native mask selection translucent")
	selection.clear(); selection.add_node(ground)
	for i: int in 3: await get_tree().process_frame
	check(not walkable.visible and ground.visible,"terrain selection hides logic overlay")
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var history: UndoRedo = undo.get_history_undo_redo(undo.get_object_history_id(map))
	var old_data: PackedByteArray = ground.tile_map_data.duplicate()
	var old_cell: Vector2i = ground.get_cell_atlas_coords(Vector2i(5,5))
	ground.set_cell(Vector2i(5,5),0,Vector2i(3,0))
	var edited: PackedByteArray = ground.tile_map_data.duplicate()
	ground.tile_map_data=old_data
	undo.create_action("Battle tile brush sandbox",UndoRedo.MERGE_DISABLE,map)
	undo.add_do_property(ground,"tile_map_data",edited); undo.add_undo_property(ground,"tile_map_data",old_data); undo.commit_action()
	check(ground.tile_map_data==edited,"native TileMap edit")
	history.undo(); check(ground.get_cell_atlas_coords(Vector2i(5,5))==old_cell,"native TileMap Undo restores exact brush variant")
	history.redo(); check(ground.tile_map_data==edited,"native TileMap Redo")
	var marker: BattleSpawnZone = map.get_node("SpawnZones/Position_1")
	var point: Vector2 = marker.position
	undo.create_action("Battle spawn drag sandbox",UndoRedo.MERGE_DISABLE,map)
	undo.add_do_property(marker,"position",point+Vector2(16,8)); undo.add_undo_property(marker,"position",point); undo.commit_action()
	check(BattlefieldCompiler.compile(map).zones[0].point.is_equal_approx(Iso.unproject(point+Vector2(16,8))),"native spawn drag compiles true point")
	history.undo(); check(marker.position==point,"spawn drag Undo")
	history.redo(); check(marker.position==point+Vector2(16,8),"spawn drag Redo")
	packed=PackedScene.new()
	check(packed.pack(map)==OK and ResourceSaver.save(packed,sandbox)==OK,"native edited scene save")
	var reload: Node = ResourceLoader.load(sandbox,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	check(reload.get_node("Terrain/Ground").get_cell_atlas_coords(Vector2i(5,5))==Vector2i(3,0) and reload.get_node("SpawnZones/Position_1").position==marker.position,"saved tile and marker reopen")
	reload.free()
	selection.clear()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png("res://artifacts/battlefield-scenes-2026-10-11/editor.png")
	check(FileAccess.get_sha256(original)==hash_before,"formal artist scene preserved")
	undo.clear_history(undo.get_object_history_id(map),false)
	print("BATTLEFIELD_EDITOR_RESULT passed=",passed," failed=",failed," manual_mouse=unverified")
	get_tree().quit(0 if failed==0 else 1)
