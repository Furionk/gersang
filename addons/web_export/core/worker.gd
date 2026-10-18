extends SceneTree
const Files = preload("files.gd")
const Profile = preload("profile.gd")
const Analyzer = preload("analyzer.gd")
const Packager = preload("package.gd")
const Publisher = preload("publish.gd")
var request:Dictionary
var job:String
var child:int = -1

func _initialize() -> void:
	call_deferred("run")

func status(message:String, current:int=0, total:int=0, unit:String="") -> void:
	if total==0 or current==total: print("WEB_EXPORT ",message)
	# Atomic status replacement prevents the editor reading a half-written JSON.
	var path:String=job.path_join("status.json")
	if Files.json_write(path+".next",{"message":message,"current":current,"total":total,"unit":unit,"indeterminate":total<=0}): DirAccess.rename_absolute(path+".next",path)

func fail(message:String) -> void:
	if child>0 and OS.is_process_running(child): OS.kill(child)
	Files.json_write(job.path_join("result.json"),{"error":message})
	print("WEB_EXPORT_FAILED ",message)
	quit(1)

func cancelled() -> bool:
	return FileAccess.file_exists(job.path_join("cancel"))

func execute_engine(args:PackedStringArray, label:String, headless:bool=true) -> bool:
	var log_path:String=job.path_join(label+".log")
	var commands:PackedStringArray=["--log-file",log_path]
	if headless: commands.insert(0,"--headless")
	commands.append_array(args)
	child=OS.create_process(OS.get_executable_path(),commands)
	if child<=0: return false
	Files.json_write(job.path_join("child.json"),{"pid":child})
	var started:int=Time.get_ticks_msec()
	while OS.is_process_running(child):
		if cancelled() or Time.get_ticks_msec()-started>1200000:
			OS.kill(child); child=-1; return false
		await create_timer(0.2).timeout
	var code:int=OS.get_process_exit_code(child)
	child=-1
	var log:String=FileAccess.get_file_as_string(log_path)
	return code==0 and not log.contains("SCRIPT ERROR:") and not log.contains("\nERROR:")

