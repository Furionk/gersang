@tool
extends EditorPlugin
## Thin integration: Godot owns selection, transforms, polygon input and brushes.
var root_map: WorldMap2D
var selected: WorldAuthorNode
var registry: Dictionary = {}
var status: Label
var dialog: AcceptDialog
var menu: PopupMenu
var inspector: EditorInspectorPlugin
var known_nodes: Dictionary = {}
var sorting_refresh_pending: bool = false

func _enter_tree() -> void:
	dialog = AcceptDialog.new()
	dialog.title = "地圖檢查"
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(560,100)
	dialog.add_child(status)
	get_editor_interface().get_base_control().add_child(dialog)
	menu = PopupMenu.new()
	for title: String in ["驗證目前地圖","試玩目前地圖（F6，隔離存檔）","新增怪物區域","新增城鎮／地城入口","新增建築／山體 Sprite","開啟簡明製圖指南"]: menu.add_item(title)
	menu.id_pressed.connect(_menu_action)
	add_tool_submenu_item("地圖",menu)
	inspector = preload("res://addons/world_authoring/world_inspector.gd").new()
	inspector.set("plugin",self)
	add_inspector_plugin(inspector)
	get_editor_interface().get_selection().selection_changed.connect(_selection_changed)
	scene_changed.connect(_scene_changed)
	get_tree().tree_changed.connect(_schedule_sorting)
	get_editor_interface().get_inspector().property_edited.connect(_sort_property_edited)
	resource_saved.connect(_sorting_resource_saved)
	_scene_changed(get_editor_interface().get_edited_scene_root())
	# Opt-in test worker keeps the real editor MainLoop/window lifecycle intact.
	if "--native-editor-smoke" in OS.get_cmdline_user_args():
		var worker: Node = Node.new()
		worker.set_script(load("res://tests/editor_native_tile_worker.gd"))
		add_child(worker)
	if "--mask-layer-smoke" in OS.get_cmdline_user_args():
		var worker: Node = Node.new()
		worker.set_script(load("res://tests/editor_mask_layer_worker.gd"))
		add_child(worker)
	if "--battlefield-editor-smoke" in OS.get_cmdline_user_args():
		var worker: Node = Node.new()
		worker.set_script(load("res://tests/editor_battlefield_worker.gd"))
		add_child(worker)
	if "--sorting-editor-smoke" in OS.get_cmdline_user_args():
		var worker: Node = Node.new()
		worker.set_script(load("res://tests/editor_sorting_worker.gd"))
		add_child(worker)
	if "--build-dialog-smoke" in OS.get_cmdline_user_args():
		var worker: Node = Node.new()
		worker.set_script(load("res://tests/editor_build_dialog_worker.gd"))
		add_child(worker)

func _exit_tree() -> void:
	if get_tree().tree_changed.is_connected(_schedule_sorting): get_tree().tree_changed.disconnect(_schedule_sorting)
	if get_editor_interface().get_inspector().property_edited.is_connected(_sort_property_edited): get_editor_interface().get_inspector().property_edited.disconnect(_sort_property_edited)
	if resource_saved.is_connected(_sorting_resource_saved): resource_saved.disconnect(_sorting_resource_saved)
	var selection: EditorSelection = get_editor_interface().get_selection()
	if selection.selection_changed.is_connected(_selection_changed): selection.selection_changed.disconnect(_selection_changed)
	if scene_changed.is_connected(_scene_changed): scene_changed.disconnect(_scene_changed)
	remove_inspector_plugin(inspector)
	remove_tool_menu_item("地圖")
	if is_instance_valid(dialog): dialog.queue_free()

func _scene_changed(scene: Node) -> void:
	root_map = scene as WorldMap2D
	known_nodes.clear()
	if root_map!=null:
		for node: Node in WorldAuthorTree.nodes(root_map):
			if node is WorldAuthorNode and not node.stable_id.is_empty(): known_nodes[node.get_instance_id()] = node.stable_id
			elif NativeScenery.is_author(node) and not str(node.get_meta("world_scenery_id","")).is_empty(): known_nodes[node.get_instance_id()]=node.get_meta("world_scenery_id")
	_selection_changed()

func _handles(object: Object) -> bool:
	return object is WorldAuthorNode or object is WorldRegionPolygon or object is WorldMap2D or object is WorldTileLayer or object is BattlefieldMap or object is BattleTileLayer or object is BattleSpawnZone or (object is Node and NativeScenery.is_author(object))

func _edit(_object: Object) -> void: _selection_changed()

