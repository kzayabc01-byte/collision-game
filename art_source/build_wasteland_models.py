"""Twelve small, independent low-poly ground assets. Blender background authoring.
Output is deliberately separate from the user's existing prop collections.
"""
from pathlib import Path
import math, random, json
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art_source/wasteland'
OUT=ROOT/'assets/models/wasteland'
for p in [SOURCE,OUT]:p.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
bpy.context.scene.unit_settings.system='METRIC'
rng=random.Random(111029)
manifest=[]
roots=[]


def mat(name,hexcolor):
    rgb=[int(hexcolor[i:i+2],16)/255 for i in (0,2,4)]
    rgb=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*rgb,1)
    bsdf=m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value=(*rgb,1)
    bsdf.inputs['Roughness'].default_value=.91
    # Gentle fill keeps these tiny forms readable in the existing dark environment.
    bsdf.inputs['Emission Color'].default_value=(*rgb,1)
    bsdf.inputs['Emission Strength'].default_value=.06
    return m


grasses=[mat('Grass_SlateBlue','475F71'),mat('Grass_DuskyTeal','466369'),mat('Grass_SageShadow','405763'),mat('Grass_SoftTip','5D7480')]
stones=[mat('Stone_Top','655B7D'),mat('Stone_SoftEdge','554D69'),mat('Stone_ShadedSide','42405A')]


def mesh(name,verts,faces,mats,indices=None,smooth=False):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
    for m in mats:data.materials.append(m)
    for i,p in enumerate(data.polygons):
        p.use_smooth=smooth
        if indices:p.material_index=indices[i]
    return obj


def leaf(name,base,angle,length,height,width,material):
    # Six rounded cross-sections: low wide blades with a curved ridge and soft point.
    direction=Vector((math.cos(angle),math.sin(angle),0))
    across=Vector((-math.sin(angle),math.cos(angle),0))
    verts=[];faces=[]
    sections=[(0,.10),(.19,.76),(.43,1),(.69,.93),(.87,.66),(.97,.31),(1,.10)]
    for t,w in sections:
        center=Vector(base)+direction*(length*t)
        center.z += height*(math.sin(t*math.pi*.63))
        for j in range(6):
            a=math.tau*j/6
            pt=center+across*(width*w*math.cos(a))
            pt.z += width*.43*w*math.sin(a)
            pt.z=max(.006,pt.z)
            verts.append(tuple(pt))
    faces.append(tuple(reversed(range(6))))
    for k in range(len(sections)-1):
        for j in range(6):faces.append((k*6+j,k*6+(j+1)%6,(k+1)*6+(j+1)%6,(k+1)*6+j))
    faces.append(tuple((len(sections)-1)*6+j for j in range(6)))
    return mesh(name,verts,faces,[material],smooth=True)


def grass_asset(index,bush=False):
    name=('low_clump_' if bush else 'small_grass_')+str(index+1).zfill(2)
    pieces=[]
    count=(9+index) if bush else (4+index)
    for i in range(count):
        angle=math.tau*i/count+rng.uniform(-.24,.24)+index*.47
        length=rng.uniform(.21,.40)*(1.15 if bush else 1)
        h=rng.uniform(.13,.28)*(1.1 if bush else 1)
        if i==index%count:h*=1.3;length*=.65
        radius=.09 if bush else .025
        base=(math.cos(angle)*radius,math.sin(angle)*radius,.01)
        pieces.append(leaf(name+'_leaf_%02d'%i,base,angle,length,h,rng.uniform(.055,.09),grasses[(i+index)%len(grasses)]))
    return name,'Bushes' if bush else 'Grass',pieces


