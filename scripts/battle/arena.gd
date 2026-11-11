class_name Arena
extends Node2D

# 싸움터. 두 가지 모드가 있다.
#   지도 모드  테마에 "map" 이 있으면 원작 지도를 구운 그림(bottom.png·top.png)과 칸 격자(map.json)를 쓴다.
#             통행 불가 칸(나무·건물)과 풀숲 칸(출현 지점)이 격자에 들어 있다. 카메라가 플레이어를 따라간다.
#             위층은 ArenaTop 이 타일 행 띠로 나눠 포켓몬과 y 정렬한다(나무 뒤는 가려지고 옆은 안 잘린다).
#   색칠 모드  옛 풀밭 아레나. 울타리 친 직사각형 + 원 바위.
# 충돌은 물리 엔진 없이 원-사각형 밀어내기로 처리한다 — 판정을 테스트에서 그대로 돌리려고.

const RECT := Rect2(32, 32, 576, 288)   # 색칠 모드의 싸움터
# 지도 한 칸의 월드 크기. 원작 타일은 16px 이지만 PMD 도트(파이리 약 20×22px)에 맞춰 1.5배로 키워 그린다(사용자: 풀숲이 파이리보다 작아 보임).
# 줌 2 에서 타일 픽셀 하나가 화면 3px 로 고르게 떨어지는 배율이라 번지지 않는다.
const TILE := 24
const SRC_TILE := 16               # 아틀라스·지도 그림의 원본 타일 크기
const MAP_SCALE := float(TILE) / float(SRC_TILE)
const ATLAS_PATH := "res://assets/tiles/frlg_general.png"

