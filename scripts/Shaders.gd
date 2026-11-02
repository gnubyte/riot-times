class_name Shaders
extends RefCounted
# Code-generated shaders: water (toxic or lake), and the full-screen post-process
# that sells damage, cold, sickness, night vision and the curses.

static func water_material(toxic := true) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D noise_tex : source_color;
uniform vec4 deep_color : source_color = vec4(0.06, 0.18, 0.08, 1.0);
uniform vec4 glow_color : source_color = vec4(0.35, 0.9, 0.25, 1.0);
uniform float glow = 1.0;
uniform float alpha = 0.92;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(w.x * 0.9 + TIME * 1.3) + cos(w.z * 0.8 + TIME * 1.1)) * 0.04;
}

void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = w.xz * 0.06;
	float n1 = texture(noise_tex, uv + TIME * vec2(0.02, 0.05)).r;
	float n2 = texture(noise_tex, uv * 2.3 - TIME * vec2(0.04, 0.03)).r;
	float n = (n1 + n2) * 0.5;
	vec3 col = mix(deep_color.rgb, glow_color.rgb, n * n * 1.6);
	float swirl = sin(uv.x * 5.0 + uv.y * 3.0 + TIME + n1 * 6.0);
	col += glow_color.rgb * 0.2 * smoothstep(0.6, 1.0, swirl);
	ALBEDO = col * 0.5;
	EMISSION = col * (0.25 + n * 0.8) * glow;
	ROUGHNESS = 0.08;
	SPECULAR = 0.8;
	ALPHA = alpha;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("noise_tex", Proc.noise_tile(256))
	if not toxic:
		m.set_shader_parameter("deep_color", Color(0.03, 0.09, 0.11))
		m.set_shader_parameter("glow_color", Color(0.18, 0.35, 0.38))
		m.set_shader_parameter("glow", 0.25)
		m.set_shader_parameter("alpha", 0.86)
	return m

static func postfx_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.25;
uniform float desat = 0.0;
uniform float red = 0.0;
uniform float aberration = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_amt = 0.0;
uniform float frost = 0.0;
uniform float wobble = 0.0;
uniform float grain = 0.04;
uniform float lift = 0.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(0.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float d = length(c);
	if (wobble > 0.0) {
		uv += vec2(sin(uv.y * 14.0 + TIME * 2.3), cos(uv.x * 11.0 + TIME * 1.9)) * 0.004 * wobble;
	}
	vec3 col;
	if (aberration > 0.001) {
		vec2 off = c * aberration * 0.018;
		col.r = texture(screen_tex, uv + off).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - off).b;
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	col += lift * (1.0 - col) * 0.5 + lift * 0.05;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l), clamp(desat, 0.0, 1.0));
	col = mix(col, col * tint.rgb * 1.4, clamp(tint_amt, 0.0, 1.0));
	float vig = smoothstep(0.32, 0.85, d);
	col *= 1.0 - vig * vignette;
	col = mix(col, vec3(0.55, 0.0, 0.02), vig * red);
	col = mix(col, vec3(0.75, 0.88, 1.0), smoothstep(0.38, 0.8, d) * frost * (0.7 + 0.3 * hash(floor(uv * 180.0))));
	col += (hash(uv * 900.0 + TIME) - 0.5) * grain;
	col = mix(col, flash_color.rgb, flash);
	COLOR = vec4(col, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
