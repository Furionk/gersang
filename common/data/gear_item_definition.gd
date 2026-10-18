@tool
class_name GearItemDefinition
extends Resource
enum Kind { EQUIPMENT, FOOD, TEA, MATERIAL, MEDICINE, BOOK }
enum Slot { WEAPON, BODY, HEAD, CHARM, HANDS, BELT, FEET, RING_LEFT, RING_RIGHT }
enum Effect { LEGACY, NONE, RESTORE_HP, RESTORE_MP, RESTORE_BOTH, LEVEL_UP }
@export_group("識別與美術")
@export var id: StringName
@export var display_name: String
@export var category: String = "legacy"
@export var icon: Texture2D
@export var debug_only: bool = false
@export_group("裝備與數值")
@export var kind: Kind = Kind.MATERIAL
@export var equipment_slot: Slot = Slot.WEAPON
@export var max_stack: int = 99
@export var weight: float = 1.0
@export var restore: float = 0.0
@export var modifiers: Dictionary = {}
@export var power_bonus: int = 0
@export_range(1,300) var required_level: int = 1
@export var allowed_roles: PackedInt32Array = PackedInt32Array()
@export var granted_skills: Array[SkillDefinition] = []
@export_group("食用效果")
@export var use_effect: Effect = Effect.LEGACY
@export var restore_health: float = 0
@export var restore_mana: float = 0
@export var affects_party: bool = false
@export var revives: bool = false
@export_range(0,100) var levels_granted: int = 1
@export_group("來源與校準")
@export var source_url: String = ""
@export var source_image_url: String = ""
@export var source_stats: Dictionary = {}
@export var source_skill_names: PackedStringArray = PackedStringArray()
@export_multiline var adaptation_notes: String = ""
@export_multiline var description: String = ""
const SLOT_NAMES: Array[StringName] = [&"weapon", &"body", &"head", &"charm", &"hands", &"belt", &"feet", &"ring_left", &"ring_right"]
func slot_name() -> StringName:
	return SLOT_NAMES[equipment_slot]
func stack_limit() -> int:
	return 1 if kind == Kind.EQUIPMENT else maxi(1,max_stack)

func effect() -> Effect:
	if use_effect != Effect.LEGACY: return use_effect
	return Effect.RESTORE_HP if kind == Kind.FOOD else Effect.RESTORE_MP if kind == Kind.TEA else Effect.NONE

func hp_amount() -> float:
	return restore if use_effect == Effect.LEGACY and kind == Kind.FOOD else restore_health

func mp_amount() -> float:
	return restore if use_effect == Effect.LEGACY and kind == Kind.TEA else restore_mana

func equip_error(level: int, role: int, bypass_level: bool = false) -> String:
	if kind != Kind.EQUIPMENT: return "不是裝備。"
	if not bypass_level and level < required_level: return "需要 Lv.%d。" % required_level
	if not allowed_roles.is_empty() and role not in allowed_roles: return "此兵種不能使用。"
	return ""

func tooltip() -> String:
	var text: String = "%s\nLv.%d · 重量 %.1f\n%s" % [display_name,required_level,weight,description]
	for key: String in modifiers: text += "\n%s: %s" % [key,str(modifiers[key])]
	if not source_skill_names.is_empty(): text += "\n來源技能："+", ".join(source_skill_names)
	if not granted_skills.is_empty():
		for skill: SkillDefinition in granted_skills: text += "\n已接入技能："+skill.display_name
	if adaptation_notes != "": text += "\n"+adaptation_notes
	return text