static var theme := {}            # 비어 있으면 meadow 기본값
static var obstacles: Array = []
static var map := {}              # 지도 모드: width, height, start(Vector2)
static var _water := {}
static var _dynamic_solid: Dictionary={}
static var _elevation: Array = []
static var _elevated_ledges := {}
static var _ledge_patches := {}
static var _ledge_resolution := 8
static var max_elevation := 0.0
static var _solid := PackedByteArray()
static var _ledge := PackedByteArray()      # 언덕 칸: 0 없음, 1~4 = 원작이 뛰어내리게 하는 방향(LEDGE_DIRS)
const LEDGE_CODES := {"e": 1, "w": 2, "n": 3, "s": 4}
const LEDGE_DIRS := [Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
static var _grass := PackedVector2Array()   # 풀숲 칸의 가운데 좌표
static var _grass_tiles := {}               # 풀숲 칸 {Vector2i: true} — 칸 하나 조회용(풀숲 흔들림)
static var _bottom: Texture2D = null
static var _pad := 0                         # bottom.png 의 사방 여백(칸) — 원작 테두리 무늬. 화면이 지도보다 넓어도 검게 비지 않는다.
static var _top: Texture2D = null
static var _atlas: Texture2D = null
static var _areas: Array = []                # [{id, rect: Rect2i}] 어느 원작 지도의 칸인지(출현표 구역)
static var _warps := {}                      # "x,y" → {x, y, map, index, to, to_warp}
static var _warp_tiles := {}                 # "map:index" → Vector2i

const NativeCollection = preload("res://scripts/johto/hgss_map_collection.gd")
const Continent = preload("res://scripts/data/continent_world.gd")
static var native_collection: NativeCollection
static var native_data: Dictionary = {}
static var continent_data: Dictionary = {}
static var native_height := Callable()
static var _native_solid := {}

static func configure(t: Dictionary) -> void:
	theme = t
	obstacles = t.get("obstacles", [])
	map = {}
	_water.clear()
	_dynamic_solid.clear()
	_elevation=[]
	_elevated_ledges={}
	_ledge_patches={}
	max_elevation=0.0
	_solid = PackedByteArray()
	_ledge = PackedByteArray()
	_cover_rows = {}
	_top_rows = {}            # 위층 행 캐시는 지도마다 다시(안 비우면 문으로 넘어간 큰 지도의 지붕·나무 윗부분이 안 그려졌다 — 2026-10-28)
	_grass = PackedVector2Array()
	_grass_tiles = {}
	_areas = []
	_warps = {}
	_warp_tiles = {}
	native_data={};continent_data={};native_height=Callable();_native_solid={}
	_bottom=null;_top=null;_pad=0
	if t.has("hgss_scene"):
		_load_native(t)
	elif t.has("map"):
		_load_map(t["map"])

static func is_native() -> bool:
	return not native_data.is_empty()

static func is_continent() -> bool:
	return not continent_data.is_empty()

static func native_at(tile: Vector2i) -> bool:
	return is_native() or (is_continent() and tile.x<0)

static func native_attributes(tile: Vector2i) -> int:
	return native_collection.attributes(native_data if is_native() else continent_data,tile if is_native() else tile-Continent.offset())

static func _attach_continent() -> void:
	native_collection=Continent.collection()
	continent_data=Continent.scene()
	var shift:=Continent.offset()
	var bound: Array=Continent.config().bounds
	map.origin=Vector2(bound[0],bound[1])*TILE
	map.world_size=Vector2(bound[2],bound[3])*TILE
	for area in continent_data.areas:
		_areas.append({"id":"johto_%03d" % int(area.header),"rect":Rect2i(Vector2i(int(area.x),int(area.z))+shift,Vector2i(int(area.width),int(area.height)))})
	for warp in continent_data.warps:
		var tile:=Vector2i(int(warp.x),int(warp.z))+shift
		var converted: Dictionary={"x":tile.x,"y":tile.y,"map":"johto_%03d" % int(warp.header),"index":int(warp.index),
			"to":"johto_%03d" % int(warp.to_header) if not String(warp.to).is_empty() else "","to_warp":int(warp.to_index)}
		if native_collection.portal(continent_data,tile-shift)==warp:
			_warps["%d,%d" % [tile.x,tile.y]]=converted
		_warp_tiles["%s:%d" % [converted.map,int(warp.index)]]=tile

static func _load_native(t: Dictionary) -> void:
	var directory: String=t.get("native_map",NativeCollection.BASE)
	if native_collection == null or native_collection.base_dir != directory:
		native_collection=NativeCollection.new(directory)
	native_data=native_collection.scene_data(t.hgss_scene)
	map={"width":int(native_data.width),"height":int(native_data.height),"start":native_collection.spawn(int(t.hgss_header))*TILE,"arena":{}}
	for area in native_data.areas:
		_areas.append({"id":"johto_%03d" % int(area.header),"rect":Rect2i(int(area.x),int(area.z),int(area.width),int(area.height))})
	for warp in native_data.warps:
		var converted := {"x":int(warp.x),"y":int(warp.z),"map":"johto_%03d" % int(warp.header),"index":int(warp.index),
			"to":"johto_%03d" % int(warp.to_header) if not String(warp.to).is_empty() else "","to_warp":int(warp.to_index)}
		if warp.has("game_to"):
			converted.to=String(warp.game_to)
			converted.to_warp=int(warp.game_to_warp)
		var key := "%d,%d" % [int(warp.x),int(warp.z)]
		# Shared scripted entrances use the explorer's canonical destination.
		var canonical := native_collection.portal(native_data,Vector2i(int(warp.x),int(warp.z)))
		if canonical == warp: _warps[key]=converted
		_warp_tiles["%s:%d" % [converted.map,int(warp.index)]]=Vector2i(int(warp.x),int(warp.z))

static func _load_map(dir: String) -> void:
	var f := FileAccess.open(dir + "/map.json", FileAccess.READ)
	if f == null:
		push_error("지도를 못 읽음 " + dir)
		return
	var j: Dictionary = JSON.parse_string(f.get_as_text())
	var w := int(j["width"])
	var h := int(j["height"])
	_solid.resize(w * h)
	_ledge.resize(w * h)
	var ledges: Array = j.get("ledge", [])
	for y in h:
		var row: String = j["solid"][y]
		var grow: String = j["grass"][y]
		var lrow: String = ledges[y] if y < ledges.size() else ""
		for x in w:
			_solid[y * w + x] = 1 if row[x] == "1" else 0
			_ledge[y * w + x] = int(LEDGE_CODES.get(lrow[x], 0)) if x < lrow.length() else 0
			if grow[x] == "1":
				_grass.append(Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0))
				_grass_tiles[Vector2i(x, y)] = true
	# 충돌 덧칠(tools/hd2d_cards.py 가 만든다): 화분은 잎 칸을 열어 화분 칸 1×1 만 막는다(사용자 2026-11-02: 화분 블록이 2×1 —
	# 1×1 이 자연스럽다). 잎 칸 뒤로 지나가면 3D 화분 판이 몸을 가린다(원작 위층처럼).
	var pf := FileAccess.open(dir + "/collision_patch.json", FileAccess.READ)
	if pf != null:
		var patch: Dictionary = JSON.parse_string(pf.get_as_text())
		for c in patch.get("open", []):
			var cx := int(c[0])
			var cy := int(c[1])
			if cx >= 0 and cx < w and cy >= 0 and cy < h:
				_solid[cy * w + cx] = 0
		# Explicit prop footprints are applied after openings so side-strip cleanup cannot clear them.
		for c in patch.get("block", []):
			var cx := int(c[0])
			var cy := int(c[1])
			if cx >= 0 and cx < w and cy >= 0 and cy < h:
				_solid[cy * w + cx] = 1
	var water_file := dir+"/water.json"
	if FileAccess.file_exists(water_file):
		var water_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(water_file))
		var water_rows: Array=water_data.get("water",[])
		for y in mini(h,water_rows.size()):
			for x in mini(w,String(water_rows[y]).length()):
				if water_rows[y][x]=="1": _water[Vector2i(x,y)]=true

	var elevation_file := dir+"/elevation.json"
	if FileAccess.file_exists(elevation_file):
		var elevation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(elevation_file))
		_elevation=elevation.corners
		for cell in elevation.ledges:_elevated_ledges[Vector2i(int(cell[0]),int(cell[1]))]=true
		for row in _elevation:
			for cell in row:
				for value in cell:max_elevation=maxf(max_elevation,float(value))
	var geometry_file := dir+"/ledge_geometry.json"
	if not _elevation.is_empty() and FileAccess.file_exists(geometry_file):
		var geometry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(geometry_file))
		_ledge_resolution=int(geometry.resolution)
		for patch in geometry.patches:_ledge_patches[Vector2i(int(patch.x),int(patch.y))]=patch
	map = {"width": w, "height": h, "start": Vector2(j["start"][0], j["start"][1]) * MAP_SCALE, "arena": j.get("arena", {})}
	for a in j.get("areas", []):
		_areas.append({"id": String(a["id"]), "rect": Rect2i(int(a["x"]), int(a["y"]), int(a["w"]), int(a["h"]))})
	for wv in j.get("warps", []):
		_warps["%d,%d" % [int(wv["x"]), int(wv["y"])]] = wv
		_warp_tiles["%s:%d" % [String(wv["map"]), int(wv["index"])]] = Vector2i(int(wv["x"]), int(wv["y"]))
	_pad = int(j.get("pad", 0))
	if dir == "res://assets/maps/kanto_world":
		# The combined continent always renders its terrain in 3D.
		_attach_continent()
	else:
		_bottom = load(dir + "/bottom.png")
		_top = load(dir + "/top.png")

