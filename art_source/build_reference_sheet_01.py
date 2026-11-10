"""Offline reference-sheet props. Blender Z-up / front -Y becomes glTF Y-up / front +Z.
Run with Blender --background --factory-startup --python this_file.py.
All generated files stay in the two dedicated reference_sheet_01 directories.
"""
from pathlib import Path
import bpy, bmesh, math, json, random, sys
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art_source' / 'reference_sheet_01'
OUT = ROOT / 'assets' / 'models' / 'reference_sheet_01'
SOURCE.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
RENDERS=SOURCE/'renders'
RENDERS.mkdir(parents=True,exist_ok=True)
random.seed(1110)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for datablock in list(bpy.data.materials):
    bpy.data.materials.remove(datablock)
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.preferences.filepaths.save_version = 0
TAU = math.tau
ASSETS = []
ACTIVE = None

def material(name, color, rough=.65, emission=0, metal=0):
    def linear(v):
        return v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4
    rgb = [linear(int(color[i:i+2],16)/255) for i in (0,2,4)]
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb,1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*rgb,1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    if emission:
        p.inputs['Emission Color'].default_value = (*rgb,1)
        p.inputs['Emission Strength'].default_value = emission
    return m

STONE = [material('Stone_Lavender_%02d'%i,c) for i,c in enumerate(['9C79C4','A786CC','B491D6','9773BA','AC87CB'])]
WOOD = [material('Wood_Mulberry_%02d'%i,c) for i,c in enumerate(['92536D','A4637B','9D5B70','AF7084','884B68'])]
BARK = [material('Bark_Plum_%02d'%i,c) for i,c in enumerate(['773C70','88477C','9A558C','69345F'])]
PURPLE = material('Trim_Grape','9457C5')
LILAC = material('Trim_Lilac','B27DDC')
DARK_PURPLE = material('Ink_DeepPlum','53375E')
PINK = material('Candy_Raspberry','EC5DB0',.38)
PALE_PINK = material('Candy_Icing','FFC0E9',.42)
MUSHROOM_SPOT = material('Mushroom_PaleLavenderSpots','E2C6FF')
GRAPE = material('Candy_Violet','A34DE0',.4)
GOLD = material('Candy_Golden','FFBB36',.38)
ORANGE = [material('Pumpkin_%02d'%i,c) for i,c in enumerate(['F7982D','FFAA3B','EC8B23'])]
INSIDE = material('Pumpkin_Inner','BB601C')
TEAL = [material('Grass_Teal_%02d'%i,c) for i,c in enumerate(['4A9C99','66B5AD','579F9E'])]
SHRUB = [material('Shrub_Berry','C8499F'),material('Shrub_Pink','D653A9'),material('Shrub_Grape','8747B5'),material('Shrub_Violet','9552BF')]
CREAM = material('Candle_Cream','FFE0AC')
FLAME = material('Candle_Flame','FFB544',.4,1.8)
GLOW = material('Lantern_WarmGlass','FFC449',.35,.7)
BOLT = material('Bolt_Lavender','A7A7D0',.4,.15)
CRYSTAL = [material('Crystal_Facet_%02d'%i,c,.32) for i,c in enumerate(['D44BFF','C146EE','B53DDD','EE81FF','DA65FC','A142CA'])]

def register(obj, name, mat=None, smooth=False):
    obj.name = name
    if ACTIVE:
        for c in list(obj.users_collection):
            c.objects.unlink(obj)
        ACTIVE['collection'].objects.link(obj)
        obj.parent = ACTIVE['root']
    if mat:
        obj.data.materials.append(mat)
    if obj.type == 'MESH':
        for p in obj.data.polygons:
            p.use_smooth = smooth
    return obj

def apply(obj, mod):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)

def bevel(obj, width=.04, segments=2):
    if width:
        mod=obj.modifiers.new('Soft carved edges','BEVEL')
        mod.width=width; mod.segments=segments
        apply(obj,mod)
        mod=obj.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
        mod.keep_sharp=True; mod.weight=35
        apply(obj,mod)
    return obj

def cube(name, loc, size, mat, soft=.04, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o=bpy.context.object; o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    register(o,name,mat,False)
    bevel(o,soft,2)
    if rotation: o.rotation_euler=rotation
    return o

def sphere(name,loc,scale,mat,segments=20,rings=12,faceted=False):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=loc)
    o=bpy.context.object; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return register(o,name,mat,not faceted)

def mesh(name,verts,faces,mat=None,smooth=False):
    d=bpy.data.meshes.new(name); d.from_pydata(verts,[],faces); d.update()
    bm=bmesh.new(); bm.from_mesh(d)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(d); bm.free()
    o=bpy.data.objects.new(name,d); bpy.context.scene.collection.objects.link(o)
    return register(o,name,mat,smooth)

def cylinder(name,loc,radius,depth,mat,vertices=24,soft=.02,front=False):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
    o=bpy.context.object; register(o,name,mat,False)
    bevel(o,soft,2)
    if front: o.rotation_euler.x=math.pi/2
    return o

def beam(name,a,b,width,depth,mat,soft=.02):
    d=Vector(b)-Vector(a)
    o=cube(name,(Vector(a)+Vector(b))/2,(width,depth,d.length),mat,soft)
    o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    return o

