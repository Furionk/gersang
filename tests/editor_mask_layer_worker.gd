@tool
extends Node
var passed: int = 0
var failed: int = 0
func _ready() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed += 1
	else: failed += 1
func run() -> void:
	await get_tree().create_timer(5).timeout
	var path: String = "res://artifacts/editor-layering-2026-10-10/sandbox.tscn"
	var source: Node = load("res://features/world/data/shaolin_temple.tscn").instantiate()
	var packed: PackedScene = PackedScene.new()
	check(packed.pack(source)==OK and ResourceSaver.save(packed,path)==OK,"isolated sandbox")
	source.free()
	EditorInterface.open_scene_from_path(path)
	await get_tree().create_timer(2).timeout
	var map: WorldMap2D = EditorInterface.get_edited_scene_root() as WorldMap2D
	if map==null: get_tree().quit(1); return
	var mask: WorldTileLayer = map.get_node("Ground/Walkable_Mask")
	var ground: WorldTileLayer = map.get_node("Ground/Ground_TileMap")
	var obstacles: WorldTileLayer = map.get_node("Ground/Obstacles_TileMap")
	var bytes: PackedByteArray = mask.tile_map_data.duplicate()
	var geometry: Dictionary = map.compile_definition().entries.duplicate(true)
	check(not mask.visible,"logic mask hidden on editor open")
	check(ground.visible and obstacles.visible,"visual terrain remains visible")
	var selection: EditorSelection = EditorInterface.get_selection()
	selection.clear()
	selection.add_node(mask)
	for i: int in 4: await get_tree().process_frame
	check(mask.visible and mask.self_modulate.a<0.3,"selected mask uses translucent overlay")
	selection.clear()
	selection.add_node(ground)
	for i: int in 4: await get_tree().process_frame
	check(not mask.visible,"terrain selection clears mask overlay")
	check(ground.visible and ground.self_modulate==Color.WHITE,"terrain tint unchanged")
	check(mask.tile_map_data==bytes,"mask brush data unchanged")
	check(map.compile_definition().entries==geometry,"compiled world geometry unchanged")
	selection.clear()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png("res://artifacts/editor-layering-2026-10-10/editor.png")
	var report: FileAccess = FileAccess.open("res://artifacts/editor-layering-2026-10-10/results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":passed,"failed":failed,"scope":"real editor APIs, isolated scene; manual mouse unverified"},"\t"))
	report.close()
	print("MASK_EDITOR_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
