extends Node
signal changed(slot: int)
signal notification(text: String)
const VERSION: int = 2
var records: Array[CharacterRecord] = []
var reserves: Array[CharacterRecord] = []
var selected_slot: int = 0
var save_path: String = DemoRules.path("party_progress.dat")
var persistence_enabled: bool = true
var save_protected: bool = false
var batching: bool = false
var last_error: String = ""
func _ready() -> void:
	reset_party()
	# Tests never load or change the real party, including pre-existing suites.
	for argument: String in OS.get_cmdline_args():
		if argument.begins_with("res://tests/") or argument == "--isolated-world-tests" or argument.begins_with("res://tools/") or argument.begins_with("res://features/battle/maps/"):
			persistence_enabled = false
	if persistence_enabled:
		load_party()
func reset_party() -> void:
	records.clear()
	reserves.clear()
	selected_slot = 0
	var definitions: Array[UnitDefinition] = DemoRules.SETUP.active
	for i: int in definitions.size():
		var record: CharacterRecord = DemoRules.make_record(definitions[i],i)
		record.changed.connect(_record_changed.bind(i))
		records.append(record)
	for i: int in DemoRules.SETUP.reserve.size():
		reserves.append(DemoRules.make_record(DemoRules.SETUP.reserve[i],definitions.size()+i))
func _record_changed(slot: int) -> void:
	if not batching:
		save_party()
	changed.emit(slot)
func select_slot(slot: int) -> void:
	if slot >= 0 and slot < records.size():
		selected_slot = slot
		changed.emit(slot)
func selected() -> CharacterRecord:
	return records[selected_slot]
func award_victory(total: int, slots: Array[int]) -> int:
	if total <= 0 or slots.is_empty():
		return 0
	var each: int = total / slots.size()
	batching = true
	for i: int in slots.size():
		var slot: int = slots[i]
		var gained: int = each + (1 if i < total % slots.size() else 0)
		var levels: int = records[slot].add_experience(gained)
		if levels > 0:
			notification.emit("%s 升至 Lv.%d，獲得 %d 配點。" % [records[slot].definition.display_name, records[slot].level(), levels * 4])
	batching = false
	save_party()
	return each
func serialize() -> Dictionary:
	var party: Array[Dictionary] = []
	for record: CharacterRecord in records:
		party.append(record.serialize())
	var reserve: Array[Dictionary] = []
	for record: CharacterRecord in reserves: reserve.append(record.serialize())
	return {"version":VERSION, "selected":selected_slot, "party":party, "reserve":reserve}
func restore(data: Variant, notify: bool = true) -> bool:
	var decoded: Dictionary = MercenaryRoster.decode(data)
	if decoded.is_empty(): return false
	for i: int in records.size():
		var callback: Callable = _record_changed.bind(i)
		if records[i].changed.is_connected(callback): records[i].changed.disconnect(callback)
	for record: CharacterRecord in reserves:
		if record.changed.is_connected(_reserve_changed): record.changed.disconnect(_reserve_changed)
	records.assign(decoded.active)
	reserves.assign(decoded.reserve)
	for i: int in records.size(): records[i].changed.connect(_record_changed.bind(i))
	for record: CharacterRecord in reserves: record.changed.connect(_reserve_changed)
	selected_slot = clampi(int(data.get("selected", 0)), 0, records.size() - 1)
	if notify: changed.emit(selected_slot)
	return true
func _reserve_changed() -> void:
	_record_changed(selected_slot)
func load_party() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file != null and file.get_length() < 1048576:
		var data: Variant = file.get_var(false)
		file.close()
		if restore(data):
			return true
	save_protected = true
	last_error = "存檔資料有誤／版本不相容：原檔保留，暫不覆寫。"
	if FileAccess.file_exists(save_path + ".bak"):
		var backup: FileAccess = FileAccess.open(save_path + ".bak", FileAccess.READ)
		if backup != null and backup.get_length() < 1048576:
			var data: Variant = backup.get_var(false)
			backup.close()
			if restore(data):
				last_error += " 已載入備份供本次試玩。"
	return false
func save_party() -> bool:
	if not persistence_enabled:
		return true
	if save_protected or not save_path.begins_with("user://"):
		if not save_protected:
			last_error = "養成存檔只允許寫入 user://。"
		return false
	var temporary: String = save_path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "無法寫入養成存檔。"
		return false
	file.store_var(serialize(), false)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		last_error = "養成存檔寫入失敗。"
		return false
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(save_path + ".bak") and DirAccess.remove_absolute(save_path + ".bak") != OK:
			last_error = "無法更新養成備份，存檔尚未完成。"
			return false
		if DirAccess.rename_absolute(save_path, save_path + ".bak") != OK:
			last_error = "無法備份原有養成存檔，原檔未覆寫。"
			return false
	if DirAccess.rename_absolute(temporary, save_path) != OK:
		if FileAccess.file_exists(save_path + ".bak"):
			DirAccess.rename_absolute(save_path + ".bak", save_path)
		last_error = "無法完成養成存檔；舊存檔已保留。"
		return false
	last_error = ""
	return true
