# 사람(NPC) 도트 출처

- `nurse.png`(간호순, NPC_PINK 팔레트), `clerk.png`(점원, NPC_WHITE 팔레트) — pret/pokefirered graphics/object_events/pics/people + palettes 를 `tools/frlg_npc.py` 로 변환. 원작 자료는 Nintendo / Game Freak / Creatures.
- 트레이너(2026-10-29): `bug_catcher.png`(곤충채집소년)·`camper.png`(캠프보이)·`brock.png`(웅) — 같은 곳, 셋 다 NPC_GREEN 팔레트(object_event_graphics_info.h). 웅은 걷기 프레임이 없는 3프레임 시트.
- `assets/fx/emote_exclaim.png` — 트레이너가 알아챌 때의 "!"(pret/pokefirered graphics/misc/emoticons.png), `tools/frlg_npc.py --emote`.
- 포켓몬 IP라서 이 게임은 개인 용도로만 쓰고 배포하지 않는다.

- 도로 추격 트레이너: `youngster.png`, `lass.png`(NPC_BLUE), `hiker.png`(NPC_WHITE), `picnicker.png`(NPC_GREEN). `tools/frlg_npc.py`로 같은 원본 자료에서 변환. 파티 데이터는 `tools/road_trainers.py`로 원작 최초 배틀 파티를 추출하며, 대사는 야생 포켓몬 시점에 맞춰 각색.

- 달맞이산 트레이너: `scientist.png`(이과계의남자)·`rocket_m.png`(로켓단 남자 조무래기), NPC_WHITE 팔레트. 같은 pret/pokefirered 원본을 `tools/frlg_npc.py`로 변환.

- 달맞이산 로사·로이 졸업 배틀의 두 사람 표시는 `rocket_f.png`·`rocket_m.png`(NPC_WHITE) 원작 로켓단 남녀 시트를 사용한다. 전용 로사·로이 도트는 아직 제작하지 않았다.

- 블루시티: `misty.png`(NPC_BLUE), `swimmer_m_water.png`(NPC_WHITE). pret/pokefirered 원작 사람 시트를 `tools/frlg_npc.py`로 변환. 이슬은 원작 3방향 대기 시트이며 관장은 접근 이동 없이 말을 걸어 배틀한다.

- 이수재: `bill.png`, pret/pokefirered `graphics/object_events/pics/people/bill.png`, NPC_BLUE 원작 팔레트. `tools/frlg_npc.py bill:npc_blue`로 변환.
