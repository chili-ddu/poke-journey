class_name MonSprite
extends RefCounted

# PMD Sprite Collab 형식의 도트 시트를 읽는다.
#   assets/sprites/<도감번호 4자리>/AnimData.xml, Walk-Anim.png, Idle-Anim.png, Hurt-Anim.png ... (이로치는 그 안의 shiny/)
# 시트 한 장은 행이 방향 8개(아래부터 시계 반대 방향), 열이 프레임이다.
# 그리는 기준은 PMD Sprite Collab 사이트의 미리보기와 같다 — 프레임 상자를 한자리에 고정하고 프레임을 그대로 보여 준다.
# 방향·프레임마다 몸 중심을 다시 맞추지 않으므로, 돌아볼 때·뛸 때·공격할 때 몸이 시트에 그려진 대로 움직인다(사용자 결정).
# 상자의 어느 점을 발밑(ground)에 둘지는 아래를 보는 Walk 첫 프레임의 검은 점(몸 중심)으로 한 번만 정한다(anchor):
# 그 프레임에서는 예전 방식과 같은 자리라 그림자(feet_dy)·판정이 그대로 맞는다.
# <이름>-Offsets.png 의 점(검정 몸 중심, 빨강·파랑 손, 초록 머리)은 그 기준점을 재는 데만 쓴다.
# 폴더가 없으면 빈 사전을 돌려주고, Mon 은 도형 자리표시로 그린다 —
# 도트를 받기 전에도 게임이 돌아가게 하려는 것.

const ROOT := "res://assets/sprites/%04d/"
const CharmanderPalette = preload("res://scripts/view/charmander_palette.gd")
const PokemonPalette = preload("res://scripts/view/pokemon_palette.gd")
# Strike = 앞으로 짧게 뛰어들며 치기(파이리 계열·뿔충이에 있음), HitGround = 쓰러져 눕기(있는 종만)
# Charge = 힘을 모으는 자세(모든 종에 있음; PMD 의 Shoot 는 보통 이것을 복사한 것), Trip = 넘어짐(쓰러질 때, 있는 종만)
# Sleep = 누워 잠(모든 종에 있음) — Trip 이 없는 종의 쓰러짐 대체
# Hop = 폴짝 뜀(플레이어 회피)
# Jab = 짧게 찌르기(독침붕 연속찌르기), Shoot = 쏘기(독침). 없는 종은 Attack 으로 대신한다.
# Dance = 춤(꽃잎댄스·달콤한향기), Rotate = 제자리 돌기(고속스핀), Withdraw = 껍질에 숨기(껍질에숨기·방어), Double = 두 번 치기(덩굴채찍)
const ANIMS := ["Walk", "Idle", "Hurt", "Attack", "Strike", "Jab", "Shoot", "Charge", "Hop", "Trip", "Sleep", "HitGround", "Swing", "TailWhip", "Eat", "Dance", "Rotate", "Withdraw", "Double", "Slice", "SpAttack", "FlapAround", "Hover"]
# PMD 의 Duration 단위는 게임 프레임(1/60초)이다.
const TICK := 1.0 / 60.0
# Approved jump preview: preserve the total flight while redistributing the
# apex hold into the final descent. Fractional ticks are visual timing only.
const HOP_SOURCE_TICKS := [2, 1, 2, 3, 4, 4, 3, 2, 1, 2]
const HOP_VISUAL_TICKS := [2.0, 1.0, 2.0, 3.0, 2.0, 2.0, 3.0, 2.8, 4.2, 2.0]

static var _cache := {}
static var _release_bounds := {}
static var _visual_floor_cache := {}
static var _visual_images := {}
const SET_CACHE_LIMIT := 32

