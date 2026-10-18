extends RefCounted
## Historical backups stay byte-identical. Resolve moved references in a scratch
## copy only; all geometry/stats/IDs still come from the original baseline.
static func load_scene(path: String) -> PackedScene:
	var original: String = FileAccess.get_file_as_string(path)
	var source: String = original
	var moves: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://specs/unit_resource_moves.json"))
	for previous: String in moves: source=source.replace('"'+previous+'"','"'+str(moves[previous])+'"')
	if source==original: return ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
	var header_end: int = source.find("\n")
	var header: String = source.substr(0,header_end)
	var uid: int = header.find(' uid="')
	if uid>=0:
		var end: int = header.find('"',uid+6)
		source=header.substr(0,uid)+header.substr(end+1)+source.substr(header_end)
	var folder: String = "res://artifacts/editor-workflow-2026-10-11/legacy-fixtures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var scratch: String = folder+"/"+path.md5_text()+".tscn"
	var file: FileAccess = FileAccess.open(scratch,FileAccess.WRITE)
	if file==null: return null
	file.store_string(source); file.close()
	return ResourceLoader.load(scratch,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
