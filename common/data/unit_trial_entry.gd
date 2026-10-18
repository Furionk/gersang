@tool
class_name UnitTrialEntry
extends Resource
## F2進階試兵直接引用兵種，不以檔名／資料夾猜種類。只影響本場，不招募、不存入正式名單。
@export var friendly: UnitDefinition
## 可留空；留空時此試兵沒有敵方版本。
@export var enemy: UnitDefinition
