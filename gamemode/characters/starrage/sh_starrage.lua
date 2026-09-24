-- Star Rage. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "starrage", {
	name = "Star Rage",
	category = "baseonly",
	hp = 100,
	model = K.Model( "starrage", "models/player/mossman.mdl" ),
	color = Color( 255, 200, 90 ),

	passives = {
		{ "Garuda", "The user possesses an animated serpentine shikigami, Garuda, that will keep floating around them and aid them in their offense during Garuda Rebound and Garuda Stab." },
	},

	abilities = {
		-- The user kicks their shikigami forwards with slight auto-aim as it curls up into a ball-shaped cursed tool, causing it to hit the target's torso and hover back to...
		-- Follow-up: If pressed again right as Garuda comes back, the user will punch their shikigami forwards again, causing any target hit to ragdoll...
		-- TODO special variant: While Garuda is coming back, the user can press the special anytime to release all stored mass through a powerful kick that sends the...
		[ 1 ] = K.Projectile{ "Garuda Rebound", cooldown = 14, damage = 5, type = "bullet", block = "all", bypassRagdoll = true, color = "blue", tip = "USE TWICE", again = K.Projectile{ "Garuda Rebound", damage = 7, type = "bullet", block = "pre", bypassRagdoll = true, ragdoll = { h = -20, v = 16 }, color = "blue" } },
		-- Amplifying their legs with cursed energy, the user performs a sweep and follows it up by an upwards kick that propels the target up and away.
		-- TODO special variant: Anytime before the second kick, the user can press the special tto make way for a third one, directed to the opponent's head and...
		-- TODO special variant: Adding a second press of the special before the third kick will change it to knock the opponent backwards rather than to the right,...
		[ 2 ] = K.Melee{ "Rising Rage", cooldown = 15, damage = 14, hits = 2, type = "melee", ragdoll = { h = 8, v = 60 }, tip = "SPECIAL" },
		-- The user charges their fist with cursed energy then lunges forwards to land a bone-breaking blow.
		-- TODO special variant: By pressing the special during the windup, the user will jolt around with their charged Mass Breaker to end their lunge with an...
		[ 3 ] = K.Melee{ "Mass Breaker", cooldown = 15, damage = 15, type = "melee", block = "none", trueRag = true, lunge = 15, tip = "SPECIAL" },
		-- By holding Garuda as a cursed tool, the user stabs forward with the shikigami's body in an attempt to puncture the opponent.
		-- TODO special variant: After pressing the special during the windup, the user will throw their shikigami forward to grab an enemy with it and pull them in, as...
		[ 4 ] = K.Melee{ "Garuda Stab", cooldown = 14, damage = 14, hits = 2, type = "melee", block = "none", tip = "SPECIAL" },
	},
	-- When held, the user will convert their cursed energy into virtual mass to fill up a "Mass" bar to their right.
	special = K.Buff{ "Mass Buildup", cooldown = 16 },

	-- Base-only: the awakening is a single move
	-- The constant addition of virtual mass does not affect the user, but only up to a certain point.
	awakenMove = K.Melee{ "Unrestricted Density", damage = 500, type = "melee", block = "none", bypassRagdoll = true },
} )
