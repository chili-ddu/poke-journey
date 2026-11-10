"""블루시티 고유 민가와 키우미집의 원작 좌표. 파손 상태와 바닥 흔적은 보존한다."""
MAPS = {'cerulean_city_house1', 'cerulean_city_house2', 'cerulean_city_house5', 'route5_pokemon_day_care'}

def specifications(name):
    out=[]
    def add(id,kind,rect,**kw):out.append(dict(id=id,kind=kind,rect=rect,**kw))
    def plant(id,x,y,wall=None):
        add(id,'card',[x,y,x+16,y+28],z1=(y+28)/16,height=1.75,donor=[0,3] if name=='cerulean_city_house2' else [2,3],**({'wall':wall} if wall is not None else {}))
    def wall(id,rect,donor=104):
        add(id,'card',rect,wall=donor,z1=2.01,base=(32-rect[3])/16,donor=[2,3])
    def cabinet(id,rect,donor=104):
        add(id,'box',rect,front=rect[1]+2,z1=2.5,depth=.4,wall=donor,donor=[0,3] if name=='cerulean_city_house2' else [2,3])
    def table(id,x,y,**kw):
        add(id,'table',[x,y,x+30,y+31],front=y+25,under=y+27,z0=y//16,z1=y//16+2,
            depth=2,leg=.5,legs=[[x+1,x+5],[x+25,x+29]],erase=[x,y,x+30,y+32],**kw)
    if name=='cerulean_city_house1':
        cabinet('cupboard',[0,12,24,40])
        add('cylinder','card',[24,25,32,40],wall=104,donor=[2,3],z1=2.5)
        for i,x in enumerate([80,112]):wall(f'window_{i}',[x+1,11,x+13,24])
        for i,(x,y) in enumerate([(128,12),(144,12),(0,52),(0,100)]):plant(f'potted_plant_{i}',x,y,104 if y<32 else None)
        table('dining_table',113,81,donor=[6,6])
        add('dining_chair','card',[96,80,112,96],donor=[6,6],z1=6,height=1)
    elif name=='cerulean_city_house2':
        add('sink','box',[0,18,32,40],front=32,z1=2.75,depth=.75,wall=92,donor=[0,3],remove_faucet=True)
        add('faucet','card',[7,16,15,24],wall=92,donor=[0,3],z1=2.16,base=.5)
        cabinet('cupboard',[33,12,56,40],92)
        cabinet('small_cabinet',[112,19,128,40],92)
        cabinet('bookshelf',[128,11,160,40],92)
        wall('window',[97,9,111,24],92)
        table('damaged_dining_table',49,65,floor_color=[56,56])
        for i,(x,y) in enumerate([(32,64),(32,80),(80,64),(80,80)]):
            add(f'damaged_chair_{i}','card',[x,y,x+16,y+16],floor_color=[56,56],z1=(y+16)/16,height=1)
        plant('standing_plant',0,100)
        add('fallen_plant','decal',[128,104,160,128],donor=[0,3])
        for i,r in enumerate([[128,40,144,56],[144,40,160,52],[144,56,160,72]]):
            add(f'scattered_book_{i}','card',r,donor=[0,3],z1=r[3]/16,height=.5)
    elif name=='cerulean_city_house5':
        for i,x in enumerate([0,16,32]):plant(f'wall_plant_{i}',x,12,96)
        wall('calendar',[49,12,63,24],96)
        for i,x in enumerate([64,80]):wall(f'window_{i}',[x+1,9,x+15,24],96)
        cabinet('small_cabinet',[97,19,112,40],96)
        for i,x in enumerate([112,144]):cabinet(f'bookshelf_{i}',[x,11,x+32,40],96)
        for i,y in enumerate([49,81]):table(f'dining_table_{i}',129,y,donor=[6,4])
        for i,(x,y) in enumerate([(112,64),(160,96)]):
            add(f'dining_chair_{i}','card',[x,y,x+16,y+16],donor=[6,4],z1=(y+16)/16,height=1)
        for i,(x,y) in enumerate([(0,68),(16,68),(0,100),(16,100)]):plant(f'floor_plant_{i}',x,y)
    else:
        cabinet('pc',[160,8,176,40],80)
        for i,x in enumerate([16,32,96,112]):wall(f'window_{i}',[x,9,x+16,24],80)
        table('daycare_table',113,65,donor=[5,6],floor_color=[88,56])
        for i,(x,y) in enumerate([(96,64),(96,80),(144,64),(144,80)]):
            add(f'stool_{i}','box',[x+1,y+1,x+15,y+15],front=y+11,z1=(y+15)/16,depth=.875,height=.25,floor_color=[88,56])
        add('pen_partition_side','box',[60,25,72,64],front=57,z1=4,depth=2.4375,height=.4375,wall=80,donor=[5,3],donor_xsplit=64,donor_left=[2,2],donor_left_until=56)
        add('pen_partition_front','box',[0,51,20,64],front=58,z1=4,depth=.4375,height=.4375,donor=[2,2],donor_after=[1,5],donor_split=56)
        for i,(x,y) in enumerate([(0,64),(0,96),(176,96)]):
            add(f'flower_display_{i}','box',[x,y,x+16,y+32],front=y+27,z1=(y+32)/16,depth=1.6875,height=.3125,donor=[1,5])
    return out
