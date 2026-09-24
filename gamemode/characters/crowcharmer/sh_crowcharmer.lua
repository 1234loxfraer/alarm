-- Crow Charmer (Mei Mei, base-only). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.

local K = JJS.Kit

K.Character( "crowcharmer", {
	name = "Crow Charmer",
	category = "baseonly",
	hp = 100,
	model = K.Model( "crowcharmer", "models/player/alyx.mdl" ),
	color = Color( 90, 90, 120 ),

	-- Fly High: uppercuts send targets nearly twice as high
	m1 = {
		-- per-hit M1 frames { startup, recovery, block endlag } (dogslamloop)
		Frames = { { 14, 5, 11 }, { 14, 5, 11 }, { 14, 5, 11 } },
		Final = {
			[ 0 ] = { h = 50 * JJS.STUD, v = 24 * JJS.STUD, ragdoll = 0.8 },
			[ 1 ] = { h = 8 * JJS.STUD, v = 130 * JJS.STUD, ragdoll = 0.8 },
			[ 2 ] = { h = 6 * JJS.STUD, v = -80 * JJS.STUD, ragdoll = 1.0 },
		},
	},

	passives = {
		{ "Fly High", "Battle axe: uppercuts launch nearly twice as high, but M1s can't hit airborne ragdolls." },
		{ "Flock", "An aerial front dash: a hop kicking the opponent up (5, 10s cooldown). (TODO)" },
		{ "Bounding", "Front dashing near an airborne ragdoll uses them as footing (3). (TODO)" },
	},

	abilities = {
		-- A vertical axe swing knocking the target into the air (major endlag on miss).
		-- Follow-up: pressed twice, two extra swings toss the opponent away (3 each).
		-- Air variant "Air Updraft": suspended midair, a long sweep launching targets away (14).
		[ 1 ] = K.Melee{ "Impetus Updraft", cooldown = 16, startup = 0.35, endlag = 0.5, damage = 11, reach = 9, type = "melee", bypassRagdoll = true,
			ragdoll = { h = 5, v = 60 }, tip = "USE TWICE",
			air = { damage = 14, width = 12, ragdoll = { h = 60, v = 20 } },
			again = K.Melee{ "Impetus Updraft: Extra Swings", window = 0.8, startup = 0.2, damage = 6, hits = 2, interval = 0.25, reach = 9, type = "melee",
				bypassRagdoll = true, ragdoll = { h = 55, v = 20 } } },
		-- Madly spinning, two long forward swings (6, then 8 launching afar).
		-- Hold: after ~0.3s the second swing becomes unblockable. Air variant "Dive Bomb": grab (6) and a crushing slam (4, +height).
		[ 2 ] = K.Melee{ "Circling", cooldown = 18, startup = 0.4, damage = 14, hits = 2, interval = 0.35, reach = 11, width = 12, type = "melee",
			bypassRagdoll = true, ragdoll = { h = 70, v = 20 },
			hold = { time = 0.3, block = "none" },
			air = { kind = "grab", damage = 10, hits = 2, interval = 0.6, ragdoll = { h = 5, v = -40 } } },
		-- Throws the spinning axe around the user like a disk before it returns; anything in the way is launched up (9, then 5).
		-- High air variant "Free Fall": a heavy overhead smash from 30 studs up (12).
		[ 3 ] = K.Zone{ "Murmurate", cooldown = 16, startup = 0.3, radius = 14, duration = 1.6, tick = 0.8, damage = 7, follow = true, type = "melee",
			bypassRagdoll = true, trueRag = true, ragdoll = { h = 10, v = 45 }, color = "white" },
		-- Calls a crow: standing still it glides the user for 2.5s; walking forward at a target within 35 studs it crashes into them (6);
		-- walking backward it slams them down (8).
		-- TODO: the direction variants (only the forward crow is in).
		[ 4 ] = K.Target{ "Bird Control", cooldown = 18, teleport = false, range = 35, startup = 0.4, damage = 6, type = "bullet", block = "all",
			ragdoll = { h = 5, v = 40 }, color = "black", tip = "DIRECTION" },
	},
	-- The younger sibling teleports the user 20 studs in the walking direction (15 up when still, to the ground when high up).
	special = K.Mobility{ "Spatial Transference", cooldown = 18, startup = 0.2, travel = 20, time = 0.08, dir = "forward", color = "white" },

	-- Takes control of a crow and guides it anywhere; its binding vow makes it explode (75 around, 115 on a direct hit). Heals 25 on hit.
	awakenMove = K.Summon{ "Bird Strike", startup = 0.8, damage = 75, speed = 120, range = 250, radius = 4, type = "explosion", block = "none",
		bypassRagdoll = true, uninterruptible = true, explode = 14, heal = 25, crater = 2000, ragdoll = { h = 60, v = 40 }, color = "black" },
} )
