extends SceneTree
const Files=preload("../core/files.gd")
const Packager=preload("../core/package.gd")
const Publisher=preload("../core/publish.gd")
func _initialize() -> void:
	var args:PackedStringArray=OS.get_cmdline_user_args()
	var original:String=args[0]
	var job:String=args[1]
	var request:Dictionary=Files.json_read(original.path_join("request.json"))
	var analysis:Dictionary=Files.json_read(original.path_join("analysis.json"))
	var stage:String=job.path_join("stage")
	var report:Dictionary=Packager.build(original.path_join("native"),stage,request.profile,analysis)
	if not report.has("error"): report=Publisher.publish(stage,request.profile.output,request.profile,report)
	Files.json_write(job.path_join("result.json"),report)
	print("REPACKAGE_RESULT ",report.get("error",report.get("release","missing")))
	quit(1 if report.has("error") else 0)