static func _ensure() -> void:
	if theme.is_empty():
		configure(DungeonDB.THEMES["meadow"])

static func has_map() -> bool:
	_ensure()
	return not map.is_empty()

static func bounds() -> Rect2:
	if has_map():
		var origin: Vector2=map.get("origin",Vector2.ZERO)
		return Rect2(origin,map.get("world_size",Vector2(map["width"],map["height"])*TILE))
	return RECT

static func atlas() -> Texture2D:
	if _atlas == null and ResourceLoader.exists(ATLAS_PATH):
		_atlas = load(ATLAS_PATH)
	return _atlas

# 메타타일 번호 → 아틀라스 안의 자리.
static func tile_src(id: int) -> Rect2:
	return Rect2((id % 16) * SRC_TILE, (id / 16) * SRC_TILE, SRC_TILE, SRC_TILE)

# 구역(원작 지도 한 장)의 칸 범위. 없으면 크기 0.
static func area_rect(id: String) -> Rect2i:
	for a in _areas:
		if a["id"] == id:
			return a["rect"]
	return Rect2i()

# 구역 안 지역 좌표 → 전체 지도 칸(지도를 다시 구워 원점이 옮겨져도 테스트·도구가 그대로 쓰게).
static func area_tile(id: String, local: Vector2i) -> Vector2i:
	return area_rect(id).position + local

static func tile_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))

static func tile_center(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE / 2.0, t.y * TILE + TILE / 2.0)

