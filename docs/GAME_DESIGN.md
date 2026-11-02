# RIOT TIMES — Game Design

> A first-person survival looter-shooter. Fallout's wasteland mood, Borderlands' lunatic
> raiders and loot, Mad Max's scrap vehicles, DayZ/Unturned's zombie open world, and
> gunplay that is meant to feel as good as Call of Duty or Fortnite on a controller.
> The world is mean, death is permanent, and the night belongs to the monsters.

---

## 1. Pillars

1. **Gunfeel first.** Every shot has recoil, sound, flash, shake, a hit marker and a damage
   number. Aiming is easy on a pad (aim assist, ADS snap, look acceleration), but there is
   still skill in recoil control, headshots and movement.
2. **Greed vs. survival.** The best loot is where the danger is: underground, at night,
   behind noise. Every expedition is a bet: one more store, or get home before dark?
3. **Noise is a resource.** Gunshots, sprinting, engines and horns are heard. Zombies come.
   Hordes come. Something worse comes on all fours. Melee, crossbows and suppressors buy silence.
4. **One life, a lasting world.** Your survivor dies for good. The world remembers: your body
   stays where you fell with everything you carried, and if you died cursed, it gets back up.
5. **Curses are a playstyle, not just a fail state.** A wolf bite, a vampire's kiss, the Rot:
   each one changes how you play until you cure it, or decide not to.

---

## 2. The Core Loop

```
          ┌──────────────── HAVEN (safe zone) ────────────────┐
          │ eat · cook · sleep · trade · upgrade gear · quest │
          └───────────────┬───────────────────▲───────────────┘
                 gear up, pick a goal         │ extract, bank the loot
                          ▼                   │
   DRIVE OUT ─► SCOUT ─► FIGHT/SNEAK ─► LOOT ─► (weight? daylight? noise?) ─► GET HOME
                 ▲                                  │
                 └──── hordes, the Gaunt, nightfall ◄┘
```

### 30 seconds: the fight
Sprint, slide behind a car, mantle onto a bus, ADS and drop three runners with headshots.
Damage numbers pop, the last kill gets a heavy hit marker and a beat of hit-stop. Reload,
swap to the shotgun as the brute closes, melee the crawler at your feet. Every gunshot was
heard for 60 m.

