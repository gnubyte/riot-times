extends CanvasLayer
# Loading screen: one full-screen canvas shader paints a living toxic vista (storm
# sky with lightning, three layers of ruined skyline with flickering windows and
# smoke plumes, a glowing waste lake, a lone survivor on a rubble ridge, falling
# ash, hazard tape, grain) plus a rusted pipe gauge that fills with bubbling
# sludge and a spinning radiation trefoil. Text on top: stenciled title, themed
# stage names that follow the real build progress, and survival notes typed out
# on a rusted plate. API used by Main: new(), set_progress(v), finish_and_free().

class_name LoadingScreen

var root: Control
var art: ColorRect
var mat: ShaderMaterial
var title: Label
var subtitle: Label
var stage: Label
var pct: Label
var note_plate: RustPlate
var note_head: Label
var note: Label
var shown := 0.0
var target := 0.0
var done := false
var _flash := 0.0
var _next_flash := 1.5
var _note_t := 0.0
var _note_i := 0
var _tips: Array = []
var _last_size := Vector2.ZERO

const STAGES := [
	[0.06, "SCORCHING THE EARTH"],
	[0.25, "FORGING WEAPONS"],
	[0.31, "POISONING THE SKY"],
	[0.42, "CRACKING THE EARTH"],
	[0.49, "FORTIFYING HAVEN"],
	[0.64, "TOPPLING SKYSCRAPERS"],
	[0.72, "ARMING CAMP HALBERD"],
	[0.76, "BURNING THE FORESTS"],
	[0.81, "SCATTERING THE DEAD"],
	[0.86, "POURING CONCRETE"],
	[0.92, "WAKING THE HORDE"],
	[1.01, "TEACHING THE DEAD TO HUNT"],
]

const TIPS := [
	"Every gunshot is heard for 60 meters. Melee and crossbows are quiet. Hushed guns are quieter.",
	"The Gaunt is blind. It hunts sound. Crouch, don't run, and don't shoot.",
	"Kill the Screamer first, or the whole street comes running.",
	"Bloaters pop into toxic gas that spreads the Rot. A gas mask laughs at it.",
	"Silver hurts werewolves. Fire hurts vampires. Stakes hurt them a lot.",
	"You only get one life. Your body and your gear stay where you fall.",
	"Die cursed, and you'll rise again. Your next survivor will have to put you down.",
	"Every third night the horde comes for Haven. Be there, or hope the guards hold.",
	"Night loot is better. Night is also when the wolves come out.",
	"Raw meat and dirty water can make you sick. Cook it at a fire.",
	"Cold makes your aim shake. Warm clothes, fires and pine tea fix that.",
	"Weight matters. Over capacity you're slower, louder, and you can't sprint.",
	"Slide by crouching mid-sprint. Jump out of a slide to keep the momentum.",
	"Engines are loud. Park away from where you're going to loot.",
	"The Galleria under the plaza is rich and packed. The skylight is a fast way down.",
	"Leave your best gear in Haven's stash. It outlives you.",
	"Smoke on the horizon means a wreck. Wrecks mean loot. Loot means company.",
	"The pylon line runs east to west. Follow it if you get lost in the wastes.",
]

func _init() -> void:
	layer = 30

func _ready() -> void:
	_tips = TIPS.duplicate()
	_tips.shuffle()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	art = ColorRect.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = _shader()
	art.material = mat
	root.add_child(art)

	title = _label(Color(0.62, 0.98, 0.28), 8)
	title.text = "RIOT TIMES"
	title.add_theme_color_override("font_shadow_color", Color(0.35, 0.9, 0.1, 0.35))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 22)
	subtitle = _label(Color(0.78, 0.82, 0.62), 4)
	subtitle.text = "SURVIVE THE DEAD  ·  LOOT THE RUINS  ·  ONE LIFE"
	stage = _label(Color(0.82, 0.95, 0.6), 5)
	stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pct = _label(Color(0.62, 0.98, 0.28), 5)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	note_plate = RustPlate.new(Vector2(600, 120), Rect2(), 0.0, 0.6)
	root.add_child(note_plate)
	note_head = _label(Color(0.86, 0.68, 0.16), 4)
	note_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note = _label(Color(0.86, 0.88, 0.76), 4)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_note()
	_layout()

