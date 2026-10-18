@tool
extends RefCounted
const Files = preload("files.gd")

# Called while the publisher lock is held. Objects are deliberately flat: an
# unexpected directory (including a hidden one) is reported, never traversed.
static func run(output:String, project_id:String, progress:Callable=Callable(), cancelled:Callable=Callable()) -> Dictionary:
	if not Files.no_links(output) or not Files.safe_descendant(output,"objects") or not Files.safe_descendant(output,"web-export-state.json") or not Files.safe_descendant(output,"index.html"):
		return {"error":"Unsafe linked output path."}
	var state:Dictionary=Files.json_read(output.path_join("web-export-state.json"))
	if state.get("project","")!=project_id: return {"error":"Output ownership mismatch."}
	var history:Variant=state.get("history",[])
	if not history is Array or history.is_empty(): return {"error":"Release registry has no history."}
	var live_hash:String=FileAccess.get_sha256(output.path_join("index.html"))
	var live:int=-1
	var known:Dictionary={}
	for i:int in history.size():
		if not history[i] is Dictionary or not history[i].get("files") is Dictionary: return {"error":"Invalid release registry."}
		if live<0 and history[i].files.get("index.html","")==live_hash: live=i
		for path:String in history[i].files:
			if path.begins_with("objects/") and not known.has(path): known[path]=history[i].files[path]
	if live<0: return {"error":"index.html does not match a registered release. No current version can be confirmed."}
	var result:Dictionary={"release":history[live].get("release",""),"current":[],"retained":[],"obsolete":[],"unknown":[],"unsafe":[],"missing":[],"corrupt":[],"manifest_errors":[],"current_valid":true,"retained_valid":true,"latest_only":false,"checked_bytes":0,"current_files":history[live].files}
	var required:Dictionary={}
	var specs:Dictionary={}
	var pattern:RegEx=RegEx.new(); pattern.compile("^objects/[a-f0-9]{64}\\.bin(\\.gz)?$")
	# Inspect live first so a shared chunk is always labelled current.
	var selected:Array[int]=[live]
	for i:int in mini(2,history.size()):
		if i!=live: selected.append(i)
	for i:int in selected:
		var category:String="current" if i==live else "retained"
		var entry:Dictionary=history[i]
		for path:String in entry.files:
			if path.begins_with("objects/") and not required.has(path): required[path]={"category":category,"hash":entry.files[path]}
		var manifest_path:String="releases/"+str(entry.get("release",""))+"/manifest.json"
		if not Files.safe_descendant(output,manifest_path) or not entry.files.has(manifest_path) or not FileAccess.file_exists(output.path_join(manifest_path)) or FileAccess.get_sha256(output.path_join(manifest_path))!=entry.files[manifest_path]:
			manifest_error(result,category,manifest_path+": missing or hash mismatch"); continue
		var manifest:Dictionary=Files.json_read(output.path_join(manifest_path))
		if manifest.get("project","")!=project_id or manifest.get("release","")!=entry.get("release") or not manifest.get("files") is Array:
			manifest_error(result,category,manifest_path+": invalid manifest"); continue
		var referenced:Dictionary={}
		for file:Variant in manifest.files:
			if not file is Dictionary or not file.get("parts") is Array:
				manifest_error(result,category,manifest_path+": invalid file record"); continue
			var size:int=0
			for part:Variant in file.parts:
				if not part is Dictionary: manifest_error(result,category,"Invalid part record"); continue
				var path:String=str(part.get("url",""))
				var encoding:String=str(part.get("encoding",""))
				var raw_size:int=int(part.get("bytes",0)); var wire_size:int=int(part.get("wire_bytes",0))
				var expected:String="objects/"+str(part.get("sha256",""))+(".bin.gz" if encoding=="gzip" else ".bin")
				if pattern.search(path)==null or path!=expected or encoding not in ["gzip","identity"] or raw_size<1 or raw_size>4194304 or wire_size<1 or wire_size>4194304 or not entry.files.has(path):
					manifest_error(result,category,"Invalid object reference: "+path); continue
				referenced[path]=true; size+=raw_size
				if specs.has(path) and specs[path]!=part: manifest_error(result,category,"Conflicting object metadata: "+path)
				else: specs[path]=part
			if size!=int(file.get("bytes",-1)): manifest_error(result,category,"Pack length mismatch: "+str(file.get("name","")))
		for path:String in entry.files:
			if path.begins_with("objects/") and not referenced.has(path): manifest_error(result,category,"Unreferenced registered object: "+path)
	var found:Dictionary={}
	var dir:DirAccess=DirAccess.open(output.path_join("objects"))
	if dir!=null:
		dir.include_hidden=true; dir.list_dir_begin()
		var name:String=dir.get_next()
		while not name.is_empty():
			var path:String="objects/"+name
			if dir.is_link(name): result.unsafe.append(path)
			elif dir.current_is_dir(): result.unknown.append(path+"/")
			else: found[path]=true
			name=dir.get_next()
		dir.list_dir_end()
	var paths:Dictionary=found.duplicate()
	for path:String in required: paths[path]=true
	var done:int=0
	for path:String in paths:
		if cancelled.is_valid() and cancelled.call(): return {"error":"Cancelled object verification."}
		var absolute:String=output.path_join(path)
		var category:String=str(required.get(path,{}).get("category",""))
		if not Files.safe_descendant(output,path):
			if path not in result.unsafe: result.unsafe.append(path)
			invalidate(result,category)
		elif not found.has(path): result.missing.append(path); invalidate(result,category)
		else:
			var handle:FileAccess=FileAccess.open(absolute,FileAccess.READ)
			var length:int=handle.get_length() if handle!=null else -1
			result.checked_bytes+=maxi(length,0)
			var hash:String=FileAccess.get_sha256(absolute)
			if not category.is_empty():
				var valid:bool=length>=0 and hash==required[path].hash and specs.has(path)
				if valid:
					var part:Dictionary=specs[path]
					valid=length==int(part.wire_bytes)
					if valid:
						var bytes:PackedByteArray=handle.get_buffer(length)
						if part.encoding=="gzip": bytes=bytes.decompress(int(part.bytes),FileAccess.COMPRESSION_GZIP)
						valid=bytes.size()==int(part.bytes) and Files.sha(bytes)==part.sha256
				if valid: result[category].append(path)
				else: result.corrupt.append(path); invalidate(result,category)
			elif known.get(path,"")==hash and pattern.search(path)!=null: result.obsolete.append(path)
			else: result.unknown.append(path)
		done+=1
		if progress.is_valid(): progress.call("Verifying objects",done,paths.size(),"files")
	# Missing historical references do not make present, current-only objects junk.
	result.latest_only=result.current_valid and found.size()==result.current.size() and result.unknown.is_empty() and result.unsafe.is_empty()
	result.required_valid=result.current_valid and result.retained_valid
	return result

