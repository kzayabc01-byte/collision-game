"""Offline slime with a real morph target, separate feet and a folding witch hat."""
from pathlib import Path
import sys,math
sys.path.insert(0,str(Path(__file__).resolve().parent))
from companion_authoring import *

clear_scene()
jelly=material('Jelly - violet glaze','9B6BC3',.20,coat=.65)
blue=material('Jelly - aqua highlights','9BE6E6',.24,glow=.08,coat=.5)
purple=material('Hat - midnight violet','65347F',.44)
band=material('Hat - peach ribbon','D79578',.5)
gold=material('Stars - warm vanilla','FFD28B',.38,glow=.4)
gold_metal=material('Buckle - old gold','DEA66B',.35,.3)
pink=material('Cheeks - rose jelly','ECA5DC',.30)
white=material('Jelly - soft shine','E7D9FF',.28,glow=.1)
root=empty('SlimeArt')
root.scale=(.94,)*3
roll=empty('RollRoot',(0,0,.70),root)
face=empty('Face',(0,-.65,0),roll)
hat=empty('Hat',(0,0,.58),roll)

# A puddle-shaped profile morphs continuously into a round rolling volume.
profile=[(-.68,.04),(-.64,.53),(-.58,.74),(-.46,.78),(-.25,.73),(0,.68),(.23,.60),(.43,.47),(.56,.30),(.63,.13),(.65,.003)]
control_profile = profile
profile = []
for sample in range(41):
    t = sample * (len(control_profile)-1) / 40
    index = min(int(t), len(control_profile)-2)
    u = t-index
    p0,p1,p2,p3 = [Vector(control_profile[max(0,min(len(control_profile)-1,index+k))]) for k in (-1,0,1,2)]
    point = .5*((2*p1)+(-p0+p2)*u+(2*p0-5*p1+4*p2-p3)*u*u+(-p0+3*p1-3*p2+p3)*u*u*u)
    profile.append((point.x,max(.003,point.y)))
vertices,faces=[],[]
segments=64
for j,(z,r) in enumerate(profile):
    petal=.10*math.exp(-((z+.58)/.16)**2)
    for i in range(segments):
        a=i*math.tau/segments
        radius=r*(1+petal*math.cos(6*a))
        vertices.append((radius*math.cos(a),radius*math.sin(a),z))
for j in range(len(profile)-1):
    for i in range(segments):
        a=j*segments+i;b=j*segments+(i+1)%segments
        faces.append((a,a+segments,b+segments,b))
faces.extend([tuple(range(segments-1,-1,-1)),tuple((len(profile)-1)*segments+i for i in range(segments))])
body=mesh('JellyBody',vertices,faces,jelly,roll)
body.shape_key_add(name='Basis')
round_key=body.shape_key_add(name='Round')
for j in range(len(profile)):
    phi=math.pi*(.001+.998*j/(len(profile)-1))
    for i in range(segments):
        a=i*math.tau/segments
        round_key.data[j*segments+i].co=(.68*math.sin(phi)*math.cos(a),.68*math.sin(phi)*math.sin(a),-.68*math.cos(phi))

# Face and surface marks turn with the body, making the rolling motion legible.
tube('EyeL',[(-.31,-.006,.20),(-.20,-.025,.145),(-.31,-.006,.085)],.023,gold,face)
tube('EyeR',[(.31,-.006,.20),(.20,-.025,.145),(.31,-.006,.085)],.023,gold,face)
tube('Mouth',[(-.10,-.035,-.015),(-.05,-.045,.025),(0,-.047,-.015),(.05,-.045,.025),(.10,-.035,-.015)],.016,gold,face)
for side in (-1,1):
    sphere('Cheek',(side*.35,.015,.02),(.065,.018,.032),pink,face,20,12)
    s=star('BodyStar',(side*.46,-.51,.13),.085,gold,roll,.009)
    s.rotation_euler.z=-side*.65
for i,(loc,scale) in enumerate([((-.22,-.42,.47),(.17,.025,.065)),((-.42,-.37,.33),(.065,.02,.045)),((.59,.16,.20),(.025,.085,.12)),((.33,.55,-.18),(.07,.025,.07))]):
    sphere('RollingShine'+str(i),loc,scale,white if i<2 else blue,roll,24,12)

feet=[]
for side,letter in ((-1,'L'),(1,'R')):
    foot=empty('Foot'+letter,(side*.32,-.14,.13),root)
    foot.scale=(.20,.25,.14)
    sphere('FootMesh',(0,0,0),(1,1,1),blue,foot,24,14)
    feet.append(foot)

