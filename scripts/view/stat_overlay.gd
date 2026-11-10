class_name StatOverlay
extends Node2D

# 원작의 능력 변화 연출(3세대 AnimTask_StatsChange; 4세대도 같은 무늬 방식). 포켓몬 몸(도트의 불투명 부분) 안에서 무늬가 위(상승)나 아래(하락)로
# 흐른다 — 원작은 도트 복사본을 하드웨어 창으로 써서 BG 무늬를 몸 안에만 보이게 했다. 여기서는 셰이더로 같은 일을 한다:
# Mon 이 방금 그린 프레임(시트·영역·변환)을 넘겨주면 그 프레임을 한 번 더 그리되, 색은 무늬에서 가져오고 알파는 도트의 알파.
# 시간: 2프레임마다 1/16 씩 10단계 올라가(20프레임) 20프레임 유지, 20프레임에 걸쳐 내려간다 = 1초. 스크롤 3px/프레임(180px/s).
# 무늬: assets/fx/stat_up_def.png(상승 무늬 + DEFENSE 초록), stat_down_spe.png(하강 무늬 + SPEED 파랑) — pret masks/stat.png + stat1/stat4.pal.
# 크기: 원작은 64×64 도트에 32px 주기 무늬. PMD 도트는 훨씬 작으므로 덩치(반지름)에 비례해 무늬와 스크롤을 줄인다(pattern_scale, 사용자).

const PATTERNS := {"def_up": "res://assets/fx/stat_up_def.png", "spe_down": "res://assets/fx/stat_down_spe.png",
	"atk_up": "res://assets/fx/stat_up_atk.png", "atk_down": "res://assets/fx/stat_down_atk.png",
	"acc_down": "res://assets/fx/stat_down_spe.png",   # 명중률(연막·모래뿌리기)은 스피드와 같은 파란 무늬
	"def_down": "res://assets/fx/stat_down_atk.png"}   # 방어 하락(꼬리흔들기)은 공격 하락과 같은 빨간 무늬   # 공격은 stat2.pal(빨강·노랑)
const RAMP := 20.0 / 60.0
const HOLD := 20.0 / 60.0
const TOTAL := RAMP * 2.0 + HOLD
const PEAK := 10.0 / 16.0            # BLDALPHA eva 10/16
const SCROLL_SPEED := 180.0          # px/s (3px/프레임), pattern_scale 배
const GBA_RADIUS := 24.0             # 원작 도트의 몸 반지름쯤 — 이 크기일 때 무늬가 원작 비율(32px 주기)

var t := 0.0                         # 남은 시간. 0 이면 안 그린다
# 회복 빛(포켓몬센터 회복 연출, 사용자 결정 2026-10-29): 원작 회복 기계의 몬스터볼 깜빡임(field_effect.c PokeballGlowEffect)을
# 볼 대신 몸에 — 몸을 위에서 아래로 네 띠로 나눠, 8프레임마다 가장 밝은 띠가 한 칸씩 내려간다(밝기 16·12·8·0 /16, 원작
# sPokeballGlowReds). 세 번 쓸어내린 뒤(96프레임) 몸 전체가 한 번 번쩍이고 사그라든다(24프레임). 색은 원작처럼 노란빛(파랑 0).
const HEAL_STEP := 8.0 / 60.0
const HEAL_SWEEPS := 3
const HEAL_LEVELS := [1.0, 0.75, 0.5, 0.0]
var heal_t := -1.0                   # 회복 빛이 시작된 뒤 지난 시간. 음수면 없음
var body_r := 8.0                    # 몸 반지름 — 네 띠는 몸 중심(그리기 기준점) 위아래로 반지름 1.2배씩(프레임 상자의 빈 곳 말고 몸에)
var up := true
var pattern_scale := 1.0             # 무늬 배율(= 덩치 / GBA_RADIUS, 0.3~1)
var pattern: Texture2D = null
# Mon 이 프레임마다 넣어 주는 그리기 정보
var tex: Texture2D = null
var dst := Rect2()
var src := Rect2()
var xform := Transform2D()

static var _shader: Shader = null

