class_name AmmoCan
extends Control
# Bottom-right weapon readout, the companion to ToxicBarrel: a rusted military
# ammo can standing in the same glowing puddle. One canvas shader draws the can
# (embossed panels, lid with carry handle, latch, rarity stripe), a sludge-lit
# display window for the ammo count, a row of cartridges that empties as you
# fire (red pulse when low), and a glowing reload strip. HUD.gd puts the text
# (weapon name, mode, ammo, gear) on top as regular controls.

const SIZE := Vector2(424, 222)

var art: ColorRect
var mat: ShaderMaterial
var _mag_k := 1.0
var _act := -1.0

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

# ammo / mag: current magazine; melee hides the cartridge row.
func set_weapon(ammo: int, mag: int, rarity_col: Color, melee: bool) -> void:
	var n := 0 if melee else clampi(mag, 1, 40)
	var filled := 0 if melee else (ammo if mag <= 40 else int(round(float(ammo) / float(mag) * 40.0)))
	mat.set_shader_parameter("slots", float(n))
	mat.set_shader_parameter("filled", float(filled))
	mat.set_shader_parameter("low", 1.0 if (not melee and ammo <= maxi(1, mag / 4)) else 0.0)
	mat.set_shader_parameter("rar_col", rarity_col)

func set_action(progress: float) -> void:
	mat.set_shader_parameter("act", progress)

static func _shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec2 rect_size = vec2(424.0, 222.0);
uniform float slots = 30.0;
uniform float filled = 30.0;
uniform float low = 0.0;
uniform float act = -1.0;
uniform vec4 rar_col : source_color = vec4(0.8, 0.8, 0.8, 1.0);

