"""pret/pokeplatinum 에서 게임이 쓰는 원본 자료만 받아 third_party/pokeplatinum/ 에 둔다 (0단계, docs/plan-gen4.md).

  python3 -I tools/plat_fetch.py            # 전부(없는 것만)
  python3 -I tools/plat_fetch.py --force    # 다시 받기

받는 것: 포켓몬 data.json 전부, 기술 data.json 전부, TM/HM 아이템 JSON(어느 기술을 가르치는지), 경험치 표, 종 순서(= 전국 도감 번호),
글꼴 PNG+폭 JSON+charmap, 전투 UI PNG(헬스박스·인터페이스·타입 아이콘), 창 틀, 출현표(영원의숲), 타입 이름.
전부 Nintendo / Game Freak 저작물의 디컴파일 결과물이다 — personal use 로만(assets/tiles/CREDITS.md 참고).
third_party/ 는 언제든 지우고 다시 받을 수 있다.
"""
import json
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPO = "pret/pokeplatinum"
BRANCH = "main"
RAW = f"https://raw.githubusercontent.com/{REPO}/{BRANCH}/"
TREE = f"https://api.github.com/repos/{REPO}/git/trees/{BRANCH}?recursive=1"
OUT = Path(__file__).resolve().parent.parent / "third_party" / "pokeplatinum"

FIXED = [
    "res/pokemon/.shared/exp_tables.csv",
    "res/pokemon/species_icons.order",
    "generated/species.txt",
    "generated/moves.txt",
    "res/fonts/font_message.png", "res/fonts/font_message.json",
    "res/fonts/font_system.png", "res/fonts/font_system.json",
    "res/fonts/font_subscreen.png", "res/fonts/font_subscreen.json",
    "res/fonts/arrow_cursor.png", "res/fonts/screen_indicators.png",
    "tools/msgenc/charmap.txt",
    "res/graphics/battle/healthbox/player_singles.png", "res/graphics/battle/healthbox/enemy.png",
    "res/graphics/battle/healthbox/healthbox_parts.png", "res/graphics/battle/healthbox/arrows_thin.png",
    "res/graphics/battle/healthbox/arrows_wide.png", "res/graphics/battle/healthbox/short_cell.json",
    "res/graphics/battle/healthbox/tall_cell.json",
    "res/graphics/battle/interface/level_up.png", "res/graphics/battle/interface/level_up.pal",
    "res/graphics/battle/interface/level_up_cell.json", "res/graphics/battle/interface/cursor.png",
    "res/graphics/battle/interface/shared.pal",
    "res/graphics/windows/message_box_00.png", "res/graphics/windows/message_box_01.png",
    "res/graphics/windows/standard_system.png", "res/graphics/windows/standard_field.png",
    "res/text/pokemon_type_names.json", "res/text/battle_strings.json",
    "res/field/encounters/encounters_eterna_forest.json",
    # 기술 연출 스크립트(첫 SE 를 tools/plat_move_se.json 에 옮겨 적는다) — 최신 습득표 기술(2026-11-02)
    "res/moves/dragon_breath/anim.s", "res/moves/bug_bite/anim.s", "res/moves/thunder_wave/anim.s", "res/moves/rollout/anim.s",
    "res/moves/rock_polish/anim.s", "res/moves/rock_throw/anim.s", "res/moves/earthquake/anim.s",
    # 기술 연출 파티클(SPA; 텍스처만 tools/plat_fx.py 로 꺼낸다)
    # 최신 습득표(사용자 결정 2026-11-02)로 데모 구간에 들어온 기술: 용의숨결·전기자석파·구르기·록커트·돌떨구기·벌레먹음, 땅고르기 대용 지진(매그니튜드 spa 는 비어 있다)
    "res/graphics/battle/particles/dragon_breath.spa", "res/graphics/battle/particles/thunder_wave.spa",
    "res/graphics/battle/particles/rollout.spa", "res/graphics/battle/particles/rock_polish.spa",
    "res/graphics/battle/particles/rock_throw.spa", "res/graphics/battle/particles/bug_bite.spa",
    "res/graphics/battle/particles/earthquake.spa",
    "res/graphics/battle/particles/fire_fang.spa", "res/graphics/battle/particles/bite.spa",
    "res/graphics/battle/particles/ember.spa", "res/graphics/battle/particles/scratch.spa",
    "res/graphics/battle/particles/growl.spa", "res/graphics/battle/particles/smoke_screen.spa",
    "res/graphics/battle/particles/dragon_rage.spa", "res/graphics/battle/particles/scary_face.spa",
    "res/graphics/battle/particles/slash.spa", "res/graphics/battle/particles/flamethrower.spa",
    "res/graphics/battle/particles/fire_spin.spa", "res/graphics/battle/particles/metal_claw.spa",
    "res/graphics/battle/particles/status_effect.spa", "res/graphics/battle/particles/hit_1.spa",
    "res/graphics/battle/particles/hit_2.spa",
    # 파티클이 아니라 2D 스프라이트로 된 연출(겁나는얼굴·발톱)
    "res/graphics/battle/moves/scary_face.png", "res/graphics/battle/moves/scary_face_cell.json",
    "res/graphics/battle/moves/scary_face_anim.json", "res/graphics/battle/moves/claw.png", "res/graphics/battle/moves/claw.pal",
    "res/graphics/battle/moves/claw_cell.json", "res/graphics/battle/moves/claw_anim.json", "res/graphics/battle/moves/crush_claw.pal",
    "res/graphics/battle/moves/anim_nclr.order",
    # 상록숲 적 기술
    "res/graphics/battle/particles/tackle.spa", "res/graphics/battle/particles/string_shot.spa",
    "res/graphics/battle/particles/harden.spa", "res/graphics/battle/particles/poison_sting.spa",
    "res/graphics/battle/particles/fury_attack.spa", "res/graphics/battle/particles/thunder_shock.spa",
    "res/graphics/battle/particles/horn_attack.spa",
    "res/graphics/battle/moves/string_shot.png", "res/graphics/battle/moves/string_shot_cell.json",
    "res/graphics/battle/moves/string_shot_anim.json",
]
PATTERNS = [  # 트리에서 정규식으로 고르는 것
    r"^res/pokemon/[a-z0-9_]+/data\.json$",
    r"^res/moves/[a-z0-9_]+/data\.json$",
    r"^res/items/data/(tm|hm)\d+\.json$",
    r"^res/graphics/battle/type_icons/.*\.(png|pal|json)$",
]


