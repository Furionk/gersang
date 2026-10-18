@tool
extends Window
const Profile = preload("core/profile.gd")
const Files = preload("core/files.gd")
const Publisher = preload("core/publish.gd")
var profile:Dictionary
var inputs:Dictionary={}
var jobs:Array[Button]=[]
var report:TextEdit
var status:Label
var progress_bar:ProgressBar
var progress_detail:Label
var job:String=""
var process:int=-1
var preview_process:int=-1
var cancel_button:Button
var timer:Timer

func _ready() -> void:
	title="Web Export Studio 1.1 — WebGL"
	min_size=Vector2i(760,680)
	profile=Profile.read()
	close_requested.connect(hide)
	var margin:MarginContainer=MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(margin)
	for side:String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	var stack:VBoxContainer=VBoxContainer.new(); margin.add_child(stack)
	var tabs:TabContainer=TabContainer.new(); tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL; stack.add_child(tabs)
	var basic:VBoxContainer=VBoxContainer.new(); basic.name="基本 · Basic"; tabs.add_child(basic)
	var presets:OptionButton=OptionButton.new(); presets.add_item("Default Web — all resources")
	for name:String in Profile.presets(): presets.add_item(name)
	for i:int in presets.item_count:
		if presets.get_item_text(i)==str(profile.preset): presets.select(i)
	row(basic,"Godot Web preset",presets); inputs.preset=presets
	field(basic,"output","Output folder",true,true)
	field(basic,"template","HTML template (blank = built-in)",true)
	field(basic,"logo","Logo (optional)",true)
	number(basic,"chunk_mib","Chunk size / MiB",1,4)
	check(basic,"cache","Verified local cache")
	var note:Label=Label.new(); note.text="Single-thread WebGL 2 · source presets stay unchanged\nStart with Analyze. Export writes only verified releases."; basic.add_child(note)
	var advanced:VBoxContainer=VBoxContainer.new(); advanced.name="進階 · Advanced"; tabs.add_child(advanced)
	check(advanced,"diagnostics","Show download diagnostics in game")
	number(advanced,"parallel","Concurrent downloads",1,6)
	number(advanced,"cache_mib","Cache budget / MiB",16,8192)
	number(advanced,"first_budget_mib","First-download warning / MiB",1,8192)
	number(advanced,"total_budget_mib","Server-size warning / MiB",1,16384)
	var compression:OptionButton=OptionButton.new(); compression.add_item("none"); compression.add_item("gzip"); compression.select(1 if profile.compression=="gzip" else 0)
	row(advanced,"Transfer compression",compression); inputs.compression=compression
	check(advanced,"trim","Export only dependency closure (advanced)")
	check(advanced,"dynamic_ack","I declared all runtime-loaded paths below")
	multiline(advanced,"include","Include resources/directories — one res:// path per line")
	multiline(advanced,"exclude","Exclude export patterns — one per line")
	report=TextEdit.new(); report.name="報告 · Report"; report.editable=false; tabs.add_child(report)
	status=Label.new(); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; status.text="Ready. Settings are saved per project."; stack.add_child(status)
	progress_bar=ProgressBar.new(); progress_bar.custom_minimum_size.y=22; progress_bar.show_percentage=false; stack.add_child(progress_bar)
	progress_detail=Label.new(); progress_detail.text="每個階段分別計算進度；原生匯出顯示處理中。"; stack.add_child(progress_detail)
	var buttons:HFlowContainer=HFlowContainer.new(); stack.add_child(buttons)
	for item:Array in [["分析",func():start("analyze")],["一鍵匯出",func():start("build")],["預覽",preview],["開啟資料夾",open_output],["檢查 objects",func():start("audit")],["乾淨上傳包",choose_upload],["清理舊版本",cleanup]]:
		var button:Button=Button.new(); button.text=item[0]; button.pressed.connect(item[1]); buttons.add_child(button); jobs.append(button)
	cancel_button=Button.new(); cancel_button.text="取消"; cancel_button.disabled=true; cancel_button.pressed.connect(cancel); buttons.add_child(cancel_button)
	timer=Timer.new(); timer.wait_time=0.3; timer.timeout.connect(poll); add_child(timer); timer.start()

func row(parent:Control,label:String,widget:Control) -> void:
	var box:HBoxContainer=HBoxContainer.new(); parent.add_child(box)
	var caption:Label=Label.new(); caption.text=label; caption.custom_minimum_size.x=300; box.add_child(caption)
	widget.size_flags_horizontal=Control.SIZE_EXPAND_FILL; box.add_child(widget)

