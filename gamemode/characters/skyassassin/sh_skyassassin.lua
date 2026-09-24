-- Sky Assassin (early access). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does. Slot 3 and the special are still TBA in the game.

local K = JJS.Kit

K.Character( "skyassassin", {
	name = "Sky Assassin",
	category = "early",
	hp = 100,
	model = K.Model( "skyassassin", "models/player/group03/male_09.mdl" ),
	color = Color( 170, 220, 255 ),

	passives = {
		{ "Sky Manipulation", "Hovers instead of walking; stronger uppercuts and midair M1 combos. (TODO)" },
		{ "Temper", "Landing hits builds a Temper bar; full, the user is bad-tempered for 15s (stronger moves). (TODO)" },
	},

	abilities = {
		-- Surges forward to grab (5), chokes the target and flies 125 studs with them, crashing into surfaces (+3 each, up to +9),
		-- then tosses them (5). TODO bad-tempered variant: two swings first.
		[ 1 ] = K.Grab{ "Blind Rage", cooldown = 15, startup = 0.3, damage = 13, hits = 3, interval = 0.5, lunge = 20, type = "melee", block = "none",
			bypassRagdoll = true, ragdoll = { h = 60, v = 30 } },
		-- Spins holding onto the atmosphere, launching anyone walked into; airborne it dashes 20 studs.
		-- TODO bad-tempered variant: a 150 stud bullet distortion after the spin (17 total).
		[ 2 ] = K.Melee{ "Sky Distortion", cooldown = 12, startup = 0.35, damage = 12, reach = 8, width = 9, type = "melee",
			ragdoll = { h = 10, v = 55 }, air = { lunge = 20 } },
		[ 3 ] = K.Stub{ "TBA" },
		-- Both hands strike the sky's surface layer, shattering it like thin ice into a focused shockwave (5 + 5).
		[ 4 ] = K.Melee{ "Thin Ice Breaker", cooldown = 15, startup = 0.4, damage = 10, hits = 2, interval = 0.25, reach = 10, type = "melee",
			block = "none", bypassRagdoll = true, ragdoll = { h = 60, v = 25 }, color = "cyan" },
	},
	special = K.Stub{ "TBA" },

	-- Base-only awakening. The real one needs the bad-tempered state: flies up, charges a giant distortion and
	-- strikes it into a shockwave that eradicates everything within 50 studs (80, heals 25).
	awakenMove = K.AoE{ "Temper", startup = 2, damage = 80, radius = 50, type = "swarm", block = "none", bypassRagdoll = true, trueRag = true,
		uninterruptible = true, iframes = 2, heal = 25, crater = 2500, ragdoll = { h = 60, v = 40 }, color = "cyan" },
} )