func _label(col: Color, outline: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 0.92))
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l

# Everything is laid out in units of screen height so it holds at any resolution.
func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	_last_size = vs
	var h := vs.y
	var cx := vs.x * 0.5
	mat.set_shader_parameter("res", vs)
	title.add_theme_font_size_override("font_size", int(h * 0.105))
	title.position = Vector2(cx - h * 0.8, h * 0.06)
	title.size = Vector2(h * 1.6, h * 0.14)
	subtitle.add_theme_font_size_override("font_size", int(h * 0.022))
	subtitle.position = Vector2(cx - h * 0.8, h * 0.19)
	subtitle.size = Vector2(h * 1.6, h * 0.04)
	# gauge sits at y 0.885 (shader), spans +-0.36h around centre
	stage.add_theme_font_size_override("font_size", int(h * 0.024))
	stage.position = Vector2(cx - h * 0.33, h * 0.815)
	stage.size = Vector2(h * 0.5, h * 0.04)
	pct.add_theme_font_size_override("font_size", int(h * 0.028))
	pct.position = Vector2(cx + h * 0.1, h * 0.81)
	pct.size = Vector2(h * 0.26, h * 0.04)
	var pw := minf(h * 0.82, vs.x - 40.0)
	note_plate.set_plate_size(Vector2(pw, h * 0.135))
	note_plate.position = Vector2(cx - pw * 0.5, h * 0.645)
	note_head.add_theme_font_size_override("font_size", int(h * 0.017))
	note_head.position = note_plate.position + Vector2(h * 0.03, h * 0.012)
	note_head.size = Vector2(pw - h * 0.06, h * 0.03)
	note.add_theme_font_size_override("font_size", int(h * 0.021))
	note.position = note_plate.position + Vector2(h * 0.03, h * 0.04)
	note.size = Vector2(pw - h * 0.06, h * 0.07)

func _next_note() -> void:
	_note_i = (_note_i + 1) % _tips.size()
	note_head.text = "SURVIVAL NOTE #%02d" % (_note_i + 1)
	note.text = _tips[_note_i]
	note.visible_ratio = 0.0
	_note_t = 0.0

func set_progress(v: float) -> void:
	target = clampf(v, 0.0, 1.0)

func _process(delta: float) -> void:
	if mat == null:
		return
	if get_viewport().get_visible_rect().size != _last_size:
		_layout()
	shown = lerpf(shown, target, clampf(delta * 6.0, 0.0, 1.0))
	mat.set_shader_parameter("progress", shown)
	pct.text = "%d%%" % int(round(shown * 100.0))
	for s in STAGES:
		if shown < float(s[0]):
			stage.text = "▸ %s%s" % [s[1], ".".repeat(1 + int(Time.get_ticks_msec() / 400) % 3)]
			break
	# dry lightning in the storm
	_next_flash -= delta
	if _next_flash <= 0.0:
		_next_flash = randf_range(2.5, 6.0)
		_flash = randf_range(0.7, 1.0)
		mat.set_shader_parameter("flash_x", randf_range(-0.7, 0.7))
	_flash = maxf(0.0, _flash - delta * 2.4)
	mat.set_shader_parameter("flash", _flash * (0.6 + 0.4 * sin(_flash * 40.0)))
	# typewriter notes
	_note_t += delta
	note.visible_ratio = clampf(_note_t / 1.6, 0.0, 1.0)
	if _note_t > 6.5:
		_next_note()

func finish_and_free() -> void:
	if done:
		return
	done = true
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.45)
	tw.tween_callback(queue_free)

