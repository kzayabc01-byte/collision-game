"""Offline authoring: editable silhouette SVG/data PNG and static Godot scatter.

Run with Python + Pillow. It never edits gameplay, cameras or collision.
The generated .tscn contains ordinary PackedScene instances, not runtime spawning.
"""
from pathlib import Path
import json
import math
import random
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art_source/wasteland'
GROUND = ROOT / 'assets/ground'
SCENES = ROOT / 'scenes/maps/arena/ground'
SEED = 111027
WIDTH, HEIGHT, PPM = 2480, 1960, 20


def make_mask():
    rng = random.Random(SEED)
    image = Image.new('L', (WIDTH, HEIGHT), 0)
    draw = ImageDraw.Draw(image)
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">',
           '<rect width="100%" height="100%" fill="black"/>',
           '<defs><filter id="soft"><feGaussianBlur stdDeviation="0.85"/></filter></defs>', '<g filter="url(#soft)">']

    def blade(base, tip, width, shade):
        dx, dy = tip[0] - base[0], tip[1] - base[1]
        length = math.hypot(dx, dy)
        nx, ny = -dy / length, dx / length
        points = []
        # Rounded leaf tip and narrow base, rather than triangles or circles.
        for side in (1, -1):
            for k in range(15):
                t = k / 14 if side == 1 else 1 - k / 14
                radius = width * math.sin(math.pi * t) ** .7
                points.append(((base[0] + dx * t + nx * radius * side + 62) * PPM,
                               (base[1] + dy * t + ny * radius * side + 49) * PPM))
        draw.polygon(points, fill=shade)
        svg.append('<polygon fill="rgb(%d,%d,%d)" points="%s"/>' %
                   (shade, shade, shade, ' '.join('%.2f,%.2f' % p for p in points)))

    def tuft(x, z, scale, shade):
        angle = rng.uniform(-math.pi, math.pi)
        for i in range(rng.randint(5, 9)):
            a = angle + rng.uniform(-1.4, 1.4)
            length = scale * rng.uniform(.50, 1.18)
            base = (x + rng.uniform(-.14, .14) * scale, z + rng.uniform(-.14, .14) * scale)
            tip = (base[0] + math.sin(a) * length, base[1] + math.cos(a) * length)
            blade(base, tip, length * rng.uniform(.12, .23), shade)

    # Unequal, staggered patches with substantial gaps; no rectangular edge band.
    clusters = [(-51,-31,4.3),(-41,-40,3.2),(-20,-37,4.5),(1,-43,4.2),(30,-38,4.8),(50,-27,3.5),
                (-53,-3,4.7),(53,1,4.1),(-46,20,4.4),(49,30,4.8),(-31,39,5.6),(-7,37,3.7),
                (21,40,4.6),(-31,-21,2.9),(22,-24,3.0),(34,-8,3.1),(-36,4,2.6),(28,19,3.1),
                (-19,21,2.7),(-15,-10,2.1),(14,9,2.3)]
    for x, z, radius in clusters:
        for j in range(rng.randint(12, 24)):
            angle = rng.uniform(0, math.tau)
            r = radius * math.sqrt(rng.random())
            tuft(x + math.cos(angle) * r, z + math.sin(angle) * r * .65,
                 rng.uniform(.65, 1.7), rng.randint(80, 190))
    for j in range(290):
        x, z = rng.uniform(-59, 59), rng.uniform(-46, 46)
        if abs(x) < 10 and abs(z) < 8:
            continue
        if abs(x) < 30 and abs(z) < 19 and rng.random() < .72:
            continue
        tuft(x, z, rng.uniform(.22, .85), rng.randint(50, 145))
    image = image.filter(ImageFilter.GaussianBlur(.85))
    image.save(GROUND / 'wasteland_grass_mask.png')
    svg.extend(['</g>', '</svg>'])
    (SOURCE / 'grass_mask_source.svg').write_text('\n'.join(svg), encoding='utf-8')
    print('MASK', image.size, '124:98 non-repeating, grayscale')


def create_asset_scene(name, size):
    x, y, z = size
    width, depth = x * 1.12, max(z, x * .45) * 1.12
    content = f'''[gd_scene load_steps=5 format=3]

[ext_resource type="PackedScene" path="res://assets/models/wasteland/{name}.glb" id="1"]
[ext_resource type="Shader" path="res://assets/shaders/ground_contact.gdshader" id="2"]

[sub_resource type="ShaderMaterial" id="ContactMaterial"]
shader = ExtResource("2")
shader_parameter/opacity = 0.14

[sub_resource type="PlaneMesh" id="ContactPlane"]
size = Vector2({width:.5f}, {depth:.5f})

[node name="{name.title().replace('_', '')}" type="Node3D"]
editor_description = "独立地表装饰；GLB 原点在底面中心；无碰撞。Model 为模型，Contact 为可调整的柔和贴地阴影。"

[node name="Model" parent="." instance=ExtResource("1")]

[node name="Contact" type="MeshInstance3D" parent="."]
position = Vector3(0.025, 0.008, 0.025)
cast_shadow = 0
mesh = SubResource("ContactPlane")
material_override = SubResource("ContactMaterial")
'''
    (SCENES / 'props' / f'{name}.tscn').write_text(content, encoding='utf-8')


