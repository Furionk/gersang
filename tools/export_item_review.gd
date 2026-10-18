extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var rows: Array[Dictionary] = []
	var csv: FileAccess = FileAccess.open("res://artifacts/world/items-review.csv",FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(["id","name","category","required_level","weight","attack_min","attack_max","defense","strength","agility","intelligence","runtime_skills","source_skills","icon","resource","source_url"]))
	for item: GearItemDefinition in ItemCatalog.all_items():
		var paths: Array[String] = []
		for skill: SkillDefinition in item.granted_skills: paths.append(skill.resource_path)
		var row: Dictionary = {"id":String(item.id),"name":item.display_name,"category":item.category,"required_level":item.required_level,"weight":item.weight,"modifiers":item.modifiers,"granted_skills":paths,"source_skills":item.source_skill_names,"icon":item.icon.resource_path if item.icon != null else "","resource":item.resource_path,"source_url":item.source_url,"use_effect":int(item.effect()),"restore_health":item.hp_amount(),"restore_mana":item.mp_amount(),"affects_party":item.affects_party,"revives":item.revives,"notes":item.adaptation_notes}
		rows.append(row)
		csv.store_csv_line(PackedStringArray([row["id"],row["name"],row["category"],str(item.required_level),str(item.weight),str(item.modifiers.get("attack_min",0)),str(item.modifiers.get("attack_max",0)),str(item.modifiers.get("defense",0)),str(item.modifiers.get("strength",0)),str(item.modifiers.get("agility",0)),str(item.modifiers.get("intelligence",0)),";".join(paths),";".join(item.source_skill_names),row["icon"],item.resource_path,item.source_url]))
	csv.close()
	var json: FileAccess = FileAccess.open("res://artifacts/world/items-review.json",FileAccess.WRITE)
	json.store_string(JSON.stringify({"authority":"Native .tres Resources. These exports are read-only review snapshots, not automatically imported.","items":rows},"\t"))
	json.close()
	print("ITEM_REVIEW_EXPORT_PASS rows=",rows.size())
	quit()
