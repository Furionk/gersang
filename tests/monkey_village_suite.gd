extends Node
var failures=0
func check(ok,label):
 if not ok: failures+=1;push_error("VILLAGE_FAIL "+label)
func _ready():
 for zone in ["easy","hard","mania","despair"]:
  var arena=load("res://features/monkey/village_"+zone+".tscn").instantiate();add_child(arena)
  for i in 120:await get_tree().physics_frame
  var map=arena.get_world_3d().navigation_map
  check(NavigationServer3D.map_get_iteration_id(map)>0,zone+" nav synchronized")
  for m in arena.monkeys:
   var ray=PhysicsRayQueryParameters3D.create(m.home+Vector3.UP*0.3,m.home-Vector3.UP,1)
   var hit=arena.get_world_3d().direct_space_state.intersect_ray(ray)
   check(not hit.is_empty(),zone+" home supported "+str(m.kind))
   if m.kind!=3:
    var route=NavigationServer3D.map_get_path(map,arena.safe_point,m.home,true)
    check(not route.is_empty() and route[-1].distance_to(m.home)<0.8,zone+" home connected "+str(m.kind))
   else:
    for target in m.path_points:
     var previous=m.home+Vector3.UP*0.7
     var clear=true
     for j in range(1,25):
      var t=j/24.0;var point=m.home.lerp(target,t)+Vector3.UP*(sin(t*PI)*2+0.7)
      if not arena.clear_line(previous,point):clear=false
      previous=point
     check(clear,zone+" high arc clear "+str(target))
  check(arena.layout.damage_at(arena.safe_point)==0,zone+" safe spawn")
  # The decorative road island overlaps the supporting terrain here.
  # Test actual capsule motion: navigation connectivity alone missed the trap.
  arena.intro=0;arena.drag_camera=true;arena.resume_game()
  arena.player.position=Vector3(3.842701,-0.3161,-8.010018)
  arena.yaw=0;arena.keys[KEY_W]=true
  var start:Vector3=arena.player.position
  for i in 20:await get_tree().physics_frame
  check(arena.player.position.distance_to(start)>0.5,zone+" overlapping road escape")
  check(arena.hp==100,zone+" road escape keeps health")
  arena.pause_game()
  arena.queue_free();await get_tree().process_frame
 print("VILLAGE_RESULT failed=",failures);get_tree().quit(failures)
