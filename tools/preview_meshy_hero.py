import bpy,json
from mathutils import Vector
from pathlib import Path
root=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root/'features/monkey/assets/meshy/hero.glb'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
print('CLIPS',[(a.name,list(a.frame_range)) for a in bpy.data.actions])
for track in rig.animation_data.nla_tracks: track.mute=True
bpy.ops.object.camera_add(location=(2.5,-5,2.5)); camera=bpy.context.object; camera.rotation_euler=(Vector((0,0,.85))-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.type='ORTHO'; camera.data.ortho_scale=2.1
scene=bpy.context.scene; scene.camera=camera
bpy.ops.object.light_add(type='AREA',location=(1,-3,4)); bpy.context.object.data.energy=450; bpy.context.object.data.size=4
scene.world=bpy.data.worlds.new('World'); scene.world.color=(.4,.4,.4); scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.render.resolution_x=600; scene.render.resolution_y=600; scene.render.resolution_percentage=100
for name,frame in [('Idle',1),('NetAttack',7),('FlyerHold',1),('Walk',8)]:
    a=next(a for a in bpy.data.actions if name in a.name); rig.animation_data.action=a
    scene.frame_set(frame); scene.render.filepath=str(root/'artifacts/monkey-meshy'/f'hero-{name}.png'); bpy.ops.render.render(write_still=True)
