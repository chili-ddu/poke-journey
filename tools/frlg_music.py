"""파이어레드 음악(m4a) 합성 → assets/audio/<곡>.wav

  python3 -I tools/frlg_music.py mus_pallet mus_route1 …     (곡 이름을 안 주면 SONGS 전부)

사용자 결정 2026-10-29: BGM 을 원본 데이터로 직접 합성한다(장소 곡은 파이어레드 — 지도 기준, 시스템·배틀 곡은 플래티넘 tools/plat_music.py).
pret/pokefirered 의
  sound/songs/midi/<곡>.mid          악보(mid2agb 가 쓰는 원본 MIDI). 메타 텍스트 "[" "]" 가 반복 구간
  sound/songs/midi/midi.cfg          곡 설정: -G 악기 묶음(voicegroup) 번호, -V 곡 볼륨, -R 리버브
  sound/voice_groups.inc             악기 묶음(프로그램 번호 → 악기). 128칸보다 짧은 묶음은 원작 롬처럼 바로 뒤 묶음의 칸으로 이어진다
  sound/keysplit_tables.inc          건반 나눔 표(voice_keysplit: 건반 → 하위 악기)
  sound/direct_sound_samples/*.wav   악기 샘플(8비트, smpl 청크의 루프)
  sound/programmable_wave_samples/*  웨이브 채널 파형(4비트 32개)
을 읽어, GBA 사운드 엔진(m4a)이 하듯 소리를 낸다:
  DirectSound      샘플을 (건반 − 기준음) 반음만큼 빠르게 읽고(보간 없이; no_resample 은 그대로), 엔벨로프는 프레임(60Hz)마다
                   attack(+attack, 255 까지) → decay(×decay/256, sustain 까지) → 건반을 떼면 release(×release/256)
  CGB 사각파·웨이브·노이즈  엔벨로프 0~15 단계(attack/decay/release 는 단계마다 걸리는 프레임 수, 0 이면 즉시), 사각파 듀티·스윕(NR10),
                   웨이브는 32개 4비트 파형, 노이즈는 LFSR(15/7비트)
  드럼킷(voice_keysplit_all)  건반 번호 = 하위 악기 번호, 소리는 그 악기의 기준음 높이로
  건반 나눔(voice_keysplit)   표대로 하위 악기를 고르고 소리는 누른 건반 높이로
  볼륨             세기 × 트랙 볼륨(CC7, 바뀌면 소리 도중에도) × 곡 볼륨(-V)
  피치             벤드(벤드 폭 CC20, 기본 2반음) + 비브라토(깊이 CC1, 속도 CC21 — m4a 처럼 아주 옅게)
  리버브           -R 값으로 한두 프레임 앞 출력을 되먹임(m4a 의 간단한 리버브 흉내)
반복 구간이 있으면 처음 → 반복 두 번을 굽고 둘째 반복을 WAV smpl 루프로 적는다(첫 반복에서 넘어온 꼬리까지 이어져 매끄럽다).
Godot 는 smpl 루프를 읽어 그대로 되풀이한다. 믹싱은 파이어레드 기본값 13379Hz(원작의 거친 소리), 16비트 모노. 원작과 똑같지는 않다(흉내).
원작 자료는 Nintendo / Game Freak — personal use 로만.
"""
import math
import re
import struct
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TP = ROOT / "third_party" / "pokefirered"
RAW = "https://raw.githubusercontent.com/pret/pokefirered/master/"
OUT = ROOT / "assets" / "audio"
RATE = 13379
FRAME = RATE / 60.0
GAIN = 0.55                     # 모든 곡 같은 배율(곡 볼륨 -V 차이가 그대로 남게). 넘치면 그 곡만 줄인다
CGB_LEVEL = 0.32                # CGB 채널 최대 진폭(DirectSound 최대 1 기준)
# 이 게임에서 쓰는 장소 곡(지도 기준, 원작 map.json 의 music)
SONGS = ["mus_pallet", "mus_oak_lab", "mus_route1", "mus_pewter", "mus_poke_center", "mus_viridian_forest", "mus_gym"]


def fetch(rel: str) -> Path:
    p = TP / rel
    if not p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(RAW + rel, timeout=60) as r:
            p.write_bytes(r.read())
    return p


# ── MIDI ──

