"""플래티넘 음악(NDS SDAT) 합성 → assets/audio/<곡>.wav

  python3 -I tools/plat_music.py SEQ_ASA SEQ_BA_TRAIN …     (곡 이름을 안 주면 SONGS 전부)

사용자 결정 2026-10-29: 장소 곡은 파이어레드(tools/frlg_music.py), 시스템·배틀·팡파르는 플래티넘. pret/pokeplatinum 의
res/prebuilt/data/sound/sound_data.sdat(원작 사운드 묶음 그대로) 한 파일에서
  SSEQ  곡(명령 흐름: 음표·쉼표·악기·볼륨·팬·벤드·비브라토·ADSR·호출·반복·점프)
  SBNK  악기 묶음(PCM·PSG 사각파·노이즈, 드럼, 건반 나눔 — 기준음·ADSR)
  SWAR  샘플(PCM8/PCM16/IMA-ADPCM, 루프)
을 읽어 NDS 사운드 드라이버처럼 소리를 낸다:
  시간      드라이버 한 프레임(약 192Hz)마다 템포를 더해 240 이 넘을 때마다 한 틱(4분음표 48틱)
  음 길이   음표마다 길이(틱), 노트 대기(C7)가 켜져 있으면 그만큼 기다린다
  엔벨로프  NDS 방식(데시벨 단위): attack 은 −92544 에서 곱셈으로 0 까지, decay 는 sustain 까지 빼기, 떼면 release 로 빼기
  볼륨      시퀀스 볼륨(INFO) · 마스터(C2) · 트랙 볼륨(C1) · 익스프레션(D5) · 세기를 데시벨 제곱 곡선으로 더해 선형으로
  피치      (건반 − 기준음) + 벤드(C4 × 범위 C5) + 비브라토(C9~CD, 옅게)
  반복      트랙 0 이 뒤로 점프하는 구간을 반복으로 보고 처음 → 반복 두 번을 굽고 둘째 반복을 WAV smpl 루프로 적는다
믹싱은 NDS 출력 32728Hz, 16비트 모노(팬은 무시). 원작과 똑같지는 않다(흉내).
원작 자료는 Nintendo / Game Freak — personal use 로만.
"""
import math
import struct
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SDAT = ROOT / "third_party" / "pokeplatinum" / "res" / "prebuilt" / "data" / "sound" / "sound_data.sdat"
RAW = "https://raw.githubusercontent.com/pret/pokeplatinum/main/res/prebuilt/data/sound/sound_data.sdat"
OUT = ROOT / "assets" / "audio"
RATE = 32728
FRAME_HZ = 33513982 / (2728 * 64)          # 드라이버 프레임 ≈ 191.97Hz
GAIN = 0.9
AMPL_MIN = -92544
# 이 게임에서 쓰는 플래티넘 곡(시스템·배틀·팡파르)
SONGS = ["SEQ_TITLE01", "SEQ_EYE_BOY", "SEQ_BA_TRAIN", "SEQ_BA_GYM", "SEQ_WINTRAIN", "SEQ_WINTGYM",
         "SEQ_BADGE", "SEQ_FANFA1", "SEQ_SHINKA", "SEQ_FANFA5", "SEQ_ASA",
         "SEQ_THE_RIV", "SEQ_BA_RIVAL",       # 라이벌 등장·배틀(1번도로 그린, 2026-10-30)
         "SEQ_FANFA4",                        # 도구를 받을 때(원작 scripts_common.s: 도구 주머니 물건 = FANFA4, 2026-10-30)
         "SEQ_WAZA"]                          # 기술머신을 받을 때(원작 scripts_common.s: 기술머신 주머니 = WAZA, 2026-10-30)
ATTACK_TABLE = [0, 1, 5, 14, 26, 38, 51, 63, 73, 84, 92, 100, 109, 116, 123, 127, 132, 137, 143]


def db10(v: int) -> float:
    """0~127 → 0.1dB 단위(NDS 데시벨 제곱 표 흉내: 20·log10((v/127)²)·10, 최저 −723)."""
    if v <= 0:
        return -723.0
    return max(-723.0, 400.0 * math.log10(v / 127.0))