def tube(name,points,radius,mat,res=3,sides=1):
    d=bpy.data.curves.new(name,'CURVE'); d.dimensions='3D'
    d.resolution_u=res; d.bevel_depth=radius; d.bevel_resolution=sides
    d.use_fill_caps=True
    sp=d.splines.new('BEZIER'); sp.bezier_points.add(len(points)-1)
    for p,co in zip(sp.bezier_points,points):
        p.co=co[:3]; p.radius=co[3] if len(co)>3 else 1
        p.handle_left_type='AUTO'; p.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,d); bpy.context.scene.collection.objects.link(o)
    return register(o,name,mat)

def lathe(name,profile,mat,sides=40,smooth=True,start=0,end=TAU,cap_ends=False):
    # profile entries are (radius,height); each row is angularly sampled.
    closed=abs(end-start-TAU)<.0001
    n=sides if closed else sides+1
    v=[(r*math.cos(start+(end-start)*i/sides),r*math.sin(start+(end-start)*i/sides),z) for r,z in profile for i in range(n)]
    f=[]
    for j in range(len(profile)-1):
        for i in range(sides):
            k=(i+1)%n
            f.append((j*n+i,j*n+k,(j+1)*n+k,(j+1)*n+i))
    if not closed and cap_ends:
        f.extend([tuple(j*n for j in range(len(profile)-1,-1,-1)),tuple(j*n+n-1 for j in range(len(profile)))])
    return mesh(name,v,f,mat,smooth)

def polygon_front(name,pts,y,depth,mat,soft=0):
    # A solid extruded outline, viewed from Blender -Y / exported +Z.
    n=len(pts)
    v=[(x,yy,z) for yy in (y-depth/2,y+depth/2) for x,z in pts]
    f=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    f.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    return bevel(mesh(name,v,f,mat),soft,2)

def new_asset(key,label,status,related=None):
    global ACTIVE
    c=bpy.data.collections.new(key); bpy.context.scene.collection.children.link(c)
    root=bpy.data.objects.new('Sheet01_'+key,None); c.objects.link(root)
    root.empty_display_type='PLAIN_AXES'; root.empty_display_size=.25
    root['中文名称']=label; root['制作状态']=status
    root['front_axis']='glTF +Z (Blender -Y)'
    root['origin']='ground center'; root['collision']='none'
    ACTIVE={'key':key,'label':label,'status':status,'related':related or [],'root':root,'collection':c}
    ASSETS.append(ACTIVE)
    return ACTIVE

def grass(x,y,s=1):
    directions=[(-.75,-.12,.6),(-.4,.16,.97),(.05,.07,1.15),(.53,.06,.87),(.87,-.08,.45),(.24,-.4,.57)]
    for i,(dx,dy,dz) in enumerate(directions):
        # Plump pointed leaves, not flat planes: adjustable meshes in the source.
        base=Vector((x,y,.018*s)); tip=base+Vector((dx,dy,dz))*.42*s
        axis=tip-base; u=Vector((0,1,0)); v=axis.normalized().cross(u).normalized()
        u=v.cross(axis.normalized()).normalized()
        verts=[tuple(base)]; rings=[(.18,.075),(.48,.103),(.77,.075),(.94,.032)]
        for t,r in rings:
            center=base+axis*t+Vector((dx*.055*s*t*t,0,0))
            for j in range(8):
                a=TAU*j/8
                verts.append(tuple(center+u*math.cos(a)*r*s*.4+v*math.sin(a)*r*s))
        verts.append(tuple(tip)); faces=[]
        faces.extend((0,1+j,1+(j+1)%8) for j in range(8))
        for k in range(3):
            for j in range(8):
                a=1+k*8+j;b=1+k*8+(j+1)%8
                faces.append((a,b,b+8,a+8))
        faces.extend((25+j,25+(j+1)%8,33) for j in range(8))
        mesh('Grass_REMADE_leaf_%02d'%i,verts,faces,TEAL[i%3],True)

def rock(name,loc,scale,index=0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=loc)
    o=bpy.context.object
    for v in o.data.vertices:
        v.co*=random.uniform(.92,1.08)
    o.scale=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    register(o,name,STONE[index%len(STONE)],False)
    bevel(o,.035,1)
    return o

def candy_swirl(name,x,y,z,r,base,icing,stick=0):
    if stick:
        beam(name+'_stick',(x,y,z-r*.1-stick),(x,y,z),r*.17,r*.17,WOOD[3],.015)
    cylinder(name+'_disc',(x,y,z),r,r*.28,base,40,r*.13,True)
    # Five curved pinwheel ribbons laid on a slightly domed front face.
    for k in range(5):
        verts=[]
        for j in range(19):
            rr=r*(.015+.91*j/18)
            for t in range(5):
                a=TAU*k/5+1.7*(1-j/18)+.56*t/4
                verts.append((x+rr*math.cos(a),y-r*.17-r*.07*(1-(rr/r)**2),z+rr*math.sin(a)))
        faces=[]
        for j in range(18):
            for t in range(4):
                n=j*5+t;faces.append((n,n+1,n+6,n+5))
        mesh(name+'_icing_%d'%k,verts,faces,icing,True)

def candy_heap(z,r=.63):
    mats=[PINK,GRAPE,GOLD,PURPLE]
    for row,(yy,zz,count) in enumerate([(.19,z+.1,4),(-.13,z,4),(0,z+.32,3)]):
        for j in range(count):
            x=(j-(count-1)/2)*r*.49
            radius=r*(.23+random.random()*.04)
            sphere('RoundCandy_%d_%d'%(row,j),(x,yy,zz+random.uniform(-.02,.03)),(radius,radius,radius),mats[(j+row*2)%4])

