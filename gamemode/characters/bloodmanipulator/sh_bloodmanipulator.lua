-- Blood Manipulator. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "bloodmanipulator", {
	name = "Blood Manipulator",
	category = "complete",
	hp = 100,
	model = K.Model( "bloodmanipulator", "models/player/group03/male_04.mdl" ),
	color = Color( 200, 30, 50 ),

	abilities = {
		-- The user claps their hands together to trap blood and fire it as an uncounterable thin beam with 30 studs of range.
		-- Hold variant: If the user has a Convergence orb, then holding down the skill for exactly 1.35 seconds or longer will use it up to strengthen the blood...
		[ 1 ] = K.Beam{ "Piercing Blood", cooldown = 15, damage = 12, bypassRagdoll = true, range = 30, color = "white", tip = "HOLD", hold = { time = 1.35, damage = 20, block = "none", trueRag = true } },
		-- The user in dashes forward a short distance after increasing their body's performance using their technique.
		-- TODO special variant "Flowing Red Scale: Stack": If a Convergence orb is available, the user will use it up to end their combo by amplifying the final kick with a blood explosion,...
		-- Air variant: When this move is instead used while the user is airborne, the user will perform a downwards axe kick, ragdolling the target upwards.
		-- TODO air special variant "Flowing Red Scale: Stack": If a Convergence orb is available, the user will place a blood mine right underneath them, which will remain static and intangible.
		[ 2 ] = K.Melee{ "Flowing Red Scale", cooldown = 12, damage = 13, hits = 2, type = "melee", block = "all", bypassRagdoll = true, ragdoll = { h = 45, v = 18 }, lunge = 15, tip = "SPECIAL", air = { damage = 6, block = "none", ragdoll = { h = 8, v = 60 } } },
		-- When used without any Convergence orbs, the user will perform a cross-armed guard for a brief moment.
		-- TODO special variant: The user tosses a Convergence orb forwards and converts it to a blood bomb that mimics their own movement (but not their camera's),...
		[ 3 ] = K.Counter{ "Supernova", cooldown = 15, counters = { melee = "counter" }, window = 0.6, riposte = 14, tip = "SPECIAL" },
		-- The user equips themselves with two blood-made blades, impaling the opponent with a thrusting jab of the left dagger before front-flipping forward and slamming the...
		[ 4 ] = K.Melee{ "Blood Edge", cooldown = 13, damage = 11, hits = 2, type = "melee", blockDamage = 5.5 },
	},
	-- By using the special, the user conjures 4 blood orbs condensed to their limit.
	special = K.Buff{ "Convergence", cooldown = 20, duration = 0.65 },

	awakening = {
		name = "Duty As A Brother",
		duration = 60,
		heal = 20,
		-- Upon initiating the Awakening sequence, the user lowers their arms, saying “Brothers, lend me your strength!” before raising them up quickly and bursting out blood...
		abilities = {
			-- The user activates an extension technique by manipulating any available Convergence orbs into a concentrated pressurized stream that will ragdoll anyone hit by it to...
			-- TODO special variant: By using their special during the move's windup, the user will form their blood into a rotating chakram, as they spin 3 times and chuck...
			[ 1 ] = K.Melee{ "Slicing Exorcism", cooldown = 3.25, damage = 3, hits = 2, type = "melee", block = "none", bypassRagdoll = true, trueRag = true, ragdoll = true, tip = "SPECIAL" },
			-- As they gain melee and bullet i-frames, the user lunges towards a target with a flurry of brutal kicks and punches and ends the combo by extending their hand at them...
			[ 2 ] = K.Melee{ "Wing King", cooldown = 16, damage = 43.75, hits = 2, type = "melee", blockDamage = 21.88, bypassRagdoll = true, armor = "bullet", lunge = 15 },
			-- The user conjures a giant blood sphere above them that erupts into an upward stream, raining pellets of blood down on anything within 35 studs of the user who is free...
			[ 3 ] = K.Melee{ "Blood Rain", cooldown = 35, damage = 2, type = "melee", block = "all", bypassRagdoll = true, ragdoll = { h = 8, v = 60 } },
			-- The Blood Manipulator takes their technique to the maximum, spinning around to create a total of 14 blood orbs before firing out a massive cone of blood with a range...
			[ 4 ] = K.Melee{ "Plasma Wave", cooldown = 45, damage = 95, type = "melee", block = "none", bypassRagdoll = true },
		},
		-- Same as base, However, once the Awakening ends, all current orbs disappear with it.
		-- TODO special variant: After Wing King is used, any available Convergence orbs will form a halo on the user's back.
		special = K.Buff{ "Convergence", cooldown = 20, tip = "SPECIAL" },
	},
} )
