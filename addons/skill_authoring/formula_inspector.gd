@tool
extends EditorInspectorPlugin
func _can_handle(object: Object) -> bool:
	return object is SkillDefinition
func _parse_begin(object: Object) -> void:
	var note: Label = Label.new()
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	note.text="技能資源控制預設操作與數值；同一資源會被多兵種共用。只改一種兵時請先複製資源及改ID。滑鼠停在欄位名稱可看中文說明。"
	add_custom_control(note)
	if object.effect_data!=null:
		var details:Button=Button.new(); details.text="開啟效果細節／召喚／持續與特效"
		details.pressed.connect(func()->void: EditorInterface.edit_resource(object.effect_data))
		add_custom_control(details)
	var panel: FormulaPreview = FormulaPreview.new()
	panel.skill = object as SkillDefinition
	var folding: FoldableContainer = FoldableContainer.new()
	folding.title="技能公式試算（展開）"
	folding.folded=true
	folding.add_child(panel)
	add_custom_control(folding)

func _parse_property(_object: Object, _type: Variant.Type, name: String, _hint: PropertyHint, _hint_string: String, _usage: int, _wide: bool) -> bool:
	if name=="default_key":
		add_property_editor(name,preload("res://addons/skill_authoring/key_property.gd").new(),false,"預設快捷鍵")
		return true
	return false

class FormulaPreview extends VBoxContainer:
	var skill: SkillDefinition
	var stats: Dictionary = {"strength":20.0, "attack":20.0, "intelligence":20.0, "agility":20.0, "vitality":20.0, "level":1.0, "luck":20.0}
	var armor: float = 0.0
	var defense: float = 0.0
	var magic_resistance: float = 0.0
	var result_label: Label
	func _ready() -> void:
		var title: Label = Label.new()
		title.text = "技能公式預覽 / 每次命中或 tick"
		add_child(title)
		var grid: GridContainer = GridContainer.new()
		grid.columns = 2
		add_child(grid)
		var labels: Dictionary = {"strength":"力量", "attack":"攻擊力", "intelligence":"智慧 / 智力", "agility":"敏捷", "vitality":"體質", "level":"等級", "luck":"幸運", "armor":"物理抵抗力（0–0.9）", "defense":"測試固定防禦", "magic_resistance":"法術抵抗力（0–0.9）"}
		for name_text: String in labels:
			var key: String = name_text
			var caption: Label = Label.new()
			caption.text = labels[key]
			grid.add_child(caption)
			var spin: SpinBox = SpinBox.new()
			spin.min_value = 0.0
			spin.max_value = 0.9 if key in ["armor","magic_resistance"] else 1000000.0
			spin.step = 0.01 if key in ["armor","magic_resistance"] else 1.0
			spin.value = armor if key == "armor" else defense if key == "defense" else magic_resistance if key == "magic_resistance" else float(stats[key])
			grid.add_child(spin)
			spin.value_changed.connect(func(value: float) -> void:
				if key == "armor":
					armor = value
				elif key == "defense":
					defense = value
				elif key == "magic_resistance":
					magic_resistance = value
				else:
					stats[key] = value
				_refresh())
		var button: Button = Button.new()
		button.text = "驗證公式"
		add_child(button)
		button.pressed.connect(_refresh)
		result_label = Label.new()
		result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(result_label)
		skill.changed.connect(_refresh)
		_refresh()
	func _refresh() -> void:
		if result_label == null:
			return
		if skill.effect_data!=null and skill.effect_data.kind in [SkillEffectDefinition.Kind.BUFF,SkillEffectDefinition.Kind.STEALTH]:
			result_label.text=SkillDescription.calculation(skill,stats,{})
			return
		var result: Dictionary = skill.result(stats)
		var mitigated: float = float(result["value"]) * (1-magic_resistance) if skill.damage_type == CombatMath.Kind.MAGIC else DamageFormula.mitigate(maxf(0,float(result["value"])-defense),armor)
		result_label.text = "基礎 %.3f\n減傷後 %.3f（%s）" % [result["value"],mitigated,"法術" if skill.damage_type == CombatMath.Kind.MAGIC else "物理"] if result["valid"] else "公式錯誤：" + str(result["error"])
		result_label.modulate = Color(0.7, 1, 0.75) if result["valid"] else Color(1, 0.45, 0.4)
	func _exit_tree() -> void:
		if skill != null and skill.changed.is_connected(_refresh):
			skill.changed.disconnect(_refresh)
