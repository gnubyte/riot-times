extends Node
# Item database: weapon classes with handling stats, melee, armor, consumables, cures,
# materials. Weapons/armor are rolled INSTANCES with rarity, level and perks
# (Borderlands-style), stackables are plain {id, count} entries.

const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [Color(0.86, 0.86, 0.84), Color(0.35, 0.92, 0.38), Color(0.3, 0.6, 1.0), Color(0.72, 0.38, 1.0), Color(1.0, 0.6, 0.12)]
const RARITY_DMG := [1.0, 1.1, 1.22, 1.36, 1.5]
const RARITY_ARMOR := [1.0, 1.12, 1.26, 1.42, 1.6]
const RARITY_PERKS := [0, 1, 1, 2, 2]

# ---------------- guns ----------------
# spread/recoil in degrees, times in seconds, ranges in meters, ads_zoom = FOV divisor
const WEAPONS := {
	"pistol": {name="Rattler 9", ammo="ammo_9mm", mag=15, dmg=24.0, rpm=420.0, mode="semi", pellets=1,
		hip=1.7, ads_spread=0.25, bloom=0.45, bloom_max=3.5, rv=1.25, rh=0.5, rec=12.0, perm=0.25,
		ads_time=0.15, swap=0.3, reload=1.3, reload_empty=1.55, r0=22.0, r1=50.0, fall=0.6, head=2.0,
		weight=1.1, ads_zoom=1.2, move_mul=1.0, noise=55.0, s2f=0.1, shake=0.12, kick=0.6, value=90,
		desc="Reliable sidearm. Quick in the hand, kind to the wrists."},
	"revolver": {name="Hand Cannon .44", ammo="ammo_44", mag=6, dmg=64.0, rpm=150.0, mode="semi", pellets=1,
		hip=2.2, ads_spread=0.18, bloom=1.2, bloom_max=4.5, rv=4.4, rh=1.1, rec=9.0, perm=0.35,
		ads_time=0.19, swap=0.36, reload=2.1, reload_empty=2.1, r0=28.0, r1=60.0, fall=0.55, head=2.2,
		weight=1.6, ads_zoom=1.25, move_mul=0.97, noise=72.0, s2f=0.12, shake=0.38, kick=1.5, value=160,
		desc="Six reasons to stop. Each one is loud."},
	"smg": {name="Buzzbox SMG", ammo="ammo_9mm", mag=32, dmg=17.0, rpm=860.0, mode="auto", pellets=1,
		hip=2.3, ads_spread=0.75, bloom=0.2, bloom_max=4.0, rv=0.5, rh=0.42, rec=14.0, perm=0.28,
		ads_time=0.17, swap=0.3, reload=1.6, reload_empty=2.0, r0=15.0, r1=35.0, fall=0.5, head=1.6,
		weight=2.6, ads_zoom=1.2, move_mul=1.0, noise=55.0, s2f=0.12, shake=0.07, kick=0.32, value=180,
		desc="Welded together from rebar and prayer. Sprays like a firehose."},
	"ar": {name="Scrap AR", ammo="ammo_556", mag=30, dmg=25.0, rpm=640.0, mode="auto", pellets=1,
		hip=3.0, ads_spread=0.32, bloom=0.24, bloom_max=4.5, rv=0.82, rh=0.38, rec=11.0, perm=0.3,
		ads_time=0.22, swap=0.4, reload=1.9, reload_empty=2.35, r0=35.0, r1=80.0, fall=0.65, head=1.8,
		weight=3.6, ads_zoom=1.4, move_mul=0.94, noise=75.0, s2f=0.2, shake=0.11, kick=0.5, value=260,
		desc="The wasteland's workhorse. Controllable, punchy, everywhere."},
	"shotgun": {name="Boomstick", ammo="ammo_12g", mag=6, dmg=13.0, rpm=72.0, mode="pump", pellets=9,
		hip=5.2, ads_spread=3.8, bloom=0.0, bloom_max=0.0, rv=5.2, rh=1.2, rec=8.0, perm=0.3,
		ads_time=0.21, swap=0.4, reload=0.52, reload_empty=0.52, shell_reload=true, r0=8.0, r1=22.0, fall=0.25, head=1.5,
		weight=3.4, ads_zoom=1.15, move_mul=0.95, noise=80.0, s2f=0.18, shake=0.55, kick=1.9, value=220,
		desc="Pump it, point it, redecorate."},
	"dmr": {name="Marksman DMR", ammo="ammo_308", mag=12, dmg=58.0, rpm=270.0, mode="semi", pellets=1,
		hip=4.0, ads_spread=0.06, bloom=0.8, bloom_max=4.0, rv=2.1, rh=0.55, rec=10.0, perm=0.3,
		ads_time=0.27, swap=0.45, reload=2.2, reload_empty=2.6, r0=60.0, r1=140.0, fall=0.75, head=2.2,
		weight=4.2, ads_zoom=2.0, move_mul=0.9, noise=85.0, s2f=0.24, shake=0.24, kick=1.0, value=380,
		desc="Semi-auto precision. Rewards a steady hand."},
	"sniper": {name="Longshot", ammo="ammo_308", mag=5, dmg=135.0, rpm=46.0, mode="bolt", pellets=1,
		hip=6.0, ads_spread=0.0, bloom=0.0, bloom_max=0.0, rv=6.0, rh=0.8, rec=7.0, perm=0.3,
		ads_time=0.37, swap=0.55, reload=2.8, reload_empty=3.1, r0=100.0, r1=250.0, fall=0.85, head=2.5,
		weight=5.5, ads_zoom=4.0, scope=true, move_mul=0.86, noise=100.0, s2f=0.3, shake=0.5, kick=2.0, value=520,
		desc="Bolt-action. One breath, one heartbeat, one less problem."},
	"lmg": {name="Chainsaw LMG", ammo="ammo_556", mag=80, dmg=24.0, rpm=720.0, mode="auto", pellets=1,
		hip=4.0, ads_spread=0.6, bloom=0.18, bloom_max=5.0, rv=0.68, rh=0.6, rec=10.0, perm=0.35,
		ads_time=0.35, swap=0.6, reload=4.0, reload_empty=4.6, r0=35.0, r1=80.0, fall=0.65, head=1.6,
		weight=8.0, ads_zoom=1.35, move_mul=0.82, noise=85.0, s2f=0.32, shake=0.13, kick=0.45, value=480,
		desc="Eighty rounds of argument. Heavy as sin."},
	"crossbow": {name="Whisper Crossbow", ammo="bolts", mag=1, dmg=115.0, rpm=60.0, mode="semi", pellets=1,
		projectile=true, speed=72.0, hip=1.4, ads_spread=0.0, bloom=0.0, bloom_max=0.0, rv=1.5, rh=0.3, rec=9.0, perm=0.2,
		ads_time=0.24, swap=0.42, reload=1.15, reload_empty=1.15, r0=40.0, r1=90.0, fall=0.8, head=2.5,
		weight=2.8, ads_zoom=1.6, move_mul=0.96, noise=5.0, s2f=0.2, shake=0.18, kick=0.8, value=300,
		desc="Silent. The dead never hear it coming. Bolts can be recovered."},
}