func _selection_changed() -> void:
	_schedule_sorting()
	var edited: Node = get_editor_interface().get_edited_scene_root()
	if edited is BattlefieldMap:
		root_map=null
		var battle_selection: Array[Node] = get_editor_interface().get_selection().get_selected_nodes()
		for node: Node in WorldAuthorTree.nodes(edited):
			if node is BattleTileLayer: node.set_editor_selected(battle_selection.has(node))
		return
	root_map = get_editor_interface().get_edited_scene_root() as WorldMap2D
	if root_map==null: return
	var selection: Array[Node] = get_editor_interface().get_selection().get_selected_nodes()
	selected = null
	_ensure_ids()
	for node: Node in WorldAuthorTree.nodes(root_map):
		if node is WorldTileLayer:
			node.set_editor_selected(selection.has(node))
		if node is WorldAuthorNode:
			node.set_editor_selected(selection.has(node))
			if selection.has(node): selected = node
		if node is WorldRegionPolygon:
			node.editor_selected = selection.has(node) or selection.has(node.get_parent())
			node.queue_redraw()
	update_overlays()

func _sort_property_edited(_property: String) -> void: _schedule_sorting()
func _sorting_resource_saved(_resource: Resource) -> void:
	ScenerySorting.invalidate_catalog()
	_schedule_sorting()
func _schedule_sorting() -> void:
	if sorting_refresh_pending: return
	sorting_refresh_pending=true
	call_deferred("refresh_sorting")
func refresh_sorting() -> void:
	sorting_refresh_pending=false
	var scene: Node = get_editor_interface().get_edited_scene_root()
	if scene is WorldMap2D:
		root_map=scene
		_ensure_ids()
	if scene is WorldMap2D or scene is BattlefieldMap: ScenerySorting.apply_map(scene)
	update_overlays()

func _set_sort_metadata(node: Node, key: StringName, value: Variant) -> void:
	if value==null and not node.has_meta(key): return
	if node.has_meta(key) and node.get_meta(key)==value: return
	var undo: EditorUndoRedoManager = get_undo_redo()
	undo.create_action("地景排序設定",UndoRedo.MERGE_DISABLE,node)
	if value==null: undo.add_do_method(node,"remove_meta",key)
	else: undo.add_do_method(node,"set_meta",key,value)
	if node.has_meta(key): undo.add_undo_method(node,"set_meta",key,node.get_meta(key))
	else: undo.add_undo_method(node,"remove_meta",key)
	undo.add_do_method(self,"refresh_sorting")
	undo.add_undo_method(self,"refresh_sorting")
	undo.commit_action()
func set_sort_override(node: Node, mode: int) -> void:
	if mode in [-1,0,1,2]: _set_sort_metadata(node,ScenerySorting.OVERRIDE_KEY,null if mode==-1 else mode)
func set_sort_preset(node: Node, preset: WorldSceneryDefinition) -> void:
	_set_sort_metadata(node,ScenerySorting.PRESET_KEY,preset)
func calibrate_foot(sprite: Sprite2D, point: Vector2) -> void:
	if not point.is_finite() or not sprite.position.is_finite(): return
	var values: Dictionary = ScenerySorting.calibration(sprite,point)
	var undo: EditorUndoRedoManager = get_undo_redo()
	undo.create_action("校準腳底（保持圖片位置）",UndoRedo.MERGE_DISABLE,sprite)
	undo.add_do_property(sprite,"position",values.position)
	undo.add_do_property(sprite,"offset",values.offset)
	undo.add_undo_property(sprite,"position",sprite.position)
	undo.add_undo_property(sprite,"offset",sprite.offset)
	undo.add_do_method(self,"refresh_sorting"); undo.add_undo_method(self,"refresh_sorting")
	undo.commit_action()
func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	var scene: Node = get_editor_interface().get_edited_scene_root()
	if not (scene is WorldMap2D or scene is BattlefieldMap): return
	var canvas: Transform2D = get_editor_interface().get_editor_viewport_2d().get_canvas_transform()
	for node: Node in get_editor_interface().get_selection().get_selected_nodes():
		if not ScenerySorting.is_scenery_sprite(node) and not (node is WorldAuthorNode and node.sprite_definition!=null): continue
		var point: Vector2 = canvas*node.global_position
		overlay.draw_line(point-Vector2(12,0),point+Vector2(12,0),Color(1,0.8,0.2),2)
		overlay.draw_line(point-Vector2(0,12),point+Vector2(0,12),Color(1,0.8,0.2),2)
		overlay.draw_circle(point,4,Color(1,0.8,0.2))
		overlay.draw_string(ThemeDB.fallback_font,point+Vector2(14,-10),"腳底／排序點",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(1,0.9,0.5))

