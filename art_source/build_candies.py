"""Offline five-candy kit; saved Blender parts and GLBs, never run by the game."""
from pathlib import Path
import sys, math, json
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent))
from companion_authoring import *

clear_scene()
pink = material('Strawberry pink', 'EB659D', .26, coat=.4)
white = material('Cream sugar', 'FFF0DC', .3)
purple = material('Grape purple', '9952CF', .26, coat=.4)
red = material('Peppermint raspberry', 'E65079', .25, coat=.4)
gold = material('Honey star', 'FFC24D', .27, coat=.4)
green = material('Apple jelly', '8ED34F', .19, coat=.65)
highlight = material('Jelly highlight', 'DCF597', .22)
roots=[]

def striped_ellipsoid(name, scale, base, color, pattern, parent):
    v=[];f=[]
    rings, sides=20,48
    for j in range(rings+1):
        p=math.pi*(.0005+.999*j/rings)
        for i in range(sides):
            a=math.tau*i/sides
            v.append((scale[0]*math.sin(p)*math.cos(a),scale[1]*math.sin(p)*math.sin(a),scale[2]*math.cos(p)))
    for j in range(rings):
        for i in range(sides):
            f.append((j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i))
    # Planar UVs keep the top-facing candy pattern crisp without extra geometry.
    mat=base.copy();mat.name=name+' icing'
    o=mesh(name,v,f,mat,parent)
    uv=o.data.uv_layers.new(name='CandyUV')
    for loop in o.data.loops:
        co=o.data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv=(co.x/scale[0]*.5+.5,co.y/scale[1]*.5+.5)
    size=512
    y,x=np.mgrid[0:size,0:size].astype(np.float32)
    x=(x/(size-1)*2-1)*scale[0];y=(y/(size-1)*2-1)*scale[1]
    phase=pattern(x,y)
    mix=np.clip(np.sin(phase)*30+.5,0,1)[...,None]
    rgb=np.array([int(color[i:i+2],16)/255 for i in (0,2,4)])
    cream=np.array([1,.941,.863])
    pixels=np.ones((size,size,4),dtype=np.float32)
    pixels[:,:,:3]=rgb*(1-mix)+cream*mix
    texture=bpy.data.images.new(name+' pattern',width=size,height=size,alpha=False)
    texture.pixels.foreach_set(pixels.ravel());texture.pack()
    node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=texture
    shader=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    mat.node_tree.links.new(node.outputs['Color'],shader.inputs['Base Color'])
    return o

def wrappers(root, mat):
    for side in (-1,1):
        v=[];f=[]
        for j in range(5):
            t=j/4
            for i in range(16):
                a=math.tau*i/16+t*.45
                r=(.043+.066*t)*(1+.24*math.cos(a*4))
                v.append((side*(.205+.13*t),math.cos(a)*r,math.sin(a)*r))
        for j in range(4):
            for i in range(16):
                a=j*16+i;b=j*16+(i+1)%16
                f.append((a,b,b+16,a+16))
        o=mesh('TwistedWrapper',v,f,mat,root)
        mod=o.modifiers.new('Wrapper thickness','SOLIDIFY');mod.thickness=.006
        bpy.context.view_layer.objects.active=o
        bpy.ops.object.modifier_apply(modifier=mod.name)
        sphere('WrapperKnot',(side*.209,0,0),(.026,.055,.055),mat,root,16,8)

r=empty('PinkWrap');roots.append(r)
striped_ellipsoid('StripedSweet',(.232,.16,.145),pink,'EB659D',lambda x,y: x*48+y*16,r)
wrappers(r,pink)
r=empty('PurpleWrap');roots.append(r)
striped_ellipsoid('SwirlSweet',(.235,.17,.145),purple,'9952CF',lambda x,y: np.arctan2(y,x)+np.hypot(x,y)*43,r)
wrappers(r,purple)
r=empty('Peppermint');roots.append(r)
striped_ellipsoid('Pinwheel',(.255,.255,.105),red,'E65079',lambda x,y: 5*np.arctan2(y,x)-np.hypot(x,y)*17,r)
r=empty('Star');roots.append(r)
verts=[]
for z in (-.075,.075):
    for i in range(10):
        a=math.pi/2+math.tau*i/10
        radius=.29 if i%2==0 else .155
        verts.append((radius*math.cos(a),radius*math.sin(a),z))
faces=[tuple(range(9,-1,-1)),tuple(range(10,20))]
faces.extend([(i,(i+1)%10,(i+1)%10+10,i+10) for i in range(10)])
o=mesh('RoundedStar',verts,faces,gold,r)
bevel=o.modifiers.new('Soft sugar edges','BEVEL');bevel.width=.038;bevel.segments=3
bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=bevel.name)
r=empty('Jelly');roots.append(r)
v=[];f=[]
profile=[(-.13,.18),(-.10,.235),(-.06,.24),(.09,.17),(.14,.16),(.16,.11),(.16,0.002)]
for z,rad in profile:
    for i in range(40):
        a=math.tau*i/40
        radius=rad*(1+.06*math.cos(5*a))
        v.append((radius*math.cos(a),radius*math.sin(a),z))
for j in range(len(profile)-1):
    for i in range(40):
        a=j*40+i;b=j*40+(i+1)%40
        f.append((a,b,b+40,a+40))
f.append(tuple(range(39,-1,-1)))
mesh('FlutedJelly',v,f,green,r)
sphere('SoftGlint',(-.08,-.07,.153),(.045,.025,.009),highlight,r,16,8)

for i,r in enumerate(roots):
    r.location=(i*.95,0,.17)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/candies.blend'))
stats={}
for name,r in zip(['pink_wrap','purple_wrap','peppermint','star','jelly'],roots):
    r.location=(0,0,0)
    bpy.ops.object.select_all(action='DESELECT')
    for o in descendants(r): o.select_set(True)
    bpy.context.view_layer.objects.active=r
    out=ROOT/'assets/models/candies';out.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_apply=True)
    stats[name]={'objects':len(descendants(r)),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in descendants(r) if o.type=='MESH')}
(out/'model_info.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
print('CANDY_KIT',stats)
