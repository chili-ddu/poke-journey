"""Source-aligned stair components. Rail elevation/depth are rendering assumptions."""
def definitions(name):
    if name not in ['players_house_1f','players_house_2f']:
        return []
    def item(label, bounds, mode, **kwargs):
        x0,y0,x1,y1=bounds
        return dict(kind='card',object_id=label,x0=x0,x1=x1,top=y0,bottom=y1,
                    source_mask=True,rect=True,base=0.0,z0=y0/16,z1=y1/16,
                    floor_y=32,wall_x=144 if name.endswith('1f') else 112,
                    wall_rows=[y0,32],floor_sample=[9,3] if name.endswith('1f') else [7,2],
                    shadow=0,placement=mode,**kwargs)
    items=[item('stair_mat',[160,32,176,56],'floor')]
    if name.endswith('1f'):
        items.append(item('stairs_up',[176,16,208,56],'card',height=2.5))
    else:
        items += [item('stairs_down',[128,32,160,52],'floor'),
                  item('rail_side',[124,25,128,56],'side',height=0.5),
                  item('rail_front',[124,52,160,62],'front',height=0.5)]
    return items