const vec3 TOX = vec3(0.55, 1.0, 0.18);
const float X0 = 18.0;
const float X1 = 398.0;
const float Y0 = 24.0;
const float Y1 = 188.0;
const float LID = 48.0;        // lid bottom
const vec4 WIN = vec4(164.0, 56.0, 386.0, 118.0);   // display window
const float BY0 = 126.0;       // bullet row
const float BY1 = 146.0;

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

	// ---------- toxic puddle ----------
	vec2 pd = (p - vec2(206.0, 202.0)) / vec2(214.0, 20.0);
	float wob = fbm(vec2(atan(pd.y, pd.x) * 2.0 + 4.0, t * 0.2)) * 0.25;
	float pr = length(pd);
	if (pr < 1.0 + wob) {
		float edge = smoothstep(1.0 + wob, 0.75, pr);
		float rip = 0.5 + 0.5 * sin(pr * 34.0 - t * 2.4);
		vec3 pcol = TOX * (0.35 + rip * 0.2) + vec3(0.0, 0.05, 0.0);
		pcol += vec3(0.8, 1.0, 0.5) * pow(fbm(p * 0.06 - vec2(t * 0.3, 0.0)), 3.0) * 0.9;
		vec2 bc = floor(p / vec2(18.0, 8.0));
		float bh = hash(bc + 2.0);
		float bph = fract(t * (0.3 + bh * 0.5) + bh * 7.0);
		float bd = length((p - (bc + vec2(0.5)) * vec2(18.0, 8.0)) / vec2(1.0, 0.6));
		pcol += vec3(0.85, 1.0, 0.6) * smoothstep(bph * 5.0 + 1.0, bph * 5.0, bd) * step(0.88, bh) * (1.0 - bph);
		col = over(col, vec4(pcol, edge * 0.92));
	}

	// ---------- carry handle (behind the lid) ----------
	vec2 hc = p - vec2(208.0, Y0 + 2.0);
	float hd = length(hc / vec2(52.0, 18.0));
	if (hc.y < 0.0 && abs(hd - 1.0) < 0.12) {
		col = over(col, vec4(vec3(0.16, 0.17, 0.12) * (0.7 + 0.5 * smoothstep(0.0, -18.0, hc.y)), 1.0));
	}

	// ---------- can body ----------
	if (p.x > X0 && p.x < X1 && p.y > Y0 && p.y < Y1) {
		float n = fbm(p * vec2(0.03, 0.05));
		float n2 = fbm(p * 0.15 + 7.0);
		vec3 paint = vec3(0.18, 0.21, 0.12) + (n2 - 0.5) * 0.05;
		vec3 rust = mix(vec3(0.3, 0.13, 0.05), vec3(0.5, 0.25, 0.08), n2);
		float edge_d = min(min(p.x - X0, X1 - p.x), min(p.y - Y0, Y1 - p.y));
		float rk = smoothstep(0.6, 0.72, n + (1.0 - smoothstep(0.0, 14.0, edge_d)) * 0.25);
		vec3 c = mix(paint, rust, rk);
		c *= 0.9 + 0.12 * fbm(vec2(p.x * 0.4, p.y * 0.02));
		// key light from top-left, darker toward the bottom
		c *= 1.05 - (p.y - Y0) / (Y1 - Y0) * 0.35;
		// outer bevel
		if (edge_d < 2.0) c *= (p.x - X0 < 2.0 || p.y - Y0 < 2.0) ? 1.5 : 0.5;
		// lid
		if (p.y < LID) {
			c *= 0.82;
			if (abs(p.y - LID) < 1.5) c *= 0.4;
			if (abs(p.y - (LID - 3.0)) < 1.0) c *= 1.4;
		}
		// rarity stripe under the lid
		if (p.y > LID + 1.0 && p.y < LID + 4.0) c = rar_col.rgb * (0.7 + n2 * 0.3) * (1.0 - rk * 0.5);
		// embossed side panel frame
		vec4 fr = vec4(X0 + 8.0, LID + 8.0, X1 - 8.0, Y1 - 8.0);
		float fx = min(abs(p.x - fr.x), abs(p.x - fr.z));
		float fy = min(abs(p.y - fr.y), abs(p.y - fr.w));
		bool inside_fr = p.x > fr.x && p.x < fr.z && p.y > fr.y && p.y < fr.w;
		if (inside_fr && (fx < 1.5 || fy < 1.5)) c *= (abs(p.x - fr.x) < 1.5 || abs(p.y - fr.y) < 1.5) ? 0.55 : 1.35;
		// latch on the right
		if (p.x > X1 - 14.0 && p.x < X1 - 2.0 && p.y > Y0 + 6.0 && p.y < LID + 18.0) {
			c = vec3(0.32, 0.33, 0.3) * (0.8 + 0.4 * smoothstep(LID + 18.0, Y0 + 6.0, p.y));
			if (abs(p.y - (LID + 4.0)) < 1.0) c *= 0.4;
		}
		// slime oozing out from under the lid
		float lane = floor(p.x / 16.0);
		float lh = hash(vec2(lane, 9.0));
		if (lh > 0.78 && p.y > LID) {
			float len = 3.0 + (lh - 0.78) * 40.0 + sin(t * (0.3 + lh) + lane) * 1.5;
			float dxl = abs(fract(p.x / 16.0) - 0.5) * 16.0;
			float w = 2.2 - (p.y - LID) / len * 1.4;
			if (p.y - LID < len && dxl < w) c = mix(c, TOX * 0.9, 0.85);
			if (length(vec2(dxl, p.y - LID - len)) < 2.5) c = mix(c, TOX * 1.1, 0.9);
		}
		// ---------- display window ----------
		if (p.x > WIN.x - 4.0 && p.x < WIN.z + 4.0 && p.y > WIN.y - 4.0 && p.y < WIN.w + 4.0) {
			c = vec3(0.07, 0.075, 0.065) * (0.7 + 0.5 * smoothstep(WIN.w + 4.0, WIN.y - 4.0, p.y));
			for (int i = 0; i < 4; i++) {
				vec2 bp = vec2(i % 2 == 0 ? WIN.x - 1.0 : WIN.z + 1.0, i < 2 ? WIN.y - 1.0 : WIN.w + 1.0);
				if (length(p - bp) < 2.0) c = vec3(0.45, 0.45, 0.4);
			}
		}
		if (p.x > WIN.x && p.x < WIN.z && p.y > WIN.y && p.y < WIN.w) {
			float gv = (p.y - WIN.y) / (WIN.w - WIN.y);
			vec3 g = vec3(0.03, 0.06, 0.03) + TOX * 0.06 * (0.6 + 0.4 * fbm(p * 0.05 + vec2(t * 0.15, 0.0)));
			g += TOX * 0.03 * step(0.5, fract(p.y * 0.5));                         // scanlines
			g = mix(g, vec3(0.25, 0.04, 0.03), low * (0.5 + 0.5 * sin(t * 8.0)) * 0.5);
			g += vec3(0.5, 0.6, 0.55) * exp(-pow((gv - 0.12) / 0.06, 2.0)) * 0.18;   // glass glint
			c = g;
		}
		// ---------- cartridge row ----------
		if (slots > 0.5 && p.y > BY0 - 3.0 && p.y < BY1 + 3.0 && p.x > X0 + 12.0 && p.x < X1 - 12.0) {
			c *= 0.45;   // recessed tray
			float x0 = X0 + 16.0;
			float w = (X1 - 16.0 - x0) / slots;
			float i = floor((p.x - x0) / w);
			float lx = (p.x - x0) / w - i;
			if (i >= 0.0 && i < slots) {
				float cw = clamp(0.62, 0.3, 0.8);
				float dx = abs(lx - 0.5) / (cw * 0.5);
				float ly = (p.y - BY0) / (BY1 - BY0);
				bool live = i < filled;
				if (dx < 1.0 && ly > 0.0 && ly < 1.0) {
					vec3 bc;
					if (ly < 0.32) {
						float tip = length(vec2(dx, (0.32 - ly) / 0.32 * 1.15));
						if (tip > 1.0) bc = c;
						else bc = live ? vec3(0.72, 0.38, 0.2) * (1.1 - dx * 0.5) : vec3(0.06);
					} else {
						bc = live ? vec3(0.85, 0.65, 0.28) * (1.15 - dx * 0.55) : vec3(0.08, 0.08, 0.07);
						if (ly > 0.9) bc *= 0.7;
					}
					if (live && low > 0.5) bc = mix(bc, vec3(1.0, 0.25, 0.15), 0.35 + 0.25 * sin(t * 8.0));
					c = bc;
				}
			}
		}
		// ---------- reload / use strip ----------
		if (act >= 0.0 && p.y > BY1 + 4.0 && p.y < BY1 + 8.0 && p.x > X0 + 14.0 && p.x < X1 - 14.0) {
			float k = (p.x - X0 - 14.0) / (X1 - X0 - 28.0);
			c = k < act ? TOX * (1.0 + 0.4 * sin(p.x * 0.3 - t * 12.0)) : vec3(0.03, 0.04, 0.03);
		}
		col = over(col, vec4(c, 1.0));
	}
	COLOR = col;
}
"""
	return sh
