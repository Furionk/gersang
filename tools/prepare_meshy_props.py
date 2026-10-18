import bpy, bmesh, math, json
from pathlib import Path
from mathutils import Vector, Matrix
root=Path(__file__).resolve().parents[1]
out=root/'features/monkey/assets/meshy'
report=[]
for name in ['net','club','radar','flyer','hoop']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(root/'artifacts/monkey-meshy/raw'/f'{name}.glb'))
    obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    obj.name=name.title()
    bpy.context.view_layer.objects.active=obj; obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # Author in Blender Z-up; GLB conversion produces Godot Y-up.
    # Handheld shafts point along Blender +Y (Godot -Z).
    if name=='net':
        bag=bpy.data.materials.new('NetWeave'); bag.diffuse_color=(0.02,0.7,0.9,1); obj.data.materials.append(bag)
        for p in obj.data.polygons:
            center=sum((obj.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
            if center.z < 0.17 and center.y>-0.1: p.material_index=1
        for v in obj.data.vertices: v.co=(v.co-Vector((0,-0.36,0.23)))*1.65
    elif name=='club':
        for v in obj.data.vertices:
            p=v.co-Vector((0.33,0,0)); v.co=Vector((p.y,-p.x,p.z))*1.2
    elif name=='radar':
        for v in obj.data.vertices: v.co=(v.co-Vector((0,0,-0.32)))*0.7
    elif name=='flyer':
        # Separate rotor faces at its neck; body and grips remain stationary.
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='DESELECT'); bpy.ops.object.mode_set(mode='OBJECT')
        for p in obj.data.polygons:
            center=sum((obj.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
            p.select=center.z>0.12
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.separate(type='SELECTED'); bpy.ops.object.mode_set(mode='OBJECT')
        for o in list(bpy.context.scene.objects):
            if o.type!='MESH': continue
            o.name='Rotor' if o!=obj else 'FlyerBody'
            for v in o.data.vertices: v.co*=1.8
    elif name=='hoop':
        for v in obj.data.vertices: v.co*=1.65
    for im in bpy.data.images:
        if im.size[0]>512: im.scale(512,512); im.pack()
    for mat in bpy.data.materials:
        if mat.use_nodes:
            bs=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
            if bs: bs.inputs['Roughness'].default_value=0.65; bs.inputs['Metallic'].default_value=0.05
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for o in meshes: o.data.calc_loop_triangles()
    bpy.ops.wm.save_as_mainfile(filepath=str(root/'artifacts/monkey-meshy'/f'{name}.blend'))
    bpy.ops.export_scene.gltf(filepath=str(out/f'{name}.glb'),export_format='GLB',export_image_format='JPEG',export_jpeg_quality=85,export_animations=False)
    report.append({'asset':name,'triangles':sum(len(o.data.loop_triangles) for o in meshes),'texture_size':512,'bytes':(out/f'{name}.glb').stat().st_size})
(root/'artifacts/monkey-meshy/props-report.json').write_text(json.dumps(report,indent=2))
