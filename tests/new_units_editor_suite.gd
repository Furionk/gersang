@tool
extends Node
var passed: int=0
var failed: int=0
func _ready() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failed+=1
func run() -> void:
	await get_tree().create_timer(5).timeout
	var path: String="res://features/skills/data/teppo_triple.tres"
	var before: String=FileAccess.get_sha256(path)
	var skill: SkillDefinition=(load(path) as SkillDefinition).duplicate(true) as SkillDefinition
	EditorInterface.edit_resource(skill)
	await get_tree().create_timer(1).timeout
	check(EditorInterface.get_inspector().get_edited_object()==skill,"native Inspector edits new SkillDefinition")
	var stats: Dictionary={"attack":100,"strength":20,"agility":20,"intelligence":20}
	check(SkillDescription.calculation(skill,stats,{}).contains("12.0"),"editor buff review shows live duration formula")
	var undo: EditorUndoRedoManager=EditorInterface.get_editor_undo_redo()
	undo.create_action("Test new skill formula",UndoRedo.MERGE_DISABLE,skill)
	undo.add_do_property(skill.effect_data,"duration_formula","10+(agility+strength)*0.1")
	undo.add_undo_property(skill.effect_data,"duration_formula",skill.effect_data.duration_formula)
	undo.commit_action()
	var history: UndoRedo=undo.get_history_undo_redo(undo.get_object_history_id(skill))
	check(skill.effect_data.resolved_duration(stats).value==14,"native editor formula change evaluates")
	history.undo(); check(skill.effect_data.resolved_duration(stats).value==12,"native editor Undo exact formula")
	history.redo(); check(skill.effect_data.resolved_duration(stats).value==14,"native editor Redo exact formula")
	var sandbox: String="res://artifacts/new-units-2026-10-11/skill-editor-"+str(Time.get_ticks_usec())+".tres"
	check(ResourceSaver.save(skill,sandbox)==OK,"native edited Resource saves to sandbox")
	var reopened: SkillDefinition=ResourceLoader.load(sandbox,"",ResourceLoader.CACHE_MODE_IGNORE)
	check(reopened.effect_data.resolved_duration(stats).value==14,"native Resource reopen retains formula")
	var definitions: Array[UnitDefinition]=UnitResourcePaths.definitions()
	for id: StringName in [&"kohime_enemy",&"ninja_enemy",&"teppo_enemy",&"earth_claw_enemy"]:
		check(definitions.any(func(unit: UnitDefinition) -> bool: return unit.id==id),str(id)+" discoverable by monster picker")
	EditorInterface.edit_resource(load("res://features/skills/data/earth_stakes.tres"))
	await get_tree().create_timer(1).timeout
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw()
		get_tree().root.get_texture().get_image().save_png("res://artifacts/new-units-2026-10-11/editor-inspector.png")
	check(FileAccess.get_sha256(path)==before,"formal skill Resource not overwritten")
	history.clear_history(false)
	var file: FileAccess=FileAccess.open("res://artifacts/new-units-2026-10-11/editor-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"scope":"real native EditorInterface/Undo and disposable Resource; physical mouse unverified"})); file.close()
	print("NEW_UNITS_EDITOR_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