# 그 자리가 속한 원작 지도(구역) id. 없으면 "".
static func area_at(pos: Vector2) -> String:
	var t := tile_of(pos)
	for a in _areas:
		if (a["rect"] as Rect2i).has_point(t):
			return a["id"]
	return ""

# 그 자리의 문(워프). 없으면 빈 사전.
static func warp_at(pos: Vector2) -> Dictionary:
	var t := tile_of(pos)
	return _warps.get("%d,%d" % [t.x, t.y], {})

# 지도의 문(워프) 전부.
static func warps() -> Array:
	return _warps.values()

# 칸을 막거나 튼다(잠긴 건물의 문 칸을 막는 데 — Game._lock_doors, 사용자 결정 2026-10-30).
static func set_solid(t: Vector2i, v: bool) -> void:
	if native_at(t):
		_native_solid[t]=v
		return
	if t.x < 0 or t.y < 0 or t.x >= int(map["width"]) or t.y >= int(map["height"]):
		return
	_solid[t.y * int(map["width"]) + t.x] = 1 if v else 0

# 지도(map id)의 index 번째 문 칸. 없으면 (-1,-1).
static func warp_tile(map_id: String, index: int) -> Vector2i:
	return _warp_tiles.get("%s:%d" % [map_id, index], Vector2i(-1, -1))

static func has_warp(map_id: String,index: int) -> bool:
	return _warp_tiles.has("%s:%d" % [map_id,index])

static func solid_at(tx: int, ty: int) -> bool:
	if native_at(Vector2i(tx,ty)):
		var tile := Vector2i(tx,ty)
		if _dynamic_solid.has(tile): return true
		if _native_solid.has(tile): return bool(_native_solid[tile])
		var door: Dictionary=_warps.get("%d,%d" % [tx,ty],{})
		if not door.is_empty() and not String(door.to).is_empty(): return false
		var value := native_attributes(tile)
		# HGSS marks ledges with bit 15 too. Our ledge layer blocks walking
		# separately and allows the existing hop to cross that one tile.
		if (value & 255) in [56,57,58,59]: return false
		return (value & 32768) != 0
	if _dynamic_solid.has(Vector2i(tx,ty)):return true
	if tx < 0 or ty < 0 or tx >= int(map["width"]) or ty >= int(map["height"]):
		return true
	return _solid[ty * int(map["width"]) + tx] == 1

static func set_dynamic_solid(tile: Vector2i,value: bool) -> void:
	if value:_dynamic_solid[tile]=true
	else:_dynamic_solid.erase(tile)

# 0: walking; 1: water-only wild; 2: surf (land + water).
static func is_water(tile: Vector2i) -> bool:
	if native_at(tile): return (native_attributes(tile) & 255) in [16,17,18,19,20,21,25,42]
	return _water.has(tile)

# Decorative map padding continues the boundary altitude, never sea level.
static func ground_corners(tile: Vector2i) -> Array:
	if native_at(tile):
		var values: Array=[]
		for step in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
			values.append(ground_height((Vector2(tile)+step)*TILE))
		return values
	if _elevation.is_empty():return [0.,0.,0.,0.]
	var rows := _elevation.size()
	var cols := (_elevation[0] as Array).size()
	var x := clampi(tile.x,0,cols-1)
	var y := clampi(tile.y,0,rows-1)
	var result: Array=(_elevation[y][x] as Array).duplicate()
	if tile.x<0:result=[result[0],result[0],result[3],result[3]]
	elif tile.x>=cols:result=[result[1],result[1],result[2],result[2]]
	if tile.y<0:result=[result[0],result[1],result[1],result[0]]
	elif tile.y>=rows:result=[result[3],result[2],result[2],result[3]]
	return result

