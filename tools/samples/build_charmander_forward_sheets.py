"""Export the transparent pixelfx layers used in the isolated forward-cast study."""
from pathlib import Path
import json
import subprocess

root = Path(__file__).resolve().parents[2]
checkout = root.parent/'pixelfx'
out = root/'docs/charmander_forward_casts/sheets'
effects = {
    'melee/claw-swipe': {'palette':['#45414a','#655a5b','#88766f','#a58f83','#c7b39f','#e2cdb5','#f2e6d3','#fff5e1'],'sparks':['#cbc0aa','#b9a58e','#a89888']},
    'melee/sword-slash': {'radius':35,'palette':['#434957','#5e6879','#8998a6','#aebdc7','#d2d9d6','#e7e9e0','#f8f6e9'],'sparks':['#d5cfc2','#aaa8a5']},
    'fire/fire-breath': {'spread':0.17,'palette':['#302841','#4f395e','#654264','#855b87','#a17ba2','#c0a5c5','#bcd5d9','#dfece7','#f4f1e2']},
    'fire/flamethrower': {'reach':112,'pilot':['#a44924','#e58737','#f9ce80'],'palette':['#532d2a','#883b29','#a44d2b','#c3662c','#de8538','#edab50','#f4c874','#f8dc98','#fff0c4']},
    'fire/fire-tornado': {'height':70}, 'fire/flame-pillar': {'height':110},
    'fire/fireball': {'radius':7}, 'explosions/smoke-bomb': {}
}
for effect, opts in effects.items():
    subprocess.run(['node','tools/render.mjs',effect,'--sheet','--no-actor','--fps','20','--max','6','--zoom','1','--opts',json.dumps(opts),'--out',str(out)],cwd=checkout,check=True)
subprocess.run(['node','tools/check.mjs',*effects],cwd=checkout,check=True)