const MELEE := {
	"fists": {name="Fists", dmg=16.0, time=0.42, hit_at=0.32, reach=1.9, radius=0.5, cleave=1, knock=2.5, noise=3.0, stamina=6.0, stealth=2.0, weight=0.0, value=0},
	"knife": {name="Combat Knife", dmg=38.0, time=0.36, hit_at=0.3, reach=2.0, radius=0.45, cleave=1, knock=1.5, noise=3.0, stamina=6.0, stealth=4.0, weight=0.4, value=40},
	"machete": {name="Machete", dmg=52.0, time=0.5, hit_at=0.35, reach=2.3, radius=0.75, cleave=2, knock=3.0, noise=4.0, stamina=9.0, stealth=3.0, weight=0.9, value=70},
	"wrench": {name="Pipe Wrench", dmg=46.0, time=0.55, hit_at=0.38, reach=2.2, radius=0.6, cleave=1, knock=4.5, noise=5.0, stamina=9.0, stealth=2.5, weight=1.4, value=45},
	"bat": {name="Nail Bat", dmg=58.0, time=0.62, hit_at=0.4, reach=2.5, radius=0.8, cleave=2, knock=6.5, noise=5.0, stamina=11.0, stealth=2.5, weight=1.2, value=60},
	"axe": {name="Fire Axe", dmg=88.0, time=0.8, hit_at=0.45, reach=2.5, radius=0.8, cleave=2, knock=5.0, noise=6.0, stamina=14.0, stealth=3.0, weight=2.4, value=110},
	"sledge": {name="Sledgehammer", dmg=125.0, time=1.05, hit_at=0.5, reach=2.7, radius=1.1, cleave=3, knock=11.0, noise=8.0, stamina=20.0, stealth=2.0, weight=6.0, value=150},
	# transformation weapons (never dropped)
	"claws": {name="Wolf Claws", dmg=72.0, time=0.3, hit_at=0.18, reach=2.6, radius=0.9, cleave=2, knock=5.0, noise=4.0, stamina=4.0, stealth=2.0, weight=0.0, value=0, form=true},
	"vamp_claws": {name="Talons", dmg=55.0, time=0.32, hit_at=0.2, reach=2.4, radius=0.7, cleave=1, knock=3.0, noise=2.0, stamina=4.0, stealth=4.0, drain=0.35, weight=0.0, value=0, form=true},
	"rot_fists": {name="Rotten Fists", dmg=62.0, time=0.5, hit_at=0.32, reach=2.2, radius=0.8, cleave=2, knock=6.0, noise=3.0, stamina=3.0, stealth=2.0, weight=0.0, value=0, form=true},
}

const PERKS := {
	"hushed": {prefix="Hushed", desc="Suppressed: 75% quieter, -5% damage."},
	"extended": {prefix="Hungry", desc="+40% magazine size."},
	"quick": {prefix="Snappy", desc="25% faster reloads."},
	"stable": {prefix="Steady", desc="30% less recoil."},
	"light": {prefix="Featherweight", desc="Faster aim & swap, 40% lighter."},
	"brutal": {prefix="Brutal", desc="+15% damage."},
	"leech": {prefix="Leeching", desc="Heal 4% of damage dealt."},
	"fire": {prefix="Blazing", desc="Sets targets on fire. Vampires burn faster."},
	"silver": {prefix="Silvered", desc="Silver: double damage to werewolves."},
	"keen": {prefix="Keen", desc="+50% headshot damage."},
	"rapid": {prefix="Twitchy", desc="+15% fire rate."},
}
const GUN_ONLY_PERKS := ["hushed", "extended", "quick", "stable", "keen", "rapid"]

