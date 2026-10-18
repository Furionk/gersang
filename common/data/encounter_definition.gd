@tool
class_name EncounterDefinition
extends Resource
## 穩定識別ID，用於存檔與技能合併；複製新種類時改成獨立ID，不要只改顯示名稱。
@export var id: StringName
## 畫面與Inspector顯示的中文名稱，不改變存檔ID。
@export var display_name: String
@export var terrain: int = 0
@export var ground_texture: Texture2D
## 初始／模板等級；實際怪隊等級還由配怪Member Rule決定。
@export var level: int = 1
@export var melee_count: int = 6
@export var ranged_count: int = 2
@export var elite_count: int = 1
@export var boss_count: int = 0
## Optional region-scoped action mode. Null preserves the existing RTS controller.
@export var action_profile: RainbowActionProfile
## Independent 3D capture encounter. Null leaves ordinary combat unchanged.
@export var monkey_profile: MonkeyProfile
@export_group("戰場布局")
## 正式戰場原生Scene路徑；指定後，舊程序布局欄位不再作權威。
@export_file("*.tscn") var battlefield_scene: String = "":
	set(value): battlefield_scene=value; notify_property_list_changed()
## 戰場邏輯格數，非畫面尺寸；擴大後需自行鋪地與通行格。
@export var battlefield_cells: Vector2i = Vector2i(44, 38)
@export var battlefield_obstacles: Array[Rect2i] = []
@export var enemy_spawn_centers: PackedVector2Array = PackedVector2Array([Vector2(1160,440),Vector2(1520,880),Vector2(1160,1320),Vector2(600,1240)])

func _validate_property(property: Dictionary) -> void:
	# Scene authors must not be offered shadow layout settings that do nothing.
	if not battlefield_scene.is_empty() and property.name in ["ground_texture","battlefield_cells","battlefield_obstacles","enemy_spawn_centers"]:
		property.usage &= ~PROPERTY_USAGE_EDITOR