# shiny: 이로치 시트(PMD Sprite Collab 의 sprite/<번호>/0000/0001 → assets/sprites/<번호>/shiny/). 받아 둔 게 없으면 보통 시트.
static func load_set(dex: int, shiny: bool = false) -> Dictionary:
	SmoothSprite.prepare_pokemon(dex)
	var key := dex * 2 + (1 if shiny else 0)
	if _cache.has(key):
		return _cache[key]
	var dir := ROOT % dex
	if shiny and FileAccess.file_exists(dir + "shiny/AnimData.xml"):
		dir += "shiny/"
	if not FileAccess.file_exists(dir+"AnimData.xml"):
		return {}
	var info := _parse_anim_data(dir + "AnimData.xml")
	var out := {}
	for name in ANIMS:
		if not info.has(name):
			continue
		var src: String = name
		var seen := {}
		while info.has(src) and info[src].has("copy_of") and not seen.has(src):
			seen[src] = true
			src = String(info[src].copy_of)
		if not info.has(src) or seen.has(src): continue
		var path := dir + "%s-Anim.png" % src
		var tex := _load_texture(path)
		if tex == null:
			continue
		var meta: Dictionary = info[src] if info.has(src) else info[name]
		var fw := int(meta["fw"])
		var fh := int(meta["fh"])
		# 방향이 하나뿐인 시트(HitGround 등)는 행이 1개다.
		var rows := maxi(1, int(tex.get_height() / fh))
		out[name] = {"tex": tex, "source_path": path, "fw": fw, "fh": fh, "rows": rows, "durations": meta["durations"],
			"polished_charmander": dex == 4 and not shiny,
			"polished_pokemon": dex != 4 and not shiny, "dex":dex,
			"hit_frame": meta.get("hit_frame",0),
			"offsets_path":dir+"%s-Offsets.png"%src,
			"centers": _load_centers(dir + "%s-Offsets.png" % src, fw, fh, meta["durations"].size(), rows)}
	# 그림자를 발밑에 두기 위한 발끝 높이: 아래를 보는 걷기 첫 프레임에서 몸 중심 아래로 몇 px 에 발이 있는가.
	# anchor: 프레임 상자 가운데에서 그 몸 중심까지의 차이. 모든 동작·방향이 이 한 값으로 상자를 발밑에 놓는다.
	if out.has("Walk"):
		out["feet_dy"] = _measure_feet(out["Walk"])
		var wk: Dictionary = out["Walk"]
		out["anchor"] = (wk["centers"][0][0] as Vector2) - Vector2(wk["fw"], wk["fh"]) / 2.0
		out["reference_span"]=_walking_span(wk)
		# Color variants keep exactly the normal form's physical display scale.
		if shiny:
			var normal:=load_set(dex,false)
			out["reference_span"]=normal.get("reference_span",out["reference_span"])
	# Actors retain their own dictionaries. Visiting a large Pokédex should
	# not pin every species' source textures for the lifetime of the process.
	if _cache.size() >= SET_CACHE_LIMIT: _cache.erase(_cache.keys()[0])
	_cache[key] = out
	return out

# One stable extent for the whole species, not a new scale per pose/direction.
# Transparent frame padding and attack lunges must not determine body size.
static func _walking_span(anim: Dictionary) -> float:
	var image: Image=anim.tex.get_image()
	if image.is_compressed():image.decompress()
	var span:=1
	for row in int(anim.rows):
		for frame in anim.durations.size():
			var region:=Rect2i(frame*int(anim.fw),row*int(anim.fh),int(anim.fw),int(anim.fh))
			var used:=image.get_region(region).get_used_rect().size
			span=maxi(span,maxi(used.x,used.y))
	return float(span)

static func _measure_feet(anim: Dictionary) -> float:
	var img: Image = anim["tex"].get_image()
	var fw: int = anim["fw"]
	var fh: int = anim["fh"]
	if img == null or img.get_width() < fw or img.get_height() < fh:
		return fh / 2.0
	var bottom := 0
	for y in fh:
		for x in fw:
			if img.get_pixel(x, y).a > 0.5:
				bottom = y
				break
	var center: Vector2 = anim["centers"][0][0]
	return float(bottom + 1) - center.y

# 에디터가 import 한 텍스처가 있으면 그걸 쓰고(내보내기에서도 동작),
# 방금 넣어서 아직 import 전인 파일은 PNG 를 직접 읽는다.
static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img != null else null

# 오프셋 시트에서 방향(행)·프레임(열)마다 검은 점(몸 중심)의 자리를 읽는다. 검은 점이 없으면 파란 점(오른손), 그것도 없으면 프레임 가운데.
# (독침붕처럼 팔이 몸에서 멀리 뻗은 종은 손 점을 쓰면 그림자가 몸 옆으로 빠진다.)
static func _load_centers(path: String, fw: int, fh: int, frames: int, rows: int, torso: bool=false) -> Array:
	var baked := SmoothSprite.pokemon_centers(path.replace("-Offsets.png", "-Anim.png"), torso)
	if baked.size() == rows and baked.all(func(row): return row.size() == frames): return baked
	var centers: Array = []
	var img: Image = null
	var tex := _load_texture(path)
	if tex != null:
		img = tex.get_image()
		if img.get_height() < rows * fh or img.get_width() < frames * fw:
			img = null
	for row in rows:
		var cols: Array = []
		for f in frames:
			var c := Vector2(fw / 2.0, fh / 2.0)
			if img != null:
				var found := false
				var hand := Vector2(-1, -1)
				var head := Vector2(-1, -1)
				for y in fh:
					if found:
						break
					for x in fw:
						var px := img.get_pixel(f * fw + x, row * fh + y)
						if px.a <= 0.5:
							continue
						if px.r < 0.1 and px.g < 0.1 and px.b < 0.1:
							head=Vector2(x,y)
							if not torso:
								c=head;found=true;break
						if torso and px.g>0.9 and px.r<0.1 and px.b<0.1:
							c=Vector2(x,y);found=true;break
						if px.b > 0.9 and px.r < 0.1 and px.g < 0.1:
							hand = Vector2(x, y)
				if not found:
					if head.x>=0:c=head
					elif hand.x>=0:c=hand
			cols.append(c)
		centers.append(cols)
	return centers