const LEGENDARY := {
	"pistol": {name="Last Word", perk="last_word", desc="The final round in the magazine deals triple damage."},
	"revolver": {name="Sunday Sermon", perk="sermon", desc="Headshots ricochet into the nearest enemy."},
	"smg": {name="Hornet Nest", perk="hornet", desc="+20% fire rate. Every hit heals you a little."},
	"ar": {name="Graveshaker", perk="explosive", desc="Rounds explode on impact."},
	"shotgun": {name="Meat Grinder", perk="grinder", desc="+4 pellets. Sets everything ablaze."},
	"dmr": {name="Widowmaker", perk="pierce", desc="Rounds punch through every body in a line."},
	"sniper": {name="Moonshot", perk="moonshot", desc="Silver rounds that pierce. Werewolves fear it."},
	"lmg": {name="Chainsaw Choir", perk="choir", desc="Double magazine. Fire rate climbs while you hold the trigger."},
	"crossbow": {name="Stake Driver", perk="stake", desc="Triple damage to vampires. Bolts explode on the undead."},
	"knife": {name="Fang", perk="fang", desc="Heals on every hit. Stealth kills are silent and lethal."},
	"machete": {name="Moonlight Edge", perk="silver_blade", desc="Silver blade. Werewolves bleed."},
	"bat": {name="Homerun Derby", perk="homerun", desc="Absurd knockback. Sends them flying."},
	"axe": {name="Widow's Kiss", perk="cleaver", desc="Cleaves through every enemy in the arc."},
	"sledge": {name="Earthquake", perk="quake", desc="Every swing sends out a shockwave."},
	"wrench": {name="Grease Lightning", perk="sparks", desc="Electrified: stuns on hit."},
}

