-- Vessel (Yuji Itadori). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.

local K = JJS.Kit

K.Character( "vessel", {
	name = "Vessel",
	category = "complete",
	hp = 85,
	model = K.Model( "vessel", "models/player/group01/male_03.mdl" ),
	color = Color( 255, 110, 110 ),

	abilities = {
		-- Slides forward with glowing eyes; on grab: punches (1.75 each) and a kick (3). Blockable from all sides.
		-- Air variant: a cursed-energy dropkick toward the ground (14, unblockable).
		[ 1 ] = K.Grab{ "Cursed Strikes", cooldown = 14, damage = 17.5, hits = 7, interval = 0.18, lunge = 14, type = "melee", block = "all",
			armor = "bullet", ragdoll = { h = 40, v = 18 },
			air = { kind = "melee", damage = 14, hits = 1, block = "none", bypassRagdoll = true, lunge = 10, height = 20 } },
		-- Charges cursed energy and slams the floor twice (6 each) with a shockwave (3).
		-- Air variant: dashes across the air, grabs the enemy and performs the same attack.
		[ 2 ] = K.Melee{ "Crushing Blow", cooldown = 15, startup = 0.45, damage = 12, hits = 2, interval = 0.35, type = "melee", block = "none",
			bypassRagdoll = true, crater = 900, ragdoll = { h = 6, v = -20 }, air = { lunge = 16 } },
		-- A decent blow followed by delayed cursed energy that launches the opponent back.
		-- Follow-up "Black Flash": pressed again as the body flashes white, the punch becomes a Black Flash (10, 20 on interruption).
		-- TODO interruption variant: the delayed impact stuns anyone it interrupts (5). Variant "Black Flash Chain".
		[ 3 ] = K.Melee{ "Divergent Fist", cooldown = 18, startup = 0.35, damage = 10, hits = 2, interval = 0.3, type = "melee", blockDamage = 5,
			ragdoll = { h = 45, v = 16 }, tip = "HIT",
			again = K.Melee{ "Black Flash", window = 0.6, tip = "USE TWICE", damage = 10, type = "melee", block = "none", startup = 0.15,
				color = "black", ragdoll = { h = 60, v = 20 } } },
		-- Counter stance: a melee or bullet attack is evaded and answered with a kick.
		[ 4 ] = K.Counter{ "Manji Kick", cooldown = 20, window = 0.6, counters = { melee = "counter", bullet = "counter" }, riposte = 8.5 },
	},
	-- During an M1 or a skill's windup (not Manji Kick): cancels it with no endlag and keeps the move off cooldown. Costs 3% awakening.
	-- TODO special variant: near a throwable, punches it forward (15).
	special = K.Feint{ "Combat Instincts", cooldown = 2, awakenCost = 0.03 },

	awakening = {
		name = "King of Curses",
		duration = 60,
		heal = 45,
		-- The user faints as Sukuna takes over: "You're such an annoying brat."
		-- TODO passive "Shrine": M1s become slashes reaching 24 studs, blockable from all sides; no uppercuts or downslams.
		abilities = {
			-- Dismantle: a barrage of slashes on the opponent in front (10 if blocked).
			-- Air variant: a flip into a long Dismantle slash (25, unblockable).
			-- TODO variant "World Cutting Slash": Rush during Dismantle's windup, then Open, then Cleave (80).
			[ 1 ] = K.Projectile{ "Dismantle", cooldown = 13, startup = 0.35, damage = 17.5, blockDamage = 10, range = 30, speed = 220, radius = 4,
				type = "bullet", block = "all", bypassRagdoll = true, color = "red",
				air = { damage = 25, blockDamage = false, block = "none", type = "explosion", explode = 10 } },
			-- Fire gathered into an arrow and shot forward.
			[ 2 ] = K.Projectile{ "Open", cooldown = 40, startup = 1.2, damage = 30, range = 110, speed = 170, radius = 5, type = "explosion",
				block = "none", bypassRagdoll = true, uninterruptible = true, explode = 16, color = "orange", crater = 1600,
				ragdoll = { h = 60, v = 30 } },
			-- Rushes forward in a straight line: impact (5), kick (15), slam (5).
			[ 3 ] = K.Melee{ "Rush", cooldown = 15, damage = 25, hits = 3, interval = 0.3, lunge = 30, startup = 0.35, type = "melee",
				block = "none", ragdoll = { h = 10, v = -25 }, crater = 900 },
			-- Domain Expansion: constant slashes on everyone inside (2 per slash, 0.5 if blocked) for 18s.
			[ 4 ] = K.Domain{ "Malevolent Shrine", cooldown = 120, duration = 18, sureHit = "damage", dps = 12, color = "red" },
		},
		-- Grabs forward and cleaves: 40% of the target's HP, minimum 10.
		special = K.Grab{ "Cleave", cooldown = 12, damage = 10, hits = 2, interval = 0.3, type = "melee", block = "none", ragdoll = { h = 30, v = 20 } },
	},
} )
