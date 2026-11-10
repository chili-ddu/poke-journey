// HD-2D 느낌 후처리(Look, 2026-11-02 시제품): 틸트시프트 + 약한 블룸 + 색보정 + 비네팅. 발광은 효과 쪽(가산 합성·빛무리)에서. 월드(캔버스 0층) 위, UI 아래 층에 화면을 덮는 사각형으로.
// 화면은 창 해상도(canvas_items 늘리기)로 그려지므로 흐림·번짐이 도트보다 고와서 'HD' 쪽 느낌이 난다.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float band_top = 0.20;        // narrow depth-of-field band preserves map pixels
uniform float band_bottom = 0.12;
uniform float blur_px = 3.0;
uniform float bloom_threshold = 0.98;
uniform float bloom_strength = 0.18;
uniform float bloom_px = 5.0;
uniform float saturation = 1.14;
uniform float contrast = 1.05;
uniform vec3 shade_tint = vec3(0.97, 0.99, 1.03);   // 어두운 곳은 조금 서늘하게
uniform vec3 light_tint = vec3(1.07, 1.01, 0.92);    // 밝은 곳은 조금 따뜻하게
uniform float vignette = 0.32;
uniform int combat_focus_count = 0;
uniform vec4 combat_focus[8]; // centre.xy and elliptical radius.zw
uniform bool dialogue_focus_enabled = false;
uniform vec2 dialogue_focus_center = vec2(0.5);
uniform vec2 dialogue_focus_radius = vec2(0.05, 0.12);

const vec2 TAPS[12] = vec2[](
	vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457), vec2(-0.203, 0.621),
	vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767), vec2(0.185, -0.893),
	vec2(0.507, 0.064), vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598));

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 col = texture(screen_tex, uv).rgb;
	// 틸트시프트: 위·아래 띠에서 가장자리로 갈수록 흐림 반지름이 커진다.
	float k = max(smoothstep(band_top, 0.0, uv.y), smoothstep(1.0 - band_bottom, 1.0, uv.y));
	if (dialogue_focus_enabled) {
		vec2 delta = (uv - dialogue_focus_center) / max(dialogue_focus_radius, vec2(0.001));
		k *= smoothstep(1.0, 1.6, length(delta));
	}
	for (int i = 0; i < 8; i++) {
		if (i >= combat_focus_count) break;
		vec4 focus = combat_focus[i];
		vec2 delta = (uv - focus.xy) / max(focus.zw, vec2(0.001));
		k *= smoothstep(1.0, 1.5, length(delta));
	}
	if (k > 0.01) {
		vec3 acc = col;
		for (int i = 0; i < 12; i++) {
			acc += texture(screen_tex, uv + TAPS[i] * px * blur_px * k).rgb;
		}
		col = acc / 13.0;
	}
	// 블룸: 둘레의 아주 밝은 픽셀만 모아 더한다.
	vec3 glow = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		vec3 s = texture(screen_tex, uv + TAPS[i] * px * bloom_px).rgb;
		float m = max(s.r, max(s.g, s.b));
		float sat = (m - min(s.r, min(s.g, s.b))) / max(m, 0.001);
		// 빨강 한 채널만 밝은 몸통은 발광하지 않는다. 노란 불꽃 핵처럼 실제로 밝은 픽셀에 집중.
		float luminance = dot(s, vec3(0.299, 0.587, 0.114));
		float bright = smoothstep(0.55, 0.85, luminance);
		glow += s * smoothstep(bloom_threshold, 1.0, m) * bright * (0.25 + 0.75 * sat);
	}
	col += glow / 12.0 * bloom_strength;
	// 색보정
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	col *= mix(shade_tint, light_tint, clamp(lum, 0.0, 1.0));
	// 비네팅
	vec2 d = uv - 0.5;
	col *= 1.0 - vignette * dot(d, d) * 2.0;
	COLOR = vec4(col, 1.0);
}