def shard(name,center,sx,sy,height,phase):
    n=rng.choice([7,8,9])
    angles=[math.tau*i/n+rng.uniform(-.20,.20)+phase for i in range(n)]
    radial=[rng.uniform(.69,1.18) for i in range(n)]
    outline=[(math.cos(a)*sx*r,math.sin(a)*sy*r) for a,r in zip(angles,radial)]
    verts=[]
    # Broad irregular top, narrow bevel and thin darker side.
    for scale,z in [(.91,0),(1,height*.30),(.89,height*.89)]:
        for x,y in outline:
            verts.append((center[0]+x*scale,center[1]+y*scale,z+(x/sx)*height*.06))
    verts.append((center[0]-.05*sx,center[1]+.08*sy,height))
    faces=[];indices=[]
    faces.append(tuple(reversed(range(n))));indices.append(2)
    for ring in range(2):
        for i in range(n):
            faces.append((ring*n+i,ring*n+(i+1)%n,(ring+1)*n+(i+1)%n,(ring+1)*n+i));indices.append(2 if ring==0 else 1)
    for i in range(n):faces.append((2*n+i,2*n+(i+1)%n,3*n));indices.append(0)
    obj=mesh(name,verts,faces,stones,indices,smooth=False)
    bpy.context.view_layer.objects.active=obj
    bevel=obj.modifiers.new('Soft weathered rim','BEVEL')
    bevel.width=min(.018,height*.19);bevel.segments=2
    bevel.limit_method='ANGLE';bevel.angle_limit=.45
    bevel.affect='EDGES';bevel.material=1
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    weighted=obj.modifiers.new('Broad face normals','WEIGHTED_NORMAL')
    weighted.keep_sharp=True
    bpy.ops.object.modifier_apply(modifier=weighted.name)
    return obj


def stone_asset(index,cluster=False):
    name=('shard_group_' if cluster else 'flat_shard_')+str(index+1).zfill(2)
    if cluster:
        offsets=[(-.23,.08,.37,.24,.078),(.35,-.08,.23,.17,.061),(.05,-.29,.15,.12,.045)]
        if index==1:offsets=[(-.30,-.03,.29,.20,.071),(.18,.20,.31,.21,.081),(.32,-.24,.18,.14,.051),(-.28,-.35,.12,.10,.036)]
        parts=[shard(name+'_%02d'%i,(x,y),sx,sy,h,rng.random()) for i,(x,y,sx,sy,h) in enumerate(offsets)]
    else:
        specs=[(.38,.24,.075),(.29,.32,.085),(.47,.22,.064),(.28,.18,.055)]
        sx,sy,h=specs[index]
        parts=[shard(name,(0,0),sx,sy,h,index*.7)]
    return name,'Stones',parts


def export(name,group,parts):
    allpts=[o.matrix_world@Vector(v) for o in parts for v in o.bound_box]
    lo=Vector(tuple(min(v[i] for v in allpts) for i in range(3)))
    hi=Vector(tuple(max(v[i] for v in allpts) for i in range(3)))
    offset=Vector(((lo.x+hi.x)*.5,(lo.y+hi.y)*.5,lo.z))
    for o in parts:o.location-=offset
    root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
    for o in parts:o.parent=root
    roots.append(root)
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,
                              export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
    triangles=0
    for o in parts:o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
    dims=hi-lo
    manifest.append({'name':name,'group':group,'dimensions_xyz':[round(dims.x,5),round(dims.z,5),round(dims.y,5)],'triangles':triangles,'collision':False,'origin':'bottom center, Y up'})
    print('EXPORTED',name,triangles,flush=True)


for i in range(3):export(*grass_asset(i))
for i in range(3):export(*grass_asset(i,True))
for i in range(4):export(*stone_asset(i))
for i in range(2):export(*stone_asset(i,True))
for i,o in enumerate(roots):o.location=((i%4)*1.9,-(i//4)*1.7,0)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'wasteland_details.blend'))
(OUT/'model_info.json').write_text(json.dumps({'seed':111029,'assets':manifest},indent=2),encoding='utf-8')
print('WASTELAND_MODELS_COMPLETE',len(manifest),flush=True)
