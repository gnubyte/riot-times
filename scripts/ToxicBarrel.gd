class_name ToxicBarrel
extends Control
# Bottom-left vitals: a rusted drum lying on its side in a glowing toxic puddle,
# drawn by one canvas shader. Health is the glowing sludge in a glass sight-gauge
# along the drum (green when healthy, curdling red when low), stamina a thinner
# tube beneath. Status chips, the HP readout, level and noise are stenciled on top
# as regular controls (HUD.gd fills them). Slime drips down the drum, leaks from
# the bung into the puddle, and the puddle ripples and bubbles.

const SIZE := Vector2(470, 214)

var art: ColorRect
var mat: ShaderMaterial
var _hp := 1.0
var _hp_shown := 1.0
var _hp_lag := 1.0
var _stam := 1.0
var _stam_shown := 1.0
var _hit := 0.0

func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	art = ColorRect.new()
	art.size = SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = _shader()
	mat.set_shader_parameter("rect_size", SIZE)
	art.material = mat
	add_child(art)

func set_vitals(hp_k: float, stam_k: float) -> void:
	if hp_k < _hp - 0.005:
		_hit = 1.0
	_hp = clampf(hp_k, 0.0, 1.0)
	_stam = clampf(stam_k, 0.0, 1.0)

func _process(delta: float) -> void:
	# liquid level eases toward the real value; a pale "lag" shows recent damage
	_hp_shown = lerpf(_hp_shown, _hp, 1.0 - exp(-delta * 10.0))
	_hp_lag = maxf(_hp_shown, _hp_lag - delta * 0.25) if _hp_lag > _hp_shown else _hp_shown
	_hit = maxf(0.0, _hit - delta * 2.5)
	mat.set_shader_parameter("hp", _hp_shown)
	mat.set_shader_parameter("hp_lag", _hp_lag)
	_stam_shown = lerpf(_stam_shown, _stam, 1.0 - exp(-delta * 12.0))
	mat.set_shader_parameter("stam", _stam_shown)
	mat.set_shader_parameter("hit", _hit)

static func _shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec2 rect_size = vec2(470.0, 214.0);
uniform float hp = 1.0;
uniform float hp_lag = 1.0;
uniform float stam = 1.0;
uniform float hit = 0.0;

const vec3 TOX = vec3(0.55, 1.0, 0.18);
const float BX0 = 40.0;   // drum body x range
const float BX1 = 452.0;
const float BY0 = 16.0;   // drum body y range
const float BY1 = 170.0;
const float GX0 = 74.0;   // gauge
const float GX1 = 368.0;
const float GY0 = 60.0;
const float GY1 = 80.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += vnoise(p) * a; p *= 2.03; a *= 0.5; }
	return v;
}
vec4 over(vec4 dst, vec4 src) { return vec4(mix(dst.rgb, src.rgb, src.a), max(dst.a, src.a)); }