func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type canvas_item;
uniform sampler2D pattern : repeat_enable, filter_linear;
uniform float scroll = 0.0;
uniform float strength = 0.0;
uniform float period = 32.0;
uniform bool heal = false;
uniform vec4 bands = vec4(0.0);
uniform float top = 0.0;
uniform float height = 1.0;
varying vec2 local_pos;
void vertex() { local_pos = VERTEX; }
void fragment() {
	vec4 s = texture(TEXTURE, UV);
	if (heal) {
		int i = clamp(int(floor((local_pos.y - top) / height * 4.0)), 0, 3);
		float a = i == 0 ? bands.x : (i == 1 ? bands.y : (i == 2 ? bands.z : bands.w));
		COLOR = vec4(1.0, 1.0, 0.55, s.a * a * strength);
	} else {
		vec4 p = texture(pattern, vec2(local_pos.x, local_pos.y + scroll) / period);
		COLOR = vec4(p.rgb, s.a * p.a * strength);
	}
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	material = mat
	use_parent_material = false

# 능력 변화 연출 시작. kind 는 PATTERNS 의 키.
func play(kind: String) -> void:
	var path: String = PATTERNS.get(kind, "")
	if path.is_empty() and kind.get_slice("_",0) in ["atk","def","spa","spd","spe","acc","eva"] and (kind.ends_with("_up") or kind.ends_with("_down")):
		path = PATTERNS["atk_up" if kind.ends_with("_up") else "spe_down"]
	pattern = load(path) if path != "" and ResourceLoader.exists(path) else null
	up = kind.ends_with("_up")
	t = TOTAL

func active() -> bool:
	return (t > 0.0 and pattern != null) or heal_active()

func play_heal() -> void:
	heal_t = 0.0

func heal_length() -> float:
	return HEAL_STEP * (HEAL_SWEEPS * 4 + 3)

func heal_active() -> bool:
	return heal_t >= 0.0 and heal_t < heal_length()

func step(dt: float) -> void:
	t = maxf(0.0, t - dt)
	if heal_t >= 0.0:
		heal_t += dt
		if heal_t >= heal_length():
			heal_t = -1.0

# 회복 빛의 네 띠 밝기(위 → 아래). 원작: 띠 k 의 단계 = (카운터 + 3 − k) & 3, 마지막 번쩍임은 모두 카운터.
func _heal_bands() -> Vector4:
	var step := int(floor(heal_t / HEAL_STEP))
	if step < HEAL_SWEEPS * 4:
		var c := step % 4
		return Vector4(HEAL_LEVELS[(c + 3) & 3], HEAL_LEVELS[(c + 2) & 3], HEAL_LEVELS[(c + 1) & 3], HEAL_LEVELS[c])
	var l: float = HEAL_LEVELS[mini(3, step - HEAL_SWEEPS * 4)]
	return Vector4(l, l, l, l)

# Shared envelope for the original 2D overlay and HD-2D body overlay.
func rank_strength() -> float:
	if t <= 0.0 or pattern == null: return 0.0
	var elapsed := TOTAL-t
	var amount := 1.0
	if elapsed < RAMP: amount = floorf(elapsed/RAMP*10.0)/10.0
	elif elapsed > RAMP+HOLD: amount = floorf((TOTAL-elapsed)/RAMP*10.0)/10.0
	return clampf(amount,0.0,1.0)*PEAK

func _draw() -> void:
	if not active() or tex == null:
		return
	var mat0 := material as ShaderMaterial
	if heal_active():
		mat0.set_shader_parameter("heal", true)
		mat0.set_shader_parameter("bands", _heal_bands())
		mat0.set_shader_parameter("strength", 0.85)
		mat0.set_shader_parameter("top", -body_r * 1.2)
		mat0.set_shader_parameter("height", body_r * 2.4)
		draw_set_transform_matrix(xform)
		draw_texture_rect_region(tex, dst, src)
		draw_set_transform_matrix(Transform2D())
		return
	mat0.set_shader_parameter("heal", false)
	var elapsed := TOTAL - t
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("pattern", pattern)
	mat.set_shader_parameter("strength", rank_strength())
	mat.set_shader_parameter("period", 32.0 * pattern_scale)
	# 상승은 무늬가 위로(원작 BG_Y += 3), 하락은 아래로. 속도도 덩치에 비례.
	mat.set_shader_parameter("scroll", (elapsed * SCROLL_SPEED * pattern_scale) * (1.0 if up else -1.0))
	draw_set_transform_matrix(xform)
	draw_texture_rect_region(tex, dst, src)
	draw_set_transform_matrix(Transform2D())
