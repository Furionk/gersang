@tool
extends EditorProperty
var picker: OptionButton
func _init() -> void:
	picker=OptionButton.new()
	for title: String in ["貼地裝飾","立體自動排序","固定前景"]: picker.add_item(title)
	add_child(picker); add_focusable(picker)
	picker.item_selected.connect(func(index: int) -> void: emit_changed(get_edited_property(),index))
func _update_property() -> void: picker.select(int(get_edited_object().get(get_edited_property())))
func _set_read_only(value: bool) -> void: picker.disabled=value
