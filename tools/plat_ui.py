"""플래티넘 전투 UI 그림을 게임용 PNG 로 뽑는다 (3단계, docs/plan-gen4.md) → assets/ui/plat/

  python3 -I tools/plat_ui.py

출처(third_party/pokeplatinum)
  res/graphics/battle/healthbox/{player_singles,enemy,healthbox_parts}.png   체력 상자 스프라이트(팔레트 포함 PNG)
  res/graphics/battle/interface/cursor.png                                    커서(꺾쇠)
  res/graphics/windows/standard_system.png                                    시스템 창 틀(레벨업 능력치 창·기술 잊기 창)
  res/graphics/windows/message_box_00.png                                     기본 대화창 틀(글상자)
  res/prebuilt/battle/graphic/pl_batt_bg.narc                                 NARC: 027 = 아래 화면 기술 메뉴(버튼 틀)
결과
  healthbox_player.png 128×64, healthbox_enemy.png 128×64, hb_parts.png 624×8, sys_window.png 24×24, cursor.png 34×34(네 모서리 꺾쇠)
  msgbox.png 24×24 (글상자 틀, 9분할 여백 10), fight_button.png 128×80 (기술 버튼 한 개, 자리표시 글자 지움, 몸통은 회색 → 게임에서 타입색으로 물들임),
  fight_cancel.png 256×24 (아래 띠)
전부 Nintendo / Game Freak 저작물 — personal use 로만.
"""
import importlib.util
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "third_party" / "pokeplatinum"
OUT = ROOT / "assets" / "ui" / "plat"
spec = importlib.util.spec_from_file_location("nd", ROOT / "tools" / "nitro_dump.py")
nd = importlib.util.module_from_spec(spec); spec.loader.exec_module(nd)

BUTTON_PAL = 221      # 기술 버튼: 회색(타입색은 게임에서 곱한다)


def indexed_to_rgba(path: Path) -> Image.Image:
    im = Image.open(path); pal = im.getpalette()
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    for y in range(im.height):
        for x in range(im.width):
            i = im.getpixel((x, y))
            if i:
                out.putpixel((x, y), (pal[i * 3], pal[i * 3 + 1], pal[i * 3 + 2], 255))
    return out