# Flight aligns the carrier's torso/talons (green native marker). Using its
# black head marker instead leaves a sideways-facing bird a beak-length away
# from its passenger. Other actions retain their existing native anchors.
static func flight_anchor(anim: Dictionary, row: int, time: float, visual: Dictionary) -> Vector2:
	if not anim.has("flight_centers"):
		anim["flight_centers"]=_load_centers(String(anim.get("offsets_path","")),int(anim.fw),int(anim.fh),anim.durations.size(),int(anim.rows),true)
	var centers: Array=anim.flight_centers[row]
	var frame:=frame_at(anim,time,true)
	var center: Vector2=centers[frame]
	if visual.tex!=anim.tex:
		if visual.has("torso_delta"):
			center += visual.torso_delta
		else:
			center=center.lerp(centers[(frame+1)%centers.size()],float(visual.get("phase_weight",0.0)))
	return center

static func _parse_anim_data(path: String) -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(path):
		return out
	var xml := XMLParser.new()
	if xml.open(path) != OK:
		return out
	var cur := {}
	var tag := ""
	while xml.read() == OK:
		match xml.get_node_type():
			XMLParser.NODE_ELEMENT:
				tag = xml.get_node_name()
				if tag == "Anim":
					cur = {"durations": []}
			XMLParser.NODE_TEXT:
				var text := xml.get_node_data().strip_edges()
				if text == "":
					continue
				match tag:
					"Name": cur["name"] = text
					"FrameWidth": cur["fw"] = int(text)
					"FrameHeight": cur["fh"] = int(text)
					"Duration": cur["durations"].append(int(text))
					"HitFrame": cur["hit_frame"] = int(text)
					"CopyOf": cur["copy_of"] = text
			XMLParser.NODE_ELEMENT_END:
				if xml.get_node_name() == "Anim" and cur.has("name"):
					out[cur["name"]] = cur
				tag = ""
	return out

# 한 동작의 프레임 상자 안에서 발밑(ground)에 놓을 점. 상자 가운데 + anchor(Walk 첫 프레임 기준) — 방향·프레임에 관계없이 같다.
static func anchor_of(sprites: Dictionary, anim: Dictionary) -> Vector2:
	return Vector2(anim["fw"], anim["fh"]) / 2.0 + (sprites.get("anchor", Vector2.ZERO) as Vector2)

# 달려드는 동작(Attack·Strike)에서 몸이 가장 멀리 나간 프레임(Offsets 시트의 몸 중심이 첫 프레임에서 가장 멀어진 곳).
# 근접기는 여기까지만 재생하고 멈춘다 — '도트를 반만' 써서 앞으로 나가며 치는 느낌(사용자 결정 2026-10-30).
static func lunge_mid(anim: Dictionary, row: int) -> int:
	var key := "mid%d" % row
	if anim.has(key):
		return int(anim[key])
	var centers: Array = anim.get("centers", [])
	var best := 0
	if row < centers.size():
		var cs: Array = centers[row]
		var far := 0.0
		for f in cs.size():
			var d: float = (cs[f] as Vector2).distance_to(cs[0])
			if d > far + 0.01:
				far = d
				best = f
	anim[key] = best
	return best

# 그 프레임에서 몸 중심이 첫 프레임보다 얼마나 옮겨 갔나(도트 px). 동작이 끝나면 이만큼 자리를 옮겨 '돌아오지 않게' 한다.
static func lunge_offset(anim: Dictionary, row: int, frame: int) -> Vector2:
	var centers: Array = anim.get("centers", [])
	if row >= centers.size():
		return Vector2.ZERO
	var cs: Array = centers[row]
	if frame >= cs.size() or cs.is_empty():
		return Vector2.ZERO
	return (cs[frame] as Vector2) - (cs[0] as Vector2)

