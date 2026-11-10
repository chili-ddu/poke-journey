"""8-pose study: 4 exact keys + 4 landmark-guided nearest-pixel mids."""
from pathlib import Path
import json
import cv2
import numpy as np
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/charizard_eight_pose_study'


def landmarks(k):
    dx,dy=[(0,0),(1,1),(0,0),(0,2)][k]
    # A rigid head quad keeps expression intact. Wing vertices describe its
    # tip, leading joint, outer edge, trailing point and attachment.
    head=[(21+dx,4+dy),(35+dx,4+dy),(35+dx,18+dy),(22+dx,18+dy)]
    wing=[[(15,3),(17,12),(13,12),(14,24),(19,22)],
          [(15,5),(18,14),(14,13),(16,26),(20,23)],
          [(15,3),(17,12),(13,12),(14,24),(19,22)],
          [(18,4),(20,13),(12,16),(12,23),(20,23)]][k]
    limbs=[[(23,28),(26,20),(22,23)],[(20,28),(30,20),(23,24)],
           [(23,28),(26,20),(22,23)],[(28,27),(23,22),(23,25)]][k]
    tail=[[(10,10),(10,24)],[(12,8),(13,22)],[(10,10),(10,24)],[(9,17),(12,27)]][k]
    return np.array([(0,0),(79,0),(79,95),(0,95)]+[(x*2,y*2) for x,y in head+wing+limbs+tail],dtype=np.float32)


def midpoint(keys,k):
    other=(k+1)%4
    a,b=landmarks(k),landmarks(other);target=(a+b)/2
    # Opening/closing uses the more open wing as the texture source so the
    # intermediate membrane has actual source detail, not interpolated noise.
    take=k if k==3 or other!=3 else other
    regions=[[(15,3),(17,6),(18,12),(19,16),(16,24),(14,25),(12,23),(12,10),(14,6)],
             [(15,5),(17,9),(19,15),(19,21),(18,27),(15,26),(14,21),(13,14),(12,10)],
             [(15,3),(17,6),(18,12),(19,16),(16,24),(14,25),(12,23),(12,10),(14,6)],
             [(18,4),(20,8),(21,13),(22,18),(19,23),(12,24),(11,21),(11,15),(14,11),(16,8)]]
    def wingmask(key):
        mask=np.zeros((96,80),np.uint8)
        cv2.fillPoly(mask,[np.array(regions[key],np.int32)*2],255)
        # Keep the supplied face and arm/leg side completely outside warping.
        mask[:42,42:]=0
        mask[52:,:]=0
        return mask
    source=landmarks(take);pixels=np.array(keys[take]);out=np.zeros_like(pixels)
    pixels[wingmask(take)==0]=0
    sub=cv2.Subdiv2D((0,0,80,96))
    for p in target:sub.insert(tuple(map(float,p)))
    for triangle in sub.getTriangleList().reshape(-1,3,2):
        ids=[int(np.linalg.norm(target-p,axis=1).argmin()) for p in triangle]
        if max(float(np.linalg.norm(target[i]-p)) for i,p in zip(ids,triangle))>.1:continue
        matrix=cv2.getAffineTransform(source[ids],target[ids])
        warped=cv2.warpAffine(pixels,matrix,(80,96),flags=cv2.INTER_NEAREST,borderMode=cv2.BORDER_CONSTANT)
        mask=np.zeros((96,80),np.uint8)
        cv2.fillConvexPoly(mask,np.rint(target[ids]).astype(np.int32),255)
        out[mask>0]=warped[mask>0]
    out[out[:,:,3]==0]=0
    # Only wings gain new geometry. Keep the original four body/face/limb
    # poses instead of accepting warped eyes or changing hands/feet anatomy.
    body=np.array(keys[k]);body[wingmask(k)>0]=0
    keep=body[:,:,3]>0
    out[keep]=body[keep]
    return Image.fromarray(out)


def main():
    report=[]
    for action,ticks in [('idle',[15]*4),('walk',[8,10,8,10])]:
        folder=OUT/f'pixelfx/local-review/charizard-wing-poses-keys-{action}'
        name=f'charizard-wing-poses-keys-{action}'
        meta=json.loads((folder/f'{name}.json').read_text());sheet=Image.open(folder/f'{name}.png').convert('RGBA')
        keys=[];start=0
        (OUT/f'{action}/keys').mkdir(parents=True,exist_ok=True)
        (OUT/f'{action}/frames').mkdir(exist_ok=True)
        for k,tick in enumerate(ticks):
            index=start+tick//2;start+=tick;r=meta['frames'][index]['frame']
            im=sheet.crop((r['x']+16,r['y']+16,r['x']+96,r['y']+112))
            im.save(OUT/f'{action}/keys/{k:03}.png');keys.append(im)
        eight=[]
        for k,a in enumerate(keys):
            b=keys[(k+1)%4]
            mid=midpoint(keys,k)
            pal=set(a.get_flattened_data())|set(b.get_flattened_data())
            assert all(c[3] in [0,255] and (c[3]==0 or c in pal) for c in mid.get_flattened_data())
            eight.extend([a,mid])
        cumulative=0;last=0;durations=[];panels=[]
        for i,im in enumerate(eight):
            im.save(OUT/f'{action}/frames/{i:03}.png')
            if i%2==0:assert im.tobytes()==keys[i//2].tobytes()
            cumulative+=ticks[i//2]/2;target=round(cumulative*1000/60/10)*10
            durations.append(target-last);last=target
            board=Image.new('RGB',(512,400),(46,56,51));d=ImageDraw.Draw(board)
            for side,(label,pic) in enumerate([('4 SOURCE POSES / WING FIX',keys[i//2]),('8 WING POSES / BODY UNWARPED',im)]):
                d.text((side*256+7,10),label,fill=(238,233,218))
                large=pic.resize((240,288),Image.Resampling.NEAREST)
                board.paste(large,(side*256+8,34),large)
                tiny=pic.resize((40,48),Image.Resampling.NEAREST);board.paste(tiny,(side*256+52,343),tiny)
                native=pic;board.paste(native,(side*256+150,300),native)
            d.text((8,326),f'{action.upper()} / '+('SOURCE KEY' if i%2==0 else 'LANDMARK MIDPOINT'),fill=(200,207,199))
            panels.append(board)
        panels[0].save(OUT/f'{action}-4-vs-8.gif',save_all=True,append_images=panels[1:],duration=durations,loop=0,disposal=2)
        contact=Image.new('RGB',(512,400*8))
        for i,p in enumerate(panels):contact.paste(p,(0,i*400))
        contact.save(OUT/f'{action}-all-poses.png')
        report.append(dict(action=action,source_keys=4,auto_midpoints=4,durations_ms=durations,
                           loop_ms=sum(durations),source_key_pixels_unchanged=True,
                           palette_locked=True,binary_alpha=True))
    (OUT/'motion-checks.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report))


if __name__=='__main__':main()
