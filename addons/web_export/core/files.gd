@tool
extends RefCounted

static func write(path:String, bytes:PackedByteArray) -> bool:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return false
	var file:FileAccess = FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(bytes)
	file.flush()
	return file.get_error() == OK

static func json_write(path:String, value:Variant) -> bool:
	return write(path,JSON.stringify(value,"  ",true).to_utf8_buffer())

static func json_read(path:String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var value:Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

static func sha(bytes:PackedByteArray) -> String:
	var ctx:HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256); ctx.update(bytes)
	return ctx.finish().hex_encode()

static func list_files(folder:String, ignored:bool = true) -> PackedStringArray:
	var result:PackedStringArray = []
	var dir:DirAccess = DirAccess.open(folder)
	if dir == null: return result
	var names:PackedStringArray = dir.get_files(); names.sort()
	for name:String in names:
		if dir.is_link(name) or (ignored and name.begins_with(".")): continue
		result.append(folder.path_join(name))
	var dirs:PackedStringArray = dir.get_directories(); dirs.sort()
	for name:String in dirs:
		if name.begins_with(".") or dir.is_link(name): continue
		var child:String = folder.path_join(name)
		if ignored and (name in ["build","artifacts","node_modules"] or FileAccess.file_exists(child.path_join(".gdignore"))): continue
		result.append_array(list_files(child,ignored))
	return result

static func relative_safe(path:String) -> bool:
	return not path.is_absolute_path() and not path.contains("..") and not path.contains(":") and not path.begins_with("/") and not path.contains("\\")

static func copy_verified(source:String, target:String) -> bool:
	if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK: return false
	if DirAccess.copy_absolute(source,target) != OK: return false
	return FileAccess.get_sha256(source) == FileAccess.get_sha256(target)

static func safe_descendant(root:String, relative:String) -> bool:
	if not relative_safe(relative): return false
	var current:String=root
	for component:String in relative.split("/"):
		var dir:DirAccess=DirAccess.open(current)
		if dir!=null and dir.is_link(component): return false
		current=current.path_join(component)
	return true

# Check every existing ancestor too; a junction at the selected output root
# must not bypass relative-path confinement.
static func no_links(path:String) -> bool:
	var current:String=ProjectSettings.globalize_path(path).simplify_path().replace("\\","/").trim_suffix("/")
	while not current.is_empty():
		var parent:String=current.get_base_dir()
		if parent==current or parent.is_empty(): break
		var dir:DirAccess=DirAccess.open(parent)
		if dir!=null and dir.is_link(current.get_file()): return false
		current=parent
	return true
