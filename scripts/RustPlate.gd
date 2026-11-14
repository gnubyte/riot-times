class_name RustPlate
extends Control
# Reusable HUD backing in the same language as ToxicBarrel / AmmoCan: a riveted,
# rust-eaten olive steel plate drawn by a canvas shader. Options:
#   window  - an inset of sludge-lit toxic glass (Rect2 in local px; zero = none)
#   hazard  - width of yellow/black hazard stripes at both ends (0 = none)
#   drips   - slime hanging off the bottom edge (0..1 density)
# Resize freely (set_plate_size); the shader follows.

var art: ColorRect
var mat: ShaderMaterial

func _init(sz := Vector2(200, 40), window := Rect2(), hazard := 0.0, drips := 0.0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	art = ColorRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = _shader()
	art.material = mat
	add_child(art)
	set_window(window)
	mat.set_shader_parameter("hazard", hazard)
	mat.set_shader_parameter("drips", drips)
	mat.set_shader_parameter("seed", randf() * 100.0)
	set_plate_size(sz)

func set_plate_size(sz: Vector2) -> void:
	custom_minimum_size = sz
	size = sz
	art.size = sz
	mat.set_shader_parameter("rect_size", sz)

func set_window(r: Rect2) -> void:
	mat.set_shader_parameter("window", Vector4(r.position.x, r.position.y, r.end.x, r.end.y))

func set_heading(deg: float, span_deg := 150.0) -> void:
	mat.set_shader_parameter("heading", deg)
	mat.set_shader_parameter("span", span_deg)

func set_alert(k: float) -> void:
	mat.set_shader_parameter("alert", k)

static var _sh: Shader
static func _shader() -> Shader:
	if _sh != null:
		return _sh
	_sh = Shader.new()
	_sh.code = """
shader_type canvas_item;
uniform vec2 rect_size = vec2(200.0, 40.0);
uniform vec4 window = vec4(0.0);
uniform float hazard = 0.0;
uniform float drips = 0.0;
uniform float seed = 0.0;
uniform float alert = 0.0;
uniform float heading = -1.0;     // >= 0: draw compass ticks in the window
uniform float span = 150.0;       // degrees across the window
const vec3 TOX = vec3(0.55, 1.0, 0.18);
const float DRIP_ROOM = 14.0;

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

void fragment() {
	vec2 p = UV * rect_size;
	float t = TIME;
	float H = rect_size.y - (drips > 0.0 ? DRIP_ROOM : 0.0);   // plate height (drips hang below)
	vec2 sz = vec2(rect_size.x, H);
	vec4 col = vec4(0.0);
	// rounded-corner plate mask
	vec2 q = abs(p - sz * 0.5) - (sz * 0.5 - vec2(3.0));
	float dbox = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 3.0;
	if (dbox < 0.0) {
		vec2 sp = p + seed * 37.0;
		float n = fbm(sp * vec2(0.03, 0.06));
		float n2 = fbm(sp * 0.15 + 7.0);
		vec3 paint = vec3(0.16, 0.19, 0.11) + (n2 - 0.5) * 0.05;
		vec3 rust = mix(vec3(0.3, 0.13, 0.05), vec3(0.48, 0.24, 0.08), n2);
		float edge_d = -dbox;
		float rk = smoothstep(0.6, 0.72, n + (1.0 - smoothstep(0.0, 10.0, edge_d)) * 0.28);
		vec3 c = mix(paint, rust, rk);
		c *= 0.9 + 0.12 * fbm(vec2(sp.x * 0.4, sp.y * 0.03));
		c *= 1.08 - (p.y / H) * 0.3;
		if (edge_d < 1.6) c *= (p.y < H * 0.5) ? 1.55 : 0.45;     // bevel
		// hazard ends
		if (hazard > 0.0 && (p.x < hazard || p.x > sz.x - hazard)) {
			float st = step(0.5, fract((p.x + p.y) / 12.0));
			vec3 hz = mix(vec3(0.85, 0.66, 0.12), vec3(0.06, 0.05, 0.04), st) * (0.75 + n2 * 0.3);
			c = mix(c, hz, 1.0 - rk * 0.6);
			if (edge_d < 1.6) c *= (p.y < H * 0.5) ? 1.3 : 0.5;
		}
		// rivets at the four corners (inside hazard ends if present)
		float bx = hazard > 0.0 ? hazard + 6.0 : 7.0;
		for (int i = 0; i < 4; i++) {
			vec2 bp = vec2(i % 2 == 0 ? bx : sz.x - bx, i < 2 ? min(7.0, H * 0.3) : max(H - 7.0, H * 0.7));
			float bd = length(p - bp);
			if (bd < 2.6) c = vec3(0.42, 0.42, 0.37) * (1.2 - (p.y - bp.y + p.x - bp.x) * 0.12);
		}
		// toxic glass window
		if (window.z > window.x) {
			vec4 w = window;
			if (p.x > w.x - 3.0 && p.x < w.z + 3.0 && p.y > w.y - 3.0 && p.y < w.w + 3.0)
				c = vec3(0.07, 0.075, 0.065) * (0.7 + 0.5 * smoothstep(w.w + 3.0, w.y - 3.0, p.y));
			if (p.x > w.x && p.x < w.z && p.y > w.y && p.y < w.w) {
				float gv = (p.y - w.y) / max(1.0, w.w - w.y);
				vec3 g = vec3(0.025, 0.05, 0.025) + TOX * 0.07 * (0.6 + 0.4 * fbm(p * 0.05 + vec2(t * 0.12, seed)));
				g += TOX * 0.025 * step(0.5, fract(p.y * 0.5));
				g += vec3(0.5, 0.6, 0.55) * exp(-pow((gv - 0.14) / 0.08, 2.0)) * 0.14;
				g = mix(g, vec3(0.3, 0.04, 0.03), alert * (0.5 + 0.5 * sin(t * 8.0)) * 0.6);
				if (heading >= 0.0) {
					float mid = (w.x + w.z) * 0.5;
					float deg = heading + ((p.x - mid) / (w.z - w.x)) * span;
					float ppd = (w.z - w.x) / span;
					float d5 = abs(fract(deg / 5.0 + 0.5) - 0.5) * 5.0 * ppd;
					float d15 = abs(fract(deg / 15.0 + 0.5) - 0.5) * 15.0 * ppd;
					float d45 = abs(fract(deg / 45.0 + 0.5) - 0.5) * 45.0 * ppd;
					float hgt = w.w - p.y;
					if (d5 < 0.6 && hgt < 3.0) g += TOX * 0.35;
					if (d15 < 0.7 && hgt < 6.0) g += TOX * 0.5;
					if (d45 < 0.9 && hgt < 9.0) g += TOX * 0.7;
					g *= 0.55 + 0.45 * (1.0 - pow(abs((p.x - mid) / ((w.z - w.x) * 0.5)), 3.0));
					float cx = abs(p.x - mid);
					if (cx < 1.0) g = mix(g, TOX * 1.2, 0.8);
					if (p.y - w.y < 5.0 && cx < 5.0 - (p.y - w.y)) g = TOX * 1.3;
				}
				c = g;
			}
		}
		col = vec4(c, 1.0);
	}
	// slime dripping off the bottom edge
	if (drips > 0.0 && p.y >= H - 2.0) {
		float lane = floor((p.x + seed * 13.0) / 12.0);
		float lh = hash(vec2(lane, 4.0 + seed));
		if (lh > 1.0 - drips * 0.35) {
			float len = 3.0 + (lh - (1.0 - drips * 0.35)) / (drips * 0.35) * (DRIP_ROOM - 6.0) + sin(t * (0.4 + lh) + lane) * 1.5;
			float dx = abs(fract((p.x + seed * 13.0) / 12.0) - 0.5) * 12.0;
			float y = p.y - H;
			float w = 2.0 - y / max(len, 1.0) * 1.2;
			if ((y < len && dx < w) || length(vec2(dx, y - len)) < 2.2) col = vec4(TOX * 0.95, 1.0);
		}
	}
	COLOR = col;
}
"""
	return _sh
