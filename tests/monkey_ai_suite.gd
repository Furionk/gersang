extends Node
var passed=0
var failed=0
func check(value:bool,label:String):
 if value:passed+=1
 else:failed+=1;push_error("MONKEY_AI_FAIL "+label)
func _ready():
 var g:MonkeyGarden=load("res://features/monkey/garden.tscn").instantiate();add_child(g)
 await get_tree().physics_frame;g.set_physics_process(false);g.intro=0
 var m:GardenMonkey=g.monkeys[0]
 m.position=Vector3(0,0,5);m.facing=Vector3.FORWARD;g.player.position=Vector3.ZERO;g.player.velocity=Vector3.ZERO
 m.perceive(.2);check(m.alert==1,"suspicion before confirmation")
 m.perceive(.5);check(m.alert==2,"sustained sight confirms")
 m.facing=Vector3.BACK;m.gaze_clock=.4
 check(not m.sees(g.player.position),"running gaze has a blind interval")
 m.gaze_clock=.1;check(m.sees(g.player.position),"deliberate glance reacquires visible pursuer")
 var wall=StaticBody3D.new();var cs=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(8,4,.5);cs.shape=box;wall.add_child(cs);wall.position=Vector3(0,1,2.5);g.add_child(wall)
 await get_tree().physics_frame
 var memory=m.last_seen
 g.player.position=Vector3(2,0,0);g.player.velocity=Vector3(5,0,0)
 m.facing=Vector3.FORWARD;m.perceive(1.1)
 check(m.alert==2,"lost sight does not immediately cancel escape")
 check(m.last_seen==memory,"occlusion preserves last observation")
 m.perceive(3.0);check(m.alert==0,"search expires without wall tracking")
 m.alert=0;m.suspicion=0;m.hearing_clock=0;m.perceive(.1)
 check(m.alert==0,"wall blocks hearing confirmation and location leak")
 wall.queue_free();await get_tree().physics_frame
 m.position=Vector3(0,0,5);m.facing=Vector3.FORWARD;g.player.position=Vector3(0,0,8);g.sneaking=true
 m.perceive(.1);check(m.alert==0,"sneaking behind is quiet")
 g.sneaking=false;m.perceive(.1);check(m.alert==1,"running behind triggers investigation only")
 m.alert=2;m.suspicion=g.profile.confirmation_seconds;m.last_seen=Vector3.ZERO;m.position=Vector3(0,0,5);m.facing=Vector3.FORWARD;g.player.position=Vector3.ZERO
 m.decision_left=0;m.burst_cooldown_left=0;m.tick(.1)
 check(m.burst_left>0 and m.burst_cooldown_left>m.burst_left,"burst cannot chain continuously")
 m.tick(.5);check(m.burst_left==0 and m.recovery_left>0,"burst has catchable recovery")
 g.profile=g.profile.duplicate();g.profile.dodge_chance=1
 m.dodge_cooldown=0;m.dodge_pending=-1;m.last_seen=g.player.position;m.position=Vector3(0,0,2);g.gadget=1;g.swing=.01
 m.tick_dodge(.016,true);check(m.dodge_pending>0,"net dodge has reaction delay")
 m.stun();check(m.dodge_pending<0 and m.attack_clock==0,"stun cancels pending dodge and pounce")
 var counter:GardenMonkey=g.monkeys[2];counter.position=Vector3(0,0,3);counter.last_seen=Vector3.ZERO;counter.tick_attack(.61)
 var committed=counter.attack_direction;g.player.position=Vector3(4,0,0);counter.alert=1;counter.tick(.1)
 check(counter.attack_clock>.7 and counter.attack_direction==committed,"pounce commits to telegraphed direction")
 counter.tick_attack(.9);check(counter.attack_clock==0 and counter.attack_cooldown>0,"pounce finishes with recovery cooldown")
 m.stunned=0;m.alert=2;m.last_seen=Vector3.ZERO;m.observed_velocity=Vector3.ZERO;m.position=Vector3(0,0,5)
 var destination=m.choose_escape();check(g.layout.activity_bounds.has_point(destination) and g.layout.damage_at(destination)==0,"escape destination stays in safe activity area")
 g.queue_free();await get_tree().process_frame
 print("MONKEY_AI_RESULT passed=",passed," failed=",failed);get_tree().quit(1 if failed else 0)
