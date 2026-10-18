class_name CombatFeelProfile
extends Resource
## 世界與戰鬥共用的移速倍率，不重寫兵種基礎速度。
@export_range(0.4, 2.5, 0.05) var movement_multiplier: float = 1.0
## 呈現面向的轉向速度，不改邏輯位置。
@export_range(2.0, 30.0, 0.5) var turn_speed: float = 16.0
## 友軍索敵距離倍率。
@export_range(0.25, 2.0, 0.05) var detection_multiplier: float = 1.0
## 普攻前搖秒數，與技能Cast Time分開。
@export_range(0.08, 0.9, 0.01) var attack_windup: float = 0.28
## 非零技能前搖的倍率；0前搖技能仍即時。
@export_range(0.15, 2.0, 0.05) var cast_multiplier: float = 1.0
## 舊連射相容欄位，目前手動技能要求每次新左鍵確認，不會用它製造冷卻。
@export_range(0.1, 1.5, 0.05) var repeat_interval: float = 0.25
## 地面單位物理半徑，影響通行與出生間距。
@export_range(5.0, 22.0, 0.5) var collision_radius: float = 11.0
## 戰鬥鏡頭手動移動速度。
@export_range(100.0, 1400.0, 25.0) var camera_speed: float = 650.0
## 停止命令後，多久再恢復友軍自動索敵（秒）。
@export_range(0.05, 2.0, 0.05) var stop_reacquire_delay: float = 0.45
## 介面字體／排版倍率。
@export_range(0.8, 1.4, 0.05) var ui_scale: float = 1.0
## 舊相容欄位；目前不允許按住沿用目標重放技能。
@export var held_repeat_enabled: bool = false
## 舊相容欄位；目前不允許Ctrl沿用舊目標重放技能。
@export var reserved_repeat_enabled: bool = false
## 允許E順序準備技能；仍需左鍵確認。
@export var sequence_enabled: bool = true
