extends SceneTree
## Explicit author step. Does not touch scenes/art/saves. --write-preset updates only the Web allowlist.
var files:PackedStringArray=PackedStringArray()
func collect(folder:String) -> void:
	for name:String in DirAccess.get_files_at(folder):
		if name.get_extension() in ["gd","tres","tscn","gdshader"]: files.append(folder+"/"+name)
	for name:String in DirAccess.get_directories_at(folder): collect(folder+"/"+name)
func _initialize() -> void:
	collect("res://common"); collect("res://features")
	files.append("res://main.tscn"); files.append(str(ProjectSettings.get_setting("application/config/icon","res://gersang_four.png")))
	var selected:Dictionary={}; var raw:PackedStringArray=PackedStringArray()
	var pattern:RegEx=RegEx.new(); pattern.compile("[\"'](res://[^\"']+)[\"']")
	for path:String in files:
		selected[path]=true
		if path.get_extension() not in ["gd","tres","tscn"]: continue
		for match_value:RegExMatch in pattern.search_all(FileAccess.get_file_as_string(path)):
			var asset:String=match_value.get_string(1)
			if asset.begins_with("res://art/music/"): continue
			if not (asset.begins_with("res://art/") or asset.begins_with("res://features/") or asset.begins_with("res://common/") or asset.trim_prefix("res://").get_base_dir().is_empty()): continue
			if asset.get_extension() not in ["png","svg","webp","ttf","otf","wav","ogg","mp3","json","glb","gltf"]: continue
			if not FileAccess.file_exists(asset) and not ResourceLoader.exists(asset): continue
			selected[asset]=true
			if asset.get_extension()=="json" and asset.trim_prefix("res://") not in raw: raw.append(asset.trim_prefix("res://"))
	var output:PackedStringArray=PackedStringArray(selected.keys()); output.sort()
	var config:ConfigFile=ConfigFile.new()
	if config.load("res://export_presets.cfg")!=OK: push_error("找不到匯出設定。"); quit(1); return
	var target:String=""
	for section:String in config.get_sections():
		if section.begins_with("preset.") and str(config.get_value(section,"name",""))=="Web Demo No BGM": target=section; break
	if target.is_empty(): push_error("找不到Web Demo No BGM預設。"); quit(1); return
	if "--write-preset" in OS.get_cmdline_user_args():
		for argument:String in OS.get_cmdline_user_args():
			if argument.begins_with("--html-shell="):
				config.set_value(target+".options","html/custom_html_shell",argument.trim_prefix("--html-shell="))
		config.set_value(target,"export_filter","selected_resources")
		config.set_value(target,"export_files",output)
		var include:PackedStringArray=PackedStringArray(["art/fonts/OFL.txt","art/fonts/NotoSansCJK-LICENSE.txt"]); include.append_array(raw)
		config.set_value(target,"include_filter",",".join(include))
		if config.save("res://export_presets.cfg")!=OK: push_error("匯出清單保存失敗。"); quit(1); return
	print("WEB_ALLOWLIST files=",output.size()," no_music=true write=","--write-preset" in OS.get_cmdline_user_args())
	quit()
