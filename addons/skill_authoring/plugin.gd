@tool
extends EditorPlugin
var inspector: EditorInspectorPlugin
var content_inspector: EditorInspectorPlugin
func _enter_tree() -> void:
	inspector = preload("res://addons/skill_authoring/formula_inspector.gd").new()
	add_inspector_plugin(inspector)
	content_inspector=preload("res://addons/skill_authoring/content_inspector.gd").new()
	add_inspector_plugin(content_inspector)
	if "--content-authoring-editor-smoke" in OS.get_cmdline_user_args():
		var worker:Node=Node.new(); worker.set_script(load("res://tests/content_authoring_editor_worker.gd")); add_child(worker)
	if "--editor-workflow-smoke" in OS.get_cmdline_user_args():
		var worker: Node = Node.new()
		worker.set_script(load("res://tests/editor_workflow_worker.gd"))
		add_child(worker)
	if "--new-units-editor-smoke" in OS.get_cmdline_user_args():
		var worker: Node=Node.new()
		worker.set_script(load("res://tests/new_units_editor_suite.gd"))
		add_child(worker)
func _exit_tree() -> void:
	if content_inspector!=null:
		remove_inspector_plugin(content_inspector)
		content_inspector=null
	if inspector != null:
		remove_inspector_plugin(inspector)
		inspector = null