# ---------------- everything else ----------------
const ITEMS := {
	# ammo (weight per round)
	"ammo_9mm": {type="ammo", name="9mm Rounds", weight=0.008, value=1, stack=300, desc="Pistol & SMG ammunition."},
	"ammo_44": {type="ammo", name=".44 Magnum", weight=0.02, value=3, stack=120, desc="Revolver rounds."},
	"ammo_556": {type="ammo", name="5.56 Rounds", weight=0.012, value=2, stack=300, desc="Rifle & LMG ammunition."},
	"ammo_12g": {type="ammo", name="12 Gauge Shells", weight=0.04, value=3, stack=80, desc="Buckshot."},
	"ammo_308": {type="ammo", name=".308 Rounds", weight=0.025, value=4, stack=120, desc="Marksman & sniper rounds."},
	"bolts": {type="ammo", name="Crossbow Bolts", weight=0.07, value=4, stack=40, desc="Recoverable if they don't break."},
	# food
	"beans": {type="food", name="Canned Beans", weight=0.4, value=8, stack=10, hunger=30.0, thirst=-2.0, desc="Mostly bean. Probably."},
	"jerky": {type="food", name="Jerky Strips", weight=0.2, value=10, stack=10, hunger=22.0, thirst=-4.0, desc="Salty. Chewy. Don't ask."},
	"mre": {type="food", name="Military MRE", weight=0.6, value=30, stack=6, hunger=55.0, thirst=8.0, hp=5.0, desc="Meal, Ready to Eat. Barely."},
	"chips": {type="food", name="Crunch Chips", weight=0.15, value=6, stack=10, hunger=14.0, thirst=-5.0, desc="Stale since the end of the world."},
	"apple": {type="food", name="Wild Apple", weight=0.2, value=4, stack=10, hunger=12.0, thirst=6.0, desc="Small, sour, real."},
	"berries": {type="food", name="Pinewood Berries", weight=0.1, value=3, stack=20, hunger=7.0, thirst=4.0, desc="Probably not poisonous."},
	"raw_meat": {type="food", name="Raw Meat", weight=0.5, value=5, stack=10, hunger=20.0, poison=0.35, raw=true, blood=12.0, desc="Cook it. Seriously."},
	"cooked_meat": {type="food", name="Grilled Steak", weight=0.4, value=18, stack=10, hunger=45.0, hp=6.0, desc="Smoky. Almost civilized."},
	"raw_fish": {type="food", name="Raw Fish", weight=0.4, value=4, stack=10, hunger=15.0, poison=0.25, raw=true, desc="Still twitching."},
	"cooked_fish": {type="food", name="Fire-Roasted Fish", weight=0.3, value=14, stack=10, hunger=36.0, hp=6.0, desc="Flaky and warm."},
	"glow_carp": {type="food", name="Glowing Carp", weight=0.6, value=45, stack=5, hunger=20.0, poison=0.6, raw=true, rads=25.0, desc="Rare catch. Traders pay well. Don't eat it raw."},
	"stew": {type="food", name="Wasteland Stew", weight=0.7, value=35, stack=5, hunger=60.0, thirst=20.0, hp=12.0, warm=2.0, desc="Hot, thick, restorative."},
	# drinks
	"dirty_water": {type="drink", name="Dirty Water", weight=0.5, value=2, stack=10, thirst=30.0, poison=0.3, desc="Boil it first."},
	"clean_water": {type="drink", name="Clean Water", weight=0.5, value=10, stack=10, thirst=45.0, desc="Boiled. Safe. Precious."},
	"soda": {type="drink", name="Fizz Bomb Cola", weight=0.4, value=14, stack=10, thirst=25.0, hunger=5.0, stamina=40.0, desc="Still fizzy. Gives you a jolt."},
	"pine_tea": {type="drink", name="Pine Needle Tea", weight=0.4, value=12, stack=10, thirst=30.0, warm=2.5, desc="Bitter, hot, keeps the cold out."},
	"blood_pack": {type="drink", name="Blood Pack", weight=0.4, value=40, stack=6, blood=45.0, desc="Hospital surplus. Only a vampire would want it."},
	# medicine
	"bandage": {type="med", name="Bandage", weight=0.1, value=12, stack=10, hp=28.0, use_time=1.5, desc="Wrap it tight."},
	"medkit": {type="med", name="Field Medkit", weight=0.6, value=60, stack=4, hp=75.0, use_time=3.0, desc="Everything a body needs. Takes a moment."},
	"painkillers": {type="med", name="Painkillers", weight=0.05, value=25, stack=10, hp=10.0, buff="tough", use_time=0.8, desc="25% damage resistance for 30s."},
	"antibiotics": {type="med", name="Antibiotics", weight=0.05, value=40, stack=10, cure="poison", rot_slow=15.0, use_time=0.8, desc="Cures food poisoning and slows the Rot."},
	"rad_flush": {type="med", name="Rad-Flush", weight=0.2, value=45, stack=6, rads=-60.0, use_time=1.2, desc="Flushes radiation. Tastes like a battery."},
	# cures
	"antiviral": {type="cure", name="Antiviral Shot", weight=0.05, value=180, stack=4, cure="rot", use_time=1.0, desc="Stops the Rot before it takes you."},
	"lazarus": {type="cure", name="Lazarus Serum", weight=0.1, value=600, stack=2, cure="rot_turned", use_time=2.0, desc="Black-site miracle. Brings the Hollow back to life."},
	"silverleaf_tincture": {type="cure", name="Silverleaf Tincture", weight=0.1, value=260, stack=4, cure="wolf", use_time=1.5, desc="Bitter silver tonic. Burns the wolf out of your blood."},
	"sanguine_serum": {type="cure", name="Sanguine Serum", weight=0.1, value=320, stack=4, cure="vampire", use_time=1.5, desc="Restores mortal blood. The sun stops hurting."},
	# throwables
	"frag": {type="throwable", name="Frag Grenade", weight=0.4, value=40, stack=6, desc="Pull pin. Count to two. Throw."},
	"molotov": {type="throwable", name="Molotov", weight=0.6, value=25, stack=6, desc="Fire puddle. Vampires hate it."},
	"noisemaker": {type="throwable", name="Noisemaker", weight=0.3, value=20, stack=6, desc="Beeps to lure the dead, then pops."},
	# materials
	"scrap": {type="material", name="Scrap Metal", weight=0.5, value=3, stack=50, desc="Workbench currency."},
	"cloth": {type="material", name="Cloth", weight=0.15, value=2, stack=50, desc="Rags, mostly."},
	"weapon_parts": {type="material", name="Weapon Parts", weight=0.4, value=15, stack=30, desc="Springs, pins, barrels. Upgrades gear."},
	"silverleaf": {type="material", name="Silverleaf Herb", weight=0.05, value=40, stack=20, desc="Pale glowing herb from Pinewood. Brew it into a tincture."},
	"pine_needles": {type="material", name="Pine Needles", weight=0.05, value=1, stack=40, desc="Brew with clean water for a warming tea."},
	"fuel_can": {type="material", name="Jerry Can", weight=4.0, value=35, stack=4, fuel=40.0, desc="40 units of fuel. Engines are loud."},
	# tools
	"fishing_rod": {type="tool", name="Fishing Rod", weight=1.2, value=30, stack=1, desc="Face the lake and interact to cast."},
	"campfire_kit": {type="tool", name="Campfire Kit", weight=2.0, value=20, stack=3, desc="Use to build a campfire: warmth, light, cooking."},
	# valuables
	"gold_ring": {type="valuable", name="Gold Ring", weight=0.02, value=60, stack=20, desc="Somebody loved somebody."},
	"old_watch": {type="valuable", name="Pocket Watch", weight=0.1, value=45, stack=10, desc="Stopped at 9:41."},
	"vinyl": {type="valuable", name="Vinyl Record", weight=0.3, value=30, stack=10, desc="'Songs for the End Times'."},
	"shards": {type="currency", name="Glowshards", weight=0.0, value=1, stack=999999, desc="Irradiated glass slivers. The wasteland trusts what glows."},
	# lore / quest
	"note_g9": {type="note", name="Specimen G-9 File", weight=0.0, value=0, stack=1, desc="BLACK SITE HALBERD — G-9 'THE GAUNT'. Blind. Hearing acute beyond measure. Speed on all fours exceeds 40 km/h. Containment holds only while the facility stays SILENT. Do not run. Do not fire. Do not scream."},
	"note_mall": {type="note", name="Torn Flyer", weight=0.0, value=0, stack=1, desc="GALLERIA UNDER — GRAND RE-OPENING! 60 stores, neon food court, fountain atrium. Service level closed until further notice (strange noises reported)."},
	"note_wolf": {type="note", name="Hunter's Journal", weight=0.0, value=0, stack=1, desc="Silverleaf grows near the lake, glows pale at dusk. Brew it with clean water at a fire. It's the only thing that stopped Pa from changing."},
}

