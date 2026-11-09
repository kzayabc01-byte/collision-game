"""Blender authoring helpers. Executed offline only; all parts are saved in .blend."""
from pathlib import Path
import math, json
import bpy, bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]


def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for mat in list(bpy.data.materials):
        if mat.users == 0:
            bpy.data.materials.remove(mat)
    bpy.context.scene.render.fps = 60
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 181
    bpy.context.scene.unit_settings.system = 'METRIC'


def material(name, color, rough=.44, metal=0., glow=0., coat=.2):
    def linear(v):
        return v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4
    rgb = tuple(linear(int(color[i:i+2], 16) / 255) for i in (0, 2, 4))
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    for key, val in [('Base Color', (*rgb, 1)), ('Roughness', rough), ('Metallic', metal), ('Coat Weight', coat), ('Coat Roughness', .25)]:
        shader.inputs[key].default_value = val
    if glow:
        shader.inputs['Emission Color'].default_value = (*rgb, 1)
        shader.inputs['Emission Strength'].default_value = glow
    return mat


def empty(name, loc=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(o)
    o.parent = parent
    o.location = loc
    o.empty_display_size = .10
    return o


def finish(obj, name, mat, parent, smooth=True):
    obj.name = name
    obj.parent = parent
    if mat:
        obj.data.materials.append(mat)
    if smooth and obj.type == 'MESH':
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def sphere(name, loc, scale, mat, parent=None, segments=28, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, parent)


def cube(name, loc, scale, mat, parent=None, bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new('Soft corners', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod = obj.modifiers.new('Face normals', 'WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, name, mat, parent)


def mesh(name, vertices, faces, mat, parent=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    o = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(o)
    return finish(o, name, mat, parent)


def tube(name, points, radius, mat, parent=None, resolution=3):
    data = bpy.data.curves.new(name, 'CURVE')
    data.dimensions = '3D'
    data.resolution_u = 8
    data.bevel_depth = radius
    data.bevel_resolution = resolution
    sp = data.splines.new('BEZIER')
    sp.bezier_points.add(len(points)-1)
    for b, p in zip(sp.bezier_points, points):
        b.co = p[:3]
        b.radius = p[3] if len(p) == 4 else 1
        b.handle_left_type = b.handle_right_type = 'AUTO'
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    return finish(obj, name, mat, parent, False)


def cylinder(name, loc, radius, depth, mat, parent=None, axis='X'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    if axis == 'X':
        obj.rotation_euler.y = math.pi/2
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    mod = obj.modifiers.new('Rounded rim', 'BEVEL')
    mod.width = .018
    mod.segments = 3
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, name, mat, parent)


def star(name, loc, radius, mat, parent=None, depth=.022):
    pts = []
    for i in range(10):
        a = math.pi/2 + i*math.pi/5
        r = radius if i % 2 == 0 else radius*.46
        pts.append((math.cos(a)*r, math.sin(a)*r))
    vertices = [(x, y, z) for y in (-depth, depth) for x, z in pts]
    faces = [tuple(range(9, -1, -1)), tuple(range(10, 20))]
    faces.extend((i, (i+1)%10, (i+1)%10+10, i+10) for i in range(10))
    obj = mesh(name, vertices, faces, mat, parent)
    obj.location = loc
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new('Soft star edge', 'BEVEL')
    mod.width = radius*.09
    mod.segments = 2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def lantern(name, loc, mat_frame, mat_glass, mat_roof, parent, scale=1.):
    pivot = empty(name, loc, parent)
    pivot.scale = (scale,)*3
    tube(name+'Loop', [(-.045,0,-.06), (-.04,0,.015), (0,0,.045), (.04,0,.015), (.045,0,-.06)], .012, mat_frame, pivot)
    cube(name+'Glass', (0,0,-.22), (.18,.15,.24), mat_glass, pivot, .025)
    cube(name+'Base', (0,0,-.35), (.24,.21,.05), mat_frame, pivot, .018)
    cube(name+'Cap', (0,0,-.085), (.25,.22,.055), mat_frame, pivot, .018)
    sphere(name+'Roof', (0,0,-.07), (.14,.12,.065), mat_roof, pivot)
    for x in (-.10,.10):
        for y in (-.085,.085):
            cube(name+'Frame', (x,y,-.22), (.022,.022,.25), mat_frame, pivot, .005)
    return pivot


def clip(obj, name, props):
    obj.animation_data_create()
    obj.animation_data.action = bpy.data.actions.new(obj.name+'_'+name)
    action = obj.animation_data.action
    for path, keys in props.items():
        for frame, value in keys:
            setattr(obj, path, value)
            obj.keyframe_insert(data_path=path, frame=frame)
    track = obj.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, action)
    obj.animation_data.action = None
    track.mute = True


def shape_clip(obj, name, key_name, keys):
    data = obj.data.shape_keys
    data.animation_data_create()
    data.animation_data.action = bpy.data.actions.new(name+'_shape')
    key = data.key_blocks[key_name]
    for frame, value in keys:
        key.value = value
        key.keyframe_insert(data_path='value', frame=frame)
    track = data.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, data.animation_data.action)
    data.animation_data.action = None
    track.mute = True
    key.value = 0


def descendants(obj):
    return [obj] + list(obj.children_recursive)


def finish_asset(name, root, merge_parents, camera_target=.95, ortho=3.5):
    scene = bpy.context.scene
    scene.frame_set(1)
    model_objects = descendants(root)
    for obj in model_objects:
        for data in (obj, obj.data.shape_keys if obj.type == 'MESH' else None):
            if data is not None and data.animation_data:
                for track in data.animation_data.nla_tracks:
                    track.mute = True
    studio = bpy.data.collections.new('Studio - excluded from GLB')
    scene.collection.children.link(studio)
    def studio_link(obj):
        for c in list(obj.users_collection):
            c.objects.unlink(obj)
        studio.objects.link(obj)
    floor_mat = material('Studio lavender', '35283F', .8)
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.025))
    floor = bpy.context.object
    floor.data.materials.append(floor_mat)
    studio_link(floor)
    bpy.ops.object.camera_add(location=(3.8,-6.7,3.4))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0,0,camera_target))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = ortho
    scene.camera = camera
    studio_link(camera)
    for label, loc, power, color in [('Key',(-3,-4,6),550,(1,.84,.73)),('Fill',(4,-2,3),360,(.70,.74,1)),('Rim',(1,3,4),750,(.92,.65,1))]:
        data = bpy.data.lights.new(label,'AREA')
        data.energy = power
        data.shape = 'DISK'
        data.size = 4
        data.color = color
        o = bpy.data.objects.new(label,data)
        studio.objects.link(o)
        o.location = loc
        o.rotation_euler = (Vector((0,0,.9))-o.location).to_track_quat('-Z','Y').to_euler()
    scene.world.color = (.12,.12,.12)
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 1100
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = 'AgX'
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = str(ROOT / 'art_source' / (name+'_blender.png'))
    bpy.ops.object.select_all(action='DESELECT')
    for o in model_objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == 'VIEW_3D':
                area.spaces.active.region_3d.view_perspective = 'CAMERA'
                area.spaces.active.shading.type = 'MATERIAL'
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source'/(name+'.blend')))
    source_count = len(model_objects)
    # The saved master keeps parts; only this disposable export copy is joined.
    for parent in merge_parents:
        objects = [o for o in parent.children if o.type in ('MESH','CURVE') and not (o.type=='MESH' and o.data.shape_keys)]
        if len(objects) < 2:
            continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.convert(target='MESH')
        bpy.ops.object.join()
        bpy.context.object.name = parent.name+'Mesh'
    model_objects = descendants(root)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in model_objects:
        obj.select_set(True)
        for data in (obj, obj.data.shape_keys if obj.type=='MESH' else None):
            if data is not None and data.animation_data:
                for track in data.animation_data.nla_tracks:
                    track.mute = False
    bpy.context.view_layer.objects.active = root
    out = ROOT/'assets'/'models'/name
    out.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',use_selection=True,
                             export_animations=True,export_animation_mode='NLA_TRACKS',export_apply=False,
                             export_frame_range=False,export_force_sampling=True)
    for obj in model_objects:
        for data in (obj,obj.data.shape_keys if obj.type=='MESH' else None):
            if data is not None and data.animation_data:
                for track in data.animation_data.nla_tracks:
                    track.mute = True
    scene.frame_set(1)
    stats={'source_objects':source_count,'export_objects':len(model_objects),
           'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in model_objects if o.type=='MESH'),
           'blender':bpy.app.version_string}
    (out/'model_info.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
    print('ASSET',name,json.dumps(stats))
    if '--render' in __import__('sys').argv:
        bpy.ops.render.render(write_still=True)
