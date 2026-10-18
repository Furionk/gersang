@tool
class_name BattlePhasePresentation
extends Resource
## 只控制演出，不決定傷害／暫停或出生。MonsterPhaseDefinition仍擁有戰鬥時鐘。
@export var headline:String="末日來了"
@export var subtitle:String="血月降臨 · 加儂幻象"
@export_range(0.05,2.0,0.05) var fade_out_seconds:float=0.55
@export_range(24,120,1) var title_size:int=64
@export var title_color:Color=Color(1,0.62,0.42)
@export_range(0.0,0.5,0.01) var flash_opacity:float=0.2
@export_range(0.0,1.0,0.01) var fog_opacity:float=0.23
@export_range(0.0,2.0,0.05) var fog_density:float=0.9
@export_range(0.0,3.0,0.05) var fog_speed:float=0.35
@export var fog_color:Color=Color(0.55,0.008,0.04)
