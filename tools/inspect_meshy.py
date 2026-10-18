import bpy, json
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[1]
report={}
for name in ['net','club','radar','flyer','hoop','hero_rig']:
    path=root/'artifacts/monkey-meshy/raw'/f'{name}.glb'
    if not path.exists(): continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    data=[]
    for o in bpy.context.scene.objects:
        row={'name':o.name,'type':o.type}
        if o.type=='MESH':
            o.data.calc_loop_triangles()
            verts=[o.matrix_world@v.co for v in o.data.vertices]
            row.update(tris=len(o.data.loop_triangles),lo=[min(v[i] for v in verts) for i in range(3)],hi=[max(v[i] for v in verts) for i in range(3)],materials=[m.name for m in o.data.materials])
        if o.type=='ARMATURE': row['bones']=[{'name':b.name,'head':list(b.head_local),'tail':list(b.tail_local)} for b in o.data.bones]
        data.append(row)
    report[name]={'objects':data,'actions':[a.name for a in bpy.data.actions]}
    if name!='hero_rig':
        for o in bpy.context.scene.objects:
            if o.type=='MESH': o.location.x+=['net','club','radar','flyer','hoop'].index(name)*1.6
        # Individual front three-quarter inspection.
        center=Vector((['net','club','radar','flyer','hoop'].index(name)*1.6,0,0))
        bpy.ops.object.camera_add(location=center+Vector((1.6,-3,1.4)))
        camera=bpy.context.object; camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.type='ORTHO'; camera.data.ortho_scale=1.65
        bpy.context.scene.camera=camera
        bpy.ops.object.light_add(type='AREA',location=center+Vector((1,-2,3))); bpy.context.object.data.energy=350; bpy.context.object.data.shape='DISK'; bpy.context.object.data.size=4
        scene=bpy.context.scene; scene.world=bpy.data.worlds.new('World'); scene.world.color=(0.35,0.35,0.35); scene.render.engine='CYCLES'; scene.cycles.samples=16; scene.render.resolution_x=512; scene.render.resolution_y=512; scene.render.resolution_percentage=100
        scene.render.filepath=str(root/'artifacts/monkey-meshy'/f'{name}-preview.png'); bpy.ops.render.render(write_still=True)
(root/'artifacts/monkey-meshy/geometry.json').write_text(json.dumps(report,indent=2))
