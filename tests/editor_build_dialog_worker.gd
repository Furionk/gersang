@tool
extends Node
## Opt-in real Editor MainLoop test. Only disposable scene copies are edited.
var passed: int = 0
var failed: int = 0
var plugin: EditorPlugin
var result_dialog: AcceptDialog
var result_label: Label
var sandbox_base: String = "res://artifacts/build-dialog-2026-10-11/"

func _ready() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failed+=1

func open_copy(path: String, label: String) -> Node:
	var source: Node = (ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	var packed: PackedScene = PackedScene.new()
	var sandbox: String = sandbox_base+label+"-"+str(Time.get_ticks_usec())+".tscn"
	check(packed.pack(source)==OK and ResourceSaver.save(packed,sandbox)==OK,label+" isolated copy saved")
	source.free()
	EditorInterface.open_scene_from_path(sandbox)
	await get_tree().create_timer(2).timeout
	return EditorInterface.get_edited_scene_root()

func stale_modal() -> void:
	result_label.text="Old validation error (injected test fixture)"
	result_dialog.popup_centered(Vector2i(620,260))
	check(result_dialog.visible,"prior modal is visible before build")

func run() -> void:
	await get_tree().create_timer(5).timeout
	for candidate: Node in get_tree().root.find_children("*","EditorPlugin",true,false):
		if candidate.get_script()!=null and candidate.get_script().resource_path=="res://addons/world_authoring/plugin.gd": plugin=candidate
	check(plugin!=null,"real World Authoring plugin available")
	if plugin==null: get_tree().quit(1); return
	result_dialog=plugin.get("dialog")
	result_label=plugin.get("status")
	var battle_path: String="res://features/battle/maps/millennium_lake.tscn"
	var world_path: String="res://features/world/data/millennium_lake.tscn"
	var battle_hash: String=FileAccess.get_sha256(battle_path)
	var world_hash: String=FileAccess.get_sha256(world_path)
	var battle: Node=await open_copy(battle_path,"battle")
	check(battle is BattlefieldMap,"native editor opens lake battlefield")
	check(plugin.call("_build") and not result_dialog.visible,"valid battlefield Play callback is silent")
	stale_modal()
	check(plugin.call("_build") and not result_dialog.visible,"valid battlefield build dismisses stale modal")
	check(result_label.text.contains("戰場配置有效"),"battlefield success text is fresh")
	var zone: BattleSpawnZone=battle.get_node("SpawnZones/Position_3")
	var capacity: int=zone.capacity
	zone.capacity=0
	print("EXPECTED_VALIDATION_ERROR_BEGIN battlefield capacity=0")
	check(not plugin.call("_build") and result_dialog.visible,"invalid battlefield still blocks Play and reports error")
	print("EXPECTED_VALIDATION_ERROR_END")
	check(result_label.text.contains("Position_3") and result_label.text.contains("容量"),"failure identifies bad spawn zone")
	zone.capacity=capacity
	check(plugin.call("_build") and not result_dialog.visible,"repaired battlefield closes prior failure modal")
	plugin.call("_menu_action",0)
	check(result_dialog.visible and result_label.text.contains("戰場配置有效"),"explicit Verify still shows success")
	check(plugin.call("_build") and not result_dialog.visible,"Play clears explicit Verify result")
	var world: Node=await open_copy(world_path,"world")
	check(world is WorldMap2D,"native editor opens lake world map")
	stale_modal()
	check(plugin.call("_build") and not result_dialog.visible,"valid world map clears stale modal")
	var walkable: WorldTileLayer=world.find_child("Walkable_Mask",true,false)
	var old_data: PackedByteArray=walkable.tile_map_data.duplicate()
	walkable.clear()
	print("EXPECTED_VALIDATION_ERROR_BEGIN empty Walkable")
	check(not plugin.call("_build") and result_dialog.visible,"invalid world draft still blocks Play")
	print("EXPECTED_VALIDATION_ERROR_END")
	walkable.tile_map_data=old_data
	check(plugin.call("_build") and not result_dialog.visible,"corrected world draft clears failure modal")
	var ordinary: Node=await open_copy("res://main.tscn","ordinary")
	check(ordinary!=null,"ordinary scene opened")
	stale_modal()
	check(plugin.call("_build") and not result_dialog.visible,"non-map Play clears stale modal")
	check(result_label.text.contains("不是世界地圖"),"non-map manual result cannot reuse stale success text")
	check(FileAccess.get_sha256(battle_path)==battle_hash,"original lake battlefield preserved")
	check(FileAccess.get_sha256(world_path)==world_hash,"original lake world map preserved")
	var file: FileAccess=FileAccess.open(sandbox_base+"results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"battle_hash":battle_hash,"world_hash":world_hash,"scope":"real native Editor callbacks and modal visibility; isolated copies only; physical F5 mouse unverified"},"\t"))
	file.close()
	print("BUILD_DIALOG_EDITOR_RESULT passed=",passed," failed=",failed," physical_F5_mouse=unverified")
	get_tree().quit(0 if failed==0 else 1)