def stone_block(name,loc,size,i=0,tilt=0):
    o=cube(name,loc,size,STONE[i%len(STONE)],min(size)*.13)
    o.rotation_euler.z=tilt
    return o

def make_crate():
    new_asset('candy_crate_NEW','糖果木箱','新增款')
    for side in (-1,1):
        for i in range(4):
            x=(i-1.5)*.285
            cube('Face_vertical_plank',(x,side*.52,.66),(.277,.12,1.04),WOOD[i],.025)
            cube('Side_vertical_plank',(side*.52,x,.66),(.12,.277,1.04),WOOD[(i+1)%5],.025)
        for zz in (.16,1.19):
            cube('Front_lavender_rail',(0,side*.57,zz),(1.32,.19,.22),LILAC,.045)
            cube('Side_lavender_rail',(side*.57,0,zz),(.19,1.32,.22),PURPLE,.045)
    for x in (-.56,.56):
        for y in (-.56,.56):
            cube('Corner_post',(x,y,.66),(.18,.18,1.15),WOOD[4],.025)
            for z in (.16,1.19):
                cube('Corner_protector',(x,y,z),(.29,.29,.26),LILAC,.04)
    for i in range(4):
        cube('Lid_plank',((i-1.5)*.277,0,1.16),(.267,1.03,.095),WOOD[(i+2)%5],.02)
    beam('Diagonal_front_brace',(-.44,-.611,.3),(.44,-.611,1.03),.14,.08,PURPLE,.02)
    beam('Diagonal_side_brace',(.611,-.43,.3),(.611,.43,1.03),.14,.08,PURPLE,.02)
    candy_swirl('Peppermint_medallion',.1,-.69,.65,.245,PINK,PALE_PINK)

def make_barrel():
    new_asset('candy_barrel_NEW','糖果木桶','新增款')
    profile=[(.46,.08),(.54,.12),(.63,.36),(.66,.69),(.61,1.04),(.53,1.27),(.46,1.27),(.54,1.02),(.58,.69),(.55,.36),(.47,.17),(.40,.14)]
    for i in range(14):
        a=TAU*i/14+.008;b=TAU*(i+1)/14-.008
        o=lathe('Separate_curved_stave_%02d'%i,profile,WOOD[i%5],4,False,a,b,True)
        bevel(o,.014,2)
    for z,r in [(.29,.625),(1.05,.615)]:
        lathe('Purple_barrel_hoop',[(r-.04,z-.085),(r+.035,z-.085),(r+.045,z-.06),(r+.045,z+.06),(r+.035,z+.085),(r-.04,z+.085),(r-.04,z-.085)],PURPLE,48,True)
    cylinder('Dark_interior',(0,0,1.13),.49,.04,DARK_PURPLE)
    candy_heap(1.25,.68)
    candy_swirl('Pink_lollipop',-.24,-.18,1.55,.13,PINK,PALE_PINK)
    bat=[(-.23,.8),(-.15,.76),(-.09,.78),(-.055,.72),(-.035,.81),(0,.78),(.035,.81),(.055,.72),(.09,.78),(.15,.76),(.23,.8),(.20,.66),(.13,.69),(.07,.63),(0,.59),(-.07,.63),(-.13,.69),(-.20,.66)]
    polygon_front('Bat_emblem',bat,-.664,.018,DARK_PURPLE,.006)

