extends "res://addons/web_export/core/worker.gd"
## Repackage the already tested native export into a fresh staging directory.
func run() -> void:
	job=ProjectSettings.globalize_path("res://artifacts/monkey/web-job")
	request=Files.json_read(job.path_join("request.json"))
	var profile: Dictionary=request.profile
	var log: String=FileAccess.get_file_as_string(job.path_join("export.log"))
	if log.contains("\nERROR:") or log.contains("SCRIPT ERROR:") or not log.contains("[ DONE ] savepack"):
		fail("Native export is not clean"); return
	var stage: String=job.path_join("stage-"+str(Time.get_ticks_usec()))
	var analysis: Dictionary=Files.json_read(job.path_join("analysis.json"))
	var report: Dictionary=Packager.build(job.path_join("native"),stage,profile,analysis,status,cancelled)
	if report.has("error"): fail(str(report.error)); return
	var output: String=ProjectSettings.globalize_path(str(profile.output))
	report=Publisher.publish(stage,output,profile,report,status,cancelled)
	if report.has("error"): fail(str(report.error)); return
	var audit: Dictionary=Publisher.inspect_output(output,str(profile.project_id),"",status,cancelled)
	report.object_audit=audit.get("object_audit",audit)
	Files.json_write(output.path_join("build-report.json"),report)
	Files.json_write(job.path_join("result.json"),report)
	if not report.object_audit.get("current_valid",false): fail("Final object audit failed"); return
	print("MONKEY_PACKAGE_OK ",report.release); quit()
