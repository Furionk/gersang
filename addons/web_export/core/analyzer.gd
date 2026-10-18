@tool
extends RefCounted
const Files = preload("files.gd")

static func analyze(profile:Dictionary) -> Dictionary:
	var report:Dictionary = {"roots":[],"resources":{},"dynamic":[],"missing":[],"warnings":[],"source_bytes":0,"texture_rgba_bytes_estimate":0}
	var queue:Array = []
	var main:String = str(ProjectSettings.get_setting("application/run/main_scene",""))
	if not main.is_empty(): queue.append([resolve(main),"Project main scene"])
	for item:Dictionary in ProjectSettings.get_property_list():
		var key:String = str(item.name)
		if key.begins_with("autoload/"): queue.append([str(ProjectSettings.get_setting(key)).trim_prefix("*"),key])
		elif key in ["application/config/icon","application/boot_splash/image","gui/theme/custom","gui/theme/custom_font"]:
			var value:String = str(ProjectSettings.get_setting(key,""))
			if not value.is_empty(): queue.append([resolve(value),key])
	for path:String in profile.get("include",[]):
		if DirAccess.dir_exists_absolute(path):
			for file:String in Files.list_files(path):
				if file.get_extension() not in ["import","uid"]: queue.append([file,"Explicit directory: "+path])
		else: queue.append([resolve(path),"Explicit include"])
	# Typed global classes are not always reported by get_dependencies().
	# Keep their scripts conservatively; dropping an apparently unused class can break parsing.
	for global_class:Dictionary in ProjectSettings.get_global_class_list():
		queue.append([str(global_class.path),"Global script class: "+str(global_class.class)])
	var native:ConfigFile=ConfigFile.new()
	var selection:String="all_resources"
	var excluded:PackedStringArray=PackedStringArray(profile.get("exclude",[]))
	if native.load("res://export_presets.cfg")==OK:
		for section:String in native.get_sections():
			if native.get_value(section,"platform","")=="Web" and native.get_value(section,"name","")==profile.preset:
				selection=str(native.get_value(section,"export_filter","all_resources"))
				excluded.append_array(str(native.get_value(section,"exclude_filter","")).split(",",false))
				if selection in ["resources","selected_resources","scenes"]:
					for path:String in native.get_value(section,"export_files",PackedStringArray()): queue.append([path,"Native preset selection"])
	if selection=="all_resources" and not profile.get("trim",false):
		for path:String in Files.list_files("res://"):
			if path.begins_with("res://addons/web_export/"): continue
			var skip:bool=false
			for pattern:String in excluded:
				if path.trim_prefix("res://").match(pattern.trim_prefix("res://")): skip=true
			if not skip and ResourceLoader.exists(path): queue.append([path,"Native preset: all resources"])
	var literal:RegEx = RegEx.new(); literal.compile("[\"'](res://[^\"']+)[\"']")
	report.roots = queue.duplicate(true)
	while not queue.is_empty():
		var entry:Array = queue.pop_front()
		var path:String = str(entry[0])
		var explicitly_excluded:bool=false
		for pattern:String in excluded:
			if path.trim_prefix("res://").match(pattern.trim_prefix("res://")): explicitly_excluded=true
		if explicitly_excluded:
			report.warnings.append("Excluded by export rule; author must ensure it is optional: "+path+" ("+str(entry[1])+")")
			continue
		if report.resources.has(path):
			if str(entry[1]) not in report.resources[path].reasons: report.resources[path].reasons.append(str(entry[1]))
			continue
		if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
			report.missing.append({"path":path,"from":entry[1]}); continue
		var file:FileAccess = FileAccess.open(path,FileAccess.READ)
		var size:int = file.get_length() if file != null else 0
		report.resources[path] = {"reasons":[entry[1]],"source_bytes":size,"dependencies":[]}
		report.source_bytes += size
		if ResourceLoader.exists(path):
			for dependency:String in ResourceLoader.get_dependencies(path):
				var target:String = resolve(dependency)
				report.resources[path].dependencies.append(target)
				queue.append([target,path])
		# Godot's script dependency API can omit preloads and literal runtime paths.
		if path.get_extension() in ["gd","tscn","tres","json","gdshader"]:
			for found:RegExMatch in literal.search_all(FileAccess.get_file_as_string(path)):
				var target:String=found.get_string(1)
				if FileAccess.file_exists(target) or ResourceLoader.exists(target):
					if target not in report.resources[path].dependencies: report.resources[path].dependencies.append(target)
					queue.append([target,"Literal in "+path])
	# Computed paths still need an explicit declaration.
	var bridge_pattern:RegEx=RegEx.new(); bridge_pattern.compile("get_interface\\(\\s*[\"']([^\"']+)[\"']")
	for path:String in Files.list_files("res://"):
		if path.begins_with("res://addons/web_export/"): continue
		if path.get_extension() == "cs": report.warnings.append("C# Web support is not certified: "+path)
		if path.get_extension() not in ["gd","json","csv"]: continue
		var text:String = FileAccess.get_file_as_string(path)
		for bridge:RegExMatch in bridge_pattern.search_all(text):
			if bridge.get_string(1) not in ["window","document","console","navigator","JSON","Math","performance"]:
				report.warnings.append("Custom browser interface requires a project HTML template: "+bridge.get_string(1)+" in "+path)
		if text.contains("load(") or text.contains("FileAccess") or text.contains("DirAccess") or text.contains("change_scene_to_file"):
			report.dynamic.append({"path":path,"note":"Review runtime paths; declare directories/files before trimming."})
		for match_value:RegExMatch in literal.search_all(text):
			var target:String = match_value.get_string(1)
			if FileAccess.file_exists(target) and not report.resources.has(target):
				report.warnings.append("Runtime literal outside static graph: "+target+" in "+path)
	for path:String in report.resources:
		if path.get_extension().to_lower() in ["png","jpg","jpeg","webp"]:
			var image:Image = Image.load_from_file(ProjectSettings.globalize_path(path))
			if image != null: report.texture_rgba_bytes_estimate += image.get_width()*image.get_height()*4
	report.warnings.append("Texture bytes estimate is base-level RGBA only; excludes mipmaps, GPU compression, duplicates and engine memory.")
	return report

static func resolve(value:String) -> String:
	var chunks:PackedStringArray = value.split("::")
	if chunks.size()==3 and not chunks[2].is_empty(): return chunks[2]
	if value.begins_with("uid://"):
		var id:int = ResourceUID.text_to_id(value)
		if ResourceUID.has_id(id): return ResourceUID.get_id_path(id)
	return value