# 바라보는 방향 → 시트의 행. 0=아래, 1=오른아래, 2=오른쪽, ... 7=왼아래. 방향이 하나뿐인 시트는 0.
static func row_for(anim: Dictionary, facing: Vector2) -> int:
	return mini(dir_row(facing), int(anim.get("rows", 8)) - 1)

static func dir_row(facing: Vector2) -> int:
	if facing.length_squared() < 0.0001:
		return 0
	# 화면 좌표는 y 가 아래로 자라므로 "아래"가 각도 π/2 이고, 화면에서 시계 반대로 돌면 각도가 줄어든다.
	var a := fposmod(PI / 2.0 - facing.angle(), TAU)
	return int(round(a / (TAU / 8.0))) % 8

# loop 가 거짓이면 끝난 뒤 마지막 프레임에 멈춘다(공격·피격).
# 동작 한 번의 길이(초).
# 그 프레임이 시작하는 시각(초).
static func frame_start(anim: Dictionary, frame: int) -> float:
	var total := 0
	var durs: Array = anim["durations"]
	for i in mini(frame, durs.size()):
		total += int(durs[i])
	return total * TICK

# 달려드는 동작에서 몸이 앞으로 나가기 시작하는 프레임(0번 프레임보다 바라보는 쪽으로 1px 넘게 나간 첫 프레임 — 몸통박치기처럼
# 뒤로 젖히는 준비 프레임은 치지 않는다). 없으면 가장 앞 프레임.
static func lunge_start(anim: Dictionary, row: int, fwd: Vector2 = Vector2.ZERO) -> int:
	var mid := lunge_mid(anim, row)
	for f in range(1, mid + 1):
		var off := lunge_offset(anim, row, f)
		if (off.dot(fwd) if fwd != Vector2.ZERO else off.length()) > 1.0:
			return f
	return mid

# 맞는 순간으로 쓸 프레임: 바라보는 쪽으로 가장 많이 나간 값의 90% 에 처음 닿는 프레임(가장 먼 프레임은 몸을 숙이는 아래 성분까지 쳐서
# 늦게 잡혔다 — 할퀴기는 다 나간 뒤 숙인다).
static func lunge_hit_frame(anim: Dictionary, row: int, fwd: Vector2) -> int:
	var mid := lunge_mid(anim, row)
	var best := 0.0
	for f in range(0, mid + 1):
		best = maxf(best, lunge_offset(anim, row, f).dot(fwd))
	if best <= 0.5:
		return mid
	for f in range(0, mid + 1):
		if lunge_offset(anim, row, f).dot(fwd) >= best * 0.9:
			return f
	return mid

static func anim_length(anim: Dictionary) -> float:
	var total := 0
	for d in anim["durations"]:
		total += int(d)
	return total * TICK

# Map the display clock back into the unmodified source sheet. All installed
# Hop sheets use this profile; unfamiliar future layouts retain their timing.
static func hop_sheet_time(anim: Dictionary, elapsed: float) -> float:
	var time := clampf(elapsed, 0.0, anim_length(anim))
	if anim.durations != HOP_SOURCE_TICKS: return time
	var remaining := time / TICK
	for i in HOP_VISUAL_TICKS.size():
		var duration: float = HOP_VISUAL_TICKS[i]
		if remaining < duration:
			return frame_start(anim, i) + remaining / duration * float(anim.durations[i]) * TICK
		remaining -= duration
	return anim_length(anim)

static func frame_at(anim: Dictionary, t: float, loop: bool = true) -> int:
	var durs: Array = anim["durations"]
	if durs.is_empty():
		return 0
	var total := 0
	for d in durs:
		total += int(d)
	var tick := int(maxf(0.0, t) / TICK)
	if not loop and tick >= total:
		return durs.size() - 1
	tick %= maxi(1, total)
	for i in durs.size():
		tick -= int(durs[i])
		if tick < 0:
			return i
	return 0