def make_pumpkin():
    new_asset('pumpkin_candy_bucket_NEW','南瓜糖桶','新增糖桶款；项目已有其他南瓜模型',['jack_o_lantern_pair.glb'])
    profile=[(.15,.04),(.43,.06),(.65,.19),(.79,.4),(.85,.65),(.82,.88),(.73,1.1),(.61,1.25),(.54,1.27),(.51,1.2),(.63,1.06),(.73,.86),(.76,.64),(.69,.4),(.57,.23),(.38,.16),(.15,.15)]
    v=[];f=[];n=100
    for r,z in profile:
        for i in range(n):
            a=TAU*i/n
            rr=r*(1+.052*math.cos(10*a))
            v.append((rr*math.cos(a),rr*math.sin(a),z))
    for j in range(len(profile)-1):
        for i in range(n):
            f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    f.append(tuple(range(n-1,-1,-1)))
    f.append(tuple((len(profile)-1)*n+i for i in range(n)))
    body=mesh('Hollow_lobed_pumpkin',v,f,ORANGE[0],True)
    for m in ORANGE[1:]+[INSIDE]: body.data.materials.append(m)
    for p in body.data.polygons:
        row=p.index//n;angle=p.index%n
        p.material_index=3 if row>=8 else ([0,1,0,2,0,1,0,1,0,2][angle//10])
    eyes=[ [(-.51,.73),(-.35,1.01),(-.18,.76)],[(.18,.76),(.35,1.01),(.51,.73)], [(-.09,.65),(0,.79),(.09,.65)] ]
    mouth=[(-.5,.56),(-.31,.5),(-.24,.55),(-.24,.45),(-.08,.42),(-.06,.49),(.09,.49),(.11,.42),(.28,.46),(.30,.53),(.49,.59),(.45,.37),(.27,.28),(.12,.3),(.10,.35),(-.08,.35),(-.1,.29),(-.28,.31),(-.43,.4)]
    for i,poly in enumerate(eyes+[mouth]):
        cutter=polygon_front('Temporary_face_cut_%d'%i,poly,-.73,.75,None)
        mod=body.modifiers.new('Carved_face_%d'%i,'BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
        apply(body,mod);bpy.data.objects.remove(cutter,do_unlink=True)
    bevel(body,.012,2)
    sphere('Dark_inner_face',(0,-.34,.66),(.61,.12,.49),DARK_PURPLE)
    cylinder('Candy_inner_support',(0,0,1.14),.49,.06,INSIDE)
    candy_heap(1.25,.74)
    candy_swirl('Pink_swirl_lollipop',-.45,.02,1.74,.23,PINK,PALE_PINK,.42)
    candy_swirl('Purple_swirl_lollipop',.45,.14,1.88,.245,GRAPE,LILAC,.54)
    beam('Cross_candy_stick',(-.1,.18,1.27),(-.18,.18,1.98),.07,.07,WOOD[1],.01)
    polygon_front('Pink_cross_candy',cross_outline(-.18,1.745,.28,.33,.115,.1,.105),.18,.095,PINK,.022)

def make_tree():
    new_asset('crooked_dead_tree_NEW','枯树','新增款；附草叶为本次重制')
    trunk=[((.0,0,.03),.47),((-.09,0,.3),.41),((-.3,.02,.7),.32),((-.37,.02,1.07),.29),((-.25,.01,1.4),.27),((0,.02,1.7),.24),((.35,.02,1.88),.17),((.63,.01,1.92),.09)]
    verts=[];faces=[];sides=10
    for j,(pos,r) in enumerate(trunk):
        for i in range(sides):
            a=TAU*i/sides
            verts.append((pos[0]+math.cos(a)*r,pos[1]+math.sin(a)*r*.8,pos[2]+(.015*math.sin(a*3) if j else 0)))
    for j in range(len(trunk)-1):
        for i in range(sides):
            a=j*sides+i;b=j*sides+(i+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(range(sides-1,-1,-1)),tuple((len(trunk)-1)*sides+i for i in range(sides))])
    o=mesh('Twisted_faceted_trunk',verts,faces,BARK[0])
    for m in BARK[1:]:o.data.materials.append(m)
    for p in o.data.polygons:p.material_index=[0,1,0,2,1,0,3,0,1,2][p.index%sides]
    bevel(o,.025,2)
    # Branch taper and curling silhouette are actual 3D geometry.
    tube('Left_crooked_branch',[(-.22,0,1.36,1.15),(-.49,.01,1.88,1),(-.59,.02,2.34,.75),(-.89,.02,2.47,.62),(-1.22,0,2.22,.54),(-1.2,-.01,1.91,.45),(-.96,-.03,1.82,.35),(-.82,-.04,1.99,.25),(-.96,-.04,2.09,.17)],.2,BARK[1],2,1)
    tube('Right_upper_branch',[(.15,.015,1.75,1.2),(.72,.01,1.98,.9),(1.04,0,2.28,.7),(.96,.01,2.63,.62),(.67,0,2.83,.52),(.36,-.01,2.72,.43),(.3,-.02,2.42,.35),(.49,-.03,2.34,.25),(.61,-.03,2.48,.16)],.18,BARK[1],2,1)
    tube('Small_right_curl',[(.5,0,1.87,1),(.66,-.01,1.61,.65),(.91,-.02,1.51,.5),(1.05,-.03,1.68,.38),(.94,-.04,1.79,.2)],.12,BARK[0],2,1)
    tube('Twig_fork',[(.72,.01,1.98,1),(.62,-.01,2.25,.65),(.72,-.02,2.44,.35)],.095,BARK[2],2,1)
    for x,y in [(-.31,-.14),(.23,-.1),(-.13,.23)]:
        tube('Root_flare',[(x*.6,y*.6,.57,.8),(x,y,.23,1),(x*1.7,y*1.7,.045,1.2)],.12,BARK[0],3,1)
    # Fuse overlapping trunk/branch solids so branch starts never show flat seams.
    woody=[o for o in ACTIVE['collection'].objects if o.type in {'MESH','CURVE'}]
    bpy.ops.object.select_all(action='DESELECT')
    for o in woody:o.select_set(True)
    bpy.context.view_layer.objects.active=woody[0]
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    sculpt=bpy.context.object;sculpt.name='Unified_sculpted_trunk_and_curls'
    mod=sculpt.modifiers.new('Fuse_organic_branch_junctions','REMESH');mod.mode='VOXEL';mod.voxel_size=.026;mod.use_smooth_shade=True
    apply(sculpt,mod)
    mod=sculpt.modifiers.new('Soften_sculpt','SMOOTH');mod.factor=.7;mod.iterations=3;apply(sculpt,mod)
    mod=sculpt.modifiers.new('Low_polygon_bark','DECIMATE');mod.ratio=.18;apply(sculpt,mod)
    sculpt.data.materials.clear()
    for m in BARK:sculpt.data.materials.append(m)
    for p in sculpt.data.polygons:
        p.use_smooth=False
        p.material_index=1 if p.normal.x<-.25 else 0
    tube('Bark_front_ridge',[(-.2,-.26,.07,1),(-.37,-.23,.65,.8),(-.51,-.18,1.03,.65),(-.3,-.21,1.48,.25)],.033,BARK[2],3,1)
    for i,(x,y,z,s) in enumerate([(-.77,.08,.36,.4),(-1,.12,.18,.27),(-.78,-.23,.13,.19),(-.6,-.42,.22,.27),(-.36,-.43,.15,.19),(-.97,-.37,.11,.17)]):
        sphere('Base_berry_shrub',(x,y,z),(s,s*.7,s),SHRUB[i%4],16,10)
    grass(.65,.05,1.18)
    rock('Base_stone',(-1.12,-.18,.07),(.21,.18,.12),0)

def make_wall():
    new_asset('low_stone_wall_NEW','矮石墙','新增款；附草叶为本次重制')
    blocks=[(-.93,.0,.27,.76,.52),(-.14,0,.28,.78,.55),(.61,0,.27,.67,.53),(1.19,0,.29,.46,.57),(-.48,.01,.77,.72,.48),(.22,.01,.77,.66,.48),(.99,.01,.87,.79,.64),(.99,.02,1.47,.86,.55)]
    for i,(x,y,z,w,h) in enumerate(blocks):
        stone_block('Masonry_block_%02d'%i,(x,y,z),(w,.55+random.random()*.08,h),i,random.uniform(-.035,.035))
    grass(-1.43,-.2,.78);grass(1.47,-.14,.98)
    rock('Fallen_rock_front',(-.38,-.51,.12),(.28,.24,.19),1)
    rock('Fallen_small_rock',(-.94,-.52,.06),(.16,.12,.1),3)

def make_arch():
    new_asset('stone_archway_NEW','石拱门','新增款；附草叶为本次重制')
    for side in (-1,1):
        stone_block('Wide_pillar_foot',(side*.98,0,.15),(.82,.82,.3),0)
        for j in range(3):
            stone_block('Pillar_course',(side*.98,0,.49+j*.38),(.58,.6,.375),j+1,side*.015*(-1)**j)
        stone_block('Impost_capital',(side*.98,0,1.62),(.82,.78,.31),2)
    inner=.7; outer=1.27; center=1.64
    for i in range(9):
        a=math.pi*i/9+.012;b=math.pi*(i+1)/9-.012
        verts=[]
        for y in (-.34,.34):
            for rr,aa in [(inner,a),(outer,a),(outer,b),(inner,b)]:
                verts.append((rr*math.cos(aa),y,center+rr*math.sin(aa)))
        o=mesh('Arch_voussoir_%02d'%i,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],STONE[(i+1)%5])
        bevel(o,.055,2)
    for side in (-1,1):
        sphere('Berry_behind_pillar',(side*1.25,.19,.3),(.27,.23,.3),SHRUB[0])
        sphere('Berry_small',(side*1.43,.1,.15),(.19,.16,.18),SHRUB[1])
        grass(side*1.39,-.27,.8)

def cross_outline(cx,z,w,h,arm_z,arm_h,stem_w):
    x0=cx-w/2;x1=cx-stem_w/2;x2=cx+stem_w/2;x3=cx+w/2
    return [(x1,z),(x2,z),(x2,z+arm_z),(x3,z+arm_z),(x3,z+arm_z+arm_h),(x2,z+arm_z+arm_h),(x2,z+h),(x1,z+h),(x1,z+arm_z+arm_h),(x0,z+arm_z+arm_h),(x0,z+arm_z),(x1,z+arm_z)]

def make_tombstone():
    new_asset('cross_tombstone_REMADE','十字墓碑','重制：项目已有同类墓碑',['arched_cross_tombstone.glb'])
    stone_block('Tombstone_plinth',(0,0,.16),(1.13,.8,.32),0)
    pts=cross_outline(0,.26,1.5,1.9,.76,.42,.48)
    body=polygon_front('Stone_cross',pts,0,.43,STONE[1],.07)
    inset=cross_outline(0,.48,1.16,1.45,.62,.15,.19)
    cutter=polygon_front('Temporary_inset_carve',inset,-.214,.11,None,.025)
    mod=body.modifiers.new('Recessed_cross_panel','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
    apply(body,mod);bpy.data.objects.remove(cutter,do_unlink=True)
    polygon_front('Inset_cross_shadow',inset,-.167,.012,STONE[3],.016)
    for i,(x,y,h,r) in enumerate([(.84,.0,.69,.16),(1.13,-.12,.38,.125)]):
        cylinder('Wax_candle_%d'%i,(x,y,h/2),r,h,CREAM,24,.025)
        for j in range(3):
            a=TAU*j/3+.2
            tube('Wax_drip',[(x+r*.92*math.cos(a),y+r*.92*math.sin(a),h-.03),(x+r*.96*math.cos(a),y+r*.96*math.sin(a),h-.14-.03*j)],.025,CREAM)
        cylinder('Candle_wick',(x,y,h+.026),.012,.065,DARK_PURPLE,8,.002)
        sphere('Candle_flame',(x,y,h+.103),(.035,.035,.105),FLAME,12,8)
    grass(-.64,-.25,.9);grass(.49,-.38,.65)

def make_fence():
    new_asset('wood_fence_REMADE','木围栏','重制：项目已有木围栏',['fence_purple_wood.glb'])
    for zz in (.42,.89):
        cube('Horizontal_wood_rail',(0,.055,zz),(2.37,.17,.23),WOOD[2],.04)
        cube('Rail_upper_painted_edge',(0,-.038,zz+.078),(2.28,.016,.045),WOOD[3],.01)
    for x in (-.84,.84):
        cube('Fence_upright',(x,0,.69),(.34,.35,1.38),WOOD[0],.065)
        cube('Post_front_grain',(x+.075,-.18,.64),(.025,.016,1.02),WOOD[1],.006)
        for z in (.43,.92):
            cylinder('Lavender_round_bolt',(x,-.207,z),.077,.046,BOLT,16,.015,True)
    grass(-1.09,-.17,.76);grass(1.11,-.17,.83)

def make_lantern():
    new_asset('lantern_post_REMADE','路灯','重制：项目已有路灯',['crooked_lantern_post.glb'])
    stone_block('Lantern_square_foot',(.28,0,.17),(.64,.62,.34),3)
    cube('Wood_lantern_post',(.28,0,1.28),(.22,.24,2.3),WOOD[0],.035)
    cube('Post_lit_edge',(.226,-.13,1.32),(.05,.022,2.16),WOOD[3],.008)
    for z in (.83,2.13):
        cube('Post_lavender_collar',(.28,0,z),(.32,.33,.135),BARK[1],.04)
    tube('Curled_hanger',[(.28,0,2.22,1.15),(.14,0,2.52,1),(-.1,0,2.78,1),(-.42,0,2.83,.94),(-.7,0,2.61,.85),(-.71,0,2.37,.7),(-.49,0,2.32,.58),(-.4,0,2.47,.43),(-.52,0,2.53,.25)],.105,BARK[1],3,1)
    lx=-.64
    cylinder('Lantern_suspension',(lx,0,2.22),.045,.2,DARK_PURPLE,12,.01)
    cube('Lantern_top_cap',(lx,0,2.12),(.23,.24,.09),STONE[3],.03)
    # Pyramid hip roof with a short ridge; four glowing tapered panes.
    verts=[(lx+x,y,z) for z,s in [(1.91,.36),(2.09,.13)] for x,y in [(-s,-s),(s,-s),(s,s),(-s,s)]]
    roof=mesh('Lantern_hip_roof',verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],BARK[1]);bevel(roof,.025,2)
    cube('Lantern_roof_rim',(lx,0,1.91),(.77,.77,.085),STONE[3],.025)
    z0=1.28;z1=1.87;s0=.22;s1=.305
    verts=[(lx+x,y,z) for z,s in [(z0,s0),(z1,s1)] for x,y in [(-s,-s),(s,-s),(s,s),(-s,s)]]
    glass=mesh('Four_warm_glass_panes',verts,[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(0,3,2,1)],GLOW)
    for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1)]:
        beam('Lantern_corner_frame',(lx+sx*s0,sy*s0,z0),(lx+sx*s1,sy*s1,z1),.065,.065,BARK[0],.015)
    cube('Lantern_bottom_frame',(lx,0,1.27),(.55,.55,.10),BARK[1],.03)
    cube('Lantern_lower_cap',(lx,0,1.20),(.36,.36,.09),STONE[3],.025)
    grass(-.14,-.21,.75);grass(.64,.09,.65)

