-- Monkey Kid (overpowered). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.

local K = JJS.Kit

K.Character( "monkeykid", {
	name = "Monkey Kid",
	category = "op",
	hp = 100,
	scale = 0.8,
	model = K.Model( "monkeykid", "models/player/group01/male_06.mdl" ),
	color = Color( 255, 160, 40 ),

	passives = {
		{ "Child Of The Clouds", "0.8x size, a staff, longer front dashes; an airborne front dash rides the Flying Nimbus. (partly TODO)" },
	},

	abilities = {
		-- Concentrates Ki and releases a massive focused beam (360 aim; airborne it suspends the user).
		[ 1 ] = K.Beam{ "Kamehameha", cooldown = 10, startup = 0.9, damage = 20, duration = 0.8, tick = 0.2, range = 110, radius = 5, pierce = true,
			maxPitch = 1, type = "special", block = "none", bypassRagdoll = true, color = "blue", ragdoll = { h = 60, v = 25 } },
		-- The Power Pole uptilts the enemy into the sky; disables ragdoll cancel.
		-- TODO special variant: appears before them for a hit and a slam down (4 + 4).
		[ 2 ] = K.Melee{ "Staff Uppercut", cooldown = 12, startup = 0.35, damage = 10, reach = 9, type = "melee", bypassRagdoll = true, trueRag = true,
			ragdoll = { h = 5, v = 80 }, tip = "SPECIAL" },
		-- Extends the staff forward, smacking the enemy away. Air/hold variant: slams it down and can ride it upward.
		[ 3 ] = K.Melee{ "Staff Extend", cooldown = 15, startup = 0.4, damage = 15, reach = 22, width = 4, type = "melee", block = "none",
			ragdoll = { h = 70, v = 8 } },
		-- Two ki blasts, each ragdolling (1 each). Holding lengthens the barrage up to 49 blasts, less accurate over time.
		[ 4 ] = K.Projectile{ "Ki Spam", cooldown = 12, startup = 0.25, damage = 1, count = 2, volley = 0.12, spread = 3, range = 80, speed = 220,
			radius = 2.5, type = "special", block = "none", bypassRagdoll = true, ragdoll = { h = 20, v = 10, time = 0.4 }, color = "gold",
			hold = { time = 0.4, count = 24, volley = 0.07, spread = 6 } },
	},
	-- Phases forward so fast they vanish; no stun or endlag.
	special = K.Mobility{ "Instant Transmission", cooldown = 1, startup = 0, travel = 25, time = 0.15, endlag = 0, iframes = 0.15, dir = "aim" },

	awakening = {
		name = "Monkey",
		duration = 60,
		heal = 15,
		scale = 3, -- 5x in the game; kept at 3x for normal maps
		-- The Power Pole slips as the small frame expands into an Oozaru that roars.
		-- TODO passive "Monkey": M1s deal 10, are unblockable and ragdoll; the front dash is a hop and slam (20).
	},
} )
