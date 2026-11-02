class_name Skills
extends RefCounted
# Skill trees. Each rank adds `fx` values that GameData.derived() sums up.
# Curse branches only accept points while you carry that curse.

const TREES := {
	"gunslinger": {name="GUNSLINGER", color=Color(1.0, 0.55, 0.25), desc="Recoil, handling, headshots."},
	"survivor": {name="SURVIVOR", color=Color(0.45, 0.9, 0.5), desc="Toughness, needs, stamina, cures."},
	"scavenger": {name="SCAVENGER", color=Color(0.4, 0.75, 1.0), desc="Carry, stealth, loot, vehicles, food."},
	"curse": {name="CURSE", color=Color(0.85, 0.25, 0.4), desc="Only while you carry a curse."},
}

const SKILLS := {
	# --- gunslinger ---
	"steady_hands": {tree="gunslinger", name="Steady Hands", max=5, desc="-7% recoil per rank.", fx={recoil=-0.07}},
	"quick_draw": {tree="gunslinger", name="Quick Draw", max=5, desc="+8% aim-down-sights and swap speed per rank.", fx={handling=0.08}},
	"deadeye": {tree="gunslinger", name="Deadeye", max=5, desc="+10% headshot damage per rank.", fx={headshot=0.1}},
	"deep_pockets": {tree="gunslinger", name="Deep Pockets", max=5, desc="+6% magazine size and +6% reload speed per rank.", fx={mag=0.06, reload=0.06}},
	"adrenaline": {tree="gunslinger", name="Adrenaline", max=5, desc="Kills give +5% move speed for 4s per rank.", fx={kill_rush=0.05}},
	"bullet_ballet": {tree="gunslinger", name="Bullet Ballet", max=3, desc="Sliding and jumping widen your spread 30% less per rank.", fx={air_spread=-0.3}},
	# --- survivor ---
	"iron_gut": {tree="survivor", name="Iron Gut", max=5, desc="-10% hunger/thirst drain and -15% poison chance per rank.", fx={needs=-0.1, poison=-0.15}},
	"thick_skin": {tree="survivor", name="Thick Skin", max=5, desc="+12 max HP and +3 warmth per rank.", fx={hp=12.0, warmth=3.0}},
	"second_wind": {tree="survivor", name="Second Wind", max=5, desc="Regenerate 0.3 HP/s per rank after 5s without damage.", fx={regen=0.3}},
	"cardio": {tree="survivor", name="Cardio", max=5, desc="+12% stamina and slide distance per rank.", fx={stamina=0.12}},
	"antibodies": {tree="survivor", name="Antibodies", max=5, desc="Curses and sickness progress 15% slower per rank.", fx={infection=-0.15}},
	"last_stand": {tree="survivor", name="Last Stand", max=1, desc="Once per day, a killing blow leaves you at 1 HP instead.", fx={last_stand=1.0}},
	# --- scavenger ---
	"pack_mule": {tree="scavenger", name="Pack Mule", max=5, desc="+6 kg carry capacity per rank.", fx={carry=6.0}},
	"light_step": {tree="scavenger", name="Light Step", max=5, desc="-10% noise from movement and gunfire per rank.", fx={noise=-0.1}},
	"lucky_find": {tree="scavenger", name="Lucky Find", max=5, desc="Better loot rarity per rank.", fx={luck=0.12}},
	"grease_monkey": {tree="scavenger", name="Grease Monkey", max=3, desc="Vehicles use 20% less fuel and take 20% less damage per rank.", fx={vehicle=0.2}},
	"camp_chef": {tree="scavenger", name="Camp Chef", max=3, desc="Cooked food and drinks are 20% stronger per rank.", fx={chef=0.2}},
	"silent_killer": {tree="scavenger", name="Silent Killer", max=5, desc="+6% melee damage and +0.6x stealth multiplier per rank.", fx={melee=0.06, stealth=0.6}},
	# --- curse branches ---
	"pack_hunter": {tree="curse", curse="wolf", name="Pack Hunter", max=3, desc="Wolf form: +15% damage and speed per rank.", fx={wolf_power=0.15}},
	"thick_hide": {tree="curse", curse="wolf", name="Thick Hide", max=3, desc="Wolf form: +12% damage resistance per rank.", fx={wolf_armor=0.12}},
	"blood_thirst": {tree="curse", curse="vampire", name="Blood Thirst", max=3, desc="Vampire: drain heals 30% more per rank.", fx={vamp_drain=0.3}},
	"night_walker": {tree="curse", curse="vampire", name="Night Walker", max=3, desc="Vampire: sunlight burns 25% less per rank.", fx={sun_resist=0.25}},
	"hollow_heart": {tree="curse", curse="rot", name="Hollow Heart", max=3, desc="Hollow: rot decay 25% slower per rank.", fx={rot_decay=-0.25}},
	"grave_strength": {tree="curse", curse="rot", name="Grave Strength", max=3, desc="Hollow: +15% melee damage per rank.", fx={melee=0.15}},
}

static func in_tree(tree: String) -> Array:
	var out := []
	for k in SKILLS:
		if SKILLS[k].tree == tree:
			out.append(k)
	return out
