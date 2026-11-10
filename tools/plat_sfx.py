"""플래티넘 효과음(SE)·포켓몬 울음소리 → assets/audio/se/<이름>.wav, assets/audio/cry/<종족>.wav (사용자 요청 2026-10-30)

  python3 -I tools/plat_sfx.py            # 전부
  python3 -I tools/plat_sfx.py se         # 효과음만 / cry 울음소리만 / cry scyther 특정 종만

효과음은 원작 SDAT(res/prebuilt/data/sound/sound_data.sdat)의 SEQ_SE_DP_* 시퀀스를 tools/plat_music.py 의 합성기로 그대로 렌더한다.
  UI·필드: SELECT(커서·글 넘김·취소), DECIDE(결정), PINPON("!"), DOOR(문), DANSA(언덕 뛰어내리기), SAVE(저장), REGI(상점 계산), PC_LOGIN(시작 화면 PC)
  배틀: KOUKA_H/M/L(효과가 굉장했다/보통/별로), BOWA(볼 열림)
  기술: 각 기술의 원작 연출 스크립트(res/moves/<기술>/anim.s)가 처음 울리는 SE(tools/plat_move_se.json, 끝의 '_' 는 _sseq 접미의 흔적)
울음소리는 SDAT 의 WAVE_ARC_PV<전국도감번호> 안의 파형(SWAV) 하나를 그대로 WAV 로 — 이 게임에 도트가 있는 종족만(assets/sprites/<번호>).
전부 Nintendo / Game Freak 저작물 — personal use 로만(assets/audio/CREDITS.md).
"""
import importlib.util
import json
import os
import shutil
import struct
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("pm", ROOT / "tools" / "plat_music.py")
pm = importlib.util.module_from_spec(spec); spec.loader.exec_module(pm)

SE_DIR = ROOT / "assets" / "audio" / "se"
CRY_DIR = ROOT / "assets" / "audio" / "cry"
# 짧은 이름 → 원작 시퀀스
SE = {"select": "SEQ_SE_DP_SELECT", "decide": "SEQ_SE_DP_DECIDE", "pinpon": "SEQ_SE_DP_PINPON", "door": "SEQ_SE_DP_DOOR",
      "dansa": "SEQ_SE_DP_DANSA", "save": "SEQ_SE_DP_SAVE", "regi": "SEQ_SE_DP_REGI", "pc_login": "SEQ_SE_DP_PC_LOGIN",
      "kouka_h": "SEQ_SE_DP_KOUKA_H", "kouka_m": "SEQ_SE_DP_KOUKA_M", "kouka_l": "SEQ_SE_DP_KOUKA_L", "bowa": "SEQ_SE_DP_BOWA"}


def move_ses(sd) -> dict:
    """기술 id → 원작 SE 이름(SDAT 에 있는 첫 번째 — 덩굴채찍의 SEQ_SE_PL_WHIP 처럼 없는 이름은 건너뛴다). 없는 기술은 뺀다."""
    table = json.loads((ROOT / "tools" / "plat_move_se.json").read_text())
    out = {}
    for mv, ses in table.items():
        for se in ses or []:
            if se.rstrip("_") in sd.seq_names:
                out[mv] = se.rstrip("_")
                break
    return out


def render_se(sd, seq: str, out: Path) -> bool:
    if seq not in sd.seq_names:
        print("없는 SE:", seq)
        return False
    tmp = pm.render(seq, sd)          # assets/audio/<소문자>.wav 에 쓴다
    out.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(tmp), str(out))
    return True


def wavearc_names(path: Path) -> list:
    d = path.read_bytes()
    symb = struct.unpack("<I", d[0x10:0x14])[0]
    recs = struct.unpack("<8I", d[symb + 8:symb + 40])
    o = symb + recs[3]
    n = struct.unpack("<I", d[o:o + 4])[0]
    offs = struct.unpack("<%dI" % n, d[o + 4:o + 4 + 4 * n])
    return [(d[symb + so:d.index(b"\0", symb + so)].decode() if so else None) for so in offs]


def cries(sd, missing_only=False, species_ids=None) -> None:
    species = json.loads((ROOT / "assets" / "data" / "species.json").read_text())
    have = {int(x) for x in os.listdir(ROOT / "assets" / "sprites") if x.isdigit()}
    names = wavearc_names(pm.SDAT)
    CRY_DIR.mkdir(parents=True, exist_ok=True)
    for sid, sp in species.items():
        if species_ids is not None and sid not in species_ids:
            continue
        dex = int(sp.get("dex", 0))
        if dex not in have or (missing_only and (CRY_DIR / f"{sid}.wav").exists()):
            continue
        name = "WAVE_ARC_PV%03d" % dex
        if name not in names:
            print("울음소리 없음:", sid, name)
            continue
        war = sd.swar(names.index(name))
        w = pm.decode_swav(*war[0])
        data = w["data"]
        peak = max(1e-6, max(abs(x) for x in data))
        gain = min(1.0, 0.9 / peak)
        with wave.open(str(CRY_DIR / f"{sid}.wav"), "wb") as f:
            f.setnchannels(1); f.setsampwidth(2); f.setframerate(int(w["rate"]))
            f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x * gain)) * 32767)) for x in data))
        print("cry", sid, dex, w["rate"], "Hz", "%.2f초" % (len(data) / w["rate"]))


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    sd = pm.Sdat(pm.SDAT)
    if what in ("all", "se"):
        for short, seq in SE.items():
            render_se(sd, seq, SE_DIR / f"{short}.wav")
        for mv, seq in move_ses(sd).items():
            render_se(sd, seq, SE_DIR / f"mv_{mv}.wav")
    if what in ("all", "cry"):
        cries(sd, species_ids=set(sys.argv[2:]) or None)


if __name__ == "__main__":
    main()