def fall_rate(v: int) -> int:
    if v == 127:
        return 0xFFFF
    if v == 126:
        return 0x3C00
    if v < 50:
        return v * 2 + 1
    return 0x1E00 // (126 - v)


def attack_rate(a: int) -> int:
    return ATTACK_TABLE[127 - a] if a >= 109 else 255 - a


# ── SDAT ──

class Sdat:
    def __init__(self, path: Path):
        if not path.exists():
            path.parent.mkdir(parents=True, exist_ok=True)
            with urllib.request.urlopen(RAW, timeout=120) as r:
                path.write_bytes(r.read())
        self.d = d = path.read_bytes()
        symb_off, _, info_off, _, fat_off, _ = struct.unpack("<6I", d[0x10:0x28])
        names = self._symb(symb_off)
        self.seq_names = names[0]
        rec = struct.unpack("<8I", d[info_off + 8:info_off + 40])

        def entries(k):
            base = info_off + rec[k]
            n = struct.unpack("<I", d[base:base + 4])[0]
            offs = struct.unpack("<%dI" % n, d[base + 4:base + 4 + 4 * n])
            return [info_off + o if o else None for o in offs]
        self.seq_info = [struct.unpack("<HHHBBBB", d[o:o + 10]) if o else None for o in entries(0)]
        self.bank_info = [struct.unpack("<HH4H", d[o:o + 12]) if o else None for o in entries(2)]
        self.wa_info = [struct.unpack("<I", d[o:o + 4])[0] & 0xFFFFFF if o else None for o in entries(3)]
        n = struct.unpack("<I", d[fat_off + 8:fat_off + 12])[0]
        self.fat = [struct.unpack("<II", d[fat_off + 12 + 16 * i:fat_off + 20 + 16 * i]) for i in range(n)]
        self._wars = {}

    def _symb(self, off: int) -> list:
        d = self.d
        rec = struct.unpack("<8I", d[off + 8:off + 40])
        out = []
        for k in range(8):
            if k == 1:                                   # SEQARC 는 겹 구조 — 안 씀
                out.append([]); continue
            base = off + rec[k]
            n = struct.unpack("<I", d[base:base + 4])[0]
            lst = []
            for i in range(n):
                p = struct.unpack("<I", d[base + 4 + 4 * i:base + 8 + 4 * i])[0]
                if p == 0:
                    lst.append(""); continue
                e = d.index(b"\0", off + p)
                lst.append(d[off + p:e].decode("latin1"))
            out.append(lst)
        return out

    def file(self, fid: int) -> bytes:
        o, s = self.fat[fid]
        return self.d[o:o + s]

    def swar(self, idx: int) -> list:
        if idx not in self._wars:
            f = self.file(self.wa_info[idx])
            n = struct.unpack("<I", f[0x38:0x3C])[0]
            offs = struct.unpack("<%dI" % n, f[0x3C:0x3C + 4 * n])
            self._wars[idx] = [(f, o) for o in offs]
        return self._wars[idx]


_wave_cache = {}


