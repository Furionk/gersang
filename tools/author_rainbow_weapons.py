"""One-shot action-only weapon resources. Existing unit definitions are untouched."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
# ID: title pair, specialty, effect, color, tuning overrides.
DATA={
'merchant':('連斬','飛刃','均衡連擊','blade','77e7dd',{}),
'guard':('重劈','震地刃','重甲破陣','heavy','ffcc73',dict(melee_range=112.,melee_half_angle=1.3,melee_windup=.26,melee_recovery=.42,melee_power=1.45,ranged_windup=.3,ranged_recovery=.6,ranged_power=1.,mana_cost=5.,projectile_speed=420.,projectile_lifetime=.85,pierce=2,knockback=240.,stagger=.22,move_multiplier=.9,guard_damage_scale=.08)),
'teppo':('槍托刺','貫穿彈','架槍狙擊','rifle','ffe4b1',dict(melee_range=65.,melee_half_angle=.45,melee_windup=.12,melee_recovery=.28,melee_power=.75,ranged_windup=.35,ranged_recovery=.55,ranged_power=1.5,mana_cost=5.,projectile_speed=1100.,projectile_lifetime=.75,pierce=3,move_multiplier=.95)),
'gunner':('銃柄擊','三連散彈','近距散射','scatter','ff873e',dict(melee_range=70.,melee_half_angle=.8,melee_windup=.18,melee_recovery=.3,melee_power=.85,ranged_windup=.25,ranged_recovery=.6,ranged_power=.38,mana_cost=5.,projectile_speed=650.,projectile_lifetime=.48,projectile_count=3,spread=.17,knockback=175.)),
'mage':('雷杖擊','穿雲雷','直線雷擊','lightning','72c9ff',dict(melee_range=95.,melee_half_angle=.75,melee_windup=.2,melee_recovery=.3,melee_power=.65,ranged_windup=.32,ranged_recovery=.48,ranged_power=.8,mana_cost=5.,projectile_speed=1050.,projectile_lifetime=.55,pierce=3,stagger=.18)),
'healer':('點穴刺','三花針','輕巧快攻','needle','91ecc2',dict(melee_range=55.,melee_half_angle=.55,melee_windup=.08,melee_recovery=.2,melee_power=.6,ranged_windup=.12,ranged_recovery=.32,ranged_power=.2,mana_cost=2.,projectile_speed=900.,projectile_lifetime=.6,projectile_count=3,spread=.08,move_multiplier=1.05,stagger=.08,knockback=80.)),
'supplier':('拂扇','爆炎符','符火爆裂','talisman','ffc76b',dict(melee_range=102.,melee_half_angle=1.45,melee_windup=.18,melee_recovery=.35,melee_power=.75,ranged_windup=.3,ranged_recovery=.55,ranged_power=.9,mana_cost=5.,projectile_speed=420.,projectile_lifetime=1.25,splash=75.)),
'controller':('封環','鎮魂印','封印控場','seal','d09aff',dict(melee_range=85.,melee_half_angle=1.2,melee_windup=.22,melee_recovery=.32,melee_power=.65,ranged_windup=.3,ranged_recovery=.65,ranged_power=.65,mana_cost=4.,projectile_speed=480.,projectile_lifetime=1.1,stagger=.38,knockback=55.)),
'ninja':('雙刃斬','三方鏢','高速游擊','kunai','ff9ab0',dict(melee_range=58.,melee_half_angle=.65,melee_windup=.07,melee_recovery=.16,melee_power=.65,ranged_windup=.1,ranged_recovery=.4,ranged_power=.23,mana_cost=3.,projectile_speed=820.,projectile_lifetime=.55,projectile_count=3,spread=.22,move_multiplier=1.15,stagger=.08,knockback=65.)),
'kohime':('月鐮斬','穿月輪','廣域月刃','crescent','e1b6ff',dict(melee_range=125.,melee_half_angle=1.55,melee_windup=.25,melee_recovery=.4,melee_power=1.25,ranged_windup=.24,ranged_recovery=.6,ranged_power=.75,mana_cost=5.,projectile_speed=600.,projectile_lifetime=.9,pierce=3,knockback=170.,stagger=.16)),
'malfory':('魔杖震','厄運球','慢速重爆','curse','67efa1',dict(melee_range=65.,melee_half_angle=.8,melee_windup=.18,melee_recovery=.34,melee_power=.55,ranged_windup=.42,ranged_recovery=.68,ranged_power=1.25,mana_cost=7.,projectile_speed=360.,projectile_lifetime=1.5,splash=95.,knockback=100.,stagger=.2)),
}
def main():
 out=ROOT/'features/rainbow/data/weapons';out.mkdir(exist_ok=True)
 for id,(melee,ranged,special,effect,color,tuning) in DATA.items():
  p=out/(id+'.tres')
  if p.exists(): raise SystemExit('Refusing to overwrite '+str(p))
  s='[gd_resource type="Resource" script_class="RainbowWeaponDefinition" load_steps=3 format=3]\n\n'
  s+='[ext_resource type="Script" path="res://features/rainbow/weapon_definition.gd" id="1"]\n'
  s+=f'[ext_resource type="Resource" path="res://features/rainbow/data/skins/{id}.tres" id="2"]\n\n[resource]\nscript = ExtResource("1")\nlayout = ExtResource("2")\nunit_id = &"{id}"\n'
  for key,value in [('melee_name',melee),('ranged_name',ranged),('specialty',special),('effect',effect)]: s+=f'{key} = {json.dumps(value,ensure_ascii=False)}\n'
  rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)]
  s+='tint = Color(%.5f, %.5f, %.5f, 1)\n'%tuple(rgb)
  for key,value in tuning.items(): s+=f'{key} = {value}\n'
  p.write_text(s,encoding='utf-8')
 p=ROOT/'features/rainbow/data/default_action.tres'
 s='[gd_resource type="Resource" script_class="RainbowActionProfile" load_steps=14 format=3]\n\n'
 s+='[ext_resource type="Script" path="res://features/rainbow/action_profile.gd" id="1"]\n'
 s+='[ext_resource type="Script" path="res://features/rainbow/weapon_definition.gd" id="2"]\n'
 for id in DATA: s+=f'[ext_resource type="Resource" path="res://features/rainbow/data/weapons/{id}.tres" id="{id}"]\n'
 s+='\n[resource]\nscript = ExtResource("1")\nweapons = Array[ExtResource("2")](['+', '.join(f'ExtResource("{id}")' for id in DATA)+'])\n'
 p.write_text(s,encoding='utf-8')
 print('Authored 11 native action weapons')
if __name__=='__main__': main()