void fragment() {
	vec2 p = UV * rect_size;
	float t = TIME;
	vec4 col = vec4(0.0);
	float cy = (BY0 + BY1) * 0.5;
	float ry = (BY1 - BY0) * 0.5;

	// ---------- toxic puddle (behind the drum) ----------
	vec2 pc = vec2(250.0, 192.0);
	vec2 pd = (p - pc) / vec2(250.0, 26.0);
	float wob = fbm(vec2(atan(pd.y, pd.x) * 2.0, t * 0.2)) * 0.25;
	float pr = length(pd);
	if (pr < 1.0 + wob) {
		float edge = smoothstep(1.0 + wob, 0.75, pr);
		float rip = 0.5 + 0.5 * sin(pr * 38.0 - t * 2.6);
		float rip2 = 0.5 + 0.5 * sin(length((p - vec2(52.0, 190.0)) / vec2(1.0, 0.25)) * 0.35 - t * 5.0);
		vec3 pcol = TOX * (0.35 + rip * 0.18 + rip2 * 0.12) + vec3(0.0, 0.05, 0.0);
		pcol += vec3(0.8, 1.0, 0.5) * pow(fbm(p * 0.06 + vec2(t * 0.3, 0.0)), 3.0) * 0.9;
		// bubbles popping
		vec2 bc = floor(p / vec2(18.0, 8.0));
		float bh = hash(bc);
		float bph = fract(t * (0.3 + bh * 0.5) + bh * 7.0);
		vec2 bp = (bc + vec2(0.5)) * vec2(18.0, 8.0);
		float bd = length((p - bp) / vec2(1.0, 0.6));
		pcol += vec3(0.85, 1.0, 0.6) * smoothstep(bph * 5.0 + 1.0, bph * 5.0, bd) * step(0.88, bh) * (1.0 - bph);
		col = over(col, vec4(pcol, edge * 0.92));
	}

	// ---------- left end cap (seen at an angle) ----------
	vec2 ed = (p - vec2(BX0, cy)) / vec2(26.0, ry);
	float er = length(ed);
	bool in_cap = er < 1.0 && p.x < BX0 + 2.0;
	float dyk = abs(p.y - cy) / ry;
	float hoop = max(step(abs(p.x - 168.0), 6.0), step(abs(p.x - 300.0), 6.0));
	float rend = BX1 - 9.0 + 9.0 * sqrt(max(0.0, 1.0 - dyk * dyk));       // curved far end
	bool in_body = p.x >= BX0 && p.x <= rend && abs(p.y - cy) <= ry + hoop * 3.0;

	if (in_body) {
		float v = (p.y - BY0) / (BY1 - BY0);
		float shade = 0.12 + 0.95 * pow(sin(3.14159 * clamp(v, 0.0, 1.0)), 0.7);
		shade *= 0.85 + 0.15 * smoothstep(BX0, BX0 + 60.0, p.x);                      // ambient falloff into the lid
		shade += exp(-pow((v - 0.27) / 0.05, 2.0)) * 0.35;      // specular band
		// paint: chipped olive drab over rust
		float n = fbm(p * vec2(0.035, 0.06));
		float n2 = fbm(p * 0.15 + 3.0);
		vec3 paint = vec3(0.17, 0.2, 0.12) + (n2 - 0.5) * 0.04;
		vec3 rust = mix(vec3(0.3, 0.13, 0.05), vec3(0.5, 0.25, 0.08), n2);
		float rk = smoothstep(0.62, 0.74, n + (1.0 - sin(3.14159 * clamp(v, 0.0, 1.0))) * 0.22);
		vec3 base = mix(paint, rust, rk);
		// streaks running down
		base *= 0.9 + 0.12 * fbm(vec2(p.x * 0.4, p.y * 0.02));
		// ribs (rolling hoops)
		for (int i = 0; i < 2; i++) {
			float rx = i == 0 ? 168.0 : 300.0;
			float dx = p.x - rx;
			if (abs(dx) < 6.0) {
				base *= 1.0 + (dx < 0.0 ? 0.35 : -0.35) * (1.0 - abs(dx) / 6.0);
				shade += 0.08;
			}
		}
		// end rims
		if (p.x < BX0 + 9.0 || p.x > BX1 - 9.0) {
			base *= p.x < BX0 + 9.0 ? 0.75 : 0.85;
			if (abs(p.x - (BX1 - 9.0)) < 1.2) base *= 1.6;
		}
		// hazard band with trefoil
		if (p.x > 384.0 && p.x < 440.0) {
			float stripe = step(0.5, fract((p.x + p.y) / 16.0));
			vec3 hz = mix(vec3(0.85, 0.66, 0.12), vec3(0.06, 0.05, 0.04), stripe) * (0.75 + n2 * 0.3);
			vec2 tc = p - vec2(412.0, cy);
			float td = length(tc);
			if (td < 24.0) {
				hz = vec3(0.86, 0.68, 0.14) * (0.8 + n2 * 0.25);
				float a = atan(tc.y, tc.x);
				float blade = step(0.5, fract((a + 1.5708) / 2.0944 + 0.25));
				if (td < 4.5 || (td > 7.0 && td < 20.0 && blade < 0.5)) hz = vec3(0.05, 0.045, 0.04);
				if (td > 22.5) hz *= 0.5;
			}
			base = mix(base, hz, 1.0 - rk * 0.6);
		}
		vec3 c = base * shade;
		// dents
		float dent = vnoise(p * 0.05 + 11.0);
		c *= 1.0 - smoothstep(0.75, 0.9, dent) * 0.25;
		// slime drips from the top rim (glowing, slowly creeping)
		float lane = floor(p.x / 14.0);
		float lh = hash(vec2(lane, 3.0));
		if (lh > 0.8) {
			float len = 8.0 + (lh - 0.8) * 160.0 + sin(t * (0.3 + lh) + lane) * 4.0;
			float dxl = abs(fract(p.x / 14.0) - 0.5) * 14.0;
			float w = 2.2 - (p.y - BY0) / len * 1.5;
			if (p.y - BY0 < len && dxl < w) {
				c = mix(c, TOX * 0.9, 0.85);
			}
			float tip = length(vec2(dxl, p.y - BY0 - len)) ;
			if (tip < 2.6) c = mix(c, TOX * 1.1, 0.9);
		}
		// ---------- HP sight gauge ----------
		if (p.x > GX0 - 4.0 && p.x < GX1 + 4.0 && p.y > GY0 - 4.0 && p.y < GY1 + 4.0) {
			c = vec3(0.08, 0.08, 0.075) * (0.7 + 0.5 * smoothstep(GY1 + 4.0, GY0 - 4.0, p.y));   // steel frame
			// frame bolts
			for (int i = 0; i < 2; i++) {
				vec2 bp = vec2(i == 0 ? GX0 - 1.0 : GX1 + 1.0, (GY0 + GY1) * 0.5);
				if (length(p - bp) < 2.2) c = vec3(0.45, 0.45, 0.4);
			}
		}
		if (p.x > GX0 && p.x < GX1 && p.y > GY0 && p.y < GY1) {
			float gv = (p.y - GY0) / (GY1 - GY0);
			vec3 glass = vec3(0.02, 0.035, 0.03);
			float fx = (p.x - GX0) / (GX1 - GX0);
			float edge_wob = sin(p.y * 0.7 + t * 7.0) * 0.004 + sin(t * 3.1) * 0.002;
			vec3 liq = mix(vec3(1.0, 0.12, 0.08), TOX, smoothstep(0.22, 0.55, hp));
			if (fx < hp + edge_wob) {
				float sl = fbm(vec2(p.x * 0.08 - t * 1.2, p.y * 0.2));
				vec3 lc = liq * (0.75 + sl * 0.6) * (0.75 + 0.5 * sin(3.14159 * gv));
				// bubbles rising through the sludge
				vec2 bc = floor(vec2(p.x / 10.0, 0.0));
				float bh = hash(bc + 5.0);
				float by = GY1 - fract(t * (0.4 + bh) + bh * 3.0) * (GY1 - GY0 + 6.0);
				float bx = (bc.x + 0.5) * 10.0 + sin(t * 2.0 + bh * 9.0) * 2.0;
				float bd = length(p - vec2(bx, by));
				lc += vec3(0.9, 1.0, 0.8) * smoothstep(2.2, 1.2, bd) * step(0.45, bh) * 0.6;
				// meniscus glow
				lc += liq * smoothstep(0.012, 0.0, abs(fx - hp - edge_wob)) * 1.2;
				glass = lc * 1.35;
			} else if (fx < hp_lag) {
				glass = mix(glass, vec3(0.95, 0.85, 0.7), 0.35);            // recent damage ghost
			}
			// tick marks every 10%
			if (abs(fract(fx * 10.0 + 0.0005) - 0.0) < 0.012 && gv < 0.28) glass = mix(glass, vec3(0.75), 0.6);
			// glass highlight
			glass += vec3(0.5, 0.6, 0.55) * exp(-pow((gv - 0.22) / 0.07, 2.0)) * 0.35;
			c = glass;
		}
		// ---------- stamina tube ----------
		float sy0 = GY1 + 7.0;
		float sy1 = sy0 + 7.0;
		if (p.x > GX0 - 2.0 && p.x < GX1 + 2.0 && p.y > sy0 - 2.0 && p.y < sy1 + 2.0) {
			c = vec3(0.07, 0.07, 0.065);
			if (p.x > GX0 && p.x < GX1 && p.y > sy0 && p.y < sy1) {
				float fx2 = (p.x - GX0) / (GX1 - GX0);
				vec3 sc = vec3(0.02, 0.03, 0.03);
				if (fx2 < stam) sc = vec3(0.45, 0.92, 0.85) * (0.8 + 0.4 * sin(3.14159 * (p.y - sy0) / 7.0));
				c = sc;
			}
		}
		// damage flash: rust-red pulse
		c = mix(c, vec3(0.9, 0.1, 0.05), hit * 0.25 * (1.0 - sin(3.14159 * v)));
		col = over(col, vec4(c, 1.0));
	}
	if (in_cap) {
		// rim ring + recessed lid + leaking bung
		vec3 c = vec3(0.13, 0.15, 0.1);
		float n = fbm(p * 0.12);
		c = mix(c, vec3(0.3, 0.14, 0.05), smoothstep(0.5, 0.7, n));
		c *= 0.55 + 0.45 * (1.0 - ed.x) * (0.6 + 0.4 * sin(3.14159 * (p.y - BY0) / (BY1 - BY0)));
		if (er > 0.82) c *= 1.35;
		if (er > 0.94) c *= 0.5;
		vec2 bung = (p - vec2(BX0 - 6.0, BY1 - 28.0)) / vec2(4.0, 8.0);
		if (length(bung) < 1.0) c = TOX * (0.8 + 0.3 * sin(t * 4.0));
		col = over(col, vec4(c, 1.0));
	}
	// leak stream from the bung into the puddle
	float lx = BX0 - 6.0 + sin(p.y * 0.15 + t * 3.0) * 1.2;
	if (p.y > BY1 - 22.0 && p.y < 194.0 && abs(p.x - lx) < 2.0 + (p.y - BY1) * 0.02 && !in_body) {
		float drop = 0.7 + 0.3 * step(0.5, fract(p.y * 0.08 - t * 2.5));
		col = over(col, vec4(TOX * drop * 1.1, 0.95));
	}
	COLOR = col;
}
"""
	return sh