func _ensure_ids() -> void:
	var occupied: Dictionary = {}
	for node: Node in WorldAuthorTree.nodes(root_map):
		if node is WorldAuthorNode and known_nodes.has(node.get_instance_id()): occupied[node.stable_id] = true
		elif NativeScenery.is_author(node) and known_nodes.has(node.get_instance_id()): occupied[str(node.get_meta("world_scenery_id",""))]=true
	for node: Node in WorldAuthorTree.nodes(root_map):
		if NativeScenery.is_author(node):
			var ancestor: Node = node.get_parent()
			while ancestor!=null and ancestor!=root_map:
				if ancestor.get_meta("scenery_parts",false) and not ancestor.scene_file_path.is_empty() and not root_map.is_editable_instance(ancestor): root_map.set_editable_instance(ancestor,true)
				ancestor=ancestor.get_parent()
			var id: String = str(node.get_meta("world_scenery_id",""))
			if not known_nodes.has(node.get_instance_id()) and (id.is_empty() or occupied.has(id)):
				id="scenery_%x_%x" % [Time.get_ticks_usec(),node.get_instance_id()]
				node.set_meta("world_scenery_id",id)
				get_editor_interface().mark_scene_as_unsaved()
			known_nodes[node.get_instance_id()]=id; occupied[id]=true
			continue
		if not node is WorldAuthorNode: continue
		if not known_nodes.has(node.get_instance_id()):
			if node.stable_id.is_empty() or occupied.has(node.stable_id):
				if occupied.has(node.stable_id) and node is WorldMonsterRegion and node.habitat!=null: node.habitat = node.habitat.duplicate(true) as WorldHabitat
				node.stable_id = "author_%x_%x" % [Time.get_ticks_usec(),node.get_instance_id()]
				get_editor_interface().mark_scene_as_unsaved()
			known_nodes[node.get_instance_id()] = node.stable_id
		occupied[node.stable_id] = true

func _menu_action(id: int) -> void:
	match id:
		0:
			# Explicit validation reports success; Play only reports failures.
			# A failed build already opened its detailed error dialog.
			if _build(): dialog.popup_centered(Vector2i(620,220))
		1:
			if _build(): get_editor_interface().play_current_scene()
		2: _add_author(WorldAuthorNode.Kind.HABITAT)
		3: _add_author(WorldAuthorNode.Kind.PORTAL)
		4: _add_author(WorldAuthorNode.Kind.SCENERY)
		5: OS.shell_open(ProjectSettings.globalize_path("res://docs/battlefield_artist_guide.md" if get_editor_interface().get_edited_scene_root() is BattlefieldMap else "res://docs/human_authoring_guide.md"))

