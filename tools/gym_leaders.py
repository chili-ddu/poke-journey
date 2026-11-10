"""Register all Kanto gym leaders; ordinary members are dialogue-only NPCs."""
import json
import re
from pathlib import Path
from frlg_npc import fetch
from road_trainers import native_data, first_battle, party_members

ROOT=Path(__file__).resolve().parents[1]
# Existing Brock/Misty parties and NPC identities remain authored.
GYMS=[
    ("pewter_gym","PewterCity_Gym","brock","Brock","웅","회색", "rock","roark"),
    ("cerulean_city_gym","CeruleanCity_Gym","misty","Misty","이슬","블루","water","wake"),
    ("vermilion_city_gym","VermilionCity_Gym","lt_surge","LtSurge","마티스","갈색","electric","volkner"),
    ("celadon_city_gym","CeladonCity_Gym","erika","Erika","민화","무지개","grass","gardenia"),
    ("fuchsia_city_gym","FuchsiaCity_Gym","koga","Koga","독수","연분홍","poison","fantina"),
    ("saffron_city_gym","SaffronCity_Gym","sabrina","Sabrina","초련","노랑","psychic","maylene"),
    ("cinnabar_island_gym","CinnabarIsland_Gym","blaine","Blaine","강연","홍련","fire","roark"),
    ("viridian_city_gym","ViridianCity_Gym","giovanni","Giovanni","비주기","상록","ground","byron")]
FLAVOR={
    "lt_surge":["찌릿한 기운이 느껴지지?\n마티스 관장님은 안쪽에 계셔!","Feel that electricity?\nLT. SURGE is waiting inside!"],
    "erika":["꽃향기를 따라가면\n민화 관장님을 만날 수 있어.","Follow the scent of flowers.\nERIKA is waiting inside."],
    "koga":["눈에 안 보여도 벽은 있어.\n천천히 길을 찾아가 봐!","Some walls are invisible.\nTake your time finding the path!"],
    "sabrina":["워프 발판은 다른 방으로 이어져.\n초련 관장님을 찾아가 봐.","The warp pads lead between rooms.\nFind your way to SABRINA."],
    "blaine":["문은 열려 있어.\n강연 관장님에게 실력을 보여 줘!","The doors are open.\nShow BLAINE what you can do!"],
    "giovanni":["여기까지 혼자 왔다고?\n비주기 관장님이 기다리실 거야.","You came all this way alone?\nGIOVANNI is waiting for you."],
    "brock":["웅 관장님은 바위처럼 단단해!\n안쪽에서 말을 걸어 봐.","BROCK is as solid as a rock!\nGo inside and speak to him."],
    "misty":["수영장에 빠지지 않게 조심해!\n이슬 관장님이 안쪽에 계셔.","Watch your step by the pool!\nMISTY is waiting inside."]}


