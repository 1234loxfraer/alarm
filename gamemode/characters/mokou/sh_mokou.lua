-- Mokou. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "mokou", {
	name = "Mokou",
	category = "other",
	hp = 100,
	model = K.Model( "mokou", "models/player/mossman_arctic.mdl" ),
	color = Color( 255, 120, 60 ),

	passives = {
		{ "Restoration", "On death, massive flames will completely envelop the user's body, who returns to life while saying: \"I'll show you the legendary phoenix..." },
	},

	abilities = {
		-- The user slashes forward twice with fiery claws, ending them with an uptilting kick that lifts both the user and the opponent into the air.
		[ 1 ] = K.Buff{ "Phoenix Maelstrom", cooldown = 5 },
		-- The user hops up before crashing down with a heavy dropkick that momentarily lights the area of impact on fire.
		[ 2 ] = K.Buff{ "Aetherflare Talon", cooldown = 3, block = "none", bypassRagdoll = true },
		-- The user unleashes a pillar of flame, decombusting themselves in the process as they turn into a flying orb of energy.
		[ 3 ] = K.Buff{ "Scorchrise", cooldown = 8, block = "none", bypassRagdoll = true },
		-- The user conjures several flame bullets and sends them barreling forwards.
		[ 4 ] = K.Buff{ "Hexflare Charm", cooldown = 5, bypassRagdoll = true },
	},
	special = K.Stub{ "Phoenix Immortality" },

	awakening = {
		name = "Immortal Blaze",
		-- When initiating their Awakening, the user will perform both of Honored One's awakening sequences in order.
		-- TODO passive "Danmaku": By using their melee basic attack, the user gains the ability to unleash a barrage of pink round bullets that delete opponents upon contact.
	},

	-- TODO other entries of the base moveset:
	--   Blazing Soar [special]: Using their pyrokinetic abilities, the user conjures a pair of wings, utilizing them to propel themselves upwards...
} )