# Thick wavy brim and a curved cone, both genuine editable meshes.
verts,polys=[],[]
for j in range(5):
    r=.24+j*.16
    for i in range(64):
        a=i*math.tau/64
        verts.append((r*math.cos(a),r*.91*math.sin(a),.035*math.cos(a*3)+.045*(r/.88)**2))
for j in range(4):
    for i in range(64):
        a=j*64+i;b=j*64+(i+1)%64
        polys.append((a,b,b+64,a+64))
brim=mesh('HatBrim',verts,polys,purple,hat)
bpy.context.view_layer.objects.active=brim
mod=brim.modifiers.new('Brim thickness','SOLIDIFY');mod.thickness=.035
bpy.ops.object.modifier_apply(modifier=mod.name)
mod=brim.modifiers.new('Rounded brim','BEVEL');mod.width=.018;mod.segments=3
bpy.ops.object.modifier_apply(modifier=mod.name)
centers=[(0,0,0,.43),(.01,.01,.18,.38),(.045,.025,.37,.31),(.12,.04,.57,.24),(.25,.045,.76,.17),(.43,.04,.91,.12),(.59,.02,.90,.075),(.60,.01,.79,.025),(.54,.0,.75,.003)]
verts,polys=[],[]
for center_index,(x,y,z,r) in enumerate(centers):
    before = Vector(centers[max(0,center_index-1)][:3])
    after = Vector(centers[min(len(centers)-1,center_index+1)][:3])
    tangent = (after-before).normalized()
    axis_u = Vector((0,1,0)).cross(tangent).normalized()
    axis_v = tangent.cross(axis_u).normalized()
    for i in range(48):
        a=i*math.tau/48
        verts.append(tuple(Vector((x,y,z))+r*(math.cos(a)*axis_u+math.sin(a)*axis_v)))
for j in range(len(centers)-1):
    for i in range(48):
        a=j*48+i;b=j*48+(i+1)%48
        polys.append((a,b,b+48,a+48))
polys.extend([tuple(range(47,-1,-1)),tuple((len(centers)-1)*48+i for i in range(48))])
cone=mesh('BentHatCone',verts,polys,purple,hat)
bpy.context.view_layer.objects.active=cone
mod=cone.modifiers.new('Soft cloth silhouette','SUBSURF');mod.levels=2
bpy.ops.object.modifier_apply(modifier=mod.name)
for z,r in ((.10,.415),(.23,.364)):
    tube('RibbonEdge',[(r*math.cos(i*math.tau/16)+.012,r*math.sin(i*math.tau/16),z) for i in range(17)],.016,gold_metal,hat)
verts,polys=[],[]
for z,r in ((.10,.415),(.23,.364)):
    for i in range(48):
        a=i*math.tau/48
        verts.append((.012+r*math.cos(a),r*math.sin(a),z))
for i in range(48):
    polys.append((i,(i+1)%48,(i+1)%48+48,i+48))
mesh('PeachRibbon',verts,polys,band,hat)
for x in (-.09,.09):
    cube('BuckleVertical',(x,-.409,.17),(.028,.035,.18),gold_metal,hat,.01)
for z in (.095,.245):
    cube('BuckleHorizontal',(0,-.409,z),(.20,.035,.028),gold_metal,hat,.01)
star('HatStar',(.10,-.245,.58),.10,gold,hat,.008)

# The normalized pose clip drives the in-game morph and folded hat.
clip(hat,'roll_pose',{'location':[(1,(0,0,.58)),(61,(0,0,.35))],
                      'scale':[(1,(1,1,1)),(61,(.55,.55,.10))]})
shape_clip(body,'roll_pose','Round',[(1,0.),(61,1.)])
clip(face,'pickup',{'scale':[(1,(1,1,1)),(7,(1.15,1.15,1.15)),(18,(1,1,1))]})
# A separate authoring demo is retained for inspection in Blender and Godot.
clip(roll,'movement_demo',{'rotation_euler':[(1,(0,0,0)),(31,(0,0,0)),(91,(math.tau,0,0)),(151,(math.tau*2,0,0)),(181,(math.tau*2,0,0))]})
clip(hat,'movement_demo',{'location':[(1,(0,0,.58)),(31,(0,0,.35)),(151,(0,0,.35)),(181,(0,0,.58))],
                         'scale':[(1,(1,1,1)),(31,(.55,.55,.1)),(151,(.55,.55,.1)),(181,(1,1,1))]})
shape_clip(body,'movement_demo','Round',[(1,0.),(31,1.),(151,1.),(181,0.)])
for foot in feet:
    original=tuple(foot.scale)
    clip(foot,'movement_demo',{'scale':[(1,original),(31,(.001,)*3),(151,(.001,)*3),(181,original)]})
finish_asset('slime',root,[face,hat,roll],.95,3.2)