static func _shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec2 res = vec2(1600.0, 900.0);
uniform float progress = 0.0;
uniform float flash = 0.0;
uniform float flash_x = 0.0;
const vec3 TOX = vec3(0.55, 1.0, 0.18);
const float HZN = 0.6;   // horizon height (fraction of screen)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float h1(float x) { return fract(sin(x * 91.17) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += vnoise(p) * a; p *= 2.02; a *= 0.5; }
	return v;
}
float sd_box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
float sd_seg(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a; vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

// skyline height for a layer at screen-x (in height units)
float skyline(float x, float seed, float w, float base, float amp) {
	float c = floor(x / w);
	float hh = base + h1(c + seed) * amp;
	// some towers are snapped off: jagged broken top
	if (h1(c * 3.1 + seed) > 0.55) {
		float f = floor(fract(x / w) * 5.0);
		hh -= h1(c * 13.0 + f * 1.7 + seed) * amp * 0.28 * step(0.35, h1(c * 5.0 + f + seed));
	}
	// rooftop antenna / water tank on some towers
	if (h1(c * 2.3 + seed) > 0.85 && abs(fract(x / w) - 0.5) < 0.04) hh += amp * 0.12;
	// gaps between buildings
	if (h1(c * 1.7 + seed) < 0.18) hh = base * 0.3;
	return hh;
}

void fragment() {
	vec2 px = UV * res;
	float H = res.y;
	vec2 q = vec2((px.x - res.x * 0.5) / H, px.y / H);   // x centred, both in height units
	float t = TIME;
	float y = q.y;

	// ---------- sky ----------
	float sk = clamp(y / HZN, 0.0, 1.0);
	vec3 col = mix(vec3(0.05, 0.08, 0.045), vec3(0.66, 0.72, 0.27), pow(sk, 1.5));
	col += vec3(0.45, 0.5, 0.12) * exp(-pow((y - HZN) / 0.07, 2.0)) * 0.7;          // toxic horizon glow
	// pale sun smothered in haze
	float sd = length(q - vec2(0.42, 0.42));
	col += vec3(0.85, 0.95, 0.55) * (smoothstep(0.05, 0.035, sd) * 0.6 + exp(-sd * 9.0) * 0.25);
	// rolling storm clouds, two layers
	vec2 cuv = vec2(q.x * 1.6, y * 3.0);
	float c1 = fbm(cuv * 1.3 + vec2(t * 0.025, 0.0));
	float c2 = fbm(cuv * 2.7 - vec2(t * 0.04, t * 0.005));
	float dens = smoothstep(0.38, 0.75, c1 * 0.7 + c2 * 0.45) * smoothstep(HZN + 0.02, HZN - 0.25, y);
	vec3 cloud = mix(vec3(0.09, 0.12, 0.06), vec3(0.62, 0.72, 0.34), smoothstep(0.35, 0.95, c1) * 0.85);
	float fl = flash * exp(-length((q - vec2(flash_x, 0.15)) * vec2(1.0, 1.6)) * 2.2);
	cloud += vec3(0.6, 0.95, 0.65) * fl * (0.6 + c2) * 1.8;
	col = mix(col, cloud, dens * 0.8);
	col += vec3(0.25, 0.35, 0.28) * flash * 0.08;
	// lightning bolt
	if (flash > 0.55) {
		float bx = flash_x + (fbm(vec2(y * 4.0, flash_x * 9.0)) - 0.5) * 0.18 + (vnoise(vec2(y * 40.0, flash_x)) - 0.5) * 0.012;
		float dxb = abs(q.x - bx);
		float inside = step(0.12, y) * step(y, HZN - 0.08);
		float bolt = (smoothstep(0.0025, 0.0, dxb) + exp(-dxb * 120.0) * 0.4) * inside;
		col += vec3(0.85, 1.0, 0.85) * bolt * (flash - 0.55) * 3.5;
	}

	// ---------- skyline layers (far to near) ----------
	for (int L = 0; L < 3; L++) {
		float fL = float(L);
		float par = t * (0.004 + fL * 0.006);
		float w = 0.05 + fL * 0.025;
		float base = 0.05 + fL * 0.035;
		float amp = 0.17 + fL * 0.09;
		float sx = q.x + par + fL * 3.7;
		float top = HZN - skyline(sx, 13.0 + fL * 7.0, w, base, amp);
		if (y > top && y < HZN + 0.02) {
			float fog = 0.75 - fL * 0.3;
			vec3 bc = mix(vec3(0.03, 0.04, 0.03), vec3(0.32, 0.4, 0.15), fog);
			// windows on the nearer layers: mostly dark, a few lit, some flicker
			if (L > 0) {
				vec2 wg = vec2(sx / (w * 0.14), (y - top) / 0.018);
				vec2 wc = floor(wg);
				vec2 wf = fract(wg);
				float r = hash(wc + fL * 11.0);
				if (wf.x > 0.25 && wf.x < 0.75 && wf.y > 0.3 && wf.y < 0.8 && fract(sx / w) > 0.12 && fract(sx / w) < 0.88) {
					float lit = step(0.965, r) * (0.7 + 0.3 * step(0.5, sin(t * (3.0 + r * 20.0) + r * 40.0)));
					vec3 wcol = r > 0.985 ? vec3(1.0, 0.7, 0.3) : TOX;
					bc += wcol * lit * (0.5 + fL * 0.2);
					bc *= 1.0 - step(r, 0.6) * 0.25;
				}
			}
			col = bc;
		}
		// smoke plumes rising from a few towers
		float pc = floor(sx / (w * 4.0));
		if (h1(pc * 5.3 + fL) > 0.55 && L > 0) {
			float px0 = (pc + 0.5) * w * 4.0;
			float ptop = HZN - skyline(px0, 13.0 + fL * 7.0, w, base, amp);
			float rise = ptop - y;
			if (rise > 0.0 && rise < 0.5) {
				float drift = rise * rise * 0.6 + sin(rise * 8.0 - t * 0.6) * 0.01;
				float wdt = 0.018 + rise * 0.18;
				float dx = abs(sx - px0 - drift);
				float puff = fbm(vec2((sx - drift) * 14.0, rise * 6.0 - t * 0.35));
				float a = smoothstep(wdt, wdt * 0.2, dx) * smoothstep(0.5, 0.15, rise) * (0.4 + puff * 0.8);
				col = mix(col, vec3(0.04, 0.045, 0.035) + vec3(0.6, 0.3, 0.1) * smoothstep(0.03, 0.0, rise) * 0.8, clamp(a, 0.0, 0.85));
			}
		}
	}

	// ---------- toxic lake and ground ----------
	if (y > HZN) {
		float g = (y - HZN) / (1.0 - HZN);
		vec3 ground = mix(vec3(0.07, 0.085, 0.05), vec3(0.025, 0.03, 0.02), g);
		ground *= 0.8 + 0.4 * fbm(vec2(q.x * 6.0, y * 30.0));
		float lake_top = HZN + 0.02 + sin(q.x * 3.0) * 0.008;
		float lake_bot = HZN + 0.09 + sin(q.x * 2.0 + 1.0) * 0.015;
		float pool = smoothstep(0.34, 0.62, fbm(vec2(q.x * 1.6 + 3.0, 0.5)));
		if (y > lake_top && y < lake_bot && pool > 0.01) {
			float ly = (y - lake_top) / (lake_bot - lake_top);
			float rip = sin(q.x * 90.0 + t * 1.5 + sin(y * 300.0) * 0.6) * 0.5 + 0.5;
			vec3 lake = TOX * (0.35 + 0.25 * rip * (1.0 - ly)) + vec3(0.0, 0.04, 0.0);
			lake += vec3(0.8, 1.0, 0.6) * pow(fbm(vec2(q.x * 12.0 - t * 0.2, y * 60.0)), 4.0) * 0.8;
			float edge = smoothstep(0.0, 0.08, ly) * smoothstep(1.0, 0.85, ly) * pool;
			ground = mix(ground, lake, edge);
			ground += TOX * 0.12 * fl;
		}
		col = ground;
	}
	col += TOX * 0.1 * exp(-pow((y - HZN - 0.05) / 0.04, 2.0));

	// ---------- foreground rubble ridge + lone survivor ----------
	float ridge = 0.8 - exp(-pow((q.x + 0.55) / 0.35, 2.0)) * 0.14 + (fbm(vec2(q.x * 9.0, 0.0)) - 0.5) * 0.04
		- exp(-pow((q.x - 0.75) / 0.3, 2.0)) * 0.08;
	// rebar / girders poking out of the ridge
	float bar1 = sd_seg(q, vec2(-0.85, ridge + 0.02), vec2(-0.8, ridge - 0.12), 0.003);
	float bar2 = sd_seg(q, vec2(0.62, 0.78), vec2(0.7, 0.65), 0.005);
	float bar3 = sd_seg(q, vec2(0.72, 0.76), vec2(0.66, 0.67), 0.003);
	vec2 sp = q - vec2(-0.55, 0.662);      // survivor's feet
	float sway = sin(t * 2.2) * 0.004;
	float body = 1e9;
	body = min(body, sd_seg(sp, vec2(-0.008, 0.0), vec2(-0.004, -0.045), 0.006));    // legs
	body = min(body, sd_seg(sp, vec2(0.009, 0.0), vec2(0.005, -0.045), 0.006));
	// long coat flaring in the wind
	vec2 cp = sp - vec2(0.0, -0.065);
	float coat = sd_box(cp + vec2(cp.y * -0.25 * (0.8 + sway * 40.0), 0.0), vec2(0.014 + max(0.0, cp.y) * 0.35, 0.03));
	body = min(body, coat);
	body = min(body, length(sp - vec2(0.0, -0.106)) - 0.0105);                       // head
	body = min(body, sd_box(sp - vec2(0.004, -0.1), vec2(0.012, 0.006)));             // hood / collar
	body = min(body, sd_seg(sp, vec2(-0.018, -0.03), vec2(0.028, -0.1), 0.0028));    // rifle slung
	body = min(body, sd_seg(sp, vec2(0.012, -0.085), vec2(0.022, -0.05), 0.004));     // arm
	float fg = min(min(bar1, min(bar2, bar3)), body);
	if (y > ridge || fg < 0.0) {
		vec3 dark = vec3(0.012, 0.016, 0.01);
		// rim light from the toxic horizon
		float rim = smoothstep(0.004, 0.0, abs(fg)) * step(fg, 0.0) + smoothstep(0.006, 0.0, abs(y - ridge)) * step(ridge, y);
		col = dark + TOX * rim * 0.35;
	}

	// ---------- falling ash ----------
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		vec2 ap = q * (14.0 + fi * 10.0) + vec2(t * (0.3 + fi * 0.2), -t * (1.2 + fi * 0.6));
		vec2 ac = floor(ap);
		vec2 af = fract(ap) - 0.5;
		float r = hash(ac + fi * 7.0);
		if (r > 0.9) {
			float d = length(af - vec2(sin(t + r * 20.0) * 0.2, 0.0));
			col += mix(vec3(0.55), TOX, step(0.98, r)) * smoothstep(0.08, 0.02, d) * 0.5;
		}
	}

	// ---------- hazard tape across top and bottom corners ----------
	vec2 tp = vec2(q.x, y);
	float tape1 = abs((tp.y - 0.03) - (tp.x + res.x / H * 0.5) * -0.05);
	float tape2 = abs((tp.y - 0.975) - (tp.x - res.x / H * 0.5) * -0.04);
	for (int i = 0; i < 2; i++) {
		float d = i == 0 ? tape1 : tape2;
		if (d < 0.016) {
			float st = step(0.5, fract((q.x + q.y) * 18.0));
			vec3 tc = mix(vec3(0.85, 0.66, 0.12), vec3(0.04, 0.035, 0.03), st);
			float wear = smoothstep(0.62, 0.7, fbm(q * 30.0 + vec2(float(i) * 3.0)));
			tc = mix(tc, col, wear * 0.7);
			if (d > 0.014) tc *= 0.5;
			col = tc;
		}
	}

	// ---------- pipe gauge ----------
	vec2 gp = q - vec2(0.0, 0.885);
	float gw = 0.36;
	float gh = 0.026;
	float pipe = sd_box(gp, vec2(gw, gh)) - 0.006;
	float flange = min(sd_box(gp - vec2(-gw, 0.0), vec2(0.012, gh + 0.014)), sd_box(gp - vec2(gw, 0.0), vec2(0.012, gh + 0.014)));
	if (min(pipe, flange) < 0.0) {
		float n = fbm(q * 40.0);
		vec3 steel = mix(vec3(0.17, 0.2, 0.12), vec3(0.42, 0.2, 0.07), smoothstep(0.55, 0.7, n));
		steel *= 0.55 + 0.6 * (1.0 - abs(gp.y) / (gh + 0.014));
		// flange bolts
		for (int i = 0; i < 4; i++) {
			vec2 bp = vec2((i < 2 ? -gw : gw), (i % 2 == 0 ? -1.0 : 1.0) * (gh + 0.006));
			if (length(gp - bp) < 0.0045) steel = vec3(0.5, 0.5, 0.45);
		}
		vec3 c = steel;
		// glass window with sludge
		float wx0 = -gw + 0.02;
		float wx1 = gw - 0.02;
		if (gp.x > wx0 && gp.x < wx1 && abs(gp.y) < gh - 0.006) {
			float fx = (gp.x - wx0) / (wx1 - wx0);
			float gv = (gp.y + gh) / (2.0 * gh);
			vec3 g = vec3(0.02, 0.035, 0.025);
			float wob = sin(gp.y * 400.0 + t * 7.0) * 0.003;
			if (fx < progress + wob) {
				float sl = fbm(vec2(gp.x * 60.0 - t * 1.5, gp.y * 120.0));
				g = TOX * (0.7 + sl * 0.7) * (0.75 + 0.5 * sin(3.14159 * gv));
				vec2 bc = floor(vec2(gp.x * 160.0, 0.0));
				float bh = hash(bc);
				float by = gh - fract(t * (0.5 + bh) + bh * 3.0) * gh * 2.4;
				float bd = length(vec2(fract(gp.x * 160.0) - 0.5, (gp.y - by) * 160.0 * 0.5));
				g += vec3(0.9, 1.0, 0.8) * smoothstep(0.35, 0.15, bd) * step(0.55, bh) * 0.6;
				g += TOX * smoothstep(0.012, 0.0, abs(fx - progress - wob)) * 1.4;
			}
			if (abs(fract(fx * 10.0 + 0.5) - 0.5) < 0.004 && gv < 0.3) g = mix(g, vec3(0.8), 0.5);
			g += vec3(0.5, 0.6, 0.55) * exp(-pow((gv - 0.22) / 0.08, 2.0)) * 0.25;
			c = g;
		}
		col = c;
	}
	// radiation trefoil spinner at the left end
	vec2 rp = q - vec2(-gw - 0.055, 0.885);
	float rd = length(rp);
	if (rd < 0.038) {
		float a = atan(rp.y, rp.x) + t * 1.5;
		float blade = step(0.5, fract(a / 2.0944 + 0.25));
		vec3 rc = vec3(0.85, 0.66, 0.12);
		if (rd < 0.007 || (rd > 0.011 && rd < 0.031 && blade < 0.5)) rc = vec3(0.04, 0.035, 0.03);
		if (rd > 0.034) rc = vec3(0.05);
		col = rc * (0.85 + 0.25 * sin(t * 4.0));
	}
	col += TOX * exp(-rd * 30.0) * 0.15;

	// ---------- grade: vignette, grain, scan flicker ----------
	vec2 vuv = UV - 0.5;
	col *= 1.0 - dot(vuv, vuv) * 1.1;
	col += (hash(px + fract(t) * 100.0) - 0.5) * 0.04;
	col *= 0.97 + 0.03 * sin(px.y * 1.5 + t * 30.0);
	COLOR = vec4(col, 1.0);
}
"""
	return sh