def crystal(name,base,r,h,lean,turn=0):
    v=[];n=6
    for z,rr in [(0,r*.75),(h*.64,r),(h*.74,r*.9)]:
        for j in range(n):
            a=TAU*j/n+turn
            v.append((rr*math.cos(a)+lean[0]*z/h,rr*math.sin(a)+lean[1]*z/h,z))
    v.append((lean[0]*1.18,lean[1]*1.18,h))
    f=[tuple(range(5,-1,-1))]
    for k in range(2):
        for j in range(n):f.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
    for j in range(n):f.append((12+j,12+(j+1)%n,18))
    o=mesh(name,v,f,CRYSTAL[0]);o.location=base
    for m in CRYSTAL[1:]:o.data.materials.append(m)
    for p in o.data.polygons:p.material_index=[2,0,3,1,4,2][p.index%6]
    return o

def make_crystals():
    new_asset('crystal_cluster_NEW','水晶簇','新增款；附草叶为本次重制')
    crystal('Tall_amethyst',(0,.08,.12),.34,1.78,(-.07,0),.2)
    crystal('Left_crystal',(-.41,-.05,.08),.23,.9,(-.25,-.04),.3)
    crystal('Right_crystal',(.44,.13,.11),.23,1.28,(.23,.03),.1)
    crystal('Small_front_shard',(-.12,-.26,.05),.16,.62,(-.09,-.1),.6)
    for i,(x,y,z,s) in enumerate([(.5,-.19,.26,.39),(-.26,-.34,.13,.24),(-.04,-.49,.08,.18)]):
        rock('Crystal_base_stone',(x,y,z),(s,s*.8,s*.85),i)
    grass(-.73,-.15,.7);grass(.92,.0,.78)