# armor & backpacks (rolled with rarity + level)
const ARMOR := {
	"beanie": {slot="head", name="Knit Beanie", armor=0.0, warmth=6.0, weight=0.1, value=15},
	"hood": {slot="head", name="Deep Hood", armor=2.0, warmth=4.0, sun=true, weight=0.3, value=40},
	"scrap_helmet": {slot="head", name="Scrap Helmet", armor=9.0, warmth=1.0, weight=1.4, value=55},
	"military_helmet": {slot="head", name="Military Helmet", armor=16.0, warmth=1.0, weight=1.6, value=140},
	"gas_mask": {slot="head", name="Gas Mask", armor=3.0, warmth=2.0, gas=true, weight=0.8, value=120},
	"jacket": {slot="body", name="Denim Jacket", armor=4.0, warmth=10.0, weight=1.2, value=30},
	"parka": {slot="body", name="Winter Parka", armor=3.0, warmth=20.0, weight=2.2, value=70},
	"leather": {slot="body", name="Road Leathers", armor=12.0, warmth=6.0, weight=3.0, value=90},
	"scrap_armor": {slot="body", name="Scrapskin Plate", armor=21.0, warmth=3.0, weight=7.5, value=160},
	"riot_armor": {slot="body", name="Riot Armor", armor=29.0, warmth=4.0, weight=10.0, value=260},
	"military_vest": {slot="body", name="Plate Carrier", armor=25.0, warmth=2.0, weight=6.0, value=240},
	"satchel": {slot="back", name="Satchel", carry=10.0, weight=0.5, value=25},
	"hiking_pack": {slot="back", name="Hiking Pack", carry=22.0, weight=1.2, value=80},
	"military_pack": {slot="back", name="Military Rucksack", carry=36.0, weight=1.8, value=180},
}

# ---------------- loot ----------------
const POOLS := {
	"@food": [["beans", 4], ["jerky", 3], ["chips", 3], ["mre", 1]],
	"@drink": [["clean_water", 3], ["dirty_water", 4], ["soda", 2]],
	"@med": [["bandage", 6], ["medkit", 1.2], ["painkillers", 2], ["antibiotics", 1.5], ["rad_flush", 1]],
	"@throwable": [["frag", 2], ["molotov", 2], ["noisemaker", 2]],
	"@valuable": [["gold_ring", 1], ["old_watch", 2], ["vinyl", 3]],
	"@cure": [["antiviral", 3], ["silverleaf_tincture", 2], ["sanguine_serum", 2], ["lazarus", 0.4]],
	"@material": [["scrap", 5], ["cloth", 4], ["weapon_parts", 1.5]],
}
const AMMO_PACK := {"ammo_9mm": [18, 40], "ammo_44": [6, 14], "ammo_556": [20, 45], "ammo_12g": [5, 12], "ammo_308": [5, 12], "bolts": [3, 8]}
const ARMOR_WARM := ["beanie", "parka", "jacket", "hood"]

const TABLES := {
	"crate": [["@food", 1, 2, 0.45], ["@drink", 1, 1, 0.35], ["@ammo", 1, 1, 0.45], ["scrap", 1, 4, 0.4], ["@med", 1, 1, 0.25], ["@melee", 1, 1, 0.07], ["@weapon", 1, 1, 0.06], ["shards", 4, 18, 0.5]],
	"locker": [["@armor", 1, 1, 0.3], ["@ammo", 1, 2, 0.45], ["@med", 1, 1, 0.3], ["@weapon", 1, 1, 0.12], ["cloth", 1, 3, 0.3], ["@backpack", 1, 1, 0.08], ["shards", 5, 25, 0.5]],
	"fridge": [["@food", 1, 3, 0.75], ["@drink", 1, 2, 0.6], ["raw_meat", 1, 2, 0.2]],
	"dumpster": [["scrap", 1, 5, 0.6], ["cloth", 1, 3, 0.4], ["@food", 1, 1, 0.2], ["@drink", 1, 1, 0.2], ["@melee", 1, 1, 0.1], ["@valuable", 1, 1, 0.15], ["campfire_kit", 1, 1, 0.08]],
	"car_trunk": [["fuel_can", 1, 1, 0.3], ["scrap", 1, 4, 0.5], ["@ammo", 1, 1, 0.3], ["@throwable", 1, 1, 0.15], ["@weapon", 1, 1, 0.05], ["@valuable", 1, 1, 0.2]],
	"weapons": [["@weapon", 1, 2, 0.9], ["@ammo", 2, 3, 0.95], ["@throwable", 1, 2, 0.35], ["weapon_parts", 1, 3, 0.4], ["@melee", 1, 1, 0.2]],
	"military": [["@weapon", 1, 1, 0.75], ["@ammo", 2, 3, 0.95], ["@throwable", 1, 2, 0.5], ["@armor", 1, 1, 0.3], ["mre", 1, 2, 0.45], ["@med", 1, 2, 0.45], ["weapon_parts", 1, 4, 0.5]],
	"pharmacy": [["@med", 2, 4, 0.95], ["antibiotics", 1, 2, 0.4], ["antiviral", 1, 1, 0.12], ["rad_flush", 1, 1, 0.3], ["blood_pack", 1, 1, 0.12]],
	"clothing": [["@armor", 1, 2, 0.75], ["@backpack", 1, 1, 0.35], ["cloth", 2, 6, 0.6]],
	"supermarket": [["@food", 2, 4, 0.95], ["@drink", 1, 3, 0.8], ["campfire_kit", 1, 1, 0.12]],
	"register": [["shards", 10, 40, 0.9], ["@valuable", 1, 1, 0.35]],
	"toolbox": [["scrap", 2, 6, 0.8], ["weapon_parts", 1, 3, 0.5], ["fuel_can", 1, 1, 0.15], ["campfire_kit", 1, 1, 0.2], ["@melee", 1, 1, 0.12]],
	"lab": [["@cure", 1, 1, 0.6], ["@med", 1, 2, 0.6], ["weapon_parts", 1, 3, 0.3], ["blood_pack", 1, 2, 0.25]],
	"raider": [["@weapon", 1, 1, 0.6], ["@ammo", 1, 3, 0.85], ["shards", 15, 60, 0.85], ["@valuable", 1, 2, 0.4], ["@throwable", 1, 2, 0.4], ["@melee", 1, 1, 0.2]],
	"ammo_box": [["@ammo", 2, 3, 1.0], ["@throwable", 1, 1, 0.2]],
	"cabin": [["@food", 1, 2, 0.5], ["@drink", 1, 1, 0.4], ["@armor", 1, 1, 0.2], ["@ammo", 1, 1, 0.3], ["fishing_rod", 1, 1, 0.15], ["pine_needles", 2, 5, 0.3], ["note_wolf", 1, 1, 0.15]],
}

