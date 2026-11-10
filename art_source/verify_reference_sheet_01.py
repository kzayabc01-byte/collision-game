"""Check the actual GLB bytes, then assemble a catalog from final Blender renders."""
from pathlib import Path
import json, struct, math, hashlib

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art_source/reference_sheet_01'
OUT=ROOT/'assets/models/reference_sheet_01'

def read_glb(path):
    raw=path.read_bytes()
    magic,version,length=struct.unpack_from('<III',raw)
    assert magic==0x46546C67 and version==2 and length==len(raw)
    chunks={};offset=12
    while offset<len(raw):
        length,kind=struct.unpack_from('<II',raw,offset);offset+=8
        chunks[kind]=raw[offset:offset+length];offset+=length
    return json.loads(chunks[0x4E4F534A]),chunks[0x004E4942],raw

def values(doc,binary,index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    ct={5121:'B',5123:'H',5125:'I',5126:'f'}[a['componentType']]
    count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    fmt='<'+ct*count;size=struct.calcsize(fmt)
    step=v.get('byteStride',size)
    start=v.get('byteOffset',0)+a.get('byteOffset',0)
    assert start+step*(a['count']-1)+size<=len(binary)
    return [struct.unpack_from(fmt,binary,start+i*step) for i in range(a['count'])]

def validate():
    info=json.loads((OUT/'model_info.json').read_text(encoding='utf-8'))
    assert len(info['assets'])==13
    result=[]
    for a in info['assets']:
        path=OUT/a['file'];doc,binary,raw=read_glb(path)
        assert not doc.get('animations') and not doc.get('skins') and not doc.get('cameras')
        assert all('uri' not in b for b in doc['buffers'])
        assert all('uri' not in im for im in doc.get('images',[]))
        assert not doc.get('extensions',{}).get('KHR_lights_punctual')
        roots=doc['scenes'][doc.get('scene',0)]['nodes'];assert len(roots)==1
        for n in doc['nodes']:
            assert n.get('translation',[0,0,0])==[0,0,0]
            assert n.get('rotation',[0,0,0,1])==[0,0,0,1]
            assert n.get('scale',[1,1,1])==[1,1,1]
            assert not any(s in n.get('name','').lower() for s in ['-col','-convcol','collision','rigidbody','staticbody'])
        assert doc['nodes'][roots[0]]['extras']['collision']=='none'
        points=[];triangles=0;front_points=[]
        for m in doc['meshes']:
            for p in m['primitives']:
                assert p.get('mode',4)==4
                vertices=values(doc,binary,p['attributes']['POSITION'])
                assert all(math.isfinite(c) for v in vertices for c in v)
                normals=values(doc,binary,p['attributes']['NORMAL'])
                assert len(normals)==len(vertices)
                assert all(math.isfinite(c) for v in normals for c in v)
                indices=values(doc,binary,p['indices'])
                assert len(indices)%3==0 and max(i[0] for i in indices)<len(vertices)
                triangles+=len(indices)//3;points.extend(vertices)
                mat=doc['materials'][p['material']]['name']
                if (a['file'].startswith('candy_crate') and mat=='Candy_Icing') or (a['file'].startswith(('candy_barrel','pumpkin_candy')) and mat=='Ink_DeepPlum'):
                    front_points.extend(vertices)
        lo=[min(v[i] for v in points) for i in range(3)]
        hi=[max(v[i] for v in points) for i in range(3)]
        assert abs(lo[1])<1e-5 and abs(hi[0]+lo[0])<1e-5 and abs(hi[2]+lo[2])<1e-5,(path.name,lo,hi)
        assert triangles==a['triangles'],(path.name,triangles,a['triangles'])
        front_z=sum(p[2] for p in front_points)/len(front_points) if front_points else None
        if front_z is not None:assert front_z>0,(path.name,front_z)
        result.append({'file':path.name,'result':'PASS','sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'triangles':triangles,'bounds_glTF_y_up':{'min':lo,'max':hi},'root_transform':'identity','origin_ground_center':'PASS','embedded_materials':'PASS','collision_nodes':'none','front_feature_mean_positive_z':front_z})
    report={'file_count':len(result),'all_passed':True,'total_triangles':sum(a['triangles'] for a in result),'files':result}
    (SOURCE/'glb_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('GLB_CHECK_PASSED',len(result),'files;',report['total_triangles'],'triangles')
    return info

def catalog(info):
    from PIL import Image,ImageDraw,ImageFont
    font_path=Path('C:/Windows/Fonts/msyh.ttc')
    def font(size):return ImageFont.truetype(str(font_path),size)
    w,h=1800,2110
    im=Image.new('RGB',(w,h),'#F5F1F8');draw=ImageDraw.Draw(im)
    draw.rounded_rectangle((50,40,1750,145),24,fill='#65507D')
    draw.text((80,56),'万圣糖果道具 · 第 1 页模型',font=font(43),fill='white')
    draw.text((82,111),'12 款主体 + 1 款独立杂草  /  GLB 实际渲染预览',font=font(20),fill='#E6DAF3')
    cell_w=420;cell_h=450;left=45;top=175
    for i,a in enumerate(info['assets'][:12]):
        x=left+(i%4)*435;y=top+(i//4)*cell_h
        draw.rounded_rectangle((x,y,x+cell_w,y+427),18,fill='white')
        p=SOURCE/'renders'/(Path(a['file']).stem+'.png')
        # Fit without distortion: crop a little empty floor instead of squashing geometry.
        with Image.open(p) as image:
            image=image.convert('RGB').crop((0,26,640,614))
            tile=image.resize((398,366),Image.Resampling.LANCZOS)
        im.paste(tile,(x+11,y+7))
        title=a['name_zh'];draw.text((x+17,y+377),title,font=font(27),fill='#42334F')
        remade='REMADE' in a['file']
        pill='重制' if remade else '新增'
        draw.rounded_rectangle((x+326,y+379,x+402,y+416),10,fill='#E9DCF5' if remade else '#DCEEEA')
        draw.text((x+341,y+382),pill,font=font(21),fill='#795A99' if remade else '#347B70')
    # Separate grass is an intentional repeat, with a prominent mapping legend.
    y=1550
    with Image.open(SOURCE/'renders/teal_grass_REMADE.png') as image:
        im.paste(image.convert('RGB').resize((360,360),Image.Resampling.LANCZOS),(55,y))
    draw.text((75,y+364),'青绿杂草 · 重制独立件',font=font(25),fill='#42334F')
    draw.text((465,y+12),'标记与交付约定',font=font(31),fill='#65507D')
    lines=[
        'NEW = 新增款    REMADE = 本次重新建模，保留旧资源',
        '重制：墓碑、围栏、路灯、蘑菇、灌木、杂草。',
        '南瓜糖桶是新增款；项目原有南瓜与本款用途不同。',
        '各主体附带的青绿草叶，也全部为本次重制。',
        'GLB：Y 向上，正面 +Z，原点位于地面中心，米制。',
        '不含碰撞、游戏逻辑或场景灯光；礼物盒未制作。',
        '材质内嵌；Blender 源文件保留可编辑分件。',
    ]
    for i,line in enumerate(lines):draw.text((465,y+70+i*43),line,font=font(25),fill='#66596F')
    draw.line((55,2015,1745,2015),fill='#D5CADF',width=2)
    draw.text((60,2042),'各卡片单独取景，展示比例不代表模型之间的实际尺寸。',font=font(22),fill='#8C7D98')
    out=SOURCE/'catalog.png';im.save(out)
    print('CATALOG',out)

if __name__=='__main__':
    import sys
    info=validate()
    if '--validate-only' not in sys.argv:catalog(info)