def build():
    native,parties=native_data()
    common=fetch("data/scripts/trainers.inc").read_text()
    trainers,places,themes,dialogue,origins,gyms,members={},{},{},{},{},{},{}
    for place,source,slug,label,ko,city,color,band in GYMS:
        text=common+"\n"+fetch(f"data/maps/{source}/scripts.inc").read_text()
        blocks=dict(re.findall(r"^(\w+)::[^\n]*\n(.*?)(?=^\w+::|\Z)",text,re.M|re.S))
        objects=json.loads(fetch(f"data/maps/{source}/map.json").read_text())["object_events"]
        arena="arena_pewter_gym" if slug=="brock" else "arena_cerulean_gym" if slug=="misty" else f"arena_{slug}_gym"
        leader=next(o for o in objects if o["script"].endswith("_"+label))
        cfg={"arena":arena,"trainers":[{"trainer":"leader_"+slug,"tile":[leader["x"],leader["y"]],"face":"down","sight":0}],"npcs":[]}
        layout=json.loads((ROOT/"assets/maps"/place/"map.json").read_text())
        occupied={(o["x"],o["y"]) for o in objects if not o["graphics_id"].endswith("CUT_TREE")}
        count=0
        for obj in objects:
            ordinary=obj.get("trainer_type")=="TRAINER_TYPE_NORMAL"
            guide=obj["script"].endswith("_GymGuy")
            if not ordinary and not guide:continue
            name=obj["script"].split("_")[-1]
            sprite=obj["graphics_id"].removeprefix("OBJ_EVENT_GFX_").lower()
            id=f"gym_{slug}_{name.lower()}"
            talk="gym_member"
            face="down"
            tile=[obj["x"],obj["y"]];talk_tile=None
            if slug=="brock" and name=="Liam":id="gym_liam";talk="gym_surprised";face="right";talk_tile=[4,8]
            if slug=="misty" and name=="Luis":id="gym_luis";talk="gym_surprised";face="left";talk_tile=[9,12]
            if slug=="misty" and name=="Diana":id="gym_diana";talk="gym_surprised";face="right";talk_tile=[5,7]
            npc={"id":id,"sprite":sprite,"tile":tile,"face":face,"talk":talk}
            if talk_tile is None:
                for dx,dy in [(0,1),(-1,0),(1,0),(0,-1)]:
                    x,y=tile[0]+dx,tile[1]+dy
                    if 0<=y<layout["height"] and 0<=x<layout["width"] and layout["solid"][y][x]=="0" and (x,y) not in occupied:
                        talk_tile=[x,y];break
            if talk_tile:npc["talk_tile"]=talk_tile
            cfg["npcs"].append(npc)
            dialogue[id]={"ko":["앗! 야생 포켓몬이\n혼자 체육관에 왔잖아!?",FLAVOR[slug][0]],
                          "en":["A wild POKéMON came\nto our GYM alone!?",FLAVOR[slug][1]]}
            if ordinary:
                count+=1
                constant=first_battle(obj["script"],blocks)
                raw=native[constant]
                pointer=re.search(r"\.party\s*=\s*\w+\((sParty_\w+)\)",raw)[1]
                roster,ivs=party_members(parties[pointer])
                members[id]={"trainer":constant,"party_id":pointer,"party":roster,"native_ivs":ivs}
        places[place]=cfg
        gyms[place]={"source":source,"slug":slug,"leader":"leader_"+slug,"name":ko,"city":city,"arena":arena,"members":count,"banner":band}
        if slug in ["brock","misty"]:continue
        constant=first_battle(leader["script"],blocks)
        raw=native[constant]
        party_id=re.search(r"\.party\s*=\s*\w+\((sParty_\w+)\)",raw)[1]
        party,ivs=party_members(parties[party_id])
        english=re.search(r'\.trainerName\s*=\s*_\("([^"\n]*)"\)',raw)[1]
        intro={
            "lt_surge":"혼자서 내 체육관에 왔다고?\n배짱 하나는 마음에 드는군!|나는 마티스!\n전기 포켓몬의 힘을 보여 주마!",
            "erika":"어머, 포켓몬이 혼자 찾아왔군요.\n저에게 도전하고 싶은 건가요?|저는 민화예요.\n꽃처럼 아름다운 승부를 해 봐요.",
            "koga":"후후… 미로를 지나 여기까지 왔군.\n트레이너 없이도 제법이구나.|나는 독수!\n독 포켓몬의 기술을 견뎌 보아라!",
            "sabrina":"네가 올 것을 알고 있었어.\n혼자 강해지려고 여행하는구나.|나는 초련.\n네 마음의 힘을 보여 줘.",
            "blaine":"와하하! 포켓몬 혼자서\n내게 도전하러 왔단 말이지!|나는 강연!\n뜨겁게 타오르는 승부를 해 보자!",
            "giovanni":"…그 눈빛, 여전히 변함없군.\n혼자서 여기까지 찾아왔나.|나는 상록체육관의 관장 비주기.\n네 실력을 직접 확인해 주마."}
        trainers["leader_"+slug]={"class":"leader","name":english,"name_ko":ko,"sprite":slug,"gym":{},"arena":arena,
            "party":party,"ivs":[v*31//255 for v in ivs],
            "cutin":{"mugshot":"plat/enc_mugshot_"+slug,"banner":"plat/enc_leader_banner_"+color},
            "intro":{"ko":intro[slug].split("|"),"en":["A POKéMON challenging\nmy GYM without a TRAINER?",f"I'm {english}.\nShow me your strength!"]},
            "defeat":{"ko":["훌륭한 승부였어.\n네 힘은 충분히 보여 주었군!","앞으로의 여행에 도움이 되도록\n이 열매들을 가져가."],"en":["That was an impressive battle.\nYou have proven your strength!","Take these BERRIES\nfor the road ahead."]},
            "after":{"ko":["네 실력은 잘 기억하고 있지.\n앞으로도 힘껏 여행하거라!"],"en":["I remember your strength.\nKeep exploring the world!"]}}
        origins["leader_"+slug]={"source":source,"trainer":constant,"party_id":party_id,"party":party,"native_ivs":ivs}
        themes[arena]={"map":"res://assets/maps/"+arena,"tiles":{}}
        places[arena]={"name":english+" GYM","name_ko":city+"시티 체육관","theme":arena,"arena_field":True,"battle_style":"room","count":0,"encounters":[]}
    return {"TRAINERS":trainers,"PLACE_OVERRIDES":places,"THEMES":themes,"DIALOGUE":dialogue,"GYMS":gyms,"NPC_PARTIES":members},origins


def main():
    data,origins=build()
    out="extends RefCounted\n# Generated by tools/gym_leaders.py; only leaders can battle.\n"
    for key,value in data.items():
        literal=json.dumps(value,ensure_ascii=False,indent=2)
        literal=re.sub(r'"(tile|talk_tile)": \[\s*(-?\d+),\s*(-?\d+)\s*\]',r'"\1": Vector2i(\2,\3)',literal)
        out+="const "+key+" := "+literal+"\n"
    (ROOT/"scripts/data/gym_leaders.gd").write_text(out)
    (ROOT/"assets/data/gym_leaders.json").write_text(json.dumps({"gyms":data["GYMS"],"origins":origins,"places":data["PLACE_OVERRIDES"],"npc_parties":data["NPC_PARTIES"]},ensure_ascii=False,indent=2)+"\n")
    print("Gym leaders:",{k:[(m[0],m[1]) for m in t["party"]] for k,t in data["TRAINERS"].items()})
    print("Ordinary dialogue members:",sum(g["members"] for g in data["GYMS"].values()))


if __name__=="__main__":main()
