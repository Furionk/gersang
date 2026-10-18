extends SceneTree
## The actual shipped font must cover every authored CJK character before export.
const FONT: String = "res://art/fonts/NotoSansCJKtc-Regular.otf"
var required: Dictionary = {}
var scanned: int = 0
func collect(folder: String) -> void:
	for name: String in DirAccess.get_files_at(folder):
		if name.get_extension() not in ["gd","tres","tscn","json","html","js"]: continue
		var path: String=folder+"/"+name
		var content: String=FileAccess.get_file_as_string(path)
		scanned+=1
		for index: int in content.length():
			var cp: int=content.unicode_at(index)
			if (cp>=0x3000 and cp<=0x9fff) or (cp>=0xf900 and cp<=0xfaff) or (cp>=0xff00 and cp<=0xffef) or (cp>=0x20000 and cp<=0x323af):
				if not required.has(cp): required[cp]=path
	for name: String in DirAccess.get_directories_at(folder): collect(folder+"/"+name)
func _initialize() -> void:
	collect("res://common"); collect("res://features")
	var face: FontFile=FontFile.new()
	var result: Error=face.load_dynamic_font(FONT)
	if result!=OK: push_error("Cannot read bundled CJK font"); quit(1); return
	var missing: Array[Dictionary]=[]
	for cp: int in required:
		if not face.has_char(cp): missing.append({"char":String.chr(cp),"codepoint":"U+%04X"%cp,"source":required[cp]})
	var report: Dictionary={"required":required.size(),"scanned":scanned,"supported":face.get_supported_chars().length(),"missing":missing}
	if "--compare-original" in OS.get_cmdline_user_args():
		var original: FontFile=FontFile.new()
		if original.load_dynamic_font("res://artifacts/demo-web-2026-10-11/NotoSansTC-source.ttf")==OK:
			var original_missing: Array[String]=[]
			for cp: int in required:
				if not original.has_char(cp): original_missing.append(String.chr(cp))
			report.original_supported=original.get_supported_chars().length(); report.original_missing=original_missing
	DirAccess.make_dir_recursive_absolute("res://artifacts/tests/font-coverage")
	var file: FileAccess=FileAccess.open("res://artifacts/tests/font-coverage/coverage.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("FONT_COVERAGE_RESULT required=",required.size()," supported=",report.supported," missing=",missing.size()," original_missing=",report.get("original_missing",[]))
	quit(0 if missing.is_empty() else 1)
