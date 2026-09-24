-- Disaster Plants (Hanami). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.

local K = JJS.Kit

K.Character( "disasterplants", {
	name = "Disaster Plants",
	category = "complete",
	hp = 100,
	scale = 1.25,
	model = K.Model( "disasterplants", "models/player/charple.mdl" ),
	color = Color( 120, 220, 90 ),

	-- Arm Wrap: the string is a single 4 damage hit (extra range on uppercuts and downslams)
	m1 = { Count = 1, Damage = { 4 } },

	passives = {
		{ "Arm Wrap", "1.25x taller; the M1 string is a single 4 damage hit." },
		{ "Lasso", "The front dash becomes a 50 stud root grab (4, 10s cooldown). (TODO)" },
	},

	abilities = {
		-- A line of roots grows 50 studs along the ground, lifting anyone in the way (10); from 25-50 studs they're knocked back to the user.
		-- TODO variants: a root bridge over gaps; spikes at the Plant Guidance mark.
		[ 1 ] = K.Beam{ "Root Swarm", cooldown = 15, startup = 0.5, damage = 10, range = 50, radius = 4, pierce = true, maxPitch = 0.05,
			type = "swarm", block = "none", bypassRagdoll = true, color = "brown", ragdoll = { h = 30, v = 45 }, tip = "SPECIAL" },
		-- Two wooden balls sprout branches pushing targets within 35 studs back onto 3 thorns that toss them further (5 each).
		-- TODO special variant: a long thorn at the Plant Guidance mark (9, 12 on interruption).
		[ 2 ] = K.Target{ "Surging Thorns", cooldown = 16, teleport = false, range = 35, cone = 0.8, startup = 0.4, damage = 15, hits = 3,
			interval = 0.3, type = "bullet", color = "green", ragdoll = { h = 50, v = 30 }, tip = "SPECIAL" },
		-- Chucks two cursed buds 70 studs (4 each); they latch on and drain cursed energy until the target uses a skill.
		[ 3 ] = K.Projectile{ "Bud Shot", cooldown = 15, startup = 0.35, damage = 4, count = 2, volley = 0.15, spread = 6, range = 70, speed = 150,
			radius = 2.5, type = "bullet", bypassRagdoll = true, color = "green" },
		-- Reclines, then surges forward with melee i-frames into a heavy smack (evadable stun, doesn't cancel ragdoll).
		-- Air variant: a spike rises 25 studs away launching anyone above it (8 + 7). TODO special variant "Flower Patch".
		[ 4 ] = K.Melee{ "Defense Response", cooldown = 15, startup = 0.45, damage = 12, lunge = 12, type = "melee", block = "none", armor = "melee",
			ragdoll = { h = 45, v = 15 },
			air = { kind = "aoe", damage = 15, radius = 8, offset = 25, up = -10, type = "swarm", bypassRagdoll = true, ragdoll = { h = 5, v = 60 },
				color = "brown" } },
	},
	-- Marks the ground within 65 studs for special follow-ups of Root Swarm, Surging Thorns and Defense Response.
	special = K.Buff{ "Plant Guidance", cooldown = 0.5, startup = 0.1, duration = 0.1, color = "green" },

	awakening = {
		name = "Unwrap",
		duration = 60,
		heal = 25,
		-- "It would seem that... I should take you somewhat seriously." The wrap comes off and five spikes rise behind them.
		-- TODO passive "Unwrap": the normal 4 hit M1 string (3 + 3 + 4 + 4); front dash becomes Defense Response's smack.
		abilities = {
			-- A steerable line of tangible roots for 7s crashing into anyone in its path (5 per hit). Perfect-blockable.
			-- TODO: steering, extra roots when empowered. Air variant "Thorn Rampage" (25).
			[ 1 ] = K.Beam{ "Root Rampage", cooldown = 16, startup = 0.6, damage = 25, duration = 2, tick = 0.4, range = 60, radius = 4, pierce = true,
				maxPitch = 0.3, type = "bullet", block = "pre", bypassRagdoll = true, color = "brown", ragdoll = { h = 40, v = 25 } },
			-- A 20x20 stud field of flowers: anyone acting inside (other than blocking or dashing) is interrupted (6).
			[ 2 ] = K.Zone{ "Flower Field", cooldown = 16, startup = 0.5, radius = 10, offset = 20, duration = 6, tick = 0.5, damage = 1.5, stun = 0.4,
				type = "swarm", block = "none", bypassRagdoll = true, color = "pink" },
			-- A massive flower ragdolls nearby opponents (8) then shoots 15 cursed buds like a turret (1.7 each).
			[ 3 ] = K.Projectile{ "Cursed Buds", cooldown = 16, startup = 0.8, damage = 2.2, count = 15, volley = 0.1, spread = 3, range = 90, speed = 170,
				radius = 2.5, type = "bullet", blockDamage = 1.1, bypassRagdoll = true, color = "green" },
			-- Domain Expansion: any action other than running, side dashing or blocking is interrupted and punished (4) with "daze".
			[ 4 ] = K.Domain{ "Shining Sea of Growing Branches", cooldown = 120, duration = 15, sureHit = "damage", dps = 3, color = "green" },
		},
		-- Stores cursed energy in the flower arm (empowered: the next move is strengthened). Costs 5% awakening.
		-- Follow-up "Flower Beam": pressed again while empowered, a devastating beam (35.6; 104 after the domain). Beam clash rank 2.
		special = K.Buff{ "Energy Absorb", cooldown = 12, startup = 0.2, duration = 0.3, awakenCost = 0.05, color = "gold", tip = "USE AGAIN",
			again = K.Beam{ "Flower Beam", window = 10, startup = 1, damage = 35.6, duration = 1, tick = 0.25, range = 120, radius = 6, pierce = true,
				clash = 2, type = "explosion", block = "none", bypassRagdoll = true, color = "gold", ragdoll = { h = 60, v = 25 } } },
	},
} )
