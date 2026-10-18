@tool
extends RefCounted
const Files = preload("files.gd")
const ObjectAudit = preload("object_audit.gd")
const MARKER := "web-export-state.json"

static func publish(stage:String, output:String, profile:Dictionary, report:Dictionary, progress:Callable=Callable(), cancelled:Callable=Callable()) -> Dictionary:
	if DirAccess.make_dir_recursive_absolute(output)!=OK: return {"error":"Cannot create output directory."}
	if not Files.no_links(output) or not Files.safe_descendant(output,".web-export-lock"): return {"error":"Linked output/lock path refused."}
	var lock_dir:String=output.path_join(".web-export-lock")
	if DirAccess.dir_exists_absolute(lock_dir):
		var owner:Dictionary=Files.json_read(lock_dir.path_join("owner.json"))
		if not owner.has("pid") or OS.is_process_running(int(owner.pid)): return {"error":"Another publisher owns this output. Retry when it finishes."}
		DirAccess.remove_absolute(lock_dir.path_join("owner.json"))
		DirAccess.remove_absolute(lock_dir)
	if DirAccess.make_dir_absolute(lock_dir)!=OK: return {"error":"Cannot acquire publish lock."}
	if not Files.json_write(lock_dir.path_join("owner.json"),{"pid":OS.get_process_id()}):
		DirAccess.remove_absolute(lock_dir); return {"error":"Cannot record publisher ownership."}
	var result:Dictionary=_publish(stage,output,profile,report,progress,cancelled)
	DirAccess.remove_absolute(lock_dir.path_join("owner.json")); DirAccess.remove_absolute(lock_dir)
	return result

static func _publish(stage:String, output:String, profile:Dictionary, report:Dictionary, progress:Callable=Callable(), cancelled:Callable=Callable()) -> Dictionary:
	var old:Dictionary = Files.json_read(output.path_join(MARKER))
	if DirAccess.dir_exists_absolute(output) and not old.has("project"):
		var entries:PackedStringArray = DirAccess.get_files_at(output)
		if ".gdignore" in entries: entries.remove_at(entries.find(".gdignore"))
		var directories:PackedStringArray=DirAccess.get_directories_at(output)
		if ".web-export-lock" in directories: directories.remove_at(directories.find(".web-export-lock"))
		if not entries.is_empty() or not directories.is_empty(): return {"error":"Output directory is not owned by Web Export Studio. Choose an empty directory."}
	if old.has("project") and old.project!=profile.project_id: return {"error":"Output belongs to another project."}
	if DirAccess.make_dir_recursive_absolute(output)!=OK: return {"error":"Cannot create output directory."}
	var previous_files:Dictionary = {}
	var history:Array = old.get("history",[])
	if not history.is_empty(): previous_files=history[0].files
	var delta:Array = []
	var delta_bytes:int = 0
	var chunk_total:int=0
	var chunk_reused:int=0
	var completed:int=0
	for relative:String in report.files:
		if cancelled.is_valid() and cancelled.call(): return {"error":"Cancelled publication; previous entry preserved."}
		completed+=1
		if progress.is_valid(): progress.call("Publishing verified files",completed-1,report.files.size(),"files")
		if not Files.safe_descendant(output,relative): return {"error":"Invalid output relative path."}
		if previous_files.get(relative,"")!=report.files[relative]:
			delta.append(relative); delta_bytes+=FileAccess.open(stage.path_join(relative),FileAccess.READ).get_length()
		if relative.begins_with("objects/"):
			var wire_size:int=FileAccess.open(stage.path_join(relative),FileAccess.READ).get_length()
			chunk_total+=wire_size
			if previous_files.get(relative,"")==report.files[relative]: chunk_reused+=wire_size
		if relative=="index.html": continue
		var target:String = output.path_join(relative)
		if FileAccess.file_exists(target) and FileAccess.get_sha256(target)==report.files[relative]: continue
		if not Files.copy_verified(stage.path_join(relative),target): return {"error":"Copy failed: "+relative+"; previous entry HTML preserved."}
	if progress.is_valid(): progress.call("Publishing verified files",report.files.size(),report.files.size(),"files")
	report.delta_files=delta; report.delta_transfer_bytes=delta_bytes
	report.chunk_reused_wire_bytes=chunk_reused; report.chunk_total_wire_bytes=chunk_total
	report.chunk_reuse_percent=100.0*chunk_reused/maxi(1,chunk_total)
	report.upload_files=report.files.keys()
	if not Files.json_write(output.path_join("build-report.json"),report): return {"error":"Report write failed; previous entry preserved."}
	var entry:Dictionary={"release":report.release,"files":report.files}
	if history.is_empty() or history[0].release!=report.release: history.push_front(entry)
	var state:Dictionary={"schema":1,"project":profile.project_id,"history":history}
	# Entry and ownership are prepared before rename. Keep prior HTML for recovery.
	if not Files.copy_verified(stage.path_join("index.html"),output.path_join("index.html.next")): return {"error":"Cannot prepare entry."}
	if not Files.json_write(output.path_join(MARKER+".next"),state): return {"error":"Cannot prepare release registry."}
	var prior:String=output.path_join("index.html.previous")
	if FileAccess.file_exists(output.path_join("index.html")):
		if not Files.copy_verified(output.path_join("index.html"),prior): return {"error":"Cannot preserve previous entry."}
	# Windows rename replaces a file atomically through Godot's native directory API.
	if DirAccess.rename_absolute(output.path_join(MARKER+".next"),output.path_join(MARKER))!=OK: return {"error":"Cannot commit release registry."}
	if DirAccess.rename_absolute(output.path_join("index.html.next"),output.path_join("index.html"))!=OK: return {"error":"Cannot commit entry. Previous index.html remains valid; registry includes both releases."}
	Files.write(output.path_join(".gdignore"),PackedByteArray())
	return report