def read_midi(path: Path) -> dict:
    d = path.read_bytes()

    def vlq(b, i):
        v = 0
        while True:
            c = b[i]; i += 1; v = (v << 7) | (c & 0x7F)
            if c < 0x80:
                return v, i

    _, ntr, div = struct.unpack(">HHH", d[8:14])
    i, tempos, tracks, loop = 14, [], [], [None, None]
    for _ in range(ntr):
        ln = struct.unpack(">I", d[i + 4:i + 8])[0]
        b = d[i + 8:i + 8 + ln]; i += 8 + ln
        j = tick = run = 0
        ev = []
        while j < len(b):
            dt, j = vlq(b, j); tick += dt
            st = b[j]
            if st == 0xFF:
                ty = b[j + 1]; ml, j2 = vlq(b, j + 2); data = b[j2:j2 + ml]; j = j2 + ml
                if ty == 0x51:
                    tempos.append((tick, int.from_bytes(data, "big")))
                elif ty in (1, 6) and data in (b"[", b"]"):
                    loop[0 if data == b"[" else 1] = tick
                continue
            if st in (0xF0, 0xF7):
                ml, j2 = vlq(b, j + 1); j = j2 + ml
                continue
            if st >= 0x80:
                run = st; j += 1
            n = 1 if run & 0xF0 in (0xC0, 0xD0) else 2
            ev.append((tick, run & 0xF0, list(b[j:j + n]))); j += n
        tracks.append(ev)
    if not tempos:
        tempos = [(0, 500000)]
    return {"div": div, "tempos": sorted(tempos), "tracks": tracks,
            "loop": (loop[0], loop[1]) if loop[0] is not None and loop[1] is not None else None}


# ── 악기 ──

def song_cfg(song: str) -> dict:
    line = next(l for l in fetch("sound/songs/midi/midi.cfg").read_text().splitlines() if l.startswith(song + ".mid"))
    cfg = {"G": 0, "V": 127, "R": 0}
    for k, v in re.findall(r"-([GVR])(\d+)", line):
        cfg[k] = int(v)
    return cfg


_flat = None


def _voices() -> tuple:
    global _flat
    if _flat is None:
        lines, labels = [], {}
        for l in fetch("sound/voice_groups.inc").read_text().splitlines():
            s = l.strip()
            m = re.match(r"(voicegroup\d+)::", s)
            if m:
                labels[m.group(1)] = len(lines)
            elif s.startswith("voice_"):
                lines.append(s)
        _flat = (lines, labels)
    return _flat


def voicegroup(n) -> list:
    """악기 묶음의 128칸. 원작 롬처럼 묶음이 128칸보다 짧으면 파일에서 바로 뒤에 오는 묶음의 칸으로 이어진다(같은 메모리)."""
    lines, labels = _voices()
    start = labels[n if isinstance(n, str) else "voicegroup%03d" % n]
    return lines[start:start + 128]


_keysplits = None


def keysplit(name: str) -> dict:
    global _keysplits
    if _keysplits is None:
        _keysplits, cur, key = {}, None, 0
        for l in fetch("sound/keysplit_tables.inc").read_text().splitlines():
            m = re.match(r"\.set (KeySplitTable\d+), \. - (\d+)", l.strip())
            if m:
                cur, key = m.group(1), int(m.group(2)); _keysplits[cur] = {}
                continue
            m = re.match(r"\.byte (\d+)", l.strip())
            if m and cur:
                _keysplits[cur][key] = int(m.group(1)); key += 1
    return _keysplits[name]


_samples = {}
_waves = {}
_parsed = {}


def parse_voice(line: str) -> dict:
    if line in _parsed:
        return _parsed[line]
    kind, _, args = line.partition(" ")
    a = [x.strip() for x in args.split(",")]
    if kind.startswith("voice_directsound"):
        v = {"kind": "ds", "base": int(a[0]), "sample": load_sample(a[2].replace("DirectSoundWaveData_", "")),
             "fixed": kind == "voice_directsound_no_resample",
             "attack": int(a[3]), "decay": int(a[4]), "sustain": int(a[5]), "release": int(a[6])}
    elif kind.startswith("voice_square_1"):
        v = {"kind": "sq", "base": int(a[0]), "sweep": int(a[2]), "duty": int(a[3]),
             "attack": int(a[4]), "decay": int(a[5]), "sustain": int(a[6]), "release": int(a[7])}
    elif kind.startswith("voice_square_2"):
        v = {"kind": "sq", "base": int(a[0]), "sweep": 0, "duty": int(a[2]),
             "attack": int(a[3]), "decay": int(a[4]), "sustain": int(a[5]), "release": int(a[6])}
    elif kind.startswith("voice_programmable_wave"):
        v = {"kind": "wave", "base": int(a[0]), "wave": load_wave(a[2]),
             "attack": int(a[3]), "decay": int(a[4]), "sustain": int(a[5]), "release": int(a[6])}
    elif kind.startswith("voice_noise"):
        v = {"kind": "noise", "base": int(a[0]), "period": int(a[2]),
             "attack": int(a[3]), "decay": int(a[4]), "sustain": int(a[5]), "release": int(a[6])}
    elif kind == "voice_keysplit":
        v = {"kind": "split", "group": a[0], "table": a[1]}
    elif kind == "voice_keysplit_all":
        v = {"kind": "drums", "group": a[0]}
    else:
        raise SystemExit("아직 못 내는 악기: " + line)
    _parsed[line] = v
    return v


