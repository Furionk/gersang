@tool
class_name MercenaryCatalog
extends Resource
## 追加兵種資料庫。正式展示版編隊由Demo Setup指定，不再提供永久招募。
@export var definitions: Array[UnitDefinition] = []
## F2進階試兵名單；拖入UnitTrialEntry，友軍／敵軍為明确Resource引用。
@export var trials: Array[UnitTrialEntry]=[]
