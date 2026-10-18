@tool
extends VBoxContainer
var plugin: EditorPlugin
var item: Node2D
var anchor_x: SpinBox
var anchor_y: SpinBox
func _ready() -> void:
	var title: Label = Label.new(); title.text="排序與腳底"; add_child(title)
	var picker: OptionButton = OptionButton.new()
	for title_text: String in ["沿用素材","貼地（角色下方）","立體（腳底自動交錯）","前景（永遠在角色前）"]: picker.add_item(title_text)
	picker.select(int(item.get_meta(ScenerySorting.OVERRIDE_KEY,-1))+1)
	picker.tooltip_text="不用調Z。素材預設共享，這裡只改目前這件；Ctrl+Z可還原。"
	picker.item_selected.connect(func(index: int) -> void: plugin.call("set_sort_override",item,index-1))
	add_child(picker)
	var preset: WorldSceneryDefinition = ScenerySorting.preset_for(item)
	var resource: EditorResourcePicker = EditorResourcePicker.new()
	resource.base_type="WorldSceneryDefinition"; resource.edited_resource=preset
	resource.resource_changed.connect(func(value: Resource) -> void: plugin.call("set_sort_preset",item,value))
	resource.resource_selected.connect(func(value: Resource, _inspect: bool) -> void: EditorInterface.edit_resource(value))
	resource.tooltip_text="同一裁切圖會自動找共享素材預設；也可拖入自己的WorldSceneryDefinition。这里只影響排序，不覆寫Sprite Texture。"
	add_child(resource)
	var explanation: Label = Label.new(); explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	explanation.text="同款素材設定一次。Z由排序類型管理；尋路只看Walkable／Blockers。" if preset!=null else "未找到素材預設：目前按腳底立體排序。可指定素材，或直接設單件類型。"
	if preset!=null and preset.sorting_review_required: explanation.text+="\n待分件審閱："+preset.sorting_note
	add_child(explanation)
	if item is Sprite2D:
		var label: Label = Label.new(); label.text="顯示裁切圖內的腳底（像素X／Y）"; add_child(label)
		var row: HBoxContainer = HBoxContainer.new(); add_child(row)
		var anchor: Vector2 = ScenerySorting.current_anchor(item)
		anchor_x=_spin(anchor.x); anchor_y=_spin(anchor.y); row.add_child(anchor_x); row.add_child(anchor_y)
		var apply: Button = Button.new(); apply.text="校準腳底（保持圖片原位）"
		apply.pressed.connect(func() -> void: plugin.call("calibrate_foot",item,Vector2(anchor_x.value,anchor_y.value)))
		add_child(apply)
		var help: Label = Label.new(); help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		help.text="改的是排序原點；會同步補償Offset，圖片不跳動。沒有移動／新增障礙格。大型混合圖仍需分件。"; add_child(help)
func _spin(value: float) -> SpinBox:
	var spin: SpinBox = SpinBox.new(); spin.min_value=-8192; spin.max_value=8192; spin.step=0.5; spin.value=value; spin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return spin