static func invalidate(result:Dictionary,category:String) -> void:
	if category=="current": result.current_valid=false
	elif category=="retained": result.retained_valid=false

static func manifest_error(result:Dictionary,category:String,message:String) -> void:
	result.manifest_errors.append(category+": "+message)
	invalidate(result,category)

# A new sibling/staging directory, never a destructive in-place "sync".
static func upload_copy(output:String,destination:String,audit:Dictionary,project_id:String,progress:Callable=Callable(),cancelled:Callable=Callable()) -> Dictionary:
	var source:String=ProjectSettings.globalize_path(output).simplify_path().replace("\\","/").trim_suffix("/")
	var target:String=ProjectSettings.globalize_path(destination).simplify_path().replace("\\","/").trim_suffix("/")
	if target.is_empty() or not target.is_absolute_path() or target.to_lower()==source.to_lower() or target.to_lower().begins_with(source.to_lower()+"/") or source.to_lower().begins_with(target.to_lower()+"/"):
		return {"error":"Choose a new upload folder outside the managed output."}
	if not Files.no_links(target): return {"error":"Upload destination contains a linked directory."}
	if DirAccess.dir_exists_absolute(target) or FileAccess.file_exists(target): return {"error":"Upload destination already exists; choose a new folder."}
	if not audit.get("current_valid",false): return {"error":"Current objects failed verification. Re-export before making an upload copy."}
	if DirAccess.make_dir_absolute(target)!=OK: return {"error":"Cannot create new upload folder; its parent must exist."}
	if not Files.write(target.path_join(".gdignore"),PackedByteArray()): return {"error":"Cannot mark upload folder as generated content."}
	var files:Dictionary=audit.current_files.duplicate()
	# Preserve common, manually supplied licence sidecars without copying notes,
	# obsolete releases or arbitrary root files. Record them in the new registry.
	for name:String in DirAccess.get_files_at(source):
		var upper:String=name.to_upper()
		if upper in ["LICENSE","LICENSE.TXT","LICENSE.MD","COPYING","COPYING.TXT"] or upper.ends_with("-LICENSE.TXT"):
			if Files.safe_descendant(source,name): files[name]=FileAccess.get_sha256(source.path_join(name))
	var count:int=0
	for path:String in files:
		if cancelled.is_valid() and cancelled.call(): return {"error":"Cancelled. Partial upload folder has no index.html: "+target}
		if not Files.safe_descendant(source,path) or not Files.safe_descendant(target,path) or not FileAccess.file_exists(source.path_join(path)) or FileAccess.get_sha256(source.path_join(path))!=files[path]: return {"error":"Release file failed verification: "+path}
		if path!="index.html" and not Files.copy_verified(source.path_join(path),target.path_join(path)): return {"error":"Upload copy failed: "+path}
		count+=1
		if progress.is_valid(): progress.call("Copying current release",count,files.size(),"files")
	var state:Dictionary={"schema":1,"project":project_id,"history":[{"release":audit.release,"files":files}]}
	if not Files.json_write(target.path_join("web-export-state.json"),state): return {"error":"Cannot write upload registry."}
	var verified:Dictionary=run_with_pending_entry(source,target,project_id,progress,cancelled)
	if verified.has("error") or not verified.get("latest_only",false): return {"error":"Upload folder failed final audit.","object_audit":verified}
	var upload_files:Array=files.keys(); upload_files.erase("index.html"); upload_files.sort(); upload_files.append("index.html")
	if not Files.json_write(target.path_join("upload-files.json"),upload_files):
		DirAccess.remove_absolute(target.path_join("index.html")); return {"error":"Cannot save upload list."}
	Files.write(target.path_join(".gdignore"),PackedByteArray())
	return {"bundle":target,"upload_files":upload_files,"object_audit":verified,"note":"Upload objects and releases first; index.html last. Registry is local tooling metadata. Existing server files are not deleted by FTP upload."}

static func run_with_pending_entry(source:String,target:String,project_id:String,progress:Callable,cancelled:Callable) -> Dictionary:
	if cancelled.is_valid() and cancelled.call(): return {"error":"Cancelled upload copy."}
	if not Files.copy_verified(source.path_join("index.html"),target.path_join("index.html")): return {"error":"Cannot copy entry."}
	var verified:Dictionary=run(target,project_id,progress,cancelled)
	if verified.has("error") or not verified.get("latest_only",false): DirAccess.remove_absolute(target.path_join("index.html"))
	return verified
