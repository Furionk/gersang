@tool
extends EditorProperty
var widget: Control
var value_type: int
var editing: bool = false

func configure(type: int, hint_text: String) -> void:
	value_type = type
	if type==TYPE_BOOL:
		var toggle: CheckBox = CheckBox.new()
		toggle.toggled.connect(func(value: bool) -> void:
			if not editing: emit_changed(get_edited_property(),value))
		widget = toggle
	elif type in [TYPE_INT,TYPE_FLOAT]:
		var spin: SpinBox = SpinBox.new()
		var limits: PackedStringArray = hint_text.split(",")
		spin.min_value = float(limits[0]) if limits.size()>=2 else 0
		spin.max_value = float(limits[1]) if limits.size()>=2 else 3600
		spin.step = 1 if type==TYPE_INT else 0.1
		spin.value_changed.connect(func(value: float) -> void:
			if not editing: emit_changed(get_edited_property(),int(value) if value_type==TYPE_INT else value))
		widget = spin
	else:
		var line: LineEdit = LineEdit.new()
		line.text_submitted.connect(func(value: String) -> void: emit_changed(get_edited_property(),value))
		line.focus_exited.connect(func() -> void:
			if not editing and line.text!=get_edited_object().get(get_edited_property()): emit_changed(get_edited_property(),line.text))
		widget = line
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(widget)
	add_focusable(widget)

func _update_property() -> void:
	editing = true
	var value: Variant = get_edited_object().get(get_edited_property())
	if widget is CheckBox: widget.set_pressed_no_signal(value)
	elif widget is SpinBox: widget.set_value_no_signal(value)
	else: widget.text = value
	editing = false

func _set_read_only(value: bool) -> void:
	if widget is CheckBox: widget.disabled = value
	elif widget is SpinBox: widget.editable = not value
	else: widget.editable = not value
