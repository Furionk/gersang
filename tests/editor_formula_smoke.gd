extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for i: int in 12:
		await process_frame
	var inspector: EditorInspector = EditorInterface.get_inspector()
	if inspector == null:
		push_error("Editor inspector unavailable for formula preview verification")
		quit(1)
		return
	inspector.edit(load("res://features/skills/data/blast.tres"))
	for i: int in 8:
		await process_frame
	var found: bool = false
	for node: Node in inspector.find_children("*", "Label", true, false):
		if (node as Label).text.contains("基礎 40.000"):
			found = true
	print("GERSANG_EDITOR_FORMULA_" + ("PASS" if found else "FAIL"))
	quit(0 if found else 1)
