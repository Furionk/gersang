@tool
extends Node
var passed: int = 0
var failed: int = 0
func _ready() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	print("PASS | " if ok else "FAIL | ",title)
	if ok: passed+=1
	else: failed+=1
func frames(count: int = 6) -> void:
	for index: int in count: await get_tree().process_frame
func run() -> void:
	await get_tree().create_timer(5).timeout
	var source_path: String = "res://features/skills/data/blast.tres"
	var source_hash: String = FileAccess.get_sha256(source_path)
	var resource: SkillDefinition = load(source_path).duplicate(true)
	var resource_path: String = "res://artifacts/editor-workflow-2026-10-11/editor-key-sandbox.tres"
	check(ResourceSaver.save(resource,resource_path)==OK,"native skill resource sandbox saved")
	resource=ResourceLoader.load(resource_path,"",ResourceLoader.CACHE_MODE_IGNORE)
	EditorInterface.edit_resource(resource)
	await frames(30)
	var editor: EditorProperty
	for node: Node in EditorInterface.get_inspector().find_children("*","EditorProperty",true,false):
		if node.get_script()!=null and node.get_script().resource_path=="res://addons/skill_authoring/key_property.gd": editor=node
	check(editor!=null,"real Inspector uses Chinese key picker")
	if editor==null: get_tree().quit(1); return
	var picker: OptionButton = editor.get("picker")
	check(picker.tooltip_text.contains("跟隨資源") and editor.label=="預設快捷鍵","Chinese meaning and override help visible in native property")
	var before_key: int = resource.default_key
	var next_key: int = KEY_K if before_key!=KEY_K else KEY_L
	picker.item_selected.emit(picker.get_item_index(next_key))
	await frames()
	check(resource.default_key==next_key,"Inspector picker changes actual resource field")
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var resource_history: UndoRedo = undo.get_history_undo_redo(undo.get_object_history_id(resource))
	resource_history.undo(); await frames()
	check(resource.default_key==before_key,"native Inspector key Undo")
	resource_history.redo(); await frames()
	check(resource.default_key==next_key,"native Inspector key Redo")
	check(ResourceSaver.save(resource,resource_path)==OK and ResourceLoader.load(resource_path,"",ResourceLoader.CACHE_MODE_IGNORE).default_key==next_key,"key Resource save/reopen")
	var scene_path: String = "res://features/world/data/qingling_town.tscn"
	var scene_hash: String = FileAccess.get_sha256(scene_path)
	var original: Node = load(scene_path).instantiate()
	var packed: PackedScene = PackedScene.new()
	var sandbox: String = "res://artifacts/editor-workflow-2026-10-11/editor-sprite-sandbox.tscn"
	check(packed.pack(original)==OK and ResourceSaver.save(packed,sandbox)==OK,"native world scene sandbox saved")
	original.free()
	EditorInterface.open_scene_from_path(sandbox)
	await get_tree().create_timer(2).timeout
	var map: WorldMap2D = EditorInterface.get_edited_scene_root()
	var plugin: EditorPlugin
	for node: Node in get_tree().root.find_children("*","EditorPlugin",true,false):
		if node.get_script()!=null and node.get_script().resource_path=="res://addons/world_authoring/plugin.gd": plugin=node
	check(map!=null and plugin!=null,"real editor world plugin available")
	if map==null or plugin==null: get_tree().quit(1); return
	plugin.call("_add_author",WorldAuthorNode.Kind.SCENERY)
	await frames()
	var sprite: Sprite2D = EditorInterface.get_selection().get_selected_nodes()[0] as Sprite2D
	check(sprite!=null and sprite.get_child_count()==0 and sprite.owner==map,"menu creates one editable Sprite2D with correct owner")
	if sprite==null: get_tree().quit(1); return
	var id: String = sprite.get_meta("world_scenery_id","")
	check(not id.is_empty(),"new native Sprite receives stable author ID")
	var clone: Sprite2D = sprite.duplicate()
	undo.create_action("Duplicate native scenery sandbox",UndoRedo.MERGE_DISABLE,map)
	undo.add_do_method(sprite.get_parent(),"add_child",clone)
	undo.add_do_property(clone,"owner",map)
	undo.add_undo_method(sprite.get_parent(),"remove_child",clone)
	undo.add_do_reference(clone)
	undo.commit_action()
	plugin.call("_select",clone); await frames()
	var clone_id: String = clone.get_meta("world_scenery_id","")
	check(not clone_id.is_empty() and clone_id!=id,"duplicate gets new stable ID without changing original")
	var history: UndoRedo = undo.get_history_undo_redo(undo.get_object_history_id(map))
	history.undo(); await frames()
	check(clone.get_parent()==null and sprite.get_meta("world_scenery_id")==id,"native Sprite duplication Undo")
	history.redo(); await frames()
	check(clone.get_parent()!=null and clone.get_meta("world_scenery_id")==clone_id,"native Sprite duplication Redo keeps same ID")
	clone.position+=Vector2(40,20)
	var definition: WorldMapDefinition = WorldAuthoringSnapshot.compile(map).definition
	var matches: Array[Dictionary] = definition.scenery.filter(func(entry: Dictionary) -> bool: return entry.id==clone_id)
	check(matches.size()==1 and matches[0].point.is_equal_approx(Iso.unproject(clone.position)),"native Sprite drag compiles exact planar foot position")
	packed=PackedScene.new()
	check(packed.pack(map)==OK and ResourceSaver.save(packed,sandbox)==OK,"single-Sprite editor scene saves")
	var reopened: Node = ResourceLoader.load(sandbox,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	var saved: Sprite2D = reopened.get_node(map.get_path_to(clone))
	check(saved!=null and saved.position==clone.position and saved.get_meta("world_scenery_id")==clone_id and saved.get_child_count()==0,"single Sprite position and ID survive reopen")
	reopened.free()
	check(plugin.call("_build"),"real build callback accepts single-Sprite scene")
	EditorInterface.edit_resource(resource); await frames(30)
	EditorInterface.get_inspector().expand_all_folding(); await frames()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png("res://artifacts/editor-workflow-2026-10-11/editor-inspector.png")
	check(FileAccess.get_sha256(source_path)==source_hash and FileAccess.get_sha256(scene_path)==scene_hash,"formal skill and artist scene unchanged by editor test")
	undo.clear_history(undo.get_object_history_id(map),false)
	print("EDITOR_WORKFLOW_EDITOR_RESULT passed=",passed," failed=",failed," manual_mouse=unverified")
	get_tree().quit(0 if failed==0 else 1)
