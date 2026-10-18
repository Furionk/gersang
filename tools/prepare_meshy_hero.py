import bpy, math, json
from mathutils import Vector, Matrix
from pathlib import Path
root=Path(__file__).resolve().parents[1]; raw=root/'artifacts/monkey-meshy/raw'; out=root/'features/monkey/assets/meshy'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps=60
bpy.ops.import_scene.gltf(filepath=str(raw/'hero_rig.glb'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
for o in list(bpy.context.scene.objects):
    if o.type=='MESH' and not o.vertex_groups: bpy.data.objects.remove(o,do_unlink=True)
rig.animation_data_clear()
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
actions=[]
for filename,label in [('walking','Walk'),('running','Run')]:
    before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=str(raw/f'{filename}.glb'))
    imported=set(bpy.data.objects)-before
    other=next(o for o in imported if o.type=='ARMATURE')
    action=other.animation_data.action; action.name=label; action.use_fake_user=True; actions.append(action)
    for o in imported: bpy.data.objects.remove(o,do_unlink=True)
scene=bpy.context.scene; scene.render.fps=60
def reset():
    for p in rig.pose.bones: p.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
def head(name): return rig.matrix_world@rig.pose.bones[name].matrix.translation
def aim(name,child,target):
    p=rig.pose.bones[name]; m=rig.matrix_world@p.matrix
    q=(head(child)-m.translation).rotation_difference(Vector(target)-m.translation)
    rot=q.to_matrix().to_4x4(); rot.translation=m.translation-rot.to_3x3()@m.translation
    p.matrix=rig.matrix_world.inverted()@rot@m; bpy.context.view_layer.update()
def arms(side,target,elbow):
    aim(side+'Arm',side+'ForeArm',elbow); aim(side+'ForeArm',side+'Hand',target)
def curves(a):
    return list(a.fcurves) if hasattr(a,'fcurves') else [fc for l in a.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves]
# Preserve original rig orientation/scales and bake explicit full-body poses.
for label,end in [('Idle',120),('NetAttack',30),('FlyerHold',60)]:
    rig.animation_data_create(); a=bpy.data.actions.new(label); rig.animation_data.action=a
    for frame in range(1,end+2):
        scene.frame_set(frame); reset(); t=(frame-1)/end; wave=math.sin(t*math.tau)
        if label=='FlyerHold':
            for side,sign in [('Right',-1),('Left',1)]:
                arms(side,(sign*0.27,-0.04,1.39+0.01*wave),(sign*0.33,0.02,1.18))
        elif label=='NetAttack':
            # Anticipation 0-.12s, forward sweep .12-.28s, recovery through .5s.
            seconds=t*0.5; drop=max(0,min(1,(seconds-0.12)/0.16))
            height=1.42-0.63*drop
            if seconds<0.12: height=0.99+0.43*(seconds/0.12)
            if seconds>0.28: height=0.79+0.20*((seconds-0.28)/0.22)
            target=(-0.26,-0.22,height)
            arms('Right',target,(-0.32,0.02,1.15 if height>1.2 else 0.92)); arms('Left',(0.25,-0.08,0.9),(0.3,0.02,0.94))
            p=rig.pose.bones['Spine']; p.rotation_mode='XYZ'; p.rotation_euler.x+=math.radians(8)*math.sin(t*math.pi)
        else:
            arms('Right',(-0.32,-0.24,0.99+0.008*wave),(-0.34,0,0.91))
            arms('Left',(0.25,-0.02,0.78+0.008*wave),(0.3,0.02,0.87))
            p=rig.pose.bones['Head']; p.rotation_mode='XYZ'; p.rotation_euler.z+=math.radians(1)*wave
        for p in rig.pose.bones:
            p.keyframe_insert('location',frame=frame); p.keyframe_insert('scale',frame=frame)
            p.keyframe_insert('rotation_quaternion' if p.rotation_mode=='QUATERNION' else 'rotation_euler',frame=frame)
    for fc in curves(a):
        for k in fc.keyframe_points: k.interpolation='LINEAR'
    a.use_fake_user=True; actions.append(a)
rig.animation_data.action=None
for a in actions:
    track=rig.animation_data.nla_tracks.new(); track.name=a.name; track.strips.new(a.name,1,a)
for im in bpy.data.images:
    if im.size[0]>1024: im.scale(1024,1024); im.pack()
for mat in bpy.data.materials:
    if mat.use_nodes:
        bs=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        if bs: bs.inputs['Roughness'].default_value=.8
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'artifacts/monkey-meshy/hero-animated.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'hero.glb'),export_format='GLB',export_image_format='JPEG',export_jpeg_quality=88,export_animation_mode='NLA_TRACKS',export_force_sampling=True)
report={'clips':[a.name for a in actions],'bytes':(out/'hero.glb').stat().st_size,'bones':len(rig.data.bones),'triangles':sum(len(o.data.polygons) for o in scene.objects if o.type=='MESH')}
(root/'artifacts/monkey-meshy/hero-report.json').write_text(json.dumps(report,indent=2))
