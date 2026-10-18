@tool
extends EditorExportPlugin
func _get_name() -> String: return "WebExportStudio"
func _export_file(path:String, _type:String, features:PackedStringArray) -> void:
	if "web" in features and path.begins_with("res://addons/web_export/"): skip()
