-- Monkey Kid. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "monkeykid", {
	name = "Monkey Kid",
	category = "op",
	hp = 100,
	model = K.Model( "monkeykid", "models/player/group01/male_06.mdl" ),
	color = Color( 255, 160, 40 ),

	passives = {
		{ "Child Of The Clouds", "When initiating a forward dash while airborne, the Flying Nimbus will swoop in under the user and enable them to fly in the air before dissipating away." },
	},

	abilities = {
		-- The user concentrates their Ki into their hands before releasing forwards it as a massive focused energy beam.
		[ 1 ] = K.Beam{ "Kamehameha", cooldown = 10, damage = 20, block = "none", bypassRagdoll = true, color = "white" },
		-- Using their Power Pole, the user uptilts the enemy with so much strength that they are propelled towards the sky.
		-- TODO special variant: By using the special right after launching a target, the user will appear before them to land a quick hit followed by a slam towards the...
		[ 2 ] = K.Melee{ "Staff Uppercut", cooldown = 12, damage = 10, type = "melee", bypassRagdoll = true, ragdoll = true, tip = "SPECIAL" },
		-- By extending their staff forwards, the user performs a smack on the enemy that slides them away.
		-- Air variant: If used while mid air, the user will instead slam their staff vertically to the floor, alongside anyone positioned near them.
		[ 3 ] = K.Melee{ "Staff Extend", cooldown = 15, damage = 15, type = "melee", block = "none", air = { bypassRagdoll = true } },
		-- The user unleashes two ki blasts forwards, with each blast ragdolling the opponent.
		[ 4 ] = K.Melee{ "Ki Spam", cooldown = 12, damage = 49, type = "melee", block = "none", bypassRagdoll = true, ragdoll = true },
	},
	-- The user phases forwards for a short duration, moving so fast that they completely disappear from sight.
	special = K.Buff{ "Instant Transmission", cooldown = 1 },

	awakening = {
		name = "Monkey",
		duration = 60,
		heal = 15,
		-- When initiating the Awakening, the Power Pole slips from the user's back as their small frame expands.
		-- TODO passive "Monkey": While in their Oozaru form, the user gains several passives due to the 5x increase in their size and 10x power level: *Their first and last basic...
	},
} )
