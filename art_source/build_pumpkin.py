"""Author the pumpkin car in Blender; no geometry is built by the game at runtime.
Run: blender --background --factory-startup --python art_source/build_pumpkin.py
The saved .blend is the editable master. Generated files stay inside this project.
"""
from pathlib import Path
import math
import json
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'models' / 'pumpkin'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = Path(__file__).resolve().parent
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for block in list(bpy.data.materials):
    bpy.data.materials.remove(block)
scene = bpy.context.scene
scene.render.fps = 60
scene.frame_start = 1
scene.frame_end = 49
scene.unit_settings.system = 'METRIC'


def linear(v):
    return v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4


def mat(name, hex_color, rough=.42, metallic=0, glow=0):
    rgb = tuple(linear(int(hex_color[i:i + 2], 16) / 255) for i in (0, 2, 4))
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*rgb, 1)
    material.use_nodes = True
    p = next(n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metallic
    if 'Coat Weight' in p.inputs:
        p.inputs['Coat Weight'].default_value = .18
        p.inputs['Coat Roughness'].default_value = .3
    if glow:
        p.inputs['Emission Color'].default_value = (*rgb, 1)
        p.inputs['Emission Strength'].default_value = glow
    return material


orange = mat('Pumpkin - warm tangerine', 'ED732C', .50)
gold = mat('Pumpkin - cut flesh', 'FFBC59', .4)
dark = mat('Mouth - plum velvet', '301D35', .82)
purple = mat('Chassis - blackberry', '553764', .38)
rubber = mat('Tyres - soft mulberry', '714878', .5)
bronze = mat('Metal - antique rose gold', 'BC805B', .36, .32)
hub = mat('Wheels - apricot', 'F6AE50', .38)
green = mat('Leaves - sage', '8EAA69', .55)
vein = mat('Leaves - pale veins', 'B0C97E', .55)
stem_mat = mat('Stem - cinnamon', '885756', .53)
eye = mat('Eyes - candlelight', 'FFE5A1', .4, glow=.7)
glass = mat('Lantern - warm glass', 'FFD282', .26, glow=1.2)
pink = mat('Candy - raspberry', 'F27CB8', .32)
mint = mat('Candy - mint', '80D9C3', .35)
cream = mat('Candy - cream', 'FFEBC8', .38)


def empty(name, loc=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = loc
    obj.empty_display_size = .12
    return obj


root = empty('PumpkinArt')
body = empty('BodyDeform', parent=root)
vine_root = empty('Vines', (0, .05, 1.62), body)
jaw = empty('Jaw', (0, -.12, .64), body)


def finish(obj, name, material, parent, smooth=True):
    obj.name = name
    if material:
        obj.data.materials.append(material)
    if smooth and obj.type == 'MESH':
        for poly in obj.data.polygons:
            poly.use_smooth = True
    obj.parent = parent
    return obj


def sphere(name, loc, scale, material, parent=body, seg=32, rings=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, material, parent)


def cube(name, loc, scale, material, parent=body, bevel=.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new('Soft edges', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 3
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        weighted = obj.modifiers.new('Corner normals', 'WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=weighted.name)
    return finish(obj, name, material, parent)


def tube(name, points, radius, material, parent=body, resolution=4):
    data = bpy.data.curves.new(name, 'CURVE')
    data.dimensions = '3D'
    data.resolution_u = 10
    data.bevel_depth = radius
    data.bevel_resolution = resolution
    sp = data.splines.new('BEZIER')
    sp.bezier_points.add(len(points) - 1)
    for bp, point in zip(sp.bezier_points, points):
        bp.co = point[:3]
        bp.radius = point[3] if len(point) == 4 else 1
        bp.handle_left_type = bp.handle_right_type = 'AUTO'
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    return finish(obj, name, material, parent, False)


def mesh(name, vertices, faces, material, parent=body):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    return finish(obj, name, material, parent)


def difference(obj, cutter):
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new('Carve', 'BOOLEAN')
    mod.operation = 'DIFFERENCE'
    mod.solver = 'EXACT'
    mod.object = cutter
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def prism(name, points, front, back):
    # Points describe an x/z polygon viewed from the front (-Y).
    n = len(points)
    vertices = [(x, y, z) for y in (front, back) for x, z in points]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    obj = mesh(name, vertices, faces, None, None)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.select_set(False)
    return obj


# A continuous lobed shell, hollowed before the mouth and eye openings are cut.
vertices, faces = [], []
segments, rings = 96, 56
for j in range(rings + 1):
    phi = math.pi * (.001 + .998 * j / rings)
    for i in range(segments):
        theta = 2 * math.pi * i / segments
        lobe = 1 + .055 * math.cos(10 * theta)
        r = math.sin(phi) ** .86 * lobe
        vertices.append((.87 * r * math.cos(theta), .77 * r * math.sin(theta), .99 + .75 * math.cos(phi)))
for j in range(rings):
    for i in range(segments):
        a = j * segments + i
        b = j * segments + (i + 1) % segments
        faces.append((a, b, b + segments, a + segments))
faces.extend([tuple(range(segments - 1, -1, -1)), tuple(rings * segments + i for i in range(segments))])
shell = mesh('CarvedShell', vertices, faces, orange)
# Match surface winding before exact boolean operations.
bpy.context.view_layer.objects.active = shell
shell.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode='OBJECT')
shell.select_set(False)
inner = sphere('CavityCutter', (0, 0, 1), (.735, .64, .615), None, None, 64, 40)
difference(shell, inner)
mouth_outline = [(-.69, .79), (-.64, 1.1), (-.50, 1.27), (-.35, 1.31),
                 (-.30, 1.19), (-.14, 1.18), (-.13, 1.32), (.12, 1.32),
                 (.18, 1.17), (.33, 1.18), (.37, 1.30), (.53, 1.23),
                 (.65, 1.07), (.68, .80), (.54, .57), (.26, .49),
                 (-.25, .49), (-.54, .58)]
difference(shell, prism('MouthCutter', mouth_outline, -1.2, -.16))
skin_surface = BVHTree.FromObject(shell, bpy.context.evaluated_depsgraph_get())
for sign in (-1, 1):
    shape = [(sign * .18, 1.51), (sign * .53, 1.55), (sign * .47, 1.37), (sign * .27, 1.39)]
    difference(shell, prism('EyeCutter', shape, -1.1, .20))
    # Inset luminous eyes; the surrounding cut exposes the thickness of the rind.
    center_x = sum(p[0] for p in shape) / len(shape)
    center_z = sum(p[1] for p in shape) / len(shape)
    outline = []
    for i in range(len(shape)):
        a, b = shape[i], shape[(i + 1) % len(shape)]
        for step in range(8):
            t = step / 8
            outline.append((center_x + ((1-t)*a[0] + t*b[0] - center_x) * 1.10,
                            center_z + ((1-t)*a[1] + t*b[1] - center_z) * 1.10))
    eye_vertices, eye_faces = [], []
    for ring in range(5):
        t = .001 + .999 * ring / 4
        for x, z in outline:
            px, pz = center_x + (x-center_x)*t, center_z + (z-center_z)*t
            hit, _, _, _ = skin_surface.ray_cast(Vector((px, -2, pz)), Vector((0, 1, 0)))
            eye_vertices.append((px, hit.y + .045 if hit is not None else -.3, pz))
    for ring in range(4):
        for i in range(len(outline)):
            a = ring * len(outline) + i
            b = ring * len(outline) + (i + 1) % len(outline)
            eye_faces.append((a, b, b + len(outline), a + len(outline)))
    obj = mesh('EyeGlowL' if sign < 0 else 'EyeGlowR', eye_vertices, eye_faces, eye)
    # Both views of this thin inset are valid; export also keeps it two-sided.
    eye.use_backface_culling = False
bevel = shell.modifiers.new('Rounded carved edges', 'BEVEL')
bevel.width = .018
bevel.segments = 2
bpy.context.view_layer.objects.active = shell
bpy.ops.object.modifier_apply(modifier=bevel.name)

# Recessed mouth is a real cavity: dark rear wall, lower tongue and separate jaw.
sphere('MouthInterior', (0, .05, .88), (.70, .48, .40), dark)
sphere('Tongue', (0, -.31, .065), (.39, .24, .045), pink, jaw)
# Jaw parts use hinge-local coordinates, below the mouth opening.
sphere('LowerLip', (0, -.49, -.055), (.64, .29, .13), orange, jaw)
sphere('CutRind', (0, -.50, .015), (.55, .23, .045), gold, jaw)
for x in (-.35, .29):
    tooth = cube('LowerTooth', (x, -.62, .11), (.15, .13, .19), gold, jaw, .035)
    tooth.rotation_euler.y = -.13 if x < 0 else .12

# Raised cheeks and tiny nose make the face friendly rather than frightening.
for sign in (-1, 1):
    sphere('Cheek', (sign * .69, -.40, .94), (.12, .075, .075), orange)
nose = prism('Nose', [(-.055, 1.385), (0, 1.425), (.055, 1.385)], -.76, -.72)
nose.data.materials.append(stem_mat)
nose.parent = body

cube('Chassis', (0, .015, .255), (1.52, 1.26, .20), purple, root, .10)
tube('FrontBumper', [(-.68, -.60, .29), (-.4, -.76, .25), (0, -.80, .25), (.4, -.76, .25), (.68, -.60, .29)], .07, purple, root)
tube('BumperGoldInlay', [(-.58, -.67, .29), (0, -.807, .29), (.58, -.67, .29)], .012, bronze, root, 2)


def cylinder(name, loc, radius, depth, material, parent, axis='X', vertices=40):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    if axis == 'X':
        obj.rotation_euler.y = math.pi / 2
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    bevel = obj.modifiers.new('Rounded rim', 'BEVEL')
    bevel.width = .025
    bevel.segments = 3
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return finish(obj, name, material, parent)


for side, side_name in ((-1, 'L'), (1, 'R')):
    for y, end in ((-.47, 'F'), (.48, 'B')):
        w = empty('Wheel' + end + side_name, (side * .79, y, .245), root)
        cylinder('Tyre', (0, 0, 0), .245, .17, rubber, w)
        cylinder('WheelRim', (side * .092, 0, 0), .193, .026, bronze, w)
        cylinder('WheelFace', (side * .112, 0, 0), .171, .018, hub, w)
        for n in range(7):
            a = n * 2 * math.pi / 7
            petal = sphere('PetalSpoke', (side * .13, .101 * math.sin(a), .101 * math.cos(a)), (.018, .047, .069), gold, w, 16, 10)
            petal.rotation_euler.x = -a
        sphere('HubCap', (side * .145, 0, 0), (.045, .063, .063), bronze, w, 20, 12)


def leaf(name, start, direction, length, width, parent=vine_root):
    origin = Vector(start)
    along = Vector(direction).normalized()
    side = along.cross(Vector((0, 0, 1))).normalized()
    if side.length < .1:
        side = Vector((1, 0, 0))
    verts, fs = [], []
    for j in range(9):
        t = j / 8
        center = origin + along * length * t + Vector((0, 0, math.sin(math.pi * t) * .075))
        for k in (-1, 0, 1):
            p = center + side * width * math.sin(math.pi * t) * k
            p.z -= abs(k) * .028 * math.sin(math.pi * t)
            verts.append(tuple(p))
    for j in range(8):
        for k in range(2):
            a = j * 3 + k
            fs.append((a, a + 1, a + 4, a + 3))
    obj = mesh(name, verts, fs, green, parent)
    mod = obj.modifiers.new('Leaf thickness', 'SOLIDIFY')
    mod.thickness = .014
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    tube(name + 'Vein', [tuple(origin), tuple(origin + along * length * .48 + Vector((0, 0, .085))), tuple(origin + along * length * .94 + Vector((0, 0, .02)))], .009, vein, parent, 2)


# Curled stems and a suspended lantern follow the concept silhouette.
tube('MainStem', [(0, 0, -.02, 1.5), (-.1, .02, .21, 1.3), (-.32, .04, .51, 1), (-.56, .02, .60, .8), (-.68, -.01, .43, .65), (-.54, -.04, .34, .50), (-.45, -.03, .42, .18)], .065, stem_mat, vine_root)
tube('LanternStem', [(.08, .10, .02, 1.3), (.24, .14, .35, 1), (.51, .08, .48, .8), (.72, .01, .36, .65), (.69, -.03, .23, .4)], .055, stem_mat, vine_root)
for i, (direction, length) in enumerate([((-.8, -.5, .15), .40), ((.7, -.8, .12), .38), ((.4, .7, .2), .37)]):
    leaf('CrownLeaf' + str(i), (0, 0, .02), direction, length, .115)
for sign in (-1, 1):
    tube('SideVine', [(sign * .69, .2, .67), (sign * .84, .15, .88), (sign * .91, .02, 1.0), (sign * .80, -.03, 1.09), (sign * .73, .01, 1.01)], .035, green)
    leaf('SideLeaf', (sign * .73, .29, .80), (sign * .3, .8, .4), .32, .09, body)

lantern = empty('LanternSwing', (.69, -.03, .22), vine_root)
tube('LanternLoop', [(-.045, 0, -.06), (-.04, 0, .015), (0, 0, .045), (.04, 0, .015), (.045, 0, -.06)], .012, bronze, lantern, 2)
cube('LanternGlass', (0, 0, -.22), (.18, .15, .24), glass, lantern, .025)
cube('LanternBase', (0, 0, -.35), (.24, .21, .05), bronze, lantern, .018)
cube('LanternCap', (0, 0, -.085), (.25, .22, .055), bronze, lantern, .018)
roof = sphere('LanternRoof', (0, 0, -.07), (.14, .12, .065), purple, lantern, 24, 12)
for x in (-.10, .10):
    for y in (-.085, .085):
        cube('LanternFrame', (x, y, -.22), (.022, .022, .25), bronze, lantern, .006)

# Small wrapped sweets rest inside the mouth, not on a flat painted decal.
for index, (x, y, z, material) in enumerate([(-.31, -.47, .12, mint), (.0, -.48, .14, pink), (.30, -.45, .12, gold)]):
    candy = sphere('MouthCandy' + str(index), (x, y, z), (.105, .09, .085), material, jaw, 24, 14)
    for sign in (-1, 1):
        wrap = sphere('CandyWrapper', (x + sign * .135, y, z), (.055, .07, .055), material, jaw, 16, 10)
        wrap.rotation_euler.y = sign * .3

# One common track name exports the independently authored parts as one GLB clip.
def clip(obj, name, properties):
    obj.animation_data_create()
    obj.animation_data.action = None
    action = bpy.data.actions.new(obj.name + '_' + name)
    obj.animation_data.action = action
    for path, keys in properties.items():
        for frame, value in keys:
            setattr(obj, path, value)
            obj.keyframe_insert(data_path=path, frame=frame, group=obj.name)
    track = obj.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, action)
    strip.name = name
    obj.animation_data.action = None
    return action


clip(jaw, 'swallow', {'rotation_euler': [(1, (0, 0, 0)), (9, (.48, 0, 0)), (26, (.48, 0, 0)), (34, (-.72, 0, 0)), (41, (.08, 0, 0)), (49, (0, 0, 0))]})
clip(body, 'swallow', {'scale': [(1, (1, 1, 1)), (9, (1.035, .98, 1.035)), (26, (1.02, 1, 1.02)), (34, (1.10, 1.06, .94)), (41, (.98, .99, 1.04)), (49, (1, 1, 1))]})
clip(vine_root, 'swallow', {'rotation_euler': [(1, (0, 0, 0)), (10, (-.07, .04, 0)), (26, (.05, -.02, 0)), (35, (-.12, .05, 0)), (42, (.06, -.02, 0)), (49, (0, 0, 0))]})
clip(lantern, 'swallow', {'rotation_euler': [(1, (0, 0, 0)), (12, (.1, .1, 0)), (28, (-.13, -.08, 0)), (37, (.18, .10, 0)), (44, (-.1, -.05, 0)), (49, (0, 0, 0))]})
for obj in (jaw, body, vine_root, lantern):
    clip(obj, 'RESET', {'rotation_euler': [(1, (0, 0, 0))], 'scale': [(1, (1, 1, 1))]})

def consolidate_export_meshes():
    # Only the export copy is merged; the saved .blend keeps every authored part.
    for parent in (body, jaw, vine_root, lantern, root):
        objs = [o for o in list(parent.children) if o.type in ('MESH', 'CURVE')]
        if not objs:
            continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.convert(target='MESH')
        bpy.ops.object.join()
        bpy.context.object.name = parent.name + 'Mesh'
    for w in [o for o in list(root.children) if o.name.startswith('Wheel')]:
        objs = [o for o in w.children if o.type == 'MESH']
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objs:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.join()
        bpy.context.object.name = w.name + 'Mesh'

# Scale the authored model to the existing base vehicle footprint (metres).
root.scale = (.82, .82, .82)
scene.frame_set(1)
for obj in (jaw, body, vine_root, lantern):
    for track in obj.animation_data.nla_tracks:
        track.mute = track.name == 'RESET'

# A small studio, excluded from the game export, is saved in the source .blend.
studio = bpy.data.collections.new('Studio - excluded from GLB')
scene.collection.children.link(studio)
def studio_link(obj):
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    studio.objects.link(obj)

floor_mat = mat('Studio - lavender charcoal', '35283F', .75)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.025))
floor = bpy.context.object
floor.name = 'StudioFloor'
floor.data.materials.append(floor_mat)
studio_link(floor)
bpy.ops.object.camera_add(location=(3.7, -6.6, 3.25))
camera = bpy.context.object
camera.name = 'StudioCamera'
camera.rotation_euler = (Vector((0, 0, .90)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 3.45
scene.camera = camera
studio_link(camera)
for name, loc, energy, size, color in [('Key', (-3, -4, 6), 550, 4, (1, .82, .68)), ('Fill', (4, -2, 3), 360, 3, (.67, .72, 1)), ('Rim', (1, 3, 4), 750, 3, (.92, .6, 1))]:
    data = bpy.data.lights.new(name, 'AREA')
    data.energy = energy
    data.shape = 'DISK'
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    studio.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = (Vector((0, 0, .8)) - obj.location).to_track_quat('-Z', 'Y').to_euler()
scene.world.color = (.12, .12, .12)
scene.render.engine = 'CYCLES'
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x = 1200
scene.render.resolution_y = 1100
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'AgX'
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = str(SOURCE / 'pumpkin_blender.png')

def descendants(obj):
    return [obj] + [child for c in obj.children for child in descendants(c)]

bpy.ops.object.select_all(action='DESELECT')
for obj in descendants(root):
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.region_3d.view_perspective = 'CAMERA'
            area.spaces.active.shading.type = 'MATERIAL'
source_objects = len(descendants(root))
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'pumpkin.blend'))
consolidate_export_meshes()
bpy.ops.object.select_all(action='DESELECT')
for obj in descendants(root):
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
for obj in (jaw, body, vine_root, lantern):
    for track in obj.animation_data.nla_tracks:
        track.mute = False
export_options = dict(filepath=str(OUT / 'pumpkin.glb'), export_format='GLB', use_selection=True,
                      export_animations=True, export_animation_mode='NLA_TRACKS', export_apply=True,
                      export_frame_range=False, export_force_sampling=True)
bpy.ops.export_scene.gltf(**export_options)
for obj in (jaw, body, vine_root, lantern):
    for track in obj.animation_data.nla_tracks:
        track.mute = track.name == 'RESET'
scene.frame_set(1)
stats = {'source_objects': source_objects, 'objects': len(descendants(root)), 'vertices': sum(len(o.data.vertices) for o in descendants(root) if o.type == 'MESH'),
         'triangles': sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in descendants(root) if o.type == 'MESH'),
         'glb_clips': ['swallow'], 'godot_clips': ['RESET', 'swallow'], 'swallow_seconds': .816667, 'blender': bpy.app.version_string}
(OUT / 'model_info.json').write_text(json.dumps(stats, indent=2), encoding='utf-8')
print('PUMPKIN_ASSET', json.dumps(stats))
if '--render' in __import__('sys').argv:
    bpy.ops.render.render(write_still=True)