func run() -> void:
	var args:PackedStringArray=OS.get_cmdline_user_args()
	if args.is_empty(): quit(2); return
	request=Files.json_read(args[0]); job=str(request.get("job",""))
	if job.is_empty(): quit(2); return
	var profile:Dictionary=request.get("profile",{})
	var errors:PackedStringArray=Profile.validate(profile)
	if not errors.is_empty(): fail("\n".join(errors)); return
	var output:String=ProjectSettings.globalize_path(str(profile.output)).simplify_path().replace("\\","/").trim_suffix("/")
	if request.get("action","") in ["audit","upload"]:
		status("Checking output ownership and manifests")
		var destination:String=str(request.get("destination","")) if request.action=="upload" else ""
		if request.action=="upload" and destination.is_empty(): fail("Choose an upload destination."); return
		var result:Dictionary=Publisher.inspect_output(output,str(profile.project_id),destination,status,cancelled)
		if result.has("error"): fail(str(result.error)); return
		Files.json_write(job.path_join("result.json"),result)
		status("Verification complete",1,1,"task"); quit(); return
	status("Waiting for Godot resource import")
	await create_timer(0.3).timeout
	var filesystem:EditorFileSystem=EditorInterface.get_resource_filesystem()
	if not filesystem.is_scanning(): filesystem.scan()
	while filesystem.is_scanning():
		if cancelled(): fail("Cancelled before export."); return
		await create_timer(0.2).timeout
	status("Analyzing dependencies")
	var analysis:Dictionary=Analyzer.analyze(profile)
	if not Files.json_write(job.path_join("analysis.json"),analysis): fail("Cannot save analysis."); return
	if request.get("action","build")=="analyze":
		Files.json_write(job.path_join("result.json"),{"analysis":analysis,"report":job.path_join("analysis.json")}); status("Analysis complete",1,1,"task"); quit(); return
	if not analysis.missing.is_empty(): fail("Missing dependencies; see analysis.json"); return
	if profile.trim and not analysis.dynamic.is_empty() and (not profile.dynamic_ack or profile.include.is_empty()): fail("Trimming requires explicit runtime includes and acknowledgement; see dynamic paths in analysis.json."); return
	var native_cfg:ConfigFile=ConfigFile.new()
	var source_section:String=""
	if native_cfg.load("res://export_presets.cfg")==OK:
		for section:String in native_cfg.get_sections():
			if native_cfg.get_value(section,"name","")==profile.preset and native_cfg.get_value(section,"platform","")=="Web": source_section=section; break
	if not str(profile.preset).is_empty() and source_section.is_empty(): fail("Selected Web preset no longer exists."); return
	var options:String=source_section+".options"
	for key:String in ["variant/thread_support","variant/extensions_support","progressive_web_app/enabled"]:
		if native_cfg.get_value(options,key,false): fail("Phase 1 supports single-thread Web without PWA/GDExtension. Disable "+key+" in a dedicated preset."); return
	for check:Dictionary in profile.checks:
		status("Project check: "+str(check.get("scene",check.get("script",""))))
		var command:PackedStringArray=["--path",ProjectSettings.globalize_path("res://")]
		if check.has("script"): command.append_array(["--script",str(check.script)])
		else: command.append(str(check.get("scene","")))
		if not await execute_engine(command,"check-"+str(profile.checks.find(check)),bool(check.get("headless",true))): fail("Project check failed."); return
		if not str(check.get("expected","")).is_empty():
			var log:String=FileAccess.get_file_as_string(job.path_join("check-"+str(profile.checks.find(check))+".log"))
			if not log.contains(str(check.expected)): fail("Project check success marker missing."); return
	status("Snapshotting project; source settings stay unchanged")
	var snapshot:String=job.path_join("project")
	var copied:int=0
	var sources:PackedStringArray=Files.list_files("res://")
	var imports:PackedStringArray=Files.list_files("res://.godot/imported",false)
	var total_copies:int=sources.size()+imports.size()
	for source:String in sources:
		if cancelled(): fail("Cancelled before export."); return
		if source.get_file() in ["web_export.cfg"]: copied+=1; continue
		if not Files.copy_verified(source,snapshot.path_join(source.trim_prefix("res://"))): fail("Snapshot copy failed: "+source); return
		copied+=1
		if copied%25==0:
			status("Snapshotting project",copied,total_copies,"files")
			await process_frame
	# Reuse import products, but never editor state, shader caches or nested build jobs.
	for source:String in imports:
		if cancelled(): fail("Cancelled."); return
		if not Files.copy_verified(source,snapshot.path_join(".godot/imported/"+source.trim_prefix("res://.godot/imported/"))): fail("Import-cache copy failed."); return
		copied+=1
		if copied%25==0:
			status("Snapshotting project",copied,total_copies,"files")
			await process_frame
	status("Snapshot complete",copied,total_copies,"files")
	var preset:ConfigFile=ConfigFile.new()
	if not source_section.is_empty():
		for key:String in native_cfg.get_section_keys(source_section): preset.set_value("preset.0",key,native_cfg.get_value(source_section,key))
		for key:String in native_cfg.get_section_keys(options): preset.set_value("preset.0.options",key,native_cfg.get_value(options,key))
	preset.set_value("preset.0","name","Web Export Studio")
	preset.set_value("preset.0","platform","Web")
	preset.set_value("preset.0","runnable",true)
	if source_section.is_empty(): preset.set_value("preset.0","export_filter","all_resources")
	# Native Resource roots must go through Godot's dependency/import pipeline.
	# include_filter is reserved for non-Resource data, never source-image copies.
	var extra_raw:PackedStringArray=[]
	var extra_resources:PackedStringArray=[]
	for path:String in profile.include:
		var candidates:PackedStringArray=Files.list_files(path) if DirAccess.dir_exists_absolute(path) else PackedStringArray([path])
		for candidate:String in candidates:
			if candidate.get_extension() in ["import","uid"]: continue
			if ResourceLoader.exists(candidate): extra_resources.append(candidate)
			else: extra_raw.append(candidate.trim_prefix("res://"))
	var selection:String=str(preset.get_value("preset.0","export_filter","all_resources"))
	if selection=="selected_resources": selection="resources" # Recover legacy authored presets in the snapshot only.
	if selection not in ["all_resources","resources","scenes","exclude","customized"]:
		fail("Unsupported native export filter: "+selection); return
	if selection in ["resources","scenes"]:
		selection="resources"
		var selected:PackedStringArray=PackedStringArray(preset.get_value("preset.0","export_files",PackedStringArray()))
		for path:String in analysis.resources:
			if ResourceLoader.exists(path) and path not in selected: selected.append(path)
		preset.set_value("preset.0","export_files",selected)
	preset.set_value("preset.0","export_filter",selection)
	for path:String in analysis.resources:
		if not ResourceLoader.exists(path) and path.get_extension() not in ["import","uid"] and path.trim_prefix("res://") not in extra_raw:
			extra_raw.append(path.trim_prefix("res://"))
	var include_filter:String=str(preset.get_value("preset.0","include_filter",""))
	if not extra_raw.is_empty(): include_filter+=("," if not include_filter.is_empty() else "")+",".join(extra_raw)
	preset.set_value("preset.0","include_filter",include_filter)
	var exclude_filter:String=str(preset.get_value("preset.0","exclude_filter",""))
	if not exclude_filter.is_empty(): exclude_filter+=","
	exclude_filter+="addons/web_export/*,web_export.cfg,build/*,artifacts/*"
	for pattern:String in profile.exclude: exclude_filter+=","+pattern.trim_prefix("res://")
	preset.set_value("preset.0","exclude_filter",exclude_filter)
	if profile.trim:
		preset.set_value("preset.0","export_filter","resources")
		preset.set_value("preset.0","export_files",PackedStringArray(analysis.resources.keys()))
	var template:String=str(profile.template)
	if template.is_empty(): template="res://addons/web_export/web/shell.html"
	var shell:String=FileAccess.get_file_as_string(template)
	for token:String in ["WEB_EXPORT_SHELL_V1","$GODOT_URL","$GODOT_CONFIG","__WX_META__","__WX_RUNTIME__","__WX_LOGO__","__WX_TITLE__"]:
		if not shell.contains(token): fail("Template missing: "+token); return
	for element:String in ["canvas","logo","web-export-loading","web-export-start","web-export-progress","web-export-status","web-export-info"]:
		if not shell.contains('id="'+element+'"') and not shell.contains("id='"+element+"'"): fail("Template missing required element: "+element); return
	if not Files.write(snapshot.path_join("web-export-shell.html"),shell.to_utf8_buffer()): fail("Template copy failed."); return
	preset.set_value("preset.0.options","html/custom_html_shell","res://web-export-shell.html")
	preset.set_value("preset.0.options","variant/thread_support",false)
	preset.set_value("preset.0.options","progressive_web_app/enabled",false)
	preset.set_value("preset.0.options","html/canvas_resize_policy",2)
	if preset.save(snapshot.path_join("export_presets.cfg"))!=OK: fail("Cannot write isolated preset."); return
	status("Godot native import — waiting for engine")
	var native_dir:String=job.path_join("native")
	DirAccess.make_dir_recursive_absolute(native_dir)
	if not await execute_engine(["--path",snapshot,"--editor","--import","--","--web-export-child"],"import"): fail("Native import failed/cancelled. See import.log."); return
	status("Godot native export — waiting for engine")
	if not await execute_engine(["--path",snapshot,"--export-release","Web Export Studio",native_dir.path_join("index.html"),"--","--web-export-child"],"export"): fail("Native export failed/cancelled. See export.log."); return
	if cancelled(): fail("Cancelled; previous release preserved."); return
	status("Packaging and verifying content-addressed chunks")
	# A retried job must not register chunks left over from an older PCK.
	var stage:String=job.path_join("stage-"+str(Time.get_ticks_usec()))
	var report:Dictionary=Packager.build(native_dir,stage,profile,analysis,status,cancelled)
	if report.has("error"): fail(str(report.error)); return
	if cancelled(): fail("Cancelled; previous release preserved."); return
	status("Publishing verified files; entry HTML last")
	report=Publisher.publish(stage,output,profile,report,status,cancelled)
	if report.has("error"): fail(str(report.error)); return
	status("Auditing published objects")
	var verification:Dictionary=Publisher.inspect_output(output,str(profile.project_id),"",status,cancelled)
	report.object_audit=verification.get("object_audit",verification)
	if verification.has("error") or not report.object_audit.get("current_valid",false): report.warnings.append("Release published, but final objects audit did not pass. Inspect object_audit before uploading.")
	if not report.object_audit.get("retained_valid",true): report.warnings.append("Retained releases have missing or invalid chunks; rollback is not verified. Current release validity is reported separately.")
	Files.json_write(output.path_join("build-report.json"),report)
	report.output=output
	Files.json_write(job.path_join("result.json"),report)
	status("Complete: "+str(report.release),1,1,"task")
	quit()