func field(parent:Control,key:String,label:String,browse:bool=false,directory:bool=false) -> void:
	var box:HBoxContainer=HBoxContainer.new()
	var input:LineEdit=LineEdit.new(); input.text=str(profile[key]); input.size_flags_horizontal=Control.SIZE_EXPAND_FILL; box.add_child(input); inputs[key]=input
	if browse:
		var button:Button=Button.new(); button.text="…"; box.add_child(button)
		button.pressed.connect(func():
			var dialog:FileDialog=FileDialog.new(); dialog.access=FileDialog.ACCESS_FILESYSTEM; dialog.file_mode=FileDialog.FILE_MODE_OPEN_DIR if directory else FileDialog.FILE_MODE_OPEN_FILE
			add_child(dialog)
			dialog.dir_selected.connect(func(path:String):input.text=path;dialog.queue_free())
			dialog.file_selected.connect(func(path:String):input.text=path;dialog.queue_free())
			dialog.canceled.connect(dialog.queue_free)
			dialog.popup_centered(Vector2i(800,500)))
	row(parent,label,box)

func number(parent:Control,key:String,label:String,minimum:int,maximum:int) -> void:
	var input:SpinBox=SpinBox.new(); input.min_value=minimum; input.max_value=maximum; input.value=float(profile[key]); inputs[key]=input; row(parent,label,input)

func check(parent:Control,key:String,label:String) -> void:
	var input:CheckBox=CheckBox.new(); input.text=label; input.button_pressed=bool(profile[key]); inputs[key]=input; parent.add_child(input)

func multiline(parent:Control,key:String,label:String) -> void:
	var caption:Label=Label.new(); caption.text=label; parent.add_child(caption)
	var input:TextEdit=TextEdit.new(); input.custom_minimum_size.y=65; input.text="\n".join(profile[key]); inputs[key]=input; parent.add_child(input)

func gather() -> Dictionary:
	var result:Dictionary=profile.duplicate(true)
	for key:String in inputs:
		var input:Control=inputs[key]
		if input is CheckBox: result[key]=input.button_pressed
		elif input is SpinBox: result[key]=int(input.value)
		elif input is OptionButton: result[key]="" if key=="preset" and input.selected==0 else input.get_item_text(input.selected)
		elif input is TextEdit:
			result[key]=[]
			for line:String in input.text.split("\n",false):
				if not line.strip_edges().is_empty(): result[key].append(line.strip_edges())
		else: result[key]=input.text.strip_edges()
	return result

func start(action:String,destination:String="") -> void:
	if process>0: return
	profile=gather()
	var errors:PackedStringArray=Profile.validate(profile)
	if not errors.is_empty(): status.text="\n".join(errors); return
	if Profile.save(profile)!=OK: status.text="Cannot save web_export.cfg"; return
	job=ProjectSettings.globalize_path("res://.godot/web_export/jobs/"+str(Time.get_unix_time_from_system()).replace(".","-")+"-"+str(OS.get_process_id()))
	if not Files.json_write(job.path_join("request.json"),{"job":job,"profile":profile,"action":action,"destination":destination}): status.text="Cannot create job"; return
	process=OS.create_process(OS.get_executable_path(),["--headless","--editor","--path",ProjectSettings.globalize_path("res://"),"--script","res://addons/web_export/core/worker.gd","--log-file",job.path_join("worker.log"),"--",job.path_join("request.json"),"--web-export-child"])
	if process<=0: status.text="Cannot start Godot worker"; return
	for button:Button in jobs: button.disabled=true
	cancel_button.disabled=false; status.text="Starting…"
	progress_bar.value=0; progress_bar.indeterminate=true; progress_detail.text="啟動工作程序…"

func poll() -> void:
	if process<=0: return
	var progress:Dictionary=Files.json_read(job.path_join("status.json"))
	if progress.has("message"): show_progress(progress)
	if OS.is_process_running(process): return
	process=-1
	progress_bar.indeterminate=false
	for button:Button in jobs: button.disabled=false
	cancel_button.disabled=true
	var result:Dictionary=Files.json_read(job.path_join("result.json"))
	if result.is_empty(): progress_bar.value=0; progress_detail.text="工作程序未完成"; status.text="Worker stopped. See "+job.path_join("worker.log"); return
	if result.has("error"): progress_bar.value=0; progress_detail.text="未完成；請查看報告"; status.text=str(result.error); report.text=JSON.stringify(result,"  ")+"\nLogs: "+job; return
	progress_bar.value=100; progress_detail.text="工作已完成"
	if result.has("release"):
		status.text="Export complete: "+str(result.release)
		report.text="Current release storage: %.2f MiB\nFirst download (upper bound): %.2f MiB\nChanged files: %.2f MiB\nChunk reuse versus previous release: %.1f%%\nAssembly buffer estimate: %.2f MiB\n%s\n\nWarnings: %s\n\nOutput: %s\nUpload delta (index.html LAST):\n%s" % [result.server_bytes/1048576.0,result.first_transfer_bytes/1048576.0,result.delta_transfer_bytes/1048576.0,result.get("chunk_reuse_percent",0.0),result.loader_memory_estimate_bytes/1048576.0,result.memory_note,str(result.warnings),result.output,"\n".join(result.delta_files)]
		report.text+="\n\n"+audit_summary(result.get("object_audit",{}))
	elif result.has("object_audit"):
		status.text="乾淨上傳包已建立："+str(result.bundle) if result.has("bundle") else "objects 檢查完成"
		report.get_parent().current_tab=2
		report.text=audit_summary(result.object_audit)+"\n\n"+JSON.stringify(result,"  ")
		if not result.object_audit.get("current_valid",false): status.text="檢查失敗：目前版本的 objects 有缺漏或損壞，請重新匯出。"
		elif not result.object_audit.get("retained_valid",true): status.text="目前版本完整；舊版分塊有缺漏，不能確認回復可用。"
		elif not result.object_audit.get("latest_only",false): status.text="目前版本分塊有效；目錄另含其他內容，請查看報告。"
	else:
		status.text="Analysis complete: "+str(result.analysis.resources.size())+" linked resources"
		report.text=JSON.stringify(result.analysis,"  ")