def mushroom(cx,cy,size):
    stem=tube('Mushroom_curved_stem',[(cx,cy,.04,.97),(cx-.07*size,cy,.23*size,.88),(cx+.02*size,cy,.62*size,.64),(cx,cy,.99*size,.72)],.19*size,STONE[2],4,2)
    z=.91*size;r=.74*size;h=.42*size
    prof=[(.005,z+h)]
    for i in range(1,14):
        theta=(math.pi*.51)*i/13
        prof.append((r*math.sin(theta),z+h*math.cos(theta)))
    prof.extend([(r*.91,z-.075*size),(.16*size,z-.08*size)])
    cap=lathe('Lilac_mushroom_cap',prof,LILAC,40,True);cap.location=(cx,cy,0)
    under=lathe('Mushroom_underside',[(.15*size,z-.083*size),(.63*size,z-.055*size)],STONE[2],40,True);under.location=(cx,cy,0)
    spots=[(-.22,-.25,.13),(.22,-.3,.12),(-.43,.04,.13),(.36,.13,.14),(0,.22,.16),(.02,-.02,.105)]
    for i,(xx,yy,rr) in enumerate(spots):
        xx*=size;yy*=size;rr*=size
        verts=[]
        for ring in range(5):
            rad=rr*ring/4
            for j in range(20):
                a=TAU*j/20
                x=xx+rad*math.cos(a);y=yy+rad*math.sin(a)
                zz=z+h*math.sqrt(max(.001,1-(x*x+y*y)/(r*r)))+.004*size
                verts.append((cx+x,cy+y,zz))
        faces=[]
        for k in range(4):
            for j in range(20):faces.append((k*20+j,k*20+(j+1)%20,(k+1)*20+(j+1)%20,(k+1)*20+j))
        mesh('Pale_cap_spot_%02d'%i,verts,faces,MUSHROOM_SPOT,True)