# Resolve the visual subframe without changing metadata used by battle logic.
# A held/truncated attack must not start morphing toward its discarded recovery.
static func visual_frame(anim: Dictionary, row: int, t: float, loop: bool = true, shown: int = -1, last: int = -1, pose_order: Array = []) -> Dictionary:
	if pose_order.is_empty():pose_order=anim.get("pose_order",[])
	var frame := frame_at(anim, t, loop)
	if not pose_order.is_empty(): shown = int(pose_order[mini(frame, pose_order.size()-1)])
	if shown < 0: shown = frame
	var size := Vector2(anim.fw, anim.fh)
	var src := Rect2(Vector2(shown * size.x, row * size.y), size)
	var body: Vector2 = anim.centers[row][shown] if anim.has("centers") else size / 2.0
	if anim.get("native_frames",false) or (frame != shown and pose_order.is_empty()) or (last >= 0 and shown >= last):
		return {"tex": anim.tex, "src": src, "body_center": body}
	var count: int = anim.durations.size()
	var next := (frame + 1) % count if loop else mini(frame + 1, count - 1)
	if not pose_order.is_empty(): next = int(pose_order[mini(next, pose_order.size()-1)])
	var duration := float(anim.durations[frame]) * TICK
	var local := fposmod(maxf(t, 0.0), anim_length(anim)) if loop else maxf(t, 0.0)
	var progress := clampf((local - frame_start(anim, frame)) / maxf(duration, 0.00001), 0.0, 1.0)
	# Custom Scratch/flight sequences keep their authored pose rhythm. Their
	# passing pose still uses the 2x atlas; generic key holds must not retime it.
	var visual := SmoothSprite.between(anim.tex, src, Rect2(Vector2(next * size.x, row * size.y), size), progress, null, String(anim.get("source_path", "")), pose_order.is_empty())
	# The visible subframe and its anchor must advance together. Using only the
	# source key's marker makes a grounded pose slide then snap at each key.
	if visual.tex != anim.tex and anim.has("centers"):
		if visual.has("body_delta"):
			body += visual.body_delta
		else:
			body = body.lerp(anim.centers[row][next], float(visual.get("phase_weight", 0.0)))
	visual["body_center"] = body
	return visual

# Keep visual_frame's source-key/atlas contract for animation and geometry
# queries. Apply species art direction only when a world actor is drawn.
static func display_frame(anim: Dictionary, row: int, t: float, loop: bool = true, shown: int = -1, last: int = -1, pose_order: Array = []) -> Dictionary:
	var visual := visual_frame(anim, row, t, loop, shown, last, pose_order)
	if anim.get("polished_charmander", false): return CharmanderPalette.frame(visual)
	if anim.get("polished_pokemon", false): return PokemonPalette.frame(visual,int(anim.dex))
	return visual

# Support point of the actual baked silhouette, in local frame coordinates.
# Grounding against the previous key's bottom makes the head bob backward
# during interpolation even though every source key appears grounded.
static func visual_bottom(visual: Dictionary) -> float:
	var rect := Rect2i(visual.src)
	var key := "%d:%s" % [visual.tex.get_instance_id(), str(rect)]
	if _visual_floor_cache.has(key): return _visual_floor_cache[key]
	var image:=_visual_image(visual.tex)
	var bottom := float(rect.size.y / 2)
	for y in range(rect.size.y - 1, -1, -1):
		var found := false
		for x in rect.size.x:
			if image.get_pixel(rect.position.x + x, rect.position.y + y).a > 0.5:
				bottom = float(y)
				found = true
				break
		if found: break
	_visual_floor_cache[key] = bottom
	return bottom

static func _visual_image(texture: Texture2D) -> Image:
	var id: int = texture.get_instance_id()
	if not _visual_images.has(id):
		if _visual_images.size() >= 8: _visual_images.erase(_visual_images.keys()[0])
		var decoded: Image = texture.get_image()
		if decoded.is_compressed(): decoded.decompress()
		_visual_images[id] = decoded
	return _visual_images[id]

static func release_bounds(texture: Texture2D,frame: Rect2i) -> Rect2:
	var key: Array=[texture.get_instance_id(),frame]
	if not _release_bounds.has(key):
		if _release_bounds.size()>=1024: _release_bounds.erase(_release_bounds.keys()[0])
		_release_bounds[key]=Rect2(_visual_image(texture).get_region(frame).get_used_rect())
	return _release_bounds[key]

# Lowest opaque pixel in a pose, cached once per sheet frame. Grounded melee
# uses the silhouette support point rather than the moving torso marker.
static func frame_bottom(anim: Dictionary, row: int, frame: int) -> float:
	var key := "floor_%d_%d" % [row, frame]
	if anim.has(key): return float(anim[key])
	var img: Image = anim["tex"].get_image()
	var fw := int(anim["fw"])
	var fh := int(anim["fh"])
	var bottom := float(fh / 2)
	for y in range(fh - 1, -1, -1):
		var found := false
		for x in fw:
			if img.get_pixel(frame * fw + x, row * fh + y).a > 0.5:
				bottom = float(y)
				found = true
				break
		if found: break
	anim[key] = bottom
	return bottom