# Same triangle split as the rendered floor; ledge edges may have two heights.
static func ground_height(pos: Vector2) -> float:
	if native_at(tile_of(pos)):
		if native_height.is_valid(): return native_height.call(pos)
		var at:=pos/TILE-(Vector2(Continent.offset()) if is_continent() else Vector2.ZERO)
		var cell := Vector2i((at/32.0).floor())
		var source: Dictionary=continent_data if is_continent() else native_data
		return float(source.chunk_index.get(cell,{}).get("altitude",0.0))
	if _elevation.is_empty():return 0.0
	var tile := tile_of(pos)
	if _ledge_patches.has(tile):
		var grid: Array=_ledge_patches[tile].heights
		var uv := (pos/float(TILE)-Vector2(tile))*_ledge_resolution
		var x := clampi(int(floorf(uv.x)),0,_ledge_resolution-1)
		var y := clampi(int(floorf(uv.y)),0,_ledge_resolution-1)
		var h00 := float(grid[y][x])
		var h10 := float(grid[y][x+1])
		var h11 := float(grid[y+1][x+1])
		var h01 := float(grid[y+1][x])
		uv-=Vector2(x,y)
		if uv.x>=uv.y:return h00+(h10-h00)*uv.x+(h11-h10)*uv.y
		return h00+(h11-h01)*uv.x+(h01-h00)*uv.y
	var h: Array=_elevation[tile.y][tile.x] if tile.y>=0 and tile.y<_elevation.size() and tile.x>=0 and tile.x<(_elevation[tile.y] as Array).size() else ground_corners(tile)
	var uv := pos/float(TILE)-Vector2(tile)
	if uv.x>=uv.y:return float(h[0])+(float(h[1])-float(h[0]))*uv.x+(float(h[2])-float(h[1]))*uv.y
	return float(h[0])+(float(h[2])-float(h[3]))*uv.x+(float(h[3])-float(h[0]))*uv.y

static func terrain_blocked(tile: Vector2i, terrain: int = 0) -> bool:
	if native_at(tile) and solid_at(tile.x,tile.y): return true
	if _dynamic_solid.has(tile):return true
	if is_water(tile): return terrain==0
	if terrain==1: return true
	return solid_at(tile.x,tile.y)

# 언덕 칸이면 원작이 뛰어내리게 하는 방향 코드(1~4, LEDGE_DIRS), 아니면 0.
static func ledge_at(tx: int, ty: int) -> int:
	if native_at(Vector2i(tx,ty)):
		var behavior := native_attributes(Vector2i(tx,ty)) & 255
		return behavior-55 if behavior in [56,57,58,59] else 0
	if _ledge.is_empty() or tx < 0 or ty < 0 or tx >= int(map["width"]) or ty >= int(map["height"]):
		return 0
	return _ledge[ty * int(map["width"]) + tx]

# pos 에서 dir 쪽으로 한 발(r + 4px) 앞 칸이 언덕이고 그 언덕의 내려가는 방향이 dir 과 같으면 그 방향, 아니면 ZERO.
static func ledge_drop_ahead(pos: Vector2, r: float, dir: Vector2) -> Vector2:
	if dir.length_squared() < 0.01:
		return Vector2.ZERO
	var t := tile_of(pos + dir.normalized() * (r + 4.0))
	var code := ledge_at(t.x, t.y)
	if code == 0:
		return Vector2.ZERO
	var ld: Vector2 = LEDGE_DIRS[code]
	return ld if dir.normalized().dot(ld) > 0.7 else Vector2.ZERO

# 원(pos, r)을 싸움터 안으로, 장애물 밖으로 밀어낸 위치. 언덕 칸은 걸어서는 막힌 칸이고 점프 중(cross_ledges)에만 지나간다.
static func resolve(pos: Vector2, r: float, cross_ledges: bool = false, terrain: int = 0) -> Vector2:
	_ensure()
	var p := pos
	if has_map():
		# 원이 걸치는 칸들 중 막힌 칸의 사각형에서 밀어낸다. 모서리에서 두 칸이 겹칠 수 있어 두 번 돈다.
		for pass_i in 2:
			var x0 := int(floor((p.x - r) / TILE))
			var x1 := int(floor((p.x + r) / TILE))
			var y0 := int(floor((p.y - r) / TILE))
			var y1 := int(floor((p.y + r) / TILE))
			for ty in range(y0, y1 + 1):
				for tx in range(x0, x1 + 1):
					if not terrain_blocked(Vector2i(tx,ty),terrain) and (cross_ledges or ledge_at(tx, ty) == 0):
						continue
					var rect := Rect2(tx * TILE, ty * TILE, TILE, TILE)
					var closest := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
					var d := p - closest
					var dist := d.length()
					if dist >= r:
						continue
					if dist > 0.001:
						p += d / dist * (r - dist)
					else:
						# 원 중심이 칸 안에 있으면 가장 가까운 변으로 내보낸다.
						var c := rect.get_center()
						var off := p - c
						if absf(off.x) > absf(off.y):
							p.x = rect.end.x + r if off.x > 0 else rect.position.x - r
						else:
							p.y = rect.end.y + r if off.y > 0 else rect.position.y - r
	else:
		for ob in obstacles:
			var d: Vector2 = p - ob["pos"]
			var min_d: float = r + ob["r"]
			if d.length_squared() < min_d * min_d:
				var n := d.normalized() if d.length_squared() > 0.0001 else Vector2.UP
				p = ob["pos"] + n * min_d
	var b := bounds()
	p.x = clampf(p.x, b.position.x + r, b.end.x - r)
	p.y = clampf(p.y, b.position.y + r, b.end.y - r)
	return p

