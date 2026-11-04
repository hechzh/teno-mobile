"""Export the existing Teno Android waveform mark to Apple asset sizes (Pillow)."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1] / 'ios/Teno/Assets.xcassets'
root.mkdir(parents=True, exist_ok=True)
(root / 'Contents.json').write_text(json.dumps({'info':{'version':1,'author':'xcode'}}), encoding='utf-8')
folder = root / 'AppIcon.appiconset'
folder.mkdir(exist_ok=True)
icon = Image.new('RGB', (2048,2048), '#20251F')
draw = ImageDraw.Draw(icon)
scale=2048/48
for x,a,b in [(13,21,27),(20,14,34),(27,18,30),(34,22,26)]:
    r=1.75*scale
    draw.rounded_rectangle((x*scale-r,a*scale-r,x*scale+r,b*scale+r), radius=r, fill='white')
entries=[]
for idiom,sizes,scales in [('iphone',[20,29,40,60],[2,3]),('ipad',[20,29,40,76],[1,2]),('ipad',[83.5],[2]),('ios-marketing',[1024],[1])]:
    for size in sizes:
        for multiplier in scales:
            pixels=round(size*multiplier)
            name=f'icon-{pixels}.png'
            icon.resize((pixels,pixels),Image.Resampling.LANCZOS).save(folder/name)
            entries.append({'idiom':idiom,'size':f'{size}x{size}','scale':f'{multiplier}x','filename':name})
(folder/'Contents.json').write_text(json.dumps({'images':entries,'info':{'version':1,'author':'xcode'}},indent=2),encoding='utf-8')