static func candidates(output:String, project_id:String) -> Dictionary:
	var state:Dictionary=Files.json_read(output.path_join(MARKER))
	if state.get("project","")!=project_id: return {"error":"Output ownership mismatch."}
	var keep:Dictionary={}; var removed:Dictionary={}
	var live_entry:String=FileAccess.get_sha256(output.path_join("index.html")) if FileAccess.file_exists(output.path_join("index.html")) else ""
	var history:Array=state.get("history",[])
	for index:int in history.size():
		for path:String in history[index].files:
			if index<2 or history[index].files.get("index.html", "") == live_entry: keep[path]=true
			elif not keep.has(path): removed[path]=history[index].files[path]
	var result:Dictionary={"files":[],"bytes":0}
	for path:String in removed:
		if keep.has(path) or not Files.safe_descendant(output,path) or path in ["index.html",".htaccess"]: continue
		var absolute:String=output.path_join(path)
		if FileAccess.file_exists(absolute) and FileAccess.get_sha256(absolute)==removed[path]:
			result.files.append(path); result.bytes+=FileAccess.open(absolute,FileAccess.READ).get_length()
	return result

static func clean(output:String, project_id:String) -> Dictionary:
	if not Files.no_links(output) or not Files.safe_descendant(output,".web-export-lock"): return {"error":"Linked output/lock path refused."}
	var lock_dir:String=output.path_join(".web-export-lock")
	if DirAccess.make_dir_absolute(lock_dir)!=OK: return {"error":"Output is busy; retry after publication finishes."}
	if not Files.json_write(lock_dir.path_join("owner.json"),{"pid":OS.get_process_id()}):
		DirAccess.remove_absolute(lock_dir); return {"error":"Cannot record cleanup ownership."}
	var result:Dictionary=_clean(output,project_id)
	DirAccess.remove_absolute(lock_dir.path_join("owner.json")); DirAccess.remove_absolute(lock_dir)
	return result

static func _clean(output:String, project_id:String) -> Dictionary:
	var preview:Dictionary=candidates(output,project_id)
	if preview.has("error"): return preview
	for path:String in preview.files:
		if DirAccess.remove_absolute(output.path_join(path))!=OK: return {"error":"Could not remove "+path}
	return preview

# Serialize verification/copy against both publication and cleanup.
static func inspect_output(output:String,project_id:String,destination:String="",progress:Callable=Callable(),cancelled:Callable=Callable()) -> Dictionary:
	if not DirAccess.dir_exists_absolute(output): return {"error":"Export a release first."}
	if not Files.no_links(output) or not Files.safe_descendant(output,".web-export-lock"): return {"error":"Linked output/lock path refused."}
	var lock_dir:String=output.path_join(".web-export-lock")
	if DirAccess.dir_exists_absolute(lock_dir):
		var owner:Dictionary=Files.json_read(lock_dir.path_join("owner.json"))
		if not owner.has("pid") or OS.is_process_running(int(owner.pid)): return {"error":"Output is busy; retry after publication finishes."}
		DirAccess.remove_absolute(lock_dir.path_join("owner.json")); DirAccess.remove_absolute(lock_dir)
	if DirAccess.make_dir_absolute(lock_dir)!=OK: return {"error":"Cannot acquire output verification lock."}
	if not Files.json_write(lock_dir.path_join("owner.json"),{"pid":OS.get_process_id()}):
		DirAccess.remove_absolute(lock_dir); return {"error":"Cannot record verification ownership."}
	var audit:Dictionary=ObjectAudit.run(output,project_id,progress,cancelled)
	var result:Dictionary={"object_audit":audit}
	if audit.has("error"): result=audit
	elif not destination.is_empty(): result=ObjectAudit.upload_copy(output,destination,audit,project_id,progress,cancelled)
	DirAccess.remove_absolute(lock_dir.path_join("owner.json")); DirAccess.remove_absolute(lock_dir)
	return result
