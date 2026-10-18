extends "res://addons/web_export/core/worker.gd"
## Focused iteration after a complete successful build. Keep the full original checks.
func run() -> void:
	job=ProjectSettings.globalize_path("res://artifacts/monkey/web-job")
	request=Files.json_read(job.path_join("request.json"))
	for name_: String in ["monkey_garden_suite","monkey_encounter_suite"]:
		if not await execute_engine(["--path",ProjectSettings.globalize_path("res://"),"res://tests/"+name_+".tscn"],"iteration-"+name_): fail("Iteration test failed"); return
	var snapshot: String=job.path_join("project")
	for path: String in ["features/monkey/garden.gd","features/monkey/monkey_actor.gd"]:
		if not Files.copy_verified("res://"+path,snapshot.path_join(path)): fail("Snapshot refresh failed"); return
	if not await execute_engine(["--path",snapshot,"--editor","--import","--","--web-export-child"],"import"): fail("Import failed"); return
	if not await execute_engine(["--path",snapshot,"--export-release","Web Export Studio",job.path_join("native/index.html"),"--","--web-export-child"],"export"): fail("Export failed"); return
	print("MONKEY_ITERATION_NATIVE_OK"); quit()