# 탄이 벽이나 장애물에 닿았는가.
static func blocks(pos: Vector2, r: float) -> bool:
	_ensure()
	if has_map():
		return terrain_blocked(tile_of(pos),2)
	if not RECT.grow(-r * 0.5).has_point(pos):
		return true
	for ob in obstacles:
		if pos.distance_to(ob["pos"]) < r + ob["r"]:
			return true
	return false

# 플레이어 시작 자리.
static func center() -> Vector2:
	if has_map():
		return map["start"]
	return RECT.get_center()

# 가장자리 안쪽에서 무작위 출현 지점(색칠 모드).
static func edge_point(rng: RandomNumberGenerator) -> Vector2:
	var inset := 26.0
	var r := RECT.grow(-inset)
	match rng.randi_range(0, 3):
		0: return Vector2(rng.randf_range(r.position.x, r.end.x), r.position.y)
		1: return Vector2(rng.randf_range(r.position.x, r.end.x), r.end.y)
		2: return Vector2(r.position.x, rng.randf_range(r.position.y, r.end.y))
		_: return Vector2(r.end.x, rng.randf_range(r.position.y, r.end.y))

# 그 칸이 풀숲인가.
static func is_grass(t: Vector2i) -> bool:
	_ensure()
	if native_at(t): return (native_attributes(t) & 255) in [2,3]
	return _grass_tiles.has(t)

# pos 에서 min_d~max_d 떨어진 풀숲 칸의 가운데 좌표들.
static func grass_points_near(pos: Vector2, min_d: float, max_d: float) -> Array:
	_ensure()
	var out: Array = []
	for g in _grass:
		var d := g.distance_to(pos)
		if d >= min_d and d <= max_d:
			out.append(g)
	return out

func _draw() -> void:
	_ensure()
	if is_native() or is_continent(): return # These maps always use View3D.
	if has_map():
		draw_texture_rect(_bottom, Rect2(Vector2.ZERO,Vector2(map.width,map.height)*TILE).grow(_pad*TILE), false)
	else:
		_draw_painted()

# 위층(나무 윗부분 등)의 한 타일 행을 그린다. ArenaTop 의 행 띠가 부른다(포켓몬과 y 정렬). dst_y 는 띠 노드 기준 그림의 위 y.
# cells: 0 = 행 전체, 1 = 걸을 수 있는 칸만(지붕 맨 윗줄 등 뒤로 숨는 칸), 2 = 막힌 칸만. 같은 종류가 이어진 칸은 한 번에 그린다.
static func draw_top_row(ci: CanvasItem, row: int, dst_y: float, cells: int = 0) -> void:
	if not has_map() or _top == null:
		return
	var w := int(map["width"])
	if cells == 0:
		ci.draw_texture_rect_region(_top, Rect2(0, dst_y, w * TILE, TILE), Rect2(0, row * SRC_TILE, w * SRC_TILE, SRC_TILE), Color.WHITE, false)
		return
	var x := 0
	while x < w:
		if top_cell_walkable(x, row) != (cells == 1):
			x += 1
			continue
		var x0 := x
		while x < w and top_cell_walkable(x, row) == (cells == 1):
			x += 1
		ci.draw_texture_rect_region(_top, Rect2(x0 * TILE, dst_y, (x - x0) * TILE, TILE),
			Rect2(x0 * SRC_TILE, row * SRC_TILE, (x - x0) * SRC_TILE, SRC_TILE), Color.WHITE, false)

