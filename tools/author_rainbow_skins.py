"""One-shot metadata authoring; reads generated alpha, never edits source images."""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'features/rainbow/art'
OUT = ROOT / 'features/rainbow/data/skins'
IDS = ['merchant','guard','teppo','gunner','mage','healer','supplier','controller','ninja','kohime','malfory']

def split_boundary(values, expected, radius):
    lo,hi=max(0,expected-radius),min(len(values),expected+radius)
    return min(range(lo,hi),key=lambda i:(values[i],abs(i-expected)))

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    report = {}
    for name in IDS:
        target=OUT/(name+'.tres')
        if target.exists(): raise SystemExit('Refusing to overwrite authored layout: '+str(target))
        image=Image.open(ART/(name+'-v1.png')).convert('RGBA')
        alpha=image.getchannel('A'); w,h=image.size
        mask=alpha.point(lambda a:255 if a>48 else 0)
        row_mass=[sum(mask.crop((0,y,w,y+1)).getdata()) for y in range(h)]
        ys=[0]+[split_boundary(row_mass,round(h*r/4),35) for r in range(1,4)]+[h]
        rects=[]; pivots=[]; crops=[]
        for row in range(4):
            y0,y1=ys[row:row+2]
            mass=[sum(mask.crop((x,y0,x+1,y1)).getdata()) for x in range(w)]
            xs=[0]+[split_boundary(mass,round(w*c/4),65) for c in range(1,4)]+[w]
            for col in range(4):
                x0,x1=xs[col:col+2]
                bbox=mask.crop((x0,y0,x1,y1)).getbbox()
                if not bbox: raise ValueError((name,row,col,'empty'))
                left,top,right,bottom=bbox
                left=max(0,left-2);top=max(0,top-2);right=min(x1-x0,right+2);bottom=min(y1-y0,bottom+2)
                rect=(x0+left,y0+top,right-left,bottom-top)
                width=right-left; height=bottom-top
                pixels=list(alpha.crop((x0+left,y0+top+int(height*.78),x0+right,y0+bottom)).getdata())
                weights=[sum(pixels[k::width]) for k in range(width)]
                px=sum(k*v for k,v in enumerate(weights))/max(1,sum(weights))
                pivots.append((px,bottom-top-2))
                rects.append(rect)
                crops.append({'row':row,'column':col,'rect':rect,'pivot':pivots[-1]})
        text='[gd_resource type="Resource" script_class="SpriteSheetLayout" load_steps=9 format=3]\n\n'
        text+='[ext_resource type="Script" path="res://common/data/sprite_sheet_layout.gd" id="1"]\n'
        text+='[ext_resource type="Script" path="res://common/data/sprite_animation_clip.gd" id="2"]\n'
        text+=f'[ext_resource type="Texture2D" path="res://features/rainbow/art/{name}-v1.png" id="3"]\n\n'
        for index,(columns,fps,loop) in enumerate([([0],3,True),([1,0,2,0],9,True),([0,3,0],9,False),([0,3,0],7,False),([0],1,False)]):
            text+=f'[sub_resource type="Resource" id="clip{index}"]\nscript = ExtResource("2")\naction = {index}\ncolumns = PackedInt32Array({", ".join(map(str,columns))})\nfps = {fps}.0\nloop = {str(loop).lower()}\n\n'
        text+='[resource]\nscript = ExtResource("1")\nsource_texture = ExtResource("3")\n'
        text+=f'source_size = Vector2i({w}, {h})\ncolumns = 4\nrows = 4\nframe_size = Vector2i(512, 400)\nfoot_point = Vector2(256, 360)\n'
        text+='frame_rects = Array[Rect2i](['+', '.join('Rect2i(%d, %d, %d, %d)'%r for r in rects)+'])\n'
        text+='source_pivots = Array[Vector2](['+', '.join('Vector2(%.1f, %.1f)'%p for p in pivots)+'])\n'
        text+='direction_rows = Array[int]([0, 0, 0, 1, 1, 3, 3, 2])\n'
        text+='animations = Array[ExtResource("2")](['+', '.join(f'SubResource("clip{i}")' for i in range(5))+'])\n'
        target.write_text(text,encoding='utf-8')
        report[name]={'size':image.size,'frames':crops,'directions':'4 painted directions mapped to 8; cast reuses attack; death uses ready frame with runtime tilt'}
    (ROOT/'artifacts/rainbow-content/atlas-audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('Authored',len(report),'native layouts; source PNGs unchanged')

if __name__=='__main__': main()