def make_mushrooms():
    new_asset('mushroom_cluster_REMADE','蘑菇丛','重制：项目已有蘑菇丛',['amethyst_mushroom_cluster.glb'])
    mushroom(.29,.12,1.1);mushroom(-.59,-.13,.62)
    grass(-.84,-.23,.62);grass(.99,.15,.89)
    rock('Mushroom_small_rock',(-.32,-.39,.09),(.2,.16,.14),3)
    rock('Mushroom_side_rock',(.66,-.29,.11),(.22,.18,.17),0)

def make_shrub():
    new_asset('berry_shrub_REMADE','灌木丛','重制：项目已有紫色灌木',['purple_shrub.glb'])
    for i,(x,y,z,rx,rz,mi) in enumerate([(-.39,.15,.67,.57,.64,0),(.37,.17,.49,.5,.48,2),(-.88,-.02,.37,.41,.37,1),(-.55,-.25,.29,.42,.32,0),(.08,-.2,.3,.4,.36,2),(.68,-.15,.26,.37,.3,3),(-1.02,-.26,.15,.26,.21,0),(-.35,-.42,.14,.24,.19,1),(.38,-.4,.13,.25,.19,2),(.91,.03,.13,.24,.2,2)]):
        o=sphere('Rounded_shrub_lobe_%02d'%i,(x,y,z),(rx,rx*.72,rz),SHRUB[mi],20,12)
        for v in o.data.vertices:
            v.co.z=max(v.co.z,.025-z)
    grass(-.31,-.7,.67);grass(.82,-.5,.63)

def make_grass():
    new_asset('teal_grass_REMADE','青绿杂草（独立件）','重制：项目已有杂草；本批主体附草同源',['teal_grass_tuft.glb'])
    grass(0,0,1)

def evaluated_bounds(objects):
    bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    points=[]
    for o in objects:
        if o.type not in {'MESH','CURVE'}:continue
        ev=o.evaluated_get(dg)
        data=ev.to_mesh()
        points.extend(o.matrix_world @ v.co for v in data.vertices)
        ev.to_mesh_clear()
    return Vector(tuple(min(p[i] for p in points) for i in range(3))),Vector(tuple(max(p[i] for p in points) for i in range(3)))

def export_asset(asset):
    global ACTIVE
    root=asset['root']
    parts=[o for o in asset['collection'].objects if o!=root]
    # Trim the bottom of roots, stones and leaf bulbs to the common ground plane.
    # This prevents one rounded root from lifting every attached grass tuft.
    bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    for original in list(parts):
        lo,_=evaluated_bounds([original])
        if lo.z>=0:continue
        o=original
        if original.type=='CURVE':
            data=bpy.data.meshes.new_from_object(original.evaluated_get(dg),depsgraph=dg)
            o=bpy.data.objects.new(original.name+'_grounded',data)
            asset['collection'].objects.link(o);o.parent=root;o.matrix_world=original.matrix_world.copy()
            parts.remove(original);parts.append(o)
            bpy.data.objects.remove(original,do_unlink=True)
        world=o.matrix_world.copy();inv=world.inverted()
        for vertex in o.data.vertices:
            co=world @ vertex.co
            if co.z<0:
                co.z=0;vertex.co=inv @ co
        o.data.update()
    lo,hi=evaluated_bounds(parts)
    offset=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
    for o in parts:o.location-=offset
    bpy.context.view_layer.update()
    asset['dimensions_m']=[round(hi.x-lo.x,4),round(hi.z-lo.z,4),round(hi.y-lo.y,4)]
    saved_active=ACTIVE;ACTIVE=None
    eroot=bpy.data.objects.new(root.name+'_Root',None);bpy.context.scene.collection.objects.link(eroot)
    for key in root.keys():eroot[key]=root[key]
    bpy.ops.object.select_all(action='DESELECT')
    dg=bpy.context.evaluated_depsgraph_get()
    copies=[]
    for original in parts:
        data=bpy.data.meshes.new_from_object(original.evaluated_get(dg),depsgraph=dg)
        o=bpy.data.objects.new(original.name+'_export',data);bpy.context.scene.collection.objects.link(o)
        o.matrix_world=original.matrix_world.copy();o.select_set(True);copies.append(o)
    bpy.context.view_layer.objects.active=copies[0]
    bpy.ops.object.join()
    combined=bpy.context.object;combined.name=asset['key']+'_visual'
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    combined.parent=eroot
    # A single material surface per palette color minimizes static draw surfaces.
    combined.data.validate(verbose=False)
    combined.data.calc_loop_triangles()
    asset['triangles']=len(combined.data.loop_triangles)
    asset['source_parts']=len(parts)
    eroot.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(asset['key']+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_extras=True,export_apply=True,export_normals=True,export_texcoords=False)
    bpy.data.objects.remove(combined,do_unlink=True);bpy.data.objects.remove(eroot,do_unlink=True)
    ACTIVE=saved_active
    print('EXPORTED',asset['key'],asset['dimensions_m'],asset['triangles'],flush=True)

