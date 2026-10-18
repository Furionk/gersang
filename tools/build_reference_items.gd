extends SceneTree
func _initialize() -> void:
	call_deferred("build")
func build() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://specs/sources/items52.json"))
	for row: Dictionary in data["items"]:
		var path: String = "res://features/progression/data/items/source52/%s.tres" % row["id"]
		if FileAccess.file_exists(path): print("PRESERVED_ITEM ",row["id"]); continue
		var item: GearItemDefinition = GearItemDefinition.new()
		item.id = StringName(row["id"])
		item.display_name = row["name"]
		item.category = row["category"]
		item.kind = GearItemDefinition.Kind.FOOD if item.category == "food" else GearItemDefinition.Kind.EQUIPMENT
		item.equipment_slot = GearItemDefinition.Slot.BODY if item.category == "armor" else GearItemDefinition.Slot.WEAPON
		item.weight = row["weight"]
		item.required_level = row["level"]
		item.modifiers = row.get("modifiers",{}).duplicate(true)
		item.use_effect = GearItemDefinition.Effect.NONE
		item.source_url = "https://www.52jushang.com/item/%s.asp" % row["page"]
		item.source_image_url = "https://www.52jushang.com/item/"+row["image"]
		item.source_stats = {"required_level":row["level"],"weight_jin":row["weight"],"modifiers":row.get("modifiers",{})}
		item.source_skill_names = PackedStringArray(row.get("source_skills",[]))
		item.adaptation_notes = row.get("notes","")
		if item.category == "food":
			item.source_stats["satiety"] = row["source_satiety"]
			item.description = "只收錄食品資料；本作不設定飽食度或食用效果。"
		else: item.description = "52巨商參考裝備；屬性與重量依來源，攻擊區間作為裝備加成。"
		var icon_path: String = "res://art/items/source52/%s.png" % row["id"]
		if ResourceLoader.exists(icon_path): item.icon = load(icon_path) as Texture2D
		else: push_error("ITEM_ICON_MISSING " + row["id"]); quit(1); return
		for skill_path: String in row.get("runtime_skill_paths",[]): item.granted_skills.append(load(skill_path) as SkillDefinition)
		var error: Error = ResourceSaver.save(item,path)
		if error != OK: push_error("ITEM_SAVE_FAILED "+path); quit(1); return
		print("BUILT_ITEM ",row["id"])
	quit()
