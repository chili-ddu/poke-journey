"""Four chairs per dining table; rug reconstruction excludes its bottom border."""
def definitions(name):
    if name not in ['players_house_1f','rivals_house','pewter_house1','pewter_house2']:
        return []
    dx=-16 if name.startswith('pewter') else 0
    result=[]
    for side,x in [('left',80+dx),('right',128+dx)]:
        for row,y in enumerate([64,80]):
            result.append(dict(kind='card',object_id=f'chair_{side}_{row}',x0=x,x1=x+16,
                top=y,bottom=y+16,z0=y/16,z1=(y+16)/16,base=0,height=1,
                source_mask=True,rect=True,chair_side=side,floor_y=0,wall_x=0,
                floor_sample=[x//16,6],floor_sample_max_row=7,shadow=0))
    return result

def footprint(name):
    return [[s['x0']//16,s['top']//16] for s in definitions(name)]
