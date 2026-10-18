@tool
extends EditorPlugin
const ExportPanel = preload("panel.gd")
const Hook = preload("export_hook.gd")
var panel:Window
var hook:EditorExportPlugin
func _enter_tree() -> void:
	hook=Hook.new(); add_export_plugin(hook)
	if "--web-export-child" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless": return
	panel=ExportPanel.new(); get_editor_interface().get_base_control().add_child(panel)
	add_tool_menu_item("Web Export Studio",_open)
	if "--web-export-studio" in OS.get_cmdline_user_args(): call_deferred("_open")
func _open() -> void:
	panel.popup_centered(Vector2i(900,720))
func _exit_tree() -> void:
	remove_tool_menu_item("Web Export Studio")
	if is_instance_valid(panel): panel.shutdown(); panel.queue_free()
	if hook!=null: remove_export_plugin(hook)
