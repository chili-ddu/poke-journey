"""PMD Sprite Collab 도트 받기 → assets/sprites/<도감번호>/

  python3 -I tools/pmd_fetch.py 0016 0019
  python3 -I tools/pmd_fetch.py --shiny 0004 …   → 이로치(sprite/<번호>/0000/0001/) 를 assets/sprites/<번호>/shiny/ 로

github.com/PMDCollab/SpriteCollab 의 sprite/<번호>/ 에서 게임이 쓰는 동작 시트(-Anim.png)와 중심점 시트(-Offsets.png), AnimData.xml,
credits.txt 만 받는다. 없는 동작은 건너뛴다(MonSprite 가 대체 동작을 고른다). 출처·조건은 assets/sprites/CREDITS.md 에 적는다.
CHUNSOFT 표기는 원작 게임 추출(닌텐도·춘소프트·포켓몬컴퍼니), 기여자 작업분은 CC BY-NC 4.0 — 개인 용도로만.
"""
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = "https://raw.githubusercontent.com/PMDCollab/SpriteCollab/master/sprite/"
ANIMS = ["Walk", "Idle", "Attack", "Strike", "Charge", "Shoot", "Hop", "Hurt", "Sleep", "Trip", "HitGround", "Jab", "Swing", "TailWhip", "Eat", "Dance", "Shake", "Rotate", "Withdraw", "Double", "Slice"]


def get(url: str) -> bytes | None:
    try:
        with urllib.request.urlopen(url, timeout=60) as r:
            return r.read()
    except Exception:
        return None


def main():
    args = sys.argv[1:]
    shiny = "--shiny" in args
    for dex in [a for a in args if a != "--shiny"]:
        out = ROOT / "assets" / "sprites" / dex
        src = dex + "/"
        if shiny:
            out, src = out / "shiny", dex + "/0000/0001/"
        out.mkdir(parents=True, exist_ok=True)
        got = []
        for name in ["AnimData.xml", "credits.txt"]:
            data = get(RAW + src + name)
            if data:
                (out / name).write_bytes(data)
        for anim in ANIMS:
            data = get(RAW + src + anim + "-Anim.png")
            if data is None:
                continue
            (out / f"{anim}-Anim.png").write_bytes(data)
            off = get(RAW + src + anim + "-Offsets.png")
            if off:
                (out / f"{anim}-Offsets.png").write_bytes(off)
            got.append(anim)
        print(dex, "anims:", got)
        cred = (out / "credits.txt")
        if cred.exists():
            print("  credits:", cred.read_text().strip().replace("\n", " | ")[:300])


if __name__ == "__main__":
    main()