var _uid_counter := 1
var icon_cache := {}

# ---------------- lookups ----------------
func get_def(id: String) -> Dictionary:
	if WEAPONS.has(id):
		var d: Dictionary = WEAPONS[id].duplicate()
		d["type"] = "weapon"
		d["stack"] = 1
		return d
	if MELEE.has(id):
		var m: Dictionary = MELEE[id].duplicate()
		m["type"] = "melee"
		m["stack"] = 1
		return m
	if ARMOR.has(id):
		var a: Dictionary = ARMOR[id].duplicate()
		a["type"] = "armor"
		a["stack"] = 1
		return a
	return ITEMS.get(id, {})

func exists(id: String) -> bool:
	return WEAPONS.has(id) or MELEE.has(id) or ARMOR.has(id) or ITEMS.has(id)

func item_type(id: String) -> String:
	return get_def(id).get("type", "junk")

func is_unique(id: String) -> bool:
	var t := item_type(id)
	return t == "weapon" or t == "melee" or t == "armor"

func rarity_color(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, 4)]

func display_name(e) -> String:
	var id: String = e if e is String else String(e.get("id", ""))
	var def := get_def(id)
	var base: String = def.get("name", id)
	if e is Dictionary and is_unique(id):
		var r := int(e.get("rarity", 0))
		if r >= 4 and LEGENDARY.has(id):
			return LEGENDARY[id].name
		var perks: Array = e.get("perks", [])
		if perks.size() > 0 and PERKS.has(perks[0]):
			return "%s %s" % [PERKS[perks[0]].prefix, base]
	return base

func weight_of(e: Dictionary) -> float:
	var id: String = e.get("id", "")
	var w := float(get_def(id).get("weight", 0.0))
	if "light" in e.get("perks", []):
		w *= 0.6
	return w * int(e.get("count", 1))

func value_of(e: Dictionary) -> int:
	var id: String = e.get("id", "")
	var v := float(get_def(id).get("value", 1))
	if is_unique(id):
		v *= (1.0 + int(e.get("rarity", 0)) * 0.6) * (1.0 + int(e.get("level", 1)) * 0.08)
	return int(v)

func new_uid() -> int:
	_uid_counter += 1
	return int(Time.get_unix_time_from_system()) % 100000 * 1000 + _uid_counter

# ---------------- rolling ----------------
func roll_rarity(level: int, luck := 0.0, min_r := 0) -> int:
	var w := [100.0, 42.0, 16.0, 5.0, 1.2]
	for i in range(1, 5):
		w[i] *= (1.0 + level * 0.07 * i) * (1.0 + luck * i)
	var total := 0.0
	for i in range(min_r, 5):
		total += w[i]
	var roll := randf() * total
	for i in range(min_r, 5):
		roll -= w[i]
		if roll <= 0.0:
			return i
	return min_r

func _roll_perks(id: String, rarity: int, gun: bool) -> Array:
	var out := []
	if rarity >= 4 and LEGENDARY.has(id):
		out.append(LEGENDARY[id].perk)
	var pool := PERKS.keys()
	if not gun:
		pool = pool.filter(func(p): return not (p in GUN_ONLY_PERKS))
	pool.shuffle()
	for i in RARITY_PERKS[clampi(rarity, 0, 4)]:
		if i < pool.size():
			out.append(pool[i])
	# legendary keeps its signature effect first so the name/desc lead with it
	return out

