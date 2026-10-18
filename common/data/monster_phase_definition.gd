@tool
class_name MonsterPhaseDefinition
extends Resource
## 原生首領死亡階段資料。下一形態／最終分身不得循環引用自己。
@export var next_form: Resource
@export var final_spawn: Resource
@export_range(0,20) var final_spawn_count:int=0
## 全戰場暫停秒數；仍可看變身與UI，不推進戰鬥、效果或扣血時鐘。
@export_range(0.0,10.0,0.1) var pause_seconds:float=2.0
@export var title:String="變身"
## 全畫面淡轉／末日文字／持續血霧，純演出Resource；留空沿用普通提示。
@export var presentation:BattlePhasePresentation
## 可選的原生戰場Scene；通行幾何必須與當前戰場相同，否則拒絕換景。
@export var battlefield:PackedScene
@export_group("戰場環境（整場一份，不疊加）")
@export var hazard_enabled:bool=false
@export_range(0.1,60.0,0.1) var hazard_interval:float=3.0
## 按最大HP比例；0.01是1%。
@export_range(0.0,1.0,0.001) var hazard_max_health_fraction:float=0.01
## 大於0改為每次固定扣血，比例欄不使用。
@export_range(0.0,10000.0,1.0) var hazard_fixed_damage:float=0.0
@export var hazard_teams:PackedInt32Array=PackedInt32Array([0,1])
