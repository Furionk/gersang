@tool
class_name DemoSetup
extends Resource
## 新遊戲初始化資料；換兵不重新發放。
@export var active: Array[UnitDefinition]=[]
@export var reserve: Array[UnitDefinition]=[]
@export_range(1,100) var mercenary_level: int=25
@export var starting_items: Array[StringName]=[&"debug_medicine",&"debug_exp_book"]
@export var starting_counts: Array[int]=[50,25]
## 日常戰鬥／行旅工具列可直接使用的背包道具。
@export var quick_consumable: StringName=&"debug_medicine"
@export var tools_enabled: bool=true
@export var save_namespace: String="demo10-v3"