# 위층 정렬에서 "걸을 수 있는 칸"(막힘도 언덕도 아님) — 그 칸의 위층은 그 행에 선 포켓몬을 덮는다.
static func top_cell_walkable(tx: int, ty: int) -> bool:
	return not solid_at(tx, ty) and ledge_at(tx, ty) == 0

# 숨는 칸 아래 막힌 칸(사용자 지적 2026-10-29: 나무 뒤로 걸으면 다리가 나무 위로 삐져나옴): 나무 윗줄은 걸을 수 있고 위층이라
# 그 칸에 선 포켓몬을 덮지만, 바로 아랫줄(나무 아랫부분)은 바닥층이라 포켓몬 밑에 그려진다. 포켓몬 도트는 칸보다 아래로 내려오므로
# 발이 아랫줄에 걸치면 그 부분만 보였다. 위 칸이 '위층 픽셀이 있는 걸을 수 있는 칸'인 막힌 칸의 바닥 그림을 ArenaTop 이 그 행 맨 위
# 정렬로 한 번 더 그려 덮는다(원작 GBA 는 도트가 칸 안에 들어가 이런 일이 없다).
static var _cover_rows := {}
static func cover_cells(row: int) -> Array:
	if not has_map() or _top == null or _bottom == null:
		return []
	if _cover_rows.is_empty():
		var img := _top.get_image()
		for r in map["height"]:
			var xs: Array = []
			if r > 0:
				for x in map["width"]:
					if solid_at(x, r) and top_cell_walkable(x, r - 1) \
							and not img.get_region(Rect2i(x * SRC_TILE, (r - 1) * SRC_TILE, SRC_TILE, SRC_TILE)).is_invisible():
						xs.append(x)
			_cover_rows[r] = xs
	return _cover_rows.get(row, [])

static func draw_cover_cells(ci: CanvasItem, row: int, dst_y: float) -> void:
	for x in cover_cells(row):
		ci.draw_texture_rect_region(_bottom, Rect2(x * TILE, dst_y, TILE, TILE),
			Rect2((x + _pad) * SRC_TILE, (row + _pad) * SRC_TILE, SRC_TILE, SRC_TILE), Color.WHITE, false)

# 그 행의 위층에 그릴 픽셀이 있는가(없는 행은 띠를 만들지 않는다).
static var _top_rows := {}
static func top_row_has_pixels(row: int) -> bool:
	if not has_map() or _top == null:
		return false
	if _top_rows.is_empty():
		var img := _top.get_image()
		for r in map["height"]:
			var any := false
			for y in range(r * SRC_TILE, (r + 1) * SRC_TILE):
				if any:
					break
				for x in img.get_width():
					if img.get_pixel(x, y).a > 0.01:
						any = true
						break
			_top_rows[r] = any
	return bool(_top_rows.get(row, false))

# ── 색칠 방식(옛 풀밭 아레나) ──

func _draw_painted() -> void:
	draw_rect(get_viewport_rect(), theme["outside"])
	var tile := 16
	for x in range(int(RECT.position.x), int(RECT.end.x), tile):
		for y in range(int(RECT.position.y), int(RECT.end.y), tile):
			var odd := ((x / tile) + (y / tile)) % 2 == 0
			draw_rect(Rect2(x, y, tile, tile), theme["floor_a"] if odd else theme["floor_b"])
	for i in 70:
		var px := RECT.position.x + fposmod(i * 97.3, RECT.size.x)
		var py := RECT.position.y + fposmod(i * 53.7, RECT.size.y)
		draw_line(Vector2(px, py), Vector2(px - 1, py - 3), theme["grass"], 1.0)
		draw_line(Vector2(px + 2, py), Vector2(px + 3, py - 3), theme["grass"], 1.0)
	draw_rect(RECT.grow(4), Color("6b4a2f"), false, 6.0)
	draw_rect(RECT.grow(1), Color("a07a4f"), false, 2.0)
	for ob in obstacles:
		var c: Vector2 = ob["pos"]
		var r: float = ob["r"]
		draw_circle(c + Vector2(0, r * 0.5), r, Color(0, 0, 0, 0.25))
		draw_circle(c, r, Color("6f6a64"))
		draw_circle(c + Vector2(-r * 0.25, -r * 0.3), r * 0.55, Color("8e8881"))