def resolve(vg: list, prog: int, key: int):
    """프로그램·건반 → (실제 악기, 소리 낼 건반). 드럼킷은 건반이 악기 번호이고 그 악기의 기준음으로 소리 낸다."""
    v = parse_voice(vg[prog])
    if v["kind"] == "split":
        sub = keysplit(v["table"]).get(key, 0)
        return parse_voice(voicegroup(v["group"])[sub]), key
    if v["kind"] == "drums":
        dv = parse_voice(voicegroup(v["group"])[key])
        return dv, dv["base"]
    return v, key


def load_sample(name: str) -> dict:
    if name in _samples:
        return _samples[name]
    d = fetch(f"sound/direct_sound_samples/{name}.wav").read_bytes()
    i, out = 12, {"rate": 0, "loop": None, "data": [], "key": 60}
    while i < len(d):
        cid = d[i:i + 4]; ln = struct.unpack("<I", d[i + 4:i + 8])[0]; body = d[i + 8:i + 8 + ln]
        if cid == b"fmt ":
            out["rate"] = struct.unpack("<I", body[4:8])[0]
            assert struct.unpack("<H", body[14:16])[0] == 8, "8비트 샘플만"
        elif cid == b"smpl":
            if struct.unpack("<I", body[28:32])[0] > 0:
                lp = struct.unpack("<6I", body[36:60])
                out["loop"] = (lp[2], lp[3] + 1)
        elif cid == b"data":
            out["data"] = [(b - 128) / 128.0 for b in body]
        i += 8 + ln + (ln & 1)
    _samples[name] = out
    return out


def load_wave(name: str) -> list:
    if name in _waves:
        return _waves[name]
    n = int(name.replace("ProgrammableWaveData_", ""))
    b = fetch(f"sound/programmable_wave_samples/{n:02d}.pcm").read_bytes()[:16]
    w = []
    for x in b:
        w.append(((x >> 4) - 7.5) / 7.5)
        w.append(((x & 15) - 7.5) / 7.5)
    _waves[name] = w
    return w


# ── 소리내기 ──

