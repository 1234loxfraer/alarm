-- Head of the Hei. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "headofthehei", {
	name = "Head of the Hei",
	category = "complete",
	hp = 90,
	model = K.Model( "headofthehei", "models/player/group03/male_02.mdl" ),
	color = Color( 240, 240, 180 ),

	passives = {
		{ "Projectionism", "The user applies several alterations to their fighting style: *A full set of M1 only deals 8 damage, with each M1 dealing 2 damage." },
		{ "Frame Freeze", "The applications of the \"Projection Sorcery\" cursed technique force all parties to abide by the 24 FPS rule, including the user." },
	},

	abilities = {
		-- The user dashes 15 studs backwards while applying their technique, gaining short melee i-frames, before spinning back with a heavy kick that throws the target away.
		[ 1 ] = K.Melee{ "Projection Breaker", cooldown = 18, damage = 9, type = "melee", bypassRagdoll = true, armor = "melee" },
		-- The user pulls out a sharp tanto blade and spins it around before quickly stabbing forwards towards the target's abdomen.
		[ 2 ] = K.Melee{ "Bleedout", cooldown = 20, damage = 5, hits = 2, type = "melee", block = "none", bypassRagdoll = true },
		-- With the help of their cursed technique, the user runs 35 studs forwards before quickly punching forwards.
		-- Follow-up: Using the move again will delay the jab and force the user extend their run by 15 studs as they plan out a longer trajectory using their...
		-- TODO use thrice variant: Using the move a third time will extend the rush by another 23 studs and make its punch entirely unblockable.
		-- TODO air target variant: By aiming at an airborne enemy within 70 studs, the first press of this move will lock the user to their target and allow them to travel...
		[ 3 ] = K.Melee{ "Decisive Strike", cooldown = 18, damage = 6, hits = 8, type = "melee", bypassRagdoll = true, tip = "USE TWICE", again = K.Melee{ "Decisive Strike", damage = 6, hits = 8, type = "melee", bypassRagdoll = true } },
		-- The user activates their technique yet again to quick step to their destination by increasing their movement speed.
		-- TODO variant: If the target was caught in a frame (regardless of who framed them), then the smack will launch them upwards, before the user quickly...
		[ 4 ] = K.Melee{ "Cursory Impact", cooldown = 16, damage = 12, hits = 2, type = "melee", block = "none", trueRag = true },
	},
	-- By aiming at a position within 50 studs, the user activates their cursed technique to cover the distance in a single second while leaving an afterimage behind.
	-- TODO special variant: Activating the special after having caught someone in a frame allows the user to target them with their cursed technique and wind up a...
	special = K.Mobility{ "Projection Sorcery", cooldown = 18, block = "none", bypassRagdoll = true, travel = 50, tip = "SPECIAL" },

	awakening = {
		name = "Vengeance",
		duration = 60,
		heal = 90,
		-- When initiating their Awakening, the user performs "Bleedout", albeit with a slowed down windup.
		-- TODO cosmetic/passive "Vengeance": Reincarnated as a vengeful curse, the user acquires new capabilities: *Their movement speed is faster than normal, hovering above the ground due...
		abilities = {
			-- By utilizing the inlets in their new cursed form to take in the air and eject it from behind, the user boosts forwards in an attempt to crash their tough shell into...
			[ 1 ] = K.Melee{ "Top Speed", cooldown = 14, damage = 5, hits = 2, type = "melee", block = "none", bypassRagdoll = true },
			-- The user activates their cursed technique and freezes the air in front of them, creating a line of 15 glass frames.
			[ 2 ] = K.AoE{ "Flash Freezing", cooldown = 18, damage = 7, type = "explosion", block = "none", bypassRagdoll = true, color = "orange" },
			-- The user plunges their arm underground, before their tendrils surge out to grab any enemies within 25 studs, immobilizing them for roughly a second.
			[ 3 ] = K.Buff{ "Tendril Grab", cooldown = 10, block = "none", bypassRagdoll = true, trueRag = true },
			-- Hopping out of their curse form, the user performs a handsign to expand their innate domain, Time Cell Moon Palace, while reverting back to their base moveset with...
			[ 4 ] = K.Domain{ "Time Cell Moon Palace", cooldown = 60, duration = 25, sureHit = "damage", dps = 3, color = "white" },
		},
		-- The user's new form gives them the ability to accumulate speed by rapidly spinning using their cursed technique, damaging the area around them while increasing their...
		special = K.AoE{ "Acceleration", cooldown = 9, damage = 7, type = "explosion", block = "all", bypassRagdoll = true, color = "orange" },
	},
} )
