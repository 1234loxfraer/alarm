-- Sky Assassin. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "skyassassin", {
	name = "Sky Assassin",
	category = "early",
	hp = 100,
	model = K.Model( "skyassassin", "models/player/group03/male_09.mdl" ),
	color = Color( 170, 220, 255 ),

	passives = {
		{ "Sky Manipulation", "Due to the user’s cursed technique, instead of walking they hover above the ground at all times." },
		{ "Temper", "With every hit they land, the user gets angrier and angrier with their opponent." },
	},

	abilities = {
		-- The user winds up a quick grab by surging forwards with their cursed technique.
		-- TODO variant: While "bad-tempered", the user will first throw two blockable swings amplified by their cursed technique before following up with their...
		[ 1 ] = K.Grab{ "Blind Rage", cooldown = 15, damage = 5, hits = 3, type = "melee", block = "none", bypassRagdoll = true },
		-- The user spins while holding onto the atmosphere in front of them, using its surface to launch any enemy they walk into.
		-- TODO variant: While "bad-tempered", the user will increase their output, improving the distortion at close range before sending a bullet-type...
		[ 2 ] = K.Melee{ "Sky Distortion", cooldown = 12, damage = 12, type = "melee" },
		[ 3 ] = K.Stub{ "TBA" },
		-- The user quickly puts both their hands forwards to strike the surface layer of the sky and shatter it like thin ice, striking opponents with a focused shockwave.
		[ 4 ] = K.Grab{ "Thin Ice Breaker", cooldown = 15, damage = 10, hits = 2, type = "melee", block = "none", bypassRagdoll = true, ragdoll = true },
	},
	special = K.Stub{ "TBA" },

	-- Base-only: the awakening is a single move
	-- This awakening can only be used while "bad-tempered" and will end the state immediately.
	awakenMove = K.Summon{ "Temper", damage = 80, heal = 25, type = "swarm", block = "none", bypassRagdoll = true, trueRag = true, uninterruptible = true, range = 50, color = "shadow" },
} )