def decode_swav(f: bytes, o: int) -> dict:
    key = (id(f), o)
    if key in _wave_cache:
        return _wave_cache[key]
    typ, loop, rate, _timer, loop_off, length = struct.unpack("<BBHHHI", f[o:o + 12])
    data = f[o + 12:o + 12 + (loop_off + length) * 4]
    if typ == 0:
        s = [((b + 128) & 255) - 128 for b in data]
        smp = [x / 128.0 for x in s]
        lstart = loop_off * 4
    elif typ == 1:
        smp = [v / 32768.0 for (v,) in struct.iter_unpack("<h", data[:len(data) // 2 * 2])]
        lstart = loop_off * 2
    else:
        smp = adpcm(data)
        lstart = max(0, (loop_off * 4 - 4) * 2)
    w = {"rate": rate, "data": smp, "loop": lstart if loop else None}
    _wave_cache[key] = w
    return w


IMA_STEP = [7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143,
            157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552,
            1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487,
            12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767]
IMA_IDX = [-1, -1, -1, -1, 2, 4, 6, 8]


def adpcm(data: bytes) -> list:
    pred, idx = struct.unpack("<hB", data[:3])
    out = []
    for b in data[4:]:
        for nib in (b & 15, b >> 4):
            step = IMA_STEP[idx]
            diff = step >> 3
            if nib & 1: diff += step >> 2
            if nib & 2: diff += step >> 1
            if nib & 4: diff += step
            pred = max(-32768, min(32767, pred - diff if nib & 8 else pred + diff))
            idx = max(0, min(88, idx + IMA_IDX[nib & 7]))
            out.append(pred / 32768.0)
    return out


# ── 악기 묶음 ──

def parse_bank(sd: Sdat, bank_idx: int) -> dict:
    fid, _, *was = sd.bank_info[bank_idx]
    f = sd.file(fid)
    n = struct.unpack("<I", f[0x38:0x3C])[0]
    insts = {}

    def notedef(o):
        swav, swar, key, a, dcy, s, r, pan = struct.unpack("<HHBBBBBB", f[o:o + 10])
        return {"swav": swav, "swar": was[swar] if swar < 4 else 0xFFFF, "key": key, "a": a, "d": dcy, "s": s, "r": r}

    for i in range(n):
        typ, off = struct.unpack("<BH", f[0x3C + 4 * i:0x3F + 4 * i])
        if typ == 0:
            continue
        if typ < 16:
            nd = notedef(off); nd["type"] = typ
            insts[i] = {"kind": "single", "def": nd}
        elif typ == 16:
            lo, hi = f[off], f[off + 1]
            defs = {}
            for k in range(hi - lo + 1):
                o = off + 2 + 12 * k
                t = struct.unpack("<H", f[o:o + 2])[0]
                nd = notedef(o + 2); nd["type"] = t
                defs[lo + k] = nd
            insts[i] = {"kind": "drums", "defs": defs}
        elif typ == 17:
            regions = list(f[off:off + 8])
            defs = []
            o = off + 8
            for up in regions:
                if up == 0:
                    break
                t = struct.unpack("<H", f[o:o + 2])[0]
                nd = notedef(o + 2); nd["type"] = t
                defs.append((up, nd)); o += 12
            insts[i] = {"kind": "split", "defs": defs}
    return insts


def pick(insts: dict, prog: int, key: int):
    inst = insts.get(prog)
    if inst is None:
        return None
    if inst["kind"] == "single":
        return inst["def"]
    if inst["kind"] == "drums":
        return inst["defs"].get(key)
    for up, nd in inst["defs"]:
        if key <= up:
            return nd
    return inst["defs"][-1][1] if inst["defs"] else None


# ── 시퀀스 해석 ──

def run_sseq(sd: Sdat, seq_idx: int) -> dict:
    fid, _, _bank, vol, *_ = sd.seq_info[seq_idx]
    f = sd.file(fid)
    data_off = struct.unpack("<I", f[0x18:0x1C])[0]
    data = f[data_off:]

    def vlq(p):
        v = 0
        while True:
            c = data[p]; p += 1; v = (v << 7) | (c & 0x7F)
            if c < 0x80:
                return v, p

    class Trk:
        def __init__(self, tid, pc):
            self.id, self.pc, self.wait, self.done = tid, pc, 0, False
            self.stack, self.loops = [], []
            self.prog, self.transpose, self.notewait = 0, 0, True
            self.adsr = [0xFF, 0xFF, 0xFF, 0xFF]
            self.visited = {}

    tracks = [Trk(0, 0)]
    notes, changes = [], []          # 음: (트랙, 시작 틱, 길이 틱, 건반, 세기, 프로그램, adsr) / 바뀜: (트랙, 틱, 무엇, 값)
    tempo_changes = [(0, 120)]
    loop = None
    tick = 0
    max_ticks = 48 * 4 * 400

    def step(t: Trk):
        nonlocal loop
        while t.wait == 0 and not t.done:
            if t.pc not in t.visited:
                t.visited[t.pc] = tick
            cmd = data[t.pc]; t.pc += 1
            if cmd < 0x80:
                vel = data[t.pc]; t.pc += 1
                ln, t.pc = vlq(t.pc)
                notes.append((t.id, tick, ln, cmd + t.transpose, vel, t.prog, tuple(t.adsr)))
                if t.notewait:
                    t.wait = ln
            elif cmd == 0x80:
                t.wait, t.pc = vlq(t.pc)
            elif cmd == 0x81:
                t.prog, t.pc = vlq(t.pc)
            elif cmd == 0x93:
                tid = data[t.pc]; off = int.from_bytes(data[t.pc + 1:t.pc + 4], "little"); t.pc += 4
                tracks.append(Trk(tid, off))
            elif cmd == 0x94:
                off = int.from_bytes(data[t.pc:t.pc + 3], "little"); t.pc += 3
                if t.id == 0 and loop is None and off in t.visited:
                    loop = (t.visited[off], tick)
                t.pc = off
            elif cmd == 0x95:
                off = int.from_bytes(data[t.pc:t.pc + 3], "little")
                t.stack.append(t.pc + 3); t.pc = off
            elif cmd == 0xFD:
                t.pc = t.stack.pop() if t.stack else t.pc
            elif cmd == 0xD4:
                cnt = data[t.pc]; t.pc += 1
                t.loops.append([t.pc, cnt])
            elif cmd == 0xFC:
                if t.loops:
                    lp = t.loops[-1]
                    if lp[1] == 0:
                        t.pc = lp[0]
                    else:
                        lp[1] -= 1
                        if lp[1] > 0:
                            t.pc = lp[0]
                        else:
                            t.loops.pop()
            elif cmd == 0xFE:
                t.pc += 2
            elif cmd == 0xFF:
                t.done = True
            elif cmd == 0xA0:                       # 무작위: 다음 명령 + 범위(최솟값으로)
                sub = data[t.pc]; t.pc += 1
                lo = struct.unpack("<h", data[t.pc:t.pc + 2])[0]; t.pc += 4
                if sub < 0x80:
                    t.pc += 1
                    notes.append((t.id, tick, max(1, lo), sub + t.transpose, 100, t.prog, tuple(t.adsr)))
                elif sub == 0x80:
                    t.wait = max(0, lo)
            elif cmd == 0xA1:                       # 변수 값으로 — 다음 명령 + 변수 번호(건너뜀)
                sub = data[t.pc]; t.pc += 1
                t.pc += 2 if sub < 0x80 else 1
            elif cmd == 0xA2:                       # 조건: 참으로 본다
                pass
            elif 0xB0 <= cmd <= 0xBD:
                t.pc += 3
            elif cmd in (0xE0, 0xE1, 0xE3):
                v = struct.unpack("<H", data[t.pc:t.pc + 2])[0]; t.pc += 2
                if cmd == 0xE1:
                    tempo_changes.append((tick, v))
                elif cmd == 0xE0:
                    changes.append((t.id, tick, "moddelay", v))
            elif 0xC0 <= cmd <= 0xD6:
                v = data[t.pc]; t.pc += 1
                if cmd == 0xC0: changes.append((t.id, tick, "pan", v))
                elif cmd == 0xC1: changes.append((t.id, tick, "vol", v))
                elif cmd == 0xC2: changes.append((t.id, tick, "master", v))
                elif cmd == 0xC3: t.transpose = v - 256 if v > 127 else v
                elif cmd == 0xC4: changes.append((t.id, tick, "bend", v - 256 if v > 127 else v))
                elif cmd == 0xC5: changes.append((t.id, tick, "bendr", v))
                elif cmd == 0xC7: t.notewait = v != 0
                elif cmd == 0xCA: changes.append((t.id, tick, "moddepth", v))
                elif cmd == 0xCB: changes.append((t.id, tick, "modspeed", v))
                elif cmd == 0xCC: changes.append((t.id, tick, "modtype", v))
                elif cmd == 0xCD: changes.append((t.id, tick, "modrange", v))
                elif cmd == 0xD0: t.adsr[0] = v
                elif cmd == 0xD1: t.adsr[1] = v
                elif cmd == 0xD2: t.adsr[2] = v
                elif cmd == 0xD3: t.adsr[3] = v
                elif cmd == 0xD5: changes.append((t.id, tick, "expr", v))
            else:
                t.done = True                       # 모르는 명령: 그 트랙만 멈춘다

    while tick < max_ticks:
        k = 0
        while k < len(tracks):                  # 같은 틱에 연 트랙도 그 틱부터 돈다
            step(tracks[k]); k += 1
        alive = [t for t in tracks if not t.done]
        if loop is not None and tick >= loop[1] + (loop[1] - loop[0]):
            break
        if not alive:
            break
        for t in alive:
            if t.wait > 0:
                t.wait -= 1
        tick += 1
    return {"notes": notes, "changes": changes, "tempos": tempo_changes, "loop": loop, "end": tick, "vol": vol}


# ── 소리내기 ──

def render(song: str, sd: Sdat) -> Path:
    idx = sd.seq_names.index(song)
    fid, _, bank, seq_vol, *_ = sd.seq_info[idx]
    insts = parse_bank(sd, bank)
    seq = run_sseq(sd, idx)
    loop = seq["loop"]
    end_tick = loop[1] + (loop[1] - loop[0]) if loop else seq["end"]
    # 틱 → 샘플: 드라이버 프레임마다 템포를 더해 240 마다 한 틱.
    tempos = sorted(seq["tempos"])
    tick_sample = []
    tmp_i, tempo, acc, frame, tk = 0, 120, 0, 0, 0
    spf = RATE / FRAME_HZ
    while tk <= end_tick + 1:
        while tmp_i < len(tempos) and tempos[tmp_i][0] <= tk:
            tempo = tempos[tmp_i][1]; tmp_i += 1
        acc += tempo
        while acc >= 240 and tk <= end_tick + 1:
            acc -= 240
            tick_sample.append(int(frame * spf))
            tk += 1
        frame += 1
    total = tick_sample[min(end_tick, len(tick_sample) - 1)]
    mix = [0.0] * (total + RATE * 6)
    fr_len = RATE / 60.0
    nfr = int(len(mix) / fr_len) + 2
    # 트랙 상태를 60Hz 표로(볼륨·익스프레션·마스터·벤드·비브라토).
    per_track = {}
    for tid in set(n[0] for n in seq["notes"]):
        ch = sorted([c for c in seq["changes"] if c[0] == tid], key=lambda c: c[1])
        st = {"vol": 127, "expr": 127, "master": 127, "bend": 0, "bendr": 2, "moddepth": 0, "modspeed": 16, "modrange": 1, "modtype": 0, "pan": 64, "moddelay": 0}
        vol_db = [0.0] * nfr
        semi = [0.0] * nfr
        ci, ph = 0, 0.0
        for fi in range(nfr):
            s0 = fi * fr_len
            while ci < len(ch) and tick_sample[min(ch[ci][1], len(tick_sample) - 1)] <= s0:
                st[ch[ci][2]] = ch[ci][3]; ci += 1
            vol_db[fi] = db10(st["vol"]) + db10(st["expr"]) + db10(st["master"])
            # 비브라토: 사인 한 바퀴 = 512/속도 드라이버 프레임, 깊이 127·범위 1 ≈ 0.93반음(드라이버 계산 흉내)
            ph += st["modspeed"] * FRAME_HZ / 512.0 / 60.0
            vib = 127 * st["moddepth"] * st["modrange"] * 60 / 16384 / 64 * math.sin(2 * math.pi * ph) if st["modtype"] == 0 else 0.0
            semi[fi] = st["bend"] / 128.0 * st["bendr"] + vib
        per_track[tid] = (vol_db, semi)
    base_db = db10(seq_vol)
    for tid, st_tick, ln, key, vel, prog, adsr in seq["notes"]:
        if st_tick >= end_tick:
            continue
        nd = pick(insts, prog, key)
        if nd is None:
            continue
        vol_db, semi = per_track[tid]
        s0 = tick_sample[min(st_tick, len(tick_sample) - 1)]
        s1 = tick_sample[min(st_tick + ln, len(tick_sample) - 1)]
        a = adsr[0] if adsr[0] != 0xFF else nd["a"]
        dcy = adsr[1] if adsr[1] != 0xFF else nd["d"]
        sus = adsr[2] if adsr[2] != 0xFF else nd["s"]
        rel = adsr[3] if adsr[3] != 0xFF else nd["r"]
        render_note(mix, nd, key, s0, s1 - s0, a, dcy, sus, rel, vel, base_db, vol_db, semi, sd, fr_len)
    loop_pts = None
    if loop:
        ls, le = tick_sample[loop[1]], tick_sample[min(end_tick, len(tick_sample) - 1)]
        mix = mix[:le]
        xf = 128
        for k in range(xf):
            al = (k + 1) / xf
            mix[le - xf + k] = mix[le - xf + k] * (1 - al) + mix[ls - xf + k] * al
        loop_pts = (ls, le)
    else:
        last = max((k for k, s in enumerate(mix) if abs(s) > 1e-3), default=0)
        mix = mix[:last + int(RATE * 0.05)]
    peak = max(1e-6, max(abs(s) for s in mix))
    g = min(GAIN, 0.98 / peak)
    pcm = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * g)) * 32767)) for s in mix)
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"{song.lower()}.wav"
    chunks = b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16)
    chunks += b"data" + struct.pack("<I", len(pcm)) + pcm
    if loop_pts:
        smpl = struct.pack("<9I", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0) + struct.pack("<6I", 0, 0, loop_pts[0], loop_pts[1] - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    out.write_bytes(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)
    print(out.name, "%.1f초" % (len(mix) / RATE), ("루프 %.1f~%.1f초" % (loop_pts[0] / RATE, loop_pts[1] / RATE)) if loop_pts else "한 번",
          "음표", len(seq["notes"]), "볼륨", seq_vol, "배율 %.2f" % g)
    return out


def render_note(mix, nd, key, start, length, a, dcy, sus, rel, vel, base_db, vol_db, semi, sd, fr_len):
    typ = nd["type"]
    env_step = RATE / FRAME_HZ
    amp = AMPL_MIN
    phase = "attack"
    arate, drate, rrate = attack_rate(a), fall_rate(dcy), fall_rate(rel)
    sus_level = db10(sus) * 128.0
    vel_db = db10(vel)
    if typ == 1:
        if nd["swar"] == 0xFFFF:
            return
        war = sd.swar(nd["swar"])
        if nd["swav"] >= len(war):
            return
        w = decode_swav(*war[nd["swav"]])
        data, lp = w["data"], w["loop"]
        if not data:
            return
    pos, t, lfsr = 0.0, 0.0, 0x7FFF
    n, next_env = 0, 0.0
    lin = 0.0
    step = 0.0
    nmax = len(mix) - start
    duty = (nd["swav"] + 1) / 8.0 if typ == 2 else 0.5
    while n < nmax:
        if n >= next_env:
            next_env += env_step
            if n >= length and phase != "release":
                phase = "release"
            if phase == "attack":
                amp = (amp * arate) // 256
                if amp >= -1 or arate == 0:
                    amp = 0; phase = "decay"
            elif phase == "decay":
                amp -= drate
                if amp <= sus_level:
                    amp = sus_level; phase = "sustain"
            elif phase == "release":
                amp -= rrate
                if amp <= AMPL_MIN:
                    break
            fi = min(int((start + n) / fr_len), len(vol_db) - 1)
            total_db = amp / 128.0 + vel_db + base_db + vol_db[fi]
            lin = 10 ** (max(-723.0, total_db) / 200.0)
            p = key - nd["key"] + semi[fi]
            if typ == 1:
                step = w["rate"] * 2 ** (p / 12.0) / RATE
            else:                                  # PSG: 기준음에서 440Hz(사각파 한 주기 8칸)
                step = 440.0 * 2 ** (p / 12.0) / RATE
        if typ == 1:
            ip = int(pos)
            if ip >= len(data):
                if lp is None:
                    break
                pos = lp + (pos - len(data)); ip = int(pos)
                if ip >= len(data):
                    break
            x = data[ip]
            pos += step
        elif typ == 2:
            t += step
            x = 1.0 if (t % 1.0) < duty else -1.0
        else:
            t += step * 8
            while t >= 1.0:
                t -= 1.0
                bit = (lfsr ^ (lfsr >> 1)) & 1
                lfsr = (lfsr >> 1) | (bit << 14)
            x = 1.0 if lfsr & 1 else -1.0
        mix[start + n] += x * lin
        n += 1


def main():
    sd = Sdat(SDAT)
    for song in sys.argv[1:] or SONGS:
        render(song, sd)


if __name__ == "__main__":
    main()