def fetch(path: str, force: bool) -> str:
    dst = OUT / path
    if dst.exists() and not force:
        return "skip"
    dst.parent.mkdir(parents=True, exist_ok=True)
    try:
        with urllib.request.urlopen(RAW + path, timeout=30) as r:
            dst.write_bytes(r.read())
        return "ok"
    except Exception as e:  # 404 등: 없는 파일은 건너뛴다
        return f"miss {e}"


def main():
    import re
    force = "--force" in sys.argv
    with urllib.request.urlopen(TREE, timeout=60) as r:
        tree = json.load(r)["tree"]
    paths = [e["path"] for e in tree if e["type"] == "blob"]
    wanted = list(FIXED)
    for pat in PATTERNS:
        rx = re.compile(pat)
        wanted += [p for p in paths if rx.match(p)]
    wanted = sorted(set(wanted))
    print(f"{len(wanted)} files → {OUT}")
    counts = {}
    with ThreadPoolExecutor(max_workers=16) as ex:
        for path, res in zip(wanted, ex.map(lambda p: fetch(p, force), wanted)):
            key = res.split()[0]
            counts[key] = counts.get(key, 0) + 1
            if key == "miss":
                print("  missing:", path)
    print(counts)
    (OUT / "SOURCE.md").write_text(
        f"pret/pokeplatinum ({BRANCH}) 에서 tools/plat_fetch.py 로 받은 파일. 원작 자료(Nintendo / Game Freak) — personal use 로만.\n")


if __name__ == "__main__":
    main()
