@tool
extends RefCounted

const FILE := "res://web_export.cfg"
const SCHEMA := 1

static func defaults() -> Dictionary:
	return {"schema":SCHEMA, "project_id":Crypto.new().generate_random_bytes(16).hex_encode(),
		"preset":"", "output":"res://build/web", "template":"", "logo":"",
		"chunk_mib":2, "parallel":3, "cache":true, "cache_mib":512,
		"compression":"none", "diagnostics":false, "first_budget_mib":256, "total_budget_mib":512,
		"trim":false, "include":[], "exclude":[], "dynamic_ack":false,
		"checks":[], "preview_port":18850}

static func read() -> Dictionary:
	var result:Dictionary = defaults()
	var cfg:ConfigFile = ConfigFile.new()
	if cfg.load(FILE) == OK:
		for key:String in result: result[key] = cfg.get_value("web_export",key,result[key])
	return result

static func save(profile:Dictionary) -> Error:
	var cfg:ConfigFile = ConfigFile.new()
	for key:String in profile: cfg.set_value("web_export",key,profile[key])
	return cfg.save(FILE)

static func presets() -> PackedStringArray:
	var names:PackedStringArray = []
	var cfg:ConfigFile = ConfigFile.new()
	if cfg.load("res://export_presets.cfg") == OK:
		for section:String in cfg.get_sections():
			if cfg.get_value(section,"platform","") == "Web": names.append(str(cfg.get_value(section,"name","")))
	return names

static func validate(p:Dictionary) -> PackedStringArray:
	var errors:PackedStringArray = []
	if int(p.get("schema",0)) != SCHEMA: errors.append("Unsupported profile schema.")
	var id:String = str(p.get("project_id",""))
	if id.length()!=32 or not id.is_valid_hex_number(): errors.append("Invalid project ID; reopen the exporter and save settings.")
	if int(p.get("chunk_mib",0)) < 1 or int(p.get("chunk_mib",0)) > 4: errors.append("Chunk size must be 1-4 MiB.")
	if int(p.get("parallel",0)) < 1 or int(p.get("parallel",0)) > 6: errors.append("Parallel requests must be 1-6.")
	if int(p.get("cache_mib",0)) < 16: errors.append("Cache budget must be at least 16 MiB.")
	if p.get("compression","") not in ["none","gzip"]: errors.append("Compression must be none or gzip.")
	var output:String = ProjectSettings.globalize_path(str(p.get("output",""))).simplify_path().replace("\\","/").trim_suffix("/")
	var project:String = ProjectSettings.globalize_path("res://").simplify_path().replace("\\","/").trim_suffix("/")
	if not output.is_absolute_path() or output.is_empty() or project.to_lower().begins_with(output.to_lower()+"/") or output.to_lower()==project.to_lower(): errors.append("Output must be a dedicated directory, not the project root or its parent.")
	if output.begins_with(project+"/") and not output.begins_with(project+"/build/") and not output.begins_with(project+"/artifacts/"): errors.append("Inside this project, use build/ or artifacts/ for output.")
	for field:String in ["template","logo"]:
		if not str(p.get(field,"")).is_empty() and not FileAccess.file_exists(str(p[field])): errors.append("Missing "+field+": "+str(p[field]))
	if not str(p.get("logo","")).is_empty() and str(p.logo).get_extension().to_lower() not in ["png","webp","jpg","jpeg","svg"]: errors.append("Logo must be PNG, WebP, JPEG or SVG.")
	if str(ProjectSettings.get_setting("rendering/renderer/rendering_method","gl_compatibility")) != "gl_compatibility": errors.append("Web export requires Compatibility renderer; select it explicitly in the project.")
	return errors