func _validate() -> bool:
	if root_map==null: return true
	WorldCatalog.initialize()
	registry.clear()
	registry.merge(WorldCatalog.definitions)
	# Fresh OFF-TREE data only: new maps/arrivals must be discoverable without restart.
	for file: String in DirAccess.get_files_at("res://features/world/data"):
		if not file.ends_with(".tscn"): continue
		var packed: PackedScene = ResourceLoader.load("res://features/world/data/"+file,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if packed==null: continue
		var fresh: WorldMap2D = packed.instantiate() as WorldMap2D
		if fresh!=null:
			var data: WorldMapDefinition = fresh.compile_definition()
			registry[data.map_id] = data
			fresh.free()
	var snapshot: Dictionary = WorldAuthoringSnapshot.compile(root_map,registry)
	if not snapshot.ok:
		status.text = snapshot.error
		return false
	var errors: Array[String] = snapshot.errors
	status.text = "配置有效。F6 可試玩目前地圖；預覽不修改正式進度。" if errors.is_empty() else "\n".join(errors)
	if not errors.is_empty():
		for node: Node in WorldAuthorTree.nodes(root_map):
			if node is WorldAuthorNode and (errors[0].contains(node.stable_id) or errors[0].contains(str(node.name))):
				_select(node)
				break
	return errors.is_empty()

func _build() -> bool:
	# Never leave an earlier validation modal over a successful Play request.
	# Reset visibility before changing the shared result label.
	if is_instance_valid(dialog): dialog.hide()
	var edited: Node = get_editor_interface().get_edited_scene_root()
	if edited is BattlefieldMap:
		var compiled: Dictionary = BattlefieldCompiler.compile(edited)
		if not compiled.errors.is_empty():
			status.text="\n".join(compiled.errors)
			push_error("戰場配置檢查未通過：\n"+status.text)
			dialog.popup_centered(Vector2i(620,260))
			return false
		status.text="戰場配置有效。F6 隔離試玩，正式戰鬥直接使用此 Scene。"
		return true
	root_map = get_editor_interface().get_edited_scene_root() as WorldMap2D
	if root_map==null:
		status.text="目前場景不是世界地圖／戰場，沒有地圖配置需要檢查。"
		return true
	var valid: bool = _validate()
	if not valid:
		push_error("地圖配置檢查未通過：\n"+status.text)
		dialog.popup_centered(Vector2i(620,260))
	return valid

func _select(node: Node) -> void:
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(node)
	get_editor_interface().inspect_object(node)

func select_shape(author: Node, shape_name: String) -> void:
	if author is WorldMonsterRegion and author.shape_source==WorldMonsterRegion.ShapeSource.TILE_BRUSH:
		var role: int = {"SpawnArea":WorldTileLayer.Role.SPAWN,"RoamingArea":WorldTileLayer.Role.ACTIVITY,"PursuitArea":WorldTileLayer.Role.CHASE}[shape_name]
		for node: Node in WorldAuthorTree.nodes(root_map,true):
			if node is WorldTileLayer and node.role==role and node.region_id==author.stable_id:
				node.show()
				var parent: Node = node.get_parent()
				while parent!=root_map:
					if parent is CanvasItem: parent.show()
					parent = parent.get_parent()
				_select(node)
				return
		status.text = "這個新區域沒有舊筆刷遮罩，請使用 Polygon 範圍。"
		dialog.popup_centered(Vector2i(620,220))
		return
	if not author.scene_file_path.is_empty():
		root_map.set_editable_instance(author,true)
		get_editor_interface().mark_scene_as_unsaved()
	var shape: Node = author.get_node_or_null(shape_name)
	if shape!=null: _select(shape)

func _add_author(kind: int) -> void:
	root_map = get_editor_interface().get_edited_scene_root() as WorldMap2D
	if root_map==null: return
	var filename: String = "monster_region" if kind==WorldAuthorNode.Kind.HABITAT else "portal" if kind==WorldAuthorNode.Kind.PORTAL else "scenery"
	var node: Node2D = (load("res://features/world/authoring/templates/"+filename+".tscn") as PackedScene).instantiate() as Node2D
	var canvas: Transform2D = get_editor_interface().get_editor_viewport_2d().get_canvas_transform()
	node.position = canvas.affine_inverse()*(get_editor_interface().get_editor_viewport_2d().size*0.5)-root_map.global_position
	var parent: Node = root_map.get_node_or_null("MonsterRegions" if kind==WorldAuthorNode.Kind.HABITAT else "Entrances" if kind==WorldAuthorNode.Kind.PORTAL else "Scenery")
	if parent==null: parent = root_map
	var undo: EditorUndoRedoManager = get_undo_redo()
	undo.create_action("新增 "+filename,UndoRedo.MERGE_DISABLE,root_map)
	undo.add_do_method(parent,"add_child",node)
	undo.add_do_property(node,"owner",root_map)
	undo.add_do_method(root_map,"set_editable_instance",node,true)
	undo.add_undo_method(parent,"remove_child",node)
	undo.add_do_reference(node)
	undo.commit_action()
	selected = node as WorldAuthorNode
	_select(node)

func _duplicate_selected() -> void:
	if not is_instance_valid(selected): return
	var clone: WorldAuthorNode = selected.duplicate() as WorldAuthorNode
	clone.position += Vector2(64,32)
	var parent: Node = selected.get_parent()
	var undo: EditorUndoRedoManager = get_undo_redo()
	undo.create_action("複製區域",UndoRedo.MERGE_DISABLE,root_map)
	undo.add_do_method(parent,"add_child",clone)
	undo.add_do_property(clone,"owner",root_map)
	undo.add_undo_method(parent,"remove_child",clone)
	undo.add_do_reference(clone)
	undo.commit_action()
	selected = clone
	_select(clone)

func _delete_selected() -> void:
	if not is_instance_valid(selected): return
	var parent: Node = selected.get_parent()
	var undo: EditorUndoRedoManager = get_undo_redo()
	undo.create_action("刪除區域",UndoRedo.MERGE_DISABLE,root_map)
	undo.add_do_method(parent,"remove_child",selected)
	undo.add_undo_method(parent,"add_child",selected)
	undo.add_undo_property(selected,"owner",root_map)
	undo.add_undo_reference(selected)
	undo.commit_action()
	selected = null
