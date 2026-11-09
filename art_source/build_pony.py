"""Offline editable pony carriage. Do not rerun over an artist-edited master."""
from pathlib import Path
import sys, math
sys.path.insert(0, str(Path(__file__).resolve().parent))
from companion_authoring import *

clear_scene()
cream=material('Pony - ivory porcelain','FFF0D9',.48)
pink=material('Pony - rose muzzle','EBA6BB',.48)
purple=material('Carriage - plum enamel','795199',.42)
lavender=material('Roof - lilac','B084CA',.44)
mane_mat=material('Mane - grape silk','6D458F',.46)
deep=material('Chassis - blackberry','463052',.5)
gold=material('Metal - honey gold','DBA45D',.36,.30)
ivory_gold=material('Gold inlay','F9CE7B',.4)
window=material('Windows - candle glow','FFD088',.35,glow=.55)
dark=material('Eyes - aubergine','282035',.3)
white=material('Eyes - highlight','FFFFFF',.25)
rubber=material('Tyres - muted purple','665071',.48)

root=empty('PonyArt')
coach=empty('Coach', (0,.24,.28),root)
head=empty('Head', (0,-.60,.92),root)
tail=empty('Tail', (0,-.08,.66),root)
bonus=empty('BonusMarker',(0,-.94,1.40),root)
root.scale=(.78,)*3

# Soft pumpkin-shaped carriage behind the seated pony.
v,f=[],[]
for j in range(33):
    phi=math.pi*(.001+.998*j/32)
    for i in range(64):
        a=i*math.tau/64
        r=math.sin(phi)**.83*(1+.055*math.cos(8*a))
        v.append((.67*r*math.cos(a),.57*r*math.sin(a),.68+.65*math.cos(phi)))
for j in range(32):
    for i in range(64):
        a=j*64+i;b=j*64+(i+1)%64
        f.append((a,b,b+64,a+64))
f.extend([tuple(range(63,-1,-1)),tuple(32*64+i for i in range(64))])
shell=mesh('CoachShell',v,f,purple,coach)
sphere('RoofCushion',(0,0,1.19),(.57,.47,.19),lavender,coach)
for side in (-1,1):
    # Raised arched side windows sit in a gold frame; separate mullions are editable.
    frame=sphere('WindowFrame',(side*.638,-.03,.72),(.055,.32,.39),gold,coach)
    sphere('WindowGlass',(side*.684,-.03,.72),(.018,.268,.325),window,coach)
    cube('WindowVertical',(side*.704,-.03,.72),(.032,.035,.61),gold,coach,.01)
    cube('WindowHorizontal',(side*.704,-.03,.70),(.032,.51,.035),gold,coach,.01)
    tube('RoofRib',[(side*.56,0,.94),(side*.51,0,1.18),(side*.28,0,1.34),(0,0,1.37)],.023,gold,coach)
    tube('RoofSideTrim',[(side*.50,-.28,1.17),(side*.31,-.41,1.32),(0,-.44,1.37)],.018,gold,coach)
# Rear door and carved crossbar are visible when the model rotates.
sphere('BackDoorFrame',(0,.55,.65),(.31,.045,.43),gold,coach)
sphere('BackDoor',(0,.59,.65),(.26,.018,.37),deep,coach)
cube('BackDoorHandle',(.14,.62,.65),(.08,.03,.025),gold,coach,.01)
star('BackDoorStar',(0,.62,.84),.10,ivory_gold,coach).rotation_euler.z=math.pi

cube('Underframe',(0,-.15,.24),(1.48,1.82,.20),deep,root,.10)
cube('FrontSeat',(0,-.68,.37),(1.04,.78,.13),purple,root,.065)
tube('FrontRail',[(-.68,-.52,.37),(-.59,-.95,.36),(0,-1.10,.32),(.59,-.95,.36),(.68,-.52,.37)],.07,purple,root)
tube('RailInlay',[(-.59,-.83,.39),(0,-1.12,.36),(.59,-.83,.39)],.012,gold,root,2)
star('FrontStar',(0,-1.18,.34),.14,ivory_gold,root)

# Pony: short legs, round muzzle, separate ears, mane curls and bright eyes.
sphere('PonyBody',(0,-.57,.66),(.30,.40,.35),cream,root)
for x in (-.18,.18):
    sphere('Foreleg',(x,-.80,.49),(.09,.11,.23),cream,root)
    sphere('Hoof',(x,-.84,.325),(.105,.14,.075),mane_mat,root)
    sphere('HindLeg',(x,-.36,.44),(.12,.15,.19),cream,root)
