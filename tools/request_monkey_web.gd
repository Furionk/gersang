extends SceneTree
func _initialize() -> void:
	var profile: Dictionary=preload("res://addons/web_export/core/profile.gd").read()
	profile.output="res://artifacts/monkey/web"
	profile.include=["res://features/monkey/","res://features/world/data/monkey_garden_arena.tres","res://features/world/data/monkey_garden_hard_arena.tres","res://features/world/data/monkey_garden_mania_arena.tres","res://features/world/data/monkey_garden_despair_arena.tres"]
	profile.checks.append({"scene":"res://tests/monkey_garden_suite.tscn","expected":"MONKEY_RESULT passed=18 failed=0"})
	profile.checks.append({"scene":"res://tests/monkey_encounter_suite.tscn","expected":"MONKEY_ENCOUNTER_RESULT passed=27 failed=0"})
	profile.checks.append({"scene":"res://tests/monkey_meshy_suite.tscn","expected":"MESHY_RESULT failed=0"})
	profile.checks.append({"scene":"res://tests/monkey_difficulty_suite.tscn","expected":"DIFFICULTY_RESULT passed=18 failed=0"})
	profile.checks.append({"scene":"res://tests/monkey_village_suite.tscn","expected":"VILLAGE_RESULT failed=0"})
	profile.checks.append({"scene":"res://tests/monkey_ai_suite.tscn","expected":"MONKEY_AI_RESULT passed=17 failed=0"})
	profile.checks.append({"scene":"res://tests/monkey_ui_suite.tscn","expected":"MONKEY_UI_RESULT passed=13 failed=0"})
	profile.checks.append({"scene":"res://tests/monkey_action_suite.tscn","expected":"MONKEY_ACTION_RESULT passed=28 failed=0"})
	var job: String=ProjectSettings.globalize_path("res://artifacts/monkey/web-job")
	DirAccess.make_dir_recursive_absolute(job)
	var file:=FileAccess.open(job.path_join("request.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"job":job,"profile":profile,"action":"build"},"\t")); file.close()
	print("MONKEY_WEB_REQUEST ",job); quit()
