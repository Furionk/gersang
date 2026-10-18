@tool
extends Node
var passed:int=0
var failed:int=0
func check(ok:bool,title:String)->void:
	print("PASS | " if ok else "FAIL | ",title)
	if ok: passed+=1
	else: failed+=1
func _ready()->void: call_deferred("run")
func run()->void:
	await get_tree().create_timer(4).timeout
	var path:String="res://features/units/data/mercenaries/ninja.tres"
	var original:String=FileAccess.get_sha256(path)
	var unit:UnitDefinition=load(path).duplicate()
	unit.sprite_layout=load("res://tests/content_authoring_suite.gd").sample()
	var sandbox:String="res://artifacts/content-authoring-2026-10-12/editor-sandbox.tres"
	check(ResourceSaver.save(unit,sandbox)==OK,"sandbox saved")
	EditorInterface.edit_resource(unit)
	await get_tree().create_timer(2).timeout
	var inspector:EditorInspector=EditorInterface.get_inspector()
	var preview:VBoxContainer
	for node:Node in inspector.find_children("*","VBoxContainer",true,false):
		if node.get_script()!=null and node.get_script().resource_path=="res://addons/skill_authoring/sprite_preview.gd": preview=node; break
	check(preview!=null,"native Inspector has sprite review controls")
	if preview==null: get_tree().quit(1); return
	var fold:FoldableContainer=preview.get_parent(); fold.folded=false
	preview.get("action").select(1); preview.get("direction").select(6); preview.call("reset_frame")
	check(preview.get("clips").get_frame_count(&"walk_6")==5,"five walk frames in actual Inspector")
	preview.get("frame_picker").value=4
	check(preview.get("detail").text.contains("第5／5") and preview.get("detail").text.contains("原圖列2"),"frame/direction labels follow real source")
	var clip:SpriteAnimationClip=unit.sprite_layout.animations[1]
	var undo:EditorUndoRedoManager=EditorInterface.get_editor_undo_redo()
	undo.create_action("Test variable frames",UndoRedo.MERGE_DISABLE,unit)
	undo.add_do_property(clip,"columns",PackedInt32Array([3,2])); undo.add_undo_property(clip,"columns",clip.columns)
	undo.add_do_property(clip,"frame_durations",PackedFloat32Array()); undo.add_undo_property(clip,"frame_durations",clip.frame_durations)
	undo.commit_action(); preview.call("rebuild")
	check(preview.get("clips").get_frame_count(&"walk_6")==2,"native resource edit updates preview")
	var history:UndoRedo=undo.get_history_undo_redo(undo.get_object_history_id(unit))
	history.undo(); preview.call("rebuild"); check(preview.get("clips").get_frame_count(&"walk_6")==5,"Undo exact frames")
	history.redo(); preview.call("rebuild"); check(preview.get("clips").get_frame_count(&"walk_6")==2,"Redo exact frames")
	check(ResourceSaver.save(unit,sandbox)==OK,"edited sandbox saved")
	var reopened:UnitDefinition=ResourceLoader.load(sandbox,"",ResourceLoader.CACHE_MODE_IGNORE)
	check(reopened.sprite_layout.animations[1].columns==PackedInt32Array([3,2]),"save/reopen keeps custom frames")
	# Check the only mutating helper on a blank disposable layout, including native Undo.
	var fresh:SpriteSheetLayout=SpriteSheetLayout.new(); fresh.source_texture=unit.sprite_layout.source_texture
	EditorInterface.edit_resource(fresh)
	await get_tree().create_timer(1).timeout
	var initialize:Button
	for node:Node in inspector.find_children("*","Button",true,false):
		if node.text.begins_with("空白新圖集"): initialize=node; break
	check(initialize!=null and not initialize.disabled,"blank layout initializer available")
	if initialize!=null:
		initialize.pressed.emit()
		await get_tree().create_timer(0.5).timeout
		check(fresh.frame_rects.size()==48 and fresh.valid_for(Vector2i(fresh.source_texture.get_size())),"blank initializer makes valid native crops")
		var fresh_history:UndoRedo=undo.get_history_undo_redo(undo.get_object_history_id(fresh))
		fresh_history.undo(); check(fresh.frame_rects.is_empty(),"blank initialization Undo exact")
		fresh_history.redo(); check(fresh.frame_rects.size()==48,"blank initialization Redo exact")
		fresh_history.clear_history(false)
	# Capture real authored art after synthetic API checks; no formal resource editing.
	EditorInterface.edit_resource(load(path))
	await get_tree().create_timer(1).timeout
	for node:Node in inspector.find_children("*","VBoxContainer",true,false):
		if node.get_script()!=null and node.get_script().resource_path=="res://addons/skill_authoring/sprite_preview.gd": preview=node; break
	fold=preview.get_parent(); fold.folded=false
	preview.get("action").select(3); preview.get("direction").select(3); preview.call("reset_frame")
	inspector.ensure_control_visible(preview.get("view"))
	await get_tree().create_timer(1).timeout
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw(); get_tree().root.get_texture().get_image().save_png("res://artifacts/content-authoring-2026-10-12/editor-preview.png")
	check(FileAccess.get_sha256(path)==original,"formal unit and original art untouched")
	history.clear_history(false)
	var file:FileAccess=FileAccess.open("res://artifacts/content-authoring-2026-10-12/editor-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"scope":"native EditorInterface/Undo/sandbox; manual mouse not verified"})); file.close()
	print("CONTENT_EDITOR_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