sphere('PonyNeck',(0,.035,.05),(.24,.24,.31),cream,head)
sphere('PonyHead',(0,-.12,.28),(.31,.30,.34),cream,head)
sphere('Muzzle',(0,-.39,.15),(.285,.22,.185),pink,head)
for side in (-1,1):
    ear=sphere('Ear',(side*.205,-.025,.57),(.104,.095,.245),cream,head)
    ear.rotation_euler.y=side*.20
    inner=sphere('InnerEar',(side*.205,-.092,.59),(.057,.022,.155),pink,head)
    inner.rotation_euler.y=side*.20
    eye=sphere('Eye',(side*.245,-.29,.32),(.068,.042,.095),dark,head)
    eye.rotation_euler.z=side*.3
    sphere('EyeSpark',(side*.246-.014,-.329,.35),(.019,.012,.028),white,head,16,10)
    sphere('Nostril',(side*.13,-.588,.17),(.030,.012,.023),mane_mat,head,16,10)
    sphere('Cheek',(side*.255,-.35,.15),(.05,.015,.03),pink,head,16,10)
tube('Smile',[(-.09,-.594,.07),(0,-.61,.045),(.09,-.594,.07)],.008,mane_mat,head,2)
for i in range(5):
    sphere('Fringe',(-.23+i*.115,-.245,.51-.025*abs(i-2)),(.115,.10,.14),mane_mat,head)
for i in range(5):
    sphere('ManeCurl',(.245,.02+i*.045,.38-i*.13),(.13,.12,.145),mane_mat,head)
tube('TailSilk',[(0,0,.03),(.18,.11,.01),(.33,.04,-.10),(.32,-.10,-.17),(.20,-.14,-.15)],.08,mane_mat,tail)
tube('Harness',[(-.27,-.45,.88),(-.22,-.72,.80),(0,-.91,.76),(.22,-.72,.80),(.27,-.45,.88)],.033,gold,root)
star('HarnessBadge',(0,-.933,.76),.075,ivory_gold,root)

wheels=[]
for side, letter in ((-1,'L'),(1,'R')):
    for y,end in ((-.67,'F'),(.56,'B')):
        w=empty('Wheel'+end+letter,(side*.73,y,.215),root)
        wheels.append(w)
        cylinder('Tyre',(0,0,0),.215,.15,rubber,w)
        cylinder('Rim',(side*.083,0,0),.17,.024,gold,w)
        cylinder('WheelDisk',(side*.10,0,0),.145,.02,purple,w)
        for i in range(6):
            a=i*math.tau/6
            spoke=cube('Spoke',(side*.122,.067*math.sin(a),.067*math.cos(a)),(.025,.035,.13),gold,w,.012)
            spoke.rotation_euler.x=-a
        sphere('Hub',(side*.14,0,0),(.035,.048,.048),ivory_gold,w,20,12)

# Bows and lanterns supply the Halloween carriage silhouette.
bow=empty('Bow',(0,.30,1.65),root)
for side in (-1,1):
    wing=sphere('BowLoop',(side*.17,0,.015),(.20,.10,.12),mane_mat,bow)
    wing.rotation_euler.y=side*-.28
sphere('BowKnot',(0,-.04,.015),(.075,.065,.075),gold,bow)
top_lantern=lantern('RoofLantern',(0,.26,2.12),gold,window,purple,root,.94)
side_lanterns=[]
for side in (-1,1):
    tube('LanternArm',[(side*.53,.02,1.17),(side*.77,-.03,1.24),(side*.83,-.10,1.12)],.025,gold,root)
    side_lanterns.append(lantern('LanternL' if side<0 else 'LanternR',(side*.83,-.10,1.12),gold,window,purple,root,.65))
for i,(x,z,r) in enumerate([(-.16,.02,.065),(.11,.14,.09)]):
    star('BonusStar'+str(i),(x,0,z),r,ivory_gold,bonus)

clip(head,'pickup',{'rotation_euler':[(1,(0,0,0)),(7,(-.20,0,0)),(15,(.07,0,0)),(23,(0,0,0))]})
clip(tail,'pickup',{'rotation_euler':[(1,(0,0,0)),(7,(0,.1,-.25)),(15,(0,-.05,.18)),(23,(0,0,0))]})
for lantern_obj in side_lanterns:
    clip(lantern_obj,'pickup',{'rotation_euler':[(1,(0,0,0)),(8,(.15,0,0)),(16,(-.10,0,0)),(23,(0,0,0))]})
finish_asset('pony',root,[head,tail,coach,bow,bonus,*side_lanterns,top_lantern,*wheels,root],.9,3.25)
