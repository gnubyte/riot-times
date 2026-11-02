class_name Shaders
extends RefCounted
# Code-generated shaders: animated toxic water, tracer lines.

static func water_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
[shader_type spatial]
uniform sampler2D noise_tex : source_is_luma;
uniform vec4 deep_color : source_color = vec4(0.06, 0.18, 0.08, 1.0);
uniform vec4 glow_color : source_color = vec4(0.35, 0.9, 0.25, 1.0);

void vertex() {
	float w = sin(VERTEX.x * 1.8 + TIME * 1.3) + cos(VERTEX.z * 1.5 + TIME * 1.1);
	VERTEX.y += w * 0.05;
}

void fragment() {
	vec2 uv = UV * 3.0;
	float n1 = texture(noise_tex, uv + TIME * vec2(0.02, 0.05)).r;
	float n2 = texture(noise_tex, uv * 2.3 - TIME * vec2(0.04, 0.03)).r;
	float n = (n1 + n2) * 0.5;
	vec3 col = mix(deep_color.rgb, glow_color.rgb, n * n * 1.6);
	// scum swirls
	float swirl = sin(uv.x * 5.0 + uv.y * 3.0 + TIME + n1 * 6.0);
	col += glow_color.rgb * 0.25 * smoothstep(0.6, 1.0, swirl);
	ALBEDO = col * 0.55;
	EMISSION = col * (0.55 + n * 1.1);
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("noise_tex", Proc.noise_tile(256))
	return m

static func tracer_material(col := Color(1.0, 0.85, 0.45)) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
[shader_type canvas_item]
void fragment() {
	float a = smoothstep(1.0, 0.0, abs(UV.y - 0.5) * 2.0);
	COLOR = vec4(vec3(1.0, 0.9, 0.6), a * 0.9);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