def hb_numbers():
    """체력 상자 숫자·Lv (src/battle/healthbox.c 그대로).
    hb_digits.png 80×8: res/fonts/font_special_chars.png 의 0~9(8×8 칸). 니블 1 = 글자, 2 = 그림자 → battle_main.c
      FontSpecialChars_Init(14, 2, 15): 체력 상자 팔레트 14번(흰색)·2번(어두운 그림자), 바탕 15번은 투명으로.
    hb_lv.png 16×16: healthbox_parts.png 의 성별 없는 Lv — 위 64·65번 칸, 아래 76·77번 칸(HealthBox_DrawLevelText)."""
    hb = Image.open(SRC / "res/graphics/battle/healthbox/healthbox_parts.png")
    pal = hb.getpalette()
    col = lambda i: tuple(pal[i * 3:i * 3 + 3]) + (255,)
    sc = Image.open(SRC / "res/fonts/font_special_chars.png")
    dig = Image.new("RGBA", (80, 8), (0, 0, 0, 0))
    for y in range(8):
        for x in range(80):
            v = sc.getpixel((x, y)) % 16
            if v == 1:
                dig.putpixel((x, y), col(14))
            elif v == 2:
                dig.putpixel((x, y), col(2))
    dig.save(OUT / "hb_digits.png")
    parts = indexed_to_rgba(SRC / "res/graphics/battle/healthbox/healthbox_parts.png")
    lv = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for k, (tile, at) in enumerate([(64, (0, 0)), (65, (8, 0)), (76, (0, 8)), (77, (8, 8))]):
        lv.paste(parts.crop((tile * 8, 0, tile * 8 + 8, 8)), at)
    lv.save(OUT / "hb_lv.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    g = SRC / "res" / "graphics" / "battle"
    indexed_to_rgba(g / "healthbox" / "player_singles.png").save(OUT / "healthbox_player.png")
    indexed_to_rgba(g / "healthbox" / "enemy.png").save(OUT / "healthbox_enemy.png")
    indexed_to_rgba(g / "healthbox" / "healthbox_parts.png").save(OUT / "hb_parts.png")
    hb_numbers()
    # 레벨업 능력치 창·메뉴 창은 시스템 창 틀(res/graphics/windows/standard_system.png, 24×24, 9분할 여백 8; 흰 바탕 청회색 테).
    # interface/level_up.png 는 파란 띠 그림이라(능력치 창이 아님) 쓰지 않는다.
    sysw = indexed_to_rgba(SRC / "res" / "graphics" / "windows" / "standard_system.png")
    bb = sysw.getbbox()                       # 24×24 셀 안에 투명 여백이 있다 → 틀만 오려 가운데를 늘려 다시 24×24(9분할 여백 8)로
    fr = sysw.crop(bb)
    fw, fh = fr.size
    m = (fw - 2) // 2
    out = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    xs = [(0, m, 0, 8), (m, fw - m, 8, 16), (fw - m, fw, 16, 24)]
    ys = [(0, m, 0, 8), (m, fh - m, 8, 16), (fh - m, fh, 16, 24)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            out.paste(fr.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST), (dx0, dy0))
    out.save(OUT / "sys_window.png")
    print("sys_window from", bb)
    # 커서: 원본은 왼쪽 위 꺾쇠 16×16 한 장. 네 모서리로 뒤집어 34×34 에 놓는다(가운데 2px 은 비움) → 게임에서 9분할(여백 16)로 어떤 네모에도 씌운다.
    corner = indexed_to_rgba(g / "interface" / "cursor.png")
    cur = Image.new("RGBA", (34, 34), (0, 0, 0, 0))
    cur.paste(corner, (0, 0))
    cur.paste(corner.transpose(Image.FLIP_LEFT_RIGHT), (18, 0))
    cur.paste(corner.transpose(Image.FLIP_TOP_BOTTOM), (0, 18))
    cur.paste(corner.transpose(Image.ROTATE_180), (18, 18))
    cur.save(OUT / "cursor.png")

    # 글상자: 기본 대화창 틀 res/graphics/windows/message_box_00.png(48×24: 흰 테 + 어두운 선 + 갈색 띠, 가운데 흰색).
    # 원본은 오른쪽 띠가 넓은 비대칭이라(스크롤 화살표 자리) 사용자 스크린샷처럼 왼쪽 띠를 거울로 써 대칭 24×24(9분할 여백 10)로 조립한다.
    mb = indexed_to_rgba(SRC / "res" / "graphics" / "windows" / "message_box_00.png")
    left = mb.crop((2, 2, 12, 22))            # 10×20: 흰 테·어두운 선 2·갈색 띠 4·밝은 줄 3
    top = mb.crop((12, 2, 16, 12))            # 4×10: 위 테 3줄 + 흰 7줄(몸통 열)
    msg = Image.new("RGBA", (24, 24), (255, 255, 255, 255))
    msg.paste(left.crop((0, 0, 10, 10)), (0, 0)); msg.paste(left.crop((0, 10, 10, 14)), (0, 10)); msg.paste(left.crop((0, 10, 10, 20)), (0, 14))
    msg.paste(msg.crop((0, 0, 10, 24)).transpose(Image.FLIP_LEFT_RIGHT), (14, 0))
    msg.paste(top, (10, 0)); msg.paste(top.transpose(Image.FLIP_TOP_BOTTOM), (10, 14))
    msg.save(OUT / "msgbox.png")
    files = nd.narc_files((SRC / "res" / "prebuilt" / "battle" / "graphic" / "pl_batt_bg.narc").read_bytes())
    # 기술 메뉴(027, 타일 026): 왼쪽 위 버튼 한 개(0,0)-(128,80), 아래 띠(0,168)-(256,192)
    tiles, bpp, _, _ = nd.ncgr(files[26]); w, h, ent = nd.nscr(files[27])
    menu = nd.draw_screen(w, h, ent, tiles, nd.nclr(files[BUTTON_PAL]), bpp)
    btn = menu.crop((0, 0, 128, 80))
    # 이름 판 안의 자리표시 글자를 판 색으로 지운다: 판 안쪽(가장 많은 색)으로 어두운 픽셀을 덮는다.
    plate = btn.crop((8, 22, 68, 40))
    colors = plate.getcolors(10000); fill = max(colors)[1]
    px = btn.load()
    for y in range(22, 40):
        for x in range(8, 68):
            r, g_, b, a = px[x, y]
            if a and (r + g_ + b) < 300:
                px[x, y] = fill
    btn.save(OUT / "fight_button.png")
    # 세 조각으로 나눠 어떤 크기로도 조립한다: 틀(판 자리를 몸통색으로 메움), 이름 판(60×18), PP 판(108×34). 9분할 여백은 틀 8, 판 4.
    body = btn.getpixel((64, 10))
    frame = btn.copy(); fp = frame.load()
    for (x0, y0, x1, y1) in ((6, 20, 70, 41), (5, 41, 116, 77)):   # 판의 그림자 선까지 덮는다
        for y in range(y0, y1):
            for x in range(x0, x1):
                fp[x, y] = body
    frame.save(OUT / "fight_frame.png")
    btn.crop((8, 22, 68, 40)).save(OUT / "name_plate.png")
    btn.crop((6, 42, 114, 76)).save(OUT / "pp_plate.png")
    menu.crop((0, 168, 256, 192)).save(OUT / "fight_cancel.png")
    # 타입 아이콘(32×16)
    (OUT / "types").mkdir(exist_ok=True)
    for f in sorted((g / "type_icons").glob("*.png")):
        indexed_to_rgba(f).save(OUT / "types" / f.name)
    print("ok", sorted(p.name for p in OUT.iterdir()))


if __name__ == "__main__":
    main()