func roll_weapon(cls: String, level: int, rarity := -1) -> Dictionary:
	if cls == "":
		cls = random_weapon_class(level)
	var r := rarity if rarity >= 0 else roll_rarity(level)
	var inst := {"id": cls, "count": 1, "uid": new_uid(), "rarity": r, "level": maxi(1, level),
		"perks": _roll_perks(cls, r, true), "ammo": 0}
	inst["ammo"] = int(weapon_stats(inst).mag)
	return inst

func roll_melee(cls: String, level: int, rarity := -1) -> Dictionary:
	if cls == "":
		cls = ["knife", "machete", "wrench", "bat", "axe", "sledge"][randi() % 6]
	var r := rarity if rarity >= 0 else roll_rarity(level)
	return {"id": cls, "count": 1, "uid": new_uid(), "rarity": r, "level": maxi(1, level), "perks": _roll_perks(cls, r, false)}

func roll_armor(cls: String, level: int, rarity := -1) -> Dictionary:
	if cls == "":
		var keys := ARMOR.keys().filter(func(k): return ARMOR[k].slot != "back")
		cls = keys[randi() % keys.size()]
	var r := rarity if rarity >= 0 else roll_rarity(level)
	return {"id": cls, "count": 1, "uid": new_uid(), "rarity": r, "level": maxi(1, level), "perks": []}

func random_weapon_class(level: int) -> String:
	var pool := [["pistol", 10], ["revolver", 5], ["smg", 8], ["shotgun", 7], ["ar", 7], ["crossbow", 4]]
	if level >= 4:
		pool.append_array([["dmr", 4], ["lmg", 2]])
	if level >= 7:
		pool.append_array([["sniper", 3], ["ar", 3], ["lmg", 2]])
	return _weighted(pool)

func _weighted(pool: Array) -> String:
	var total := 0.0
	for p in pool:
		total += float(p[1])
	var roll := randf() * total
	for p in pool:
		roll -= float(p[1])
		if roll <= 0.0:
			return p[0]
	return pool[0][0]

# Roll a container. `owned_ammo` biases ammo drops toward guns the player carries.
func roll_container(kind: String, level: int, luck := 0.0, owned_ammo: Array = []) -> Array:
	var out := []
	var rows: Array = TABLES.get(kind, TABLES["crate"])
	for row in rows:
		var id: String = row[0]
		var cmin: int = row[1]
		var cmax: int = row[2]
		if randf() > float(row[3]) * (1.0 + luck * 0.5):
			continue
		var n := randi_range(cmin, cmax)
		var reps := n if id.begins_with("@") else 1
		for i in reps:
			out.append_array(_roll_entry(id, n, level, luck, owned_ammo))
	return out

func _roll_entry(id: String, n: int, level: int, luck: float, owned_ammo: Array) -> Array:
	var lvl := clampi(level + randi_range(-1, 1), 1, 30)
	match id:
		"@weapon":
			return [roll_weapon("", lvl, roll_rarity(lvl, luck))]
		"@melee":
			return [roll_melee("", lvl, roll_rarity(lvl, luck))]
		"@armor":
			return [roll_armor("", lvl, roll_rarity(lvl, luck))]
		"@backpack":
			var bp := "satchel"
			if lvl >= 4 and randf() < 0.5: bp = "hiking_pack"
			if lvl >= 9 and randf() < 0.35: bp = "military_pack"
			return [roll_armor(bp, lvl, roll_rarity(lvl, luck))]
		"@ammo":
			var aid: String
			if not owned_ammo.is_empty() and randf() < 0.7:
				aid = owned_ammo[randi() % owned_ammo.size()]
			else:
				var keys := AMMO_PACK.keys()
				aid = keys[randi() % keys.size()]
			var rng: Array = AMMO_PACK[aid]
			return [{"id": aid, "count": randi_range(rng[0], rng[1])}]
		_:
			if POOLS.has(id):
				return [{"id": _weighted(POOLS[id]), "count": 1}]
			return [{"id": id, "count": n}]

# ---------------- resolved stats ----------------
func weapon_stats(e: Dictionary) -> Dictionary:
	var id: String = e.get("id", "pistol")
	var s: Dictionary = WEAPONS.get(id, WEAPONS["pistol"]).duplicate()
	var lvl := int(e.get("level", 1))
	var r := clampi(int(e.get("rarity", 0)), 0, 4)
	s["dmg"] = float(s.dmg) * RARITY_DMG[r] * (1.0 + 0.07 * (lvl - 1))
	s["element"] = ""
	s["leech"] = 0.0
	s["explosive"] = false
	s["pierce"] = false
	for p in e.get("perks", []):
		match p:
			"hushed": s.noise = float(s.noise) * 0.25; s.dmg *= 0.95; s["suppressed"] = true
			"extended": s.mag = int(ceil(float(s.mag) * 1.4))
			"quick": s.reload = float(s.reload) * 0.75; s.reload_empty = float(s.reload_empty) * 0.75
			"stable": s.rv = float(s.rv) * 0.7; s.rh = float(s.rh) * 0.7
			"light": s.ads_time = float(s.ads_time) * 0.8; s.swap = float(s.swap) * 0.8; s.weight = float(s.weight) * 0.6
			"brutal": s.dmg *= 1.15
			"leech": s.leech = 0.04
			"fire": s.element = "fire"
			"silver": s.element = "silver"
			"keen": s.head = float(s.head) + 0.5
			"rapid": s.rpm = float(s.rpm) * 1.15
			"hornet": s.rpm = float(s.rpm) * 1.2; s.leech = 0.06
			"explosive": s.explosive = true
			"grinder": s.pellets = int(s.pellets) + 4; s.element = "fire"
			"pierce": s.pierce = true
			"moonshot": s.pierce = true; s.element = "silver"
			"choir": s.mag = int(s.mag) * 2
			"stake": s["stake"] = true
			"last_word": s["last_word"] = true
			"sermon": s["sermon"] = true
	return s