### 5 minutes: the room
Clear a store in the neon mall. Loot shelves (rarity-colored beams show what's worth it).
Check the weight bar. Eat. Decide whether to push to the next store or back out while the
noise you made draws the mall in.

### 30–60 minutes: the expedition
Take a Haven bounty ("Clear the pharmacy", "Silver Lining", "Specimen G-9"), check the clock
(night is coming), drive out. Park the buggy away from the target, because engines are loud.
Raid the Point of Interest. Survive the sudden horde rush that always comes once you feel
comfortable. Drive home over the bodies, bank the haul, cook, sleep through the night or go
out into it on purpose, because night loot is better.

### Session: the build
Level ups give skill points in three trees (Gunslinger, Survivor, Scavenger). Workbench
upgrades push your favorite gun's level up. Haven grows. Every third night is a **Siege**:
the horde comes for the walls and you defend them.

### Life: permadeath
When you die:
- The survivor is gone: name, level and skills go onto the **Memorial** wall.
- Your body stays where you died as a **Grave** with everything you carried.
- If you died **cursed** (Rot, Wolf, Vampire), you rise as a **Revenant**: a named, buffed
  version of your old self that guards your gear. Your new survivor has to kill you to get it back.
- Haven, its stash and its upgrades survive. So does what you learned.

That's the hook: *"My level-14 vampire died in the mall food court with a Legendary Moonshot.
My new level-1 mechanic is going to go get it."*

---

## 3. Gunplay & Movement

| System | Behavior |
|---|---|
| **Recoil** | Per-weapon pattern: vertical kick + horizontal drift + random jitter. ~70% recovers on a spring; ~30% stays as climb you pull down. Visual kick, roll and slide on the viewmodel. |
| **Handling** | ADS time, swap time, sprint-to-fire, reload (tactical vs. empty), sway (idle, move, cold-shiver), move speed while aiming. |
| **Spread** | Hip spread + per-shot bloom (Fortnite-style) shown by the dynamic crosshair. ADS nearly removes it. Moving and jumping widen it. |
| **Damage** | Falloff by range, headshot multiplier per class, crits shown as big yellow numbers. Level and rarity scale damage. |
| **Feedback** | Muzzle flash light, tracers, shells with physics, impact sparks/blood, hit marker (white/orange headshot/red kill), kill chime, hit-stop on heavy kills, trauma-based screen shake, FOV punch, controller rumble. |
| **Melee** | Dedicated button, any weapon. Swing arcs hit multiple targets on heavy weapons. Silent; triple damage on unaware targets. |
| **Throwables** | Frag, Molotov, Noisemaker (beeps to lure hordes, then explodes). |
| **Movement** | Sprint, slide (crouch while sprinting; momentum carries into slide-jumps), crouch, jump, mantle/vault, landing dip. Encumbrance slows you and blocks sprinting. |

### Controller (Xbox layout)
| Input | Action | Input | Action |
|---|---|---|---|
| LS / L3 | Move / Sprint (toggle) | RS / R3 | Look / Melee |
| LT / RT | Aim / Fire | LB / RB | Quick heal / Throw |
| A | Jump, mantle | B | Crouch, slide |
| X | Reload (tap) · Interact (hold) | Y | Swap weapon |
| D-pad ↑ | Flashlight / headlights | D-pad ↓ | Cycle throwable |
| View | Inventory/Skills/Quests | Menu | Pause |

**Aim assist** (pad only, toggleable): slowdown near targets, rotational tracking while
strafing, ADS snap to the nearest target in a cone, head bias when the reticle is close to a head.
**Look curve:** radial deadzone, exponential response, edge acceleration for fast 180s.

### Keyboard & mouse
WASD · Shift sprint · Space jump · C/Ctrl crouch/slide · LMB/RMB fire/aim · R reload ·
E interact · V/Mouse4 melee · 1/2/wheel swap · G throw · H heal · F light · Tab menus · Esc pause

---

## 4. Weapons & Loot

Classes: **Pistol, Revolver, SMG, Assault Rifle, Shotgun, DMR, Sniper, LMG, Crossbow** (silent
projectile). Melee: Knife, Machete, Nail Bat, Fire Axe, Sledgehammer.

**Rarity:** Common (white), Uncommon (green), Rare (blue), Epic (purple), Legendary (orange).
Higher rarity means more damage and more perks. Every item has a **level** (zone-scaled); the
workbench can raise it.

**Perks** (rolled, shown as name prefixes): Hushed (suppressed), Hungry (extended mag),
Snappy (fast reload), Steady (low recoil), Featherweight, Brutal, Leeching, Blazing (fire,
vampires hate it), Silvered (werewolves hate it), Keen (headshots), Twitchy (fire rate).
**Legendaries** have a unique effect: *Graveshaker* (explosive rounds), *Moonshot* (silver,
pierces), *Stake Driver* (vampire slayer), *Meat Grinder*, *Hornet Nest*, *Last Word*,
*Sunday Sermon*, *Chainsaw Choir*, *Widowmaker*.

Loot drops are physics objects with rarity-colored light beams.

---

## 5. Enemies

| Enemy | Role |
|---|---|
| **Walker** | Slow, comes in numbers, grabs. |
| **Runner** | Sprints, the backbone of horde rushes. |
| **Brute** | Armored tank, heavy swings, knockback. |
| **Screamer** | Screams on sight and calls everything within 70 m. Kill it first. |
| **Bloater** | Explodes into a toxic cloud that spreads the Rot. Gas mask counters it. |
| **Goliath** | 4 m boss zombie. Ground slam, thrown debris. Lives in the mall atrium. |
| **The Gaunt** | SCP-style specimen: a giant pale thing that sprints on all fours toward **noise**. Blind. Stay quiet, stay crouched, stay out of its way. Lives in the Halberd lab and the mall sub-level; roams downtown at night. |
| **Werewolf** | Forest, at night. Fast, leaping. Bite → Lycanthropy. Weak to silver. |
| **Vampire** | Downtown and the mall, at night. Dash, life-drain. Bite → Vampirism. Weak to fire and stakes. |
| **Scrapjaws** | Borderlands-style raider gang. Gunners strafe and shoot; Psychos charge screaming with buzzaxes; King Gnasher runs the camp. They fight zombies too. |
| **Wildlife** | Mutant boar and deer: food for cooking. |

**Director:** keeps a population budget around the player, scales by time of day and zone,
and fires events:
- **Horde Rush**: once you've been calm for a while, a scream, then 20–40 zombies from one direction.
- **Siege**: every third night a horde hits Haven's walls. Guards on towers help.
- **Nightfall**: wolves, vampires and the Gaunt come out; density up, temperature down.

---

## 6. Survival

| Need | Effect |
|---|---|
| **Hunger / Thirst** | Drain over time (faster when sprinting/hot). Low = slower stamina, then damage. |
| **Temperature** | Body temp moves toward felt temperature: time of day, underground, water, fires, clothing warmth. Cold makes aim shake, then hypothermia. Heat burns thirst. |
| **Weight** | Every item has weight (ammo too). Over capacity = slower, no sprint, louder. Backpacks and skills raise capacity. |
| **Sickness** | Raw meat and dirty water can poison you. Antibiotics cure it. |
| **Radiation** | Hot zones near the crater and the lab. Rad-Flush clears it. |

**Cooking** at campfires and Haven's stove: raw meat/fish → cooked, dirty → clean water,
stew, pine tea (warms you). **Fishing** at the lake: cast, wait for the bite, react in time.

---

## 7. Curses (getting turned)

| Curse | Caught from | While incubating | Turned form | Cure |
|---|---|---|---|---|
| **The Rot** | Zombie bites, bloater gas | Fever, coughing, max HP drops | **Hollow**: zombies ignore you, huge melee and toughness, melee only, you slowly rot unless you eat raw meat | Antiviral (before turning) · Lazarus Serum (after) |
| **Lycanthropy** | Werewolf bites | Hunger spikes, vision flickers at night | **Wolf** (forced at night): claws, speed, leaps, regen; no guns; ravenous | Silverleaf Tincture (forest herb + clean water) |
| **Vampirism** | Vampire bites | Sun sensitivity grows | **Vampire**: sun burns (hoods/indoors protect), night vision, strength and drain-heal at night; normal food does nothing; you feed on blood | Sanguine Serum (Halberd lab) |

Each curse unlocks a fourth skill branch while you carry it.

---

## 8. Progression

- **Level 1–30.** XP from kills (headshots and melee pay more), looting, discovering places,
  bounties, cooking and crafting.
- **Skill trees** (1–5 ranks each):
  - *Gunslinger*: Steady Hands, Quick Draw, Deadeye, Deep Pockets (mag), Adrenaline, Bullet Ballet
  - *Survivor*: Iron Gut, Thick Skin, Second Wind, Cardio, Antibodies, Last Stand
  - *Scavenger*: Pack Mule, Light Step, Lucky Find, Grease Monkey, Camp Chef, Silent Killer
- **Backgrounds** (pick per life): Soldier, Medic, Mechanic, Hunter, Drifter. Each has a
  different kit and a small edge, so every new life plays differently.

---

## 9. World

| Place | Level | What's there |
|---|---|---|
| **Haven** | 1 | Walled safe zone: trader, workbench, stove, stash, bed, bounty board, guards, your buggy. Gets sieged. |
| **Downtown Plaza** | 3–6 | Wrecked skyscrapers (some leaning, some you can climb into), bus barricades, neon signs. Vampires at night. |
| **The Galleria (underground mall)** | 6–10 | Neon-lit dead mall under the plaza: stores, food court, atrium fountain, supermarket, pharmacy, gun store. Resource-rich and packed with zombies of every type. The Goliath. A sub-level where something crawls. |
| **Camp Halberd + Black Site** | 10–14 | Military base, then an underground lab: red emergency light, broken containment, the Gaunt, the best gear and the cures. |
| **Pinewood (forest & lake)** | 2–8 | Cabins, fishing, silverleaf, deer and boar. Werewolves at night. |
| **Scrapjaw Yard** | 5–9 | Raider camp of scrap walls, burning barrels, towers. King Gnasher. |
| **The Highway** | – | Wrecks, a gas station, fuel cans, and nowhere to hide from a horde. |

Day/night cycle: about 20 minutes per day. Night is colder, darker and louder with monsters,
and its loot tables are better.

---

## 10. Tech notes (Godot 4.7)

- Everything is procedural: meshes, textures, normal maps, sounds. No imported assets yet.
  This keeps iteration fast. Swapping in real models and audio later is a content task, not a rewrite.
- Static world geometry is **batched per material** into merged meshes to keep draw calls low.
- AI paths on per-region baked navmeshes (Haven, downtown/mall, base, camp); open ground
  uses direct steering. Far AI is frozen; the director despawns stragglers.
- Persistence: `user://rt_world.json` (memorial, graves, Haven, stash, day) and
  `user://rt_survivor.json` (deleted on death). Autosaves on a timer, so no save-scumming.
- Dev switches: `RT_DEBUG_AUTOSTART=1`, `RT_DEBUG_GOD=1`, `RT_DEBUG_SPAWN=<poi>`,
  `RT_DEBUG_FPS=1`, `RT_DEBUG_SHOTS=1` (auto screenshots to `user://shots/`).

---

## 11. Build status

See the table at the end of `README.md` for what is playable in the current build and what
is next.