def make_scatter():
    info = json.loads((ROOT / 'assets/models/wasteland/model_info.json').read_text(encoding='utf-8'))
    assets = info['assets']
    for a in assets:
        create_asset_scene(a['name'], a['dimensions_xyz'])
    rng = random.Random(SEED + 1)
    placed = []
    # These are existing map prop/spawn exclusion zones, not changes to gameplay.
    forbidden = [(x,z,2.1) for x in [-24,-16,-6,6,16,24] for z in [-13,13]]
    forbidden += [(x,0,2.0) for x in [-24,-4,4,24]]
    forbidden += [(-11,-4,3.0),(11,4,3.0)]
    forbidden += [(x,z,2.6) for x in [-30,30] for z in [-18,18]]
    forbidden += [(-18,-35,7.0),(18,-36,7.0)]
    forbidden += [(x,z,2.1) for x,z in [(-46,-22),(-34,-36),(-1,-38),(38,-38),(46,12),(-46,18),(-44,-8),(44,-7),(34,34)]]

    def allowed(x,z,spacing):
        if math.hypot(x/1.15,z) < 8.7:
            return False
        # Keep the authored wall footprint and the broad main cross routes clear.
        if abs(abs(x)-40.5) < 1.7 and abs(z)<30: return False
        if abs(abs(z)-28.5) < 1.5 and abs(x)<42: return False
        if abs(x)<3.1 and abs(z)<28: return False
        if abs(z)<2.5 and abs(x)<40: return False
        if any(math.hypot(x-a,z-b)<r for a,b,r in forbidden): return False
        return all(math.hypot(x-a['x'],z-a['z'])>spacing for a in placed)

    def place(x,z,outer=False):
        if not allowed(x,z,1.05 if outer else 2.2): return
        p=rng.random()
        group = 'Grass' if p < .48 else ('Bushes' if p < .64 else 'Stones')
        choices=[a for a in assets if a['group']==group]
        a=rng.choice(choices)
        scale=rng.uniform(.72,1.19)
        placed.append({'name':a['name'],'group':group,'x':round(x,4),'z':round(z,4),
                       'yaw':round(rng.uniform(-math.pi,math.pi),5),'scale':round(scale,4),
                       'stretch':round(rng.uniform(.84,1.09),4)})

    # Loose asymmetric islands. Each island has its own count and spread.
    islands=[(-48,-25,5.0,10),(-35,-36,5.6,9),(-4,-38,5.4,8),(40,-35,5.2,11),
             (49,-11,4.1,8),(-49,8,5.5,11),(-42,32,5.4,9),(-22,37,5.4,8),
             (8,39,5.3,7),(39,31,5.0,12),(50,17,4.0,8),(-35,-17,3.2,4),
             (32,-19,3.1,5),(-28,21,3.5,5),(28,22,3.9,6)]
    for x,z,r,count in islands:
        for _ in range(count):
            angle=rng.uniform(0,math.tau); distance=r*math.sqrt(rng.random())
            place(x+math.cos(angle)*distance,z+math.sin(angle)*distance,True)
    # Isolated pieces in the mid-ground, leaving the center and routes mostly bare.
    for _ in range(26):
        place(rng.uniform(-36,36),rng.uniform(-24,24))
    for _ in range(40):
        x,z=rng.uniform(-56,56),rng.uniform(-43,43)
        if abs(x)>36 or abs(z)>25: place(x,z,True)

    lines=['[gd_scene load_steps=%d format=3]'%(len(assets)+1),'']
    ids={a['name']:str(i+1) for i,a in enumerate(assets)}
    for a in assets:
        lines.append('[ext_resource type="PackedScene" path="res://scenes/maps/arena/ground/props/%s.tscn" id="%s"]'%(a['name'],ids[a['name']]))
    lines += ['', '[node name="GroundScatter" type="Node3D"]',
              'editor_description = "固定种子 111028 离线散布；所有实例均保存在此场景，运行时不重新随机。外围疏密分组，中央和主要通道留白，无碰撞。可直接手动编辑；重新运行生成器会覆盖本场景。"',
              'metadata/authoring_seed = 111028']
    for group in ['Grass','Bushes','Stones']:
        lines += ['', '[node name="%s" type="Node3D" parent="."]'%group]
        n=0
        for p in placed:
            if p['group']!=group:continue
            n+=1
            lines += ['', '[node name="%s%03d" parent="%s" instance=ExtResource("%s")]'%(group,n,group,ids[p['name']]),
                      'position = Vector3(%.4f, 0, %.4f)'%(p['x'],p['z']),
                      'rotation = Vector3(0, %.5f, 0)'%p['yaw'],
                      'scale = Vector3(%.4f, %.4f, %.4f)'%(p['scale']*1.3,p['scale']*p['stretch'],p['scale']*1.3)]
    (SCENES/'ground_scatter.tscn').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    (SOURCE/'scatter_layout.json').write_text(json.dumps({'seed':SEED+1,'instances':placed},indent=2),encoding='utf-8')
    print('SCATTER',len(placed),{g:sum(p['group']==g for p in placed) for g in ['Grass','Bushes','Stones']})


if __name__=='__main__':
    for p in [SOURCE,GROUND,SCENES/'props']:p.mkdir(parents=True,exist_ok=True)
    make_mask()
    if (ROOT/'assets/models/wasteland/model_info.json').exists():make_scatter()