func melee_stats(e: Dictionary) -> Dictionary:
	var id: String = e.get("id", "fists")
	var s: Dictionary = MELEE.get(id, MELEE["fists"]).duplicate()
	var lvl := int(e.get("level", 1))
	var r := clampi(int(e.get("rarity", 0)), 0, 4)
	if not s.get("form", false):
		s["dmg"] = float(s.dmg) * RARITY_DMG[r] * (1.0 + 0.07 * (lvl - 1))
	s["element"] = ""
	s["leech"] = float(s.get("drain", 0.0))
	for p in e.get("perks", []):
		match p:
			"brutal": s.dmg *= 1.15
			"leech": s.leech += 0.05
			"fire": s.element = "fire"
			"silver", "silver_blade": s.element = "silver"
			"light": s.time = float(s.time) * 0.85; s.weight = float(s.weight) * 0.6
			"fang": s.leech += 0.12; s.stealth = float(s.stealth) + 3.0; s.noise = 0.0
			"homerun": s.knock = float(s.knock) * 3.0
			"cleaver": s.cleave = 6
			"quake": s["quake"] = true
			"sparks": s["stun"] = true
	return s

func armor_stats(e: Dictionary) -> Dictionary:
	var id: String = e.get("id", "")
	var s: Dictionary = ARMOR.get(id, {}).duplicate()
	if s.is_empty():
		return s
	var lvl := int(e.get("level", 1))
	var r := clampi(int(e.get("rarity", 0)), 0, 4)
	s["armor"] = float(s.get("armor", 0.0)) * RARITY_ARMOR[r] * (1.0 + 0.06 * (lvl - 1))
	s["warmth"] = float(s.get("warmth", 0.0)) * (1.0 + r * 0.1)
	s["carry"] = float(s.get("carry", 0.0)) * (1.0 + r * 0.12)
	return s

func describe(e: Dictionary) -> String:
	var id: String = e.get("id", "")
	var def := get_def(id)
	var lines: PackedStringArray = []
	var t: String = def.get("type", "")
	if t == "weapon":
		var s := weapon_stats(e)
		lines.append("%s · Lv %d · %s" % [RARITY_NAMES[int(e.get("rarity", 0))], int(e.get("level", 1)), def.name])
		var pel := (" x%d" % int(s.pellets)) if int(s.pellets) > 1 else ""
		lines.append("Damage %.0f%s   Rate %d rpm   Mag %d" % [s.dmg, pel, int(s.rpm), int(s.mag)])
		lines.append("Recoil %.1f   Aim %.2fs   Reload %.1fs   %s" % [float(s.rv) + float(s.rh) * 0.5, s.ads_time, s.reload, get_def(s.ammo).get("name", "")])
		lines.append("Noise %dm%s" % [int(s.noise), "  (suppressed)" if s.get("suppressed", false) else ""])
	elif t == "melee":
		var m := melee_stats(e)
		lines.append("%s · Lv %d · %s" % [RARITY_NAMES[int(e.get("rarity", 0))], int(e.get("level", 1)), def.name])
		lines.append("Damage %.0f   Swing %.2fs   Hits up to %d   Stealth x%.1f" % [m.dmg, m.time, int(m.cleave), m.stealth])
	elif t == "armor":
		var a := armor_stats(e)
		lines.append("%s · Lv %d · %s (%s)" % [RARITY_NAMES[int(e.get("rarity", 0))], int(e.get("level", 1)), def.name, String(def.slot).to_upper()])
		if a.get("carry", 0.0) > 0.0:
			lines.append("Carry +%.0f kg" % a.carry)
		else:
			lines.append("Armor %.0f   Warmth +%.0f" % [a.armor, a.warmth])
		if a.get("gas", false): lines.append("Filters toxic gas.")
		if a.get("sun", false): lines.append("Shields a vampire from the sun.")
	else:
		lines.append(def.get("name", id))
	for p in e.get("perks", []):
		if PERKS.has(p):
			lines.append("• %s: %s" % [PERKS[p].prefix, PERKS[p].desc])
		else:
			for k in LEGENDARY:
				if LEGENDARY[k].perk == p:
					lines.append("★ %s" % LEGENDARY[k].desc)
					break
	var d: String = def.get("desc", "")
	if d != "":
		lines.append(d)
	lines.append("Weight %.2f kg   Value %d" % [weight_of(e), value_of(e)])
	return "\n".join(lines)

# ---------------- procedural icons ----------------
# Icons are hand-authored pixel art painted by IconArt (outline, shading,
# riveted backplate) and cached here.
func icon(e) -> Texture2D:
	var id: String = e if e is String else String(e.get("id", ""))
	if icon_cache.has(id):
		return icon_cache[id]
	var tex := IconArt.icon(id)
	icon_cache[id] = tex
	return tex