def render_note(v: dict, key: int, start: int, length: int, ctl) -> tuple:
    """한 음 → (시작 샘플, 진폭 목록). ctl(frame) → (반음 보정, 볼륨 배율) — 트랙의 벤드·비브라TO·볼륨을 프레임마다."""
    out = []
    fr = int(FRAME)
    n = 0
    if v["kind"] == "ds":
        s = v["sample"]
        data, loop = s["data"], s["loop"]
        if not data:
            return start, out
        env, phase = 0.0, "attack"
        pos, step, vol = 0.0, 1.0, 0.0
        while n < RATE * 6:
            if n % fr == 0:
                if n >= length and phase != "release":
                    phase = "release"
                if phase == "attack":
                    env = min(255.0, env + v["attack"])
                    if env >= 255.0:
                        phase = "decay"
                elif phase == "decay":
                    env = env * v["decay"] / 256.0
                    if env <= v["sustain"]:
                        env = float(v["sustain"]); phase = "sustain"
                elif phase == "release":
                    env = env * v["release"] / 256.0
                    if env < 1.0:
                        break
                if phase == "sustain" and env < 1.0:
                    break
                semi, vol = ctl((start + n) // fr)
                step = 1.0 if v["fixed"] else s["rate"] * 2 ** ((key + semi - v["base"]) / 12.0) / RATE
            ip = int(pos)
            if loop is not None and ip >= loop[1]:
                pos -= (loop[1] - loop[0]); ip = int(pos)
            if ip >= len(data):
                break
            out.append(data[ip] * env / 255.0 * vol)
            pos += step
            n += 1
        return start, out
    # CGB(사각파·웨이브·노이즈): 엔벨로프 0~15, 단계마다 attack/decay/release 프레임.
    env = 15 if v["attack"] == 0 else 0
    phase = "decay" if v["attack"] == 0 else "attack"
    cnt = 0
    t, vol, freq = 0.0, 0.0, 440.0
    reg = None
    lfsr, nacc = 0x7FFF, 0.0
    duty = [0.125, 0.25, 0.5, 0.75][v.get("duty", 2) & 3]
    sweep = v.get("sweep", 0)
    sw_time, sw_dir, sw_shift = (sweep >> 4) & 7, (sweep >> 3) & 1, sweep & 7
    sw_every = int(RATE / 128.0 * sw_time) if sw_time else 0
    level = CGB_LEVEL * (0.8 if v["kind"] == "noise" else 1.0)
    while n < RATE * 6:
        if n % fr == 0:
            if n >= length and phase != "release":
                phase = "release"; cnt = 0
                if v["release"] == 0:
                    break
            cnt += 1
            if phase == "attack" and cnt >= max(1, v["attack"]):
                cnt = 0; env += 1
                if env >= 15:
                    env = 15; phase = "decay"
            elif phase == "decay" and v["decay"] and cnt >= v["decay"]:
                cnt = 0; env -= 1
                if env <= v["sustain"]:
                    env = v["sustain"]; phase = "sustain"
            elif phase == "release" and cnt >= v["release"]:
                cnt = 0; env -= 1
            if env <= 0 and phase != "attack":
                break
            semi, vol = ctl((start + n) // fr)
            freq = 440.0 * 2 ** ((key + semi - 69) / 12.0)
            if reg is None:
                reg = 2048.0 - 131072.0 / freq
        if v["kind"] == "sq":
            if sw_every and sw_shift and n and n % sw_every == 0:
                reg += (-1 if sw_dir else 1) * (int(reg) >> sw_shift)
                if reg >= 2047 or reg <= 0:
                    break
            f = 131072.0 / (2048.0 - reg) if sw_every else freq
            t += f / RATE
            smp = 1.0 if (t % 1.0) < duty else -1.0
        elif v["kind"] == "wave":
            t += freq / RATE
            smp = v["wave"][int((t % 1.0) * 32) & 31]
        else:
            nacc += freq * 16.0 / RATE
            while nacc >= 1.0:
                nacc -= 1.0
                bit = (lfsr ^ (lfsr >> 1)) & 1
                lfsr = (lfsr >> 1) | (bit << 14)
                if v["period"]:
                    lfsr = (lfsr & ~0x40) | (bit << 6)
            smp = 1.0 if lfsr & 1 else -1.0
        out.append(smp * env / 15.0 * level * vol)
        n += 1
    return start, out


def render(song: str) -> Path:
    cfg = song_cfg(song)
    mid = read_midi(fetch(f"sound/songs/midi/{song}.mid"))
    vg = voicegroup(cfg["G"])
    div, loop = mid["div"], mid["loop"]
    end_tick = max((ev[-1][0] if ev else 0) for ev in mid["tracks"])
    # 반복: 처음 ~ 반복 끝, 그리고 반복 구간을 한 번 더(둘째 반복이 WAV 루프).
    tracks = []
    for ev in mid["tracks"]:
        if loop:
            first = [e for e in ev if e[0] < loop[1]]
            again = [(e[0] + loop[1] - loop[0], e[1], e[2]) for e in ev if loop[0] <= e[0] < loop[1]]
            tracks.append(first + again)
        else:
            tracks.append(ev)
    tempos = list(mid["tempos"])
    if loop:
        tempos += [(t + loop[1] - loop[0], v) for t, v in mid["tempos"] if loop[0] <= t < loop[1]]
    tempos.sort()
    total_ticks = loop[1] + (loop[1] - loop[0]) if loop else end_tick

    def tick_to_sample(tk):
        s, last_t, cur = 0.0, 0, tempos[0][1]
        for t, v in tempos:
            if t >= tk:
                break
            s += (t - last_t) * cur / 1e6 / div * RATE
            last_t, cur = t, v
        return int(s + (tk - last_t) * cur / 1e6 / div * RATE)

    total = tick_to_sample(total_ticks) + (0 if loop else RATE * 3)
    nframes = int(total / FRAME) + RATE * 7 // int(FRAME)
    mix = [0.0] * (total + RATE * 7)
    master = cfg["V"] / 127.0
    for ev in tracks:
        # 트랙 상태를 프레임 단위 표로 편다(볼륨·벤드·비브라토). 바뀌는 시각부터 적용.
        vol_f = [100.0] * nframes
        bend_f = [0.0] * nframes
        mod_f = [0.0] * nframes
        lfos_f = [22.0] * nframes
        prog, vol, bend, bendr, mod, lfos = 0, 100, 0, 2, 0, 22
        changes = []
        notes, on = [], {}
        for tick, cmd, args in ev:
            at = tick_to_sample(tick)
            if cmd == 0xC0:
                prog = args[0]
            elif cmd == 0xB0:
                c, val = args
                if c == 7:
                    vol = val; changes.append((at, "vol", val))
                elif c == 1:
                    mod = val; changes.append((at, "mod", val))
                elif c == 20:
                    bendr = val; changes.append((at, "bend", bend / 8192.0 * bendr))
                elif c == 21:
                    lfos = val; changes.append((at, "lfos", val))
            elif cmd == 0xE0:
                bend = ((args[1] << 7) | args[0]) - 8192
                changes.append((at, "bend", bend / 8192.0 * bendr))
            elif cmd == 0x90 and args[1] > 0:
                on.setdefault(args[0], []).append((at, args[1], prog))
            elif cmd == 0x80 or (cmd == 0x90 and args[1] == 0):
                if on.get(args[0]):
                    st, vel, pr = on[args[0]].pop(0)
                    notes.append((st, at - st, args[0], vel, pr))
        state = {"vol": 100.0, "bend": 0.0, "mod": 0.0, "lfos": 22.0}
        ci = 0
        changes.sort(key=lambda c: c[0])
        for f in range(nframes):
            fs = f * FRAME
            while ci < len(changes) and changes[ci][0] <= fs:
                state[changes[ci][1]] = float(changes[ci][2]); ci += 1
            vol_f[f], bend_f[f], mod_f[f], lfos_f[f] = state["vol"], state["bend"], state["mod"], state["lfos"]
        lfo_phase = [0.0] * nframes
        ph = 0.0
        for f in range(nframes):
            ph += lfos_f[f] / 256.0
            lfo_phase[f] = ph

        def make_ctl(vel):
            amp = vel / 127.0 * master

            def ctl(f):
                f = min(f, nframes - 1)
                semi = bend_f[f] + 0.25 * mod_f[f] / 127.0 * math.sin(2 * math.pi * lfo_phase[f])
                return semi, amp * vol_f[f] / 127.0
            return ctl

        for st, ln, key, vel, pr in notes:
            v, k = resolve(vg, pr, key)
            s0, data = render_note(v, k, st, ln, make_ctl(vel))
            for i2, x in enumerate(data):
                if s0 + i2 < len(mix):
                    mix[s0 + i2] += x
    # 리버브(-R): 한·두 프레임 앞 출력을 되먹임.
    r = cfg["R"] / 128.0 * 0.5
    f1, f2 = int(FRAME), int(FRAME * 2)
    for n in range(len(mix)):
        mix[n] += r * ((mix[n - f1] if n >= f1 else 0.0) + (mix[n - f2] if n >= f2 else 0.0)) * 0.5
    # DC 빼기(8비트 샘플·좁은 듀티 사각파의 치우침): 한 극 저역 차단(약 10Hz).
    prev_x = prev_y = 0.0
    for n in range(len(mix)):
        x = mix[n]
        prev_y = x - prev_x + 0.995 * prev_y
        prev_x = x
        mix[n] = prev_y
    loop_pts = None
    if loop:
        ls, le = tick_to_sample(loop[1]), tick_to_sample(loop[1] + loop[1] - loop[0])
        mix = mix[:le]
        # 이음매: 루프 끝 64샘플을 루프 시작 바로 앞 소리로 서서히 바꿔, 끝 → 시작으로 넘어갈 때 튀지 않게.
        xf = 64
        for k in range(xf):
            a = (k + 1) / xf
            mix[le - xf + k] = mix[le - xf + k] * (1 - a) + mix[ls - xf + k] * a
        loop_pts = (ls, le)
    else:
        last = max((k for k, s in enumerate(mix) if abs(s) > 1e-3), default=0)
        mix = mix[:last + int(RATE * 0.05)]
    peak = max(1e-6, max(abs(s) for s in mix))
    g = min(GAIN, 0.98 / peak)
    pcm = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * g)) * 32767)) for s in mix)
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"{song}.wav"
    chunks = b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16)
    chunks += b"data" + struct.pack("<I", len(pcm)) + pcm
    if loop_pts:
        smpl = struct.pack("<9I", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0) + struct.pack("<6I", 0, 0, loop_pts[0], loop_pts[1] - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    out.write_bytes(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)
    print(out.name, "%.1f초" % (len(mix) / RATE), ("루프 %.1f~%.1f초" % (loop_pts[0] / RATE, loop_pts[1] / RATE)) if loop_pts else "한 번",
          "악기 묶음", cfg["G"], "볼륨", cfg["V"], "배율 %.2f" % g)
    return out


def main():
    for song in sys.argv[1:] or SONGS:
        render(song)


if __name__ == "__main__":
    main()
