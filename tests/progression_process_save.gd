extends Node
func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var fixture: String = ""
	for argument: String in args:
		if argument.begins_with("--fixture="):
			fixture = argument.trim_prefix("--fixture=")
	if not fixture.begins_with("user://progression-process-"):
		get_tree().quit(2)
		return
	PartyProgress.save_path = fixture
	PartyProgress.persistence_enabled = true
	if "--write" in args:
		PartyProgress.select_slot(2)
		var record: CharacterRecord = PartyProgress.records[2]
		record.add_experience(1230)
		record.allocate("luck")
		record.allocate("luck")
		record.use_item(0)
		record.health = 80
		record.mana = 17
		record.use_item(4)
		var success: bool = PartyProgress.save_party()
		print("GERSANG_PROGRESS_PROCESS_WRITE_", "PASS" if success else "FAIL")
		get_tree().quit(0 if success else 1)
	else:
		var success: bool = PartyProgress.load_party()
		var record: CharacterRecord = PartyProgress.records[2]
		success = success and PartyProgress.selected_slot==2 and record.experience==1230 and record.level()==9 and record.stats()["luck"]==22 and record.health==140 and record.mana==17 and record.equipment[&"weapon"]==&"blade" and record.bag[4]["count"]==2
		print("GERSANG_PROGRESS_PROCESS_READ_", "PASS" if success else "FAIL")
		get_tree().quit(0 if success else 1)
