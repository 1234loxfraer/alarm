-- Locust Guy. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "locustguy", {
	name = "Locust Guy",
	category = "baseonly",
	hp = 90,
	model = K.Model( "locustguy", "models/player/zombie_fast.mdl" ),
	color = Color( 150, 190, 60 ),

	passives = {
		{ "Naturally Selected", "Since they derive from the hate towards locusts, the user's physiology tends to resemble such insects, giving them two antennas that protrude from the top of their head, an extra pair of arms, and..." },
	},

	abilities = {
		-- The user crouches, getting ready to charge forward with a barrage of punches that ragdoll the target then leaves them stunned in place.
		[ 1 ] = K.Melee{ "Clever", cooldown = 15, damage = 14.2, type = "melee", ragdoll = true, lunge = 15 },
		-- The user winds their head back before spitting out a ball of dark mucus that will travel a maximum of 60 studs forwards, ragdolling anyone it hits and applying a 15%...
		[ 2 ] = K.Projectile{ "Black Mucus", cooldown = 17, damage = 8, type = "bullet", block = "none", bypassRagdoll = true, range = 60, ragdoll = { h = 45, v = 18 }, color = "blue" },
		-- The user swings their head back and forth 3 times while biting.
		[ 3 ] = K.Grab{ "Crushing Jaws", cooldown = 17, damage = 16, hits = 3, type = "melee", blockDamage = 8, armor = "total", ragdoll = { h = 8, v = 60 } },
		-- The user winds their arm back before reaching forward to grab their opponent, gaining free flight and melee i-frames shortly before tossing their target away.
		[ 4 ] = K.Grab{ "Wing Throw", cooldown = 15, damage = 8, hits = 2, type = "melee", bypassRagdoll = true, ragdoll = { h = 45, v = 18 } },
	},
	-- The user spreads their wings, flying about 25 studs in the direction they're facing and carrying some momentum wherever they go.
	-- TODO special variant: If the user aims at a ragdolled airborne enemy within 80 studs, they will initiate an air combo by flying to them and suspending both...
	special = K.Buff{ "Fluttering Pounce", cooldown = 16, tip = "SPECIAL" },

	-- Base-only: the awakening is a single move
	-- The user extends their insect abdomen which is equipped with a sharp end, while exclaiming "俺の勝ち!" (pronounced "Ore no kachi!", which is Japanese for "I win!") before...
	awakenMove = K.AoE{ "Directed Poison", damage = 90, heal = 25, type = "explosion", block = "none", bypassRagdoll = true, uninterruptible = true, color = "orange" },
} )
