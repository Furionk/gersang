@tool
extends Node
const OUT: String = "res://artifacts/depth-sorting-2026-10-11/"
var passed: int = 0
var failed: int = 0
func _ready() -> void:
	get_tree().create_timer(60).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func check(ok: bool, title: String) -> void:
	print("PASS | " if ok else "FAIL | ",title)
	if ok: passed+=1
	else: failed+=1
func frames(count: int = 8) -> void:
	for index: int in count: await get_tree().process_frame
func run() -> void:
	await get_tree().create_timer(5).timeout
	var original: String = "res://features/world/data/qingling_town.tscn"
	var hash: String = FileAccess.get_sha256(original)
	var source: Node = load(original).instantiate()
	var packed: PackedScene = PackedScene.new()
	var run_id: String = str(Time.get_ticks_usec())
	var sandbox: String = OUT+"editor-sandbox-"+run_id+".tscn"
	check(packed.pack(source)==OK and ResourceSaver.save(packed,sandbox)==OK,"native sorting sandbox saved")
	source.free()
	EditorInterface.open_scene_from_path(sandbox)
	await get_tree().create_timer(2).timeout
	EditorInterface.set_main_screen_editor("2D")
	var map: WorldMap2D = EditorInterface.get_edited_scene_root()
	var plugin: EditorPlugin
	for node: Node in get_tree().root.find_children("*","EditorPlugin",true,false):
		if node.get_script()!=null and node.get_script().resource_path=="res://addons/world_authoring/plugin.gd": plugin=node
	check(map!=null and plugin!=null,"actual Godot editor loads sorting integration")
	if map==null or plugin==null: get_tree().quit(1); return
	var sprite: Sprite2D
	for node: Node in WorldAuthorTree.nodes(map):
		if ScenerySorting.is_scenery_sprite(node): sprite=node; break
	if sprite==null: get_tree().quit(1); return
	plugin.call("_select",sprite); await frames(30)
	var controls: VBoxContainer
	for node: Node in EditorInterface.get_inspector().find_children("*","VBoxContainer",true,false):
		if node.get_script()!=null and node.get_script().resource_path=="res://addons/world_authoring/sorting_controls.gd": controls=node
	check(controls!=null and sprite.get_child_count()==0,"native Inspector sorting controls, no extra Sprite child nodes")
	if controls==null: get_tree().quit(1); return
	var picker: OptionButton
	for child: Node in controls.get_children():
		if child is OptionButton: picker=child
	check(picker!=null and picker.item_count==4 and picker.selected==0 and picker.get_item_text(0)=="沿用素材","four Chinese choices and inherit is visibly selected")
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var history: UndoRedo = undo.get_history_undo_redo(undo.get_object_history_id(map))
	var previous_mode: int = ScenerySorting.mode_for(sprite)
	picker.item_selected.emit(1); await frames()
	check(sprite.z_index==ScenerySorting.GROUND_Z and sprite.get_meta(ScenerySorting.OVERRIDE_KEY)==0,"Inspector override applies ground band automatically")
	history.undo(); await frames()
	check(sprite.z_index==ScenerySorting.z_for(previous_mode) and not sprite.has_meta(ScenerySorting.OVERRIDE_KEY),"override Undo restores inherit, not a copied Z")
	history.redo(); await frames()
	check(sprite.z_index==ScenerySorting.GROUND_Z,"override Redo restores category")
	# Native Inspector rebuilds its controls when metadata/Undo changes the node.
	plugin.call("_select",sprite); await frames(30)
	controls=null
	for node: Node in EditorInterface.get_inspector().find_children("*","VBoxContainer",true,false):
		if node.get_script()!=null and node.get_script().resource_path=="res://addons/world_authoring/sorting_controls.gd": controls=node
	if controls==null: get_tree().quit(1); return
	for child: Node in controls.get_children():
		if child is OptionButton: picker=child
	picker.item_selected.emit(0); await frames()
	check(not sprite.has_meta(ScenerySorting.OVERRIDE_KEY) and sprite.z_index==ScenerySorting.z_for(previous_mode),"real inherit choice clears override instead of incorrectly selecting ground")
	plugin.call("_select",sprite); await frames(30)
	for node: Node in EditorInterface.get_inspector().find_children("*","VBoxContainer",true,false):
		if node.get_script()!=null and node.get_script().resource_path=="res://addons/world_authoring/sorting_controls.gd": controls=node
	var position: Vector2 = sprite.position; var offset: Vector2 = sprite.offset
	var origin: Vector2 = sprite.transform*sprite.get_rect().position
	var anchor: Vector2 = ScenerySorting.current_anchor(sprite)+Vector2(13,19)
	controls.get("anchor_x").value=anchor.x; controls.get("anchor_y").value=anchor.y
	for child: Node in controls.get_children():
		if child is Button and child.text.begins_with("校準腳底"):
			child.pressed.emit()
			break
	await frames()
	check((sprite.transform*sprite.get_rect().position).distance_to(origin)<0.001 and sprite.position!=position,"actual calibration button moves foot without moving image")
	history.undo(); await frames()
	check(sprite.position==position and sprite.offset==offset,"foot calibration Undo exact")
	history.redo(); await frames()
	check(ScenerySorting.current_anchor(sprite).is_equal_approx(anchor),"foot calibration Redo exact")
	# Shared Resource edits affect two independent scenery instances, not only the selected one.
	var preset: WorldSceneryDefinition = ScenerySorting.preset_for(sprite).duplicate()
	preset.sorting_mode=ScenerySorting.Mode.DEPTH
	var resource_path: String = OUT+"editor-preset-"+run_id+".tres"
	check(ResourceSaver.save(preset,resource_path)==OK,"isolated reusable sorting Resource")
	preset=ResourceLoader.load(resource_path,"",ResourceLoader.CACHE_MODE_IGNORE)
	var clone: Sprite2D = sprite.duplicate(); clone.name="SecondPresetUser"
	map.get_node("Scenery").add_child(clone); clone.owner=map
	sprite.remove_meta(ScenerySorting.OVERRIDE_KEY); clone.remove_meta(ScenerySorting.OVERRIDE_KEY)
	sprite.set_meta(ScenerySorting.PRESET_KEY,preset); clone.set_meta(ScenerySorting.PRESET_KEY,preset)
	plugin.call("refresh_sorting")
	EditorInterface.edit_resource(preset); await frames(30)
	EditorInterface.get_inspector().expand_all_folding(); await frames()
	var property: EditorProperty
	for node: Node in EditorInterface.get_inspector().find_children("*","EditorProperty",true,false):
		if node.get_script()!=null and node.get_script().resource_path=="res://addons/world_authoring/sorting_mode_property.gd": property=node
	check(property!=null and property.label=="排序類型","native Resource category has Chinese label")
	if property==null: get_tree().quit(1); return
	property.get("picker").item_selected.emit(2); await frames()
	check(sprite.z_index==1000 and clone.z_index==1000,"one shared Resource edit updates both instances in editor")
	var resource_history: UndoRedo = undo.get_history_undo_redo(undo.get_object_history_id(preset))
	resource_history.undo(); await frames()
	check(sprite.z_index==0 and clone.z_index==0,"native Resource Undo restores both users")
	resource_history.redo(); await frames()
	check(sprite.z_index==1000 and clone.z_index==1000,"native Resource Redo restores both users")
	check(ResourceSaver.save(preset,resource_path)==OK,"edited sorting Resource save")
	var parts_source: String = "res://features/world/authoring/templates/sorted_gate_parts.tscn"
	var parts_hash: String = FileAccess.get_sha256(parts_source)
	var parts: Node2D = load(parts_source).instantiate()
	map.get_node("Scenery").add_child(parts); parts.owner=map
	parts.position=Vector2(250,200); parts.scale=Vector2(-0.6,0.8)
	plugin.call("refresh_sorting"); await frames()
	var ids: Dictionary = {}
	for node: Node in WorldAuthorTree.nodes(parts):
		if node is Sprite2D: ids[str(node.get_meta("world_scenery_id",""))]=true
	check(map.is_editable_instance(parts) and ids.size()==3 and not ids.has(""),"placed parts prefab auto gets editable children and independent stable IDs")
	var duplicate: Node2D = parts.duplicate(); duplicate.name="SecondGate"
	map.get_node("Scenery").add_child(duplicate); duplicate.owner=map
	plugin.call("refresh_sorting"); await frames()
	var unique: bool = true
	for node: Node in WorldAuthorTree.nodes(duplicate):
		if node is Sprite2D: unique=unique and not ids.has(str(node.get_meta("world_scenery_id","")))
	check(unique and FileAccess.get_sha256(parts_source)==parts_hash,"duplicate parts get new IDs without mutating prefab source")
	WorldCatalog.initialize() # Editor MainLoop does not instantiate game autoloads.
	var parts_snapshot: Dictionary = WorldAuthoringSnapshot.compile(map)
	if not parts_snapshot.errors.is_empty(): print("PARTS_SNAPSHOT_ERRORS ",parts_snapshot.errors)
	check(parts_snapshot.errors.is_empty(),"real editor snapshot accepts moved/mirrored visual parts")
	packed=PackedScene.new()
	check(packed.pack(map)==OK and ResourceSaver.save(packed,sandbox)==OK,"sorting and calibrated Sprite scene saved")
	var saved: WorldMap2D = ResourceLoader.load(sandbox,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	var same: Sprite2D = saved.get_node(map.get_path_to(sprite))
	ScenerySorting.apply_map(saved)
	check(same.position==sprite.position and same.offset==sprite.offset and ScenerySorting.mode_for(same)==2,"save/reopen retains foot and Resource classification")
	var reopened: Node = saved.get_node(map.get_path_to(parts))
	var same_ids: Dictionary = {}
	for node: Node in WorldAuthorTree.nodes(reopened):
		if node is Sprite2D: same_ids[str(node.get_meta("world_scenery_id",""))]=true
	check(same_ids==ids,"instanced prefab per-map identities survive native save/reopen")
	saved.free()
	plugin.call("_select",sprite); await frames(30)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(OUT+"editor-sorting.png")
	check(FileAccess.get_sha256(original)==hash,"formal artist map unchanged by editor sandbox")
	undo.clear_history(undo.get_object_history_id(map),false)
	print("SORTING_EDITOR_RESULT passed=",passed," failed=",failed," manual_mouse=unverified")
	get_tree().quit(0 if failed==0 else 1)
