@tool
extends EditorProperty
var picker: OptionButton
func _init() -> void:
	label="預設快捷鍵"
	picker=OptionButton.new()
	picker.add_item("未綁定",KEY_NONE)
	for code: int in range(KEY_A,KEY_Z+1): picker.add_item(OS.get_keycode_string(code),code)
	for code: int in range(KEY_F3,KEY_F12+1): picker.add_item(OS.get_keycode_string(code),code)
	picker.add_item("Space",KEY_SPACE)
	add_child(picker); add_focusable(picker)
	picker.tooltip_text="改資源預設鍵。玩家在遊戲內自訂的鍵會優先；在設定頁按『跟隨資源』可取消覆蓋。F1/F2、數字、方向與修飾鍵保留。"
	picker.item_selected.connect(func(index: int) -> void: emit_changed(get_edited_property(),picker.get_item_id(index)))
func _update_property() -> void:
	var value: int = int(get_edited_object().get(get_edited_property()))
	var index: int = picker.get_item_index(value)
	if index<0:
		picker.add_item(OS.get_keycode_string(value)+"（現有值）",value)
		index=picker.item_count-1
	picker.select(index)