def setup_studio():
    global ACTIVE
    ACTIVE=None
    scene=bpy.context.scene
    scene.render.engine='CYCLES'
    scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.world.color=(.38,.38,.38)
    scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get('Background');bg.inputs['Color'].default_value=(.56,.53,.63,1);bg.inputs['Strength'].default_value=.45
    scene.view_settings.view_transform='Standard'
    floor=material('STUDIO_only_floor','E5E0EB',.85)
    cube('STUDIO_only_ground',(0,0,-.065),(200,200,.12),floor,.0)
    def area(name,loc,energy,size):
        d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.shape='DISK';d.size=size
        o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc
        o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
    area('STUDIO_Key',(-3,-4,7),450,5)
    area('STUDIO_Fill',(4,-1,4),190,4)
    area('STUDIO_Rim',(1,4,6),330,3)
    d=bpy.data.cameras.new('STUDIO_Camera');cam=bpy.data.objects.new('STUDIO_Camera',d);scene.collection.objects.link(cam)
    scene.camera=cam;d.type='ORTHO';d.lens=50
    scene.render.film_transparent=False
    return cam

def render_glbs():
    # A fresh scene proves that previews use the exported artifact, not source-only modifiers.
    global ACTIVE
    ACTIVE=None
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    cam=setup_studio()
    validation=[]
    for asset in ASSETS:
        before=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(OUT/(asset['key']+'.glb')))
        imported=set(bpy.data.objects)-before
        lo,hi=evaluated_bounds(imported)
        dims=hi-lo
        assert abs(lo.z)<.0001,(asset['key'],'ground',lo)
        assert abs((lo.x+hi.x)/2)<.0001 and abs((lo.y+hi.y)/2)<.0001,(asset['key'],'center',lo,hi)
        assert all(o.type in {'MESH','EMPTY'} for o in imported)
        for o in imported:
            assert o.rigid_body is None
        target=Vector((0,0,dims.z*.48))
        cam.location=target+Vector((4,-7,3.6))
        cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.data.ortho_scale=max(dims.z*1.23,dims.x*.95+dims.y*.62)*1.13
        bpy.context.scene.render.filepath=str(RENDERS/(asset['key']+'.png'))
        bpy.ops.render.render(write_still=True)
        # Front view additionally checks the three small candy props.
        if asset['key'].startswith(('candy_','pumpkin_')):
            cam.location=target+Vector((0,-8,.8))
            cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
            bpy.context.scene.render.filepath=str(RENDERS/(asset['key']+'_front.png'))
            bpy.ops.render.render(write_still=True)
        validation.append({'file':asset['key']+'.glb','roundtrip_import':'passed','ground_center':'passed','bounds_blender':[list(lo),list(hi)],'object_types':sorted(set(o.type for o in imported))})
        for o in imported:bpy.data.objects.remove(o,do_unlink=True)
        print('PREVIEW_VERIFIED',asset['key'],flush=True)
    (SOURCE/'roundtrip_validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2),encoding='utf-8')

def main():
    global ACTIVE
    if '--render-only' in sys.argv:
        data=json.loads((OUT/'model_info.json').read_text(encoding='utf-8'))
        ASSETS.extend({'key':Path(a['file']).stem} for a in data['assets'])
        render_glbs()
        print('REFERENCE_PREVIEWS_COMPLETE',len(ASSETS),flush=True)
        return
    for fn in [make_crate,make_barrel,make_pumpkin,make_tree,make_wall,make_arch,make_tombstone,make_fence,make_lantern,make_crystals,make_mushrooms,make_shrub,make_grass]:
        fn()
        print('BUILT',ASSETS[-1]['key'],flush=True)
        export_asset(ASSETS[-1])
    ACTIVE=None
    for i,a in enumerate(ASSETS):
        a['root'].location=((i%4)*4.3,-(i//4)*4.4,0)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.scene.camera=None
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                space=area.spaces.active
                space.shading.type='SOLID';space.shading.color_type='MATERIAL'
                space.shading.show_cavity=True
                space.region_3d.view_location=(6.45,-6.6,1)
                space.region_3d.view_distance=21
                space.region_3d.view_rotation=Vector((4,-7,6)).to_track_quat('Z','Y')
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'reference_sheet_01.blend'))
    manifest={'title':'参考图第1页：12款主体 + 1款独立杂草','excluded':['右上角糖果礼盒'],'date':'2026-11-10','blender':bpy.app.version_string,'units':'meters; authored approximate game prop scale, reference has no measured scale','axes':{'up':'+Y','front':'+Z','origin':'horizontal bounding-box center at minimum Y; root translation 0, rotation identity, scale 1'},'collision':'none','game_integration':'not connected; no scene/script/config changes','materials':'embedded glTF PBR solid-color materials, no external textures','remade_note':'REMADE files are newly modeled alternatives; existing assets have not been overwritten. Grass in all composite props is also remade.','source':'art_source/reference_sheet_01/reference_sheet_01.blend','assets':[]}
    for a in ASSETS:
        manifest['assets'].append({'file':a['key']+'.glb','name_zh':a['label'],'status':a['status'],'existing_related':a['related'],'dimensions_xyz_m':a['dimensions_m'],'triangles':a['triangles'],'editable_source_parts':a['source_parts']})
    (OUT/'model_info.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    render_glbs()
    print('REFERENCE_SHEET_COMPLETE',len(ASSETS),flush=True)

if __name__=='__main__':main()