func cancel() -> void:
	if process>0: Files.write(job.path_join("cancel"),PackedByteArray()); status.text="Cancelling; previous release stays available…"

func output_path() -> String: return ProjectSettings.globalize_path(str(gather().output))
func open_output() -> void: OS.shell_open(output_path())
func preview() -> void:
	if not FileAccess.file_exists(output_path().path_join("index.html")): status.text="Export a release first."; return
	if preview_process>0 and OS.is_process_running(preview_process): OS.kill(preview_process)
	preview_process=OS.create_process(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://addons/web_export/core/preview.gd","--",output_path(),str(profile.preview_port)])
	await get_tree().create_timer(1.0).timeout
	if OS.is_process_running(preview_process): OS.shell_open("http://127.0.0.1:"+str(profile.preview_port)+"/")
	else: status.text="Preview server could not start; port may be occupied."

func cleanup() -> void:
	var output:String=output_path()
	var candidates:Dictionary=Publisher.candidates(output,str(profile.project_id))
	if candidates.has("error"): status.text=str(candidates.error); return
	if candidates.files.is_empty(): status.text="No unused owned files. Current and previous releases are retained."; return
	var dialog:ConfirmationDialog=ConfirmationDialog.new(); add_child(dialog)
	dialog.dialog_text="Delete %d owned files (%.2f MiB)? Current and previous releases remain.\n%s" % [candidates.files.size(),candidates.bytes/1048576.0,"\n".join(candidates.files).left(1200)]
	dialog.confirmed.connect(func():status.text=JSON.stringify(Publisher.clean(output,str(profile.project_id)));dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); dialog.popup_centered(Vector2i(700,450))

func shutdown() -> void:
	cancel()
	if preview_process>0 and OS.is_process_running(preview_process): OS.kill(preview_process)

func show_progress(progress:Dictionary) -> void:
	status.text=str(progress.get("message","Working…"))
	var total:int=int(progress.get("total",0)); var current:int=int(progress.get("current",0))
	progress_bar.indeterminate=total<=0
	if total<=0:
		progress_detail.text="處理中 · 此階段由 Godot 執行，沒有可靠的百分比"
		return
	progress_bar.value=100.0*current/maxi(1,total)
	if progress.get("unit","")=="bytes": progress_detail.text="此階段 %.1f%% · %.2f / %.2f MiB" % [progress_bar.value,current/1048576.0,total/1048576.0]
	else: progress_detail.text="此階段 %.1f%% · %d / %d" % [progress_bar.value,current,total]

func audit_summary(audit:Dictionary) -> String:
	if audit.has("error"): return "objects 檢查未完成："+str(audit.error)
	if audit.is_empty(): return "尚未檢查 objects。"
	return "objects 驗證：%s\n保留舊版完整：%s\n僅包含目前版本：%s\n目前 %d · 保留舊版 %d · 可清理舊塊 %d\n未知 %d · 不安全路徑 %d · 缺失 %d · 損壞 %d · 清單錯誤 %d\n保留舊版支援回復；『乾淨上傳包』另建只含目前版本的目錄。未知檔案不會自動刪除。" % ["通過" if audit.get("current_valid",false) else "失敗","是" if audit.get("retained_valid",false) else "否","是" if audit.get("latest_only",false) else "否",audit.get("current",[]).size(),audit.get("retained",[]).size(),audit.get("obsolete",[]).size(),audit.get("unknown",[]).size(),audit.get("unsafe",[]).size(),audit.get("missing",[]).size(),audit.get("corrupt",[]).size(),audit.get("manifest_errors",[]).size()]

func choose_upload() -> void:
	var dialog:FileDialog=FileDialog.new(); dialog.access=FileDialog.ACCESS_FILESYSTEM; dialog.file_mode=FileDialog.FILE_MODE_OPEN_DIR
	dialog.title="選擇上傳包的父資料夾（自動建立新的 web-upload 子資料夾）"
	dialog.current_dir=output_path().get_base_dir(); add_child(dialog)
	dialog.dir_selected.connect(func(parent:String):
		var name:String="web-upload-"+str(Time.get_unix_time_from_system()).replace(".","-")+"-"+str(OS.get_process_id())
		start("upload",parent.path_join(name)); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); dialog.popup_centered(Vector2i(800,500))
