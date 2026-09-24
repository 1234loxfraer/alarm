-- Strongest Of History. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "strongestofhistory", {
	name = "Strongest Of History",
	category = "op",
	hp = 100,
	model = K.Model( "strongestofhistory", "models/player/charple.mdl" ),
	color = Color( 255, 60, 60 ),

	passives = {
		{ "Pinnacle Of Jujutsu Sorcery", "The legends never lied about the King of Curses, since being described as an imaginary demon was likely a result of the unique body structure the user possesses, that being their significant size,..." },
	},

	abilities = {
		-- The player does a swinging gesture with their left arm aiming forward, sending two large slashes towards the target.
		-- TODO special variant "Dismantle Barrage": Upon reciting of one incantation, the player will swing their arm forwards while exclaiming: "解" (pronounced: Kai, and means...
		-- TODO special variant "Disgraced Sovereign": After reciting two incantations, the user will levitate upwards with their arms spread out and laugh as they increasingly release more...
		-- TODO special variant "World Cutting Slash": Upon reciting three incantations, the user will extend their hand before them as they utter: "分を弁えろ" (pronounced: Bun-o Wakimaero, and...
		[ 1 ] = K.Melee{ "Strong Dismantle", cooldown = 4, damage = 20, hits = 2, type = "melee", block = "none", bypassRagdoll = true, tip = "SPECIAL" },
		-- The user conjures fire from their hands as they proceed to aggressively clap twice to gain i-frames and mold the flames into an arrow while saying: "構えろ" (pronounced:...
		[ 2 ] = K.Melee{ "Open FURNACE", cooldown = 12, damage = 70, type = "melee", block = "none", bypassRagdoll = true },
		-- The player winds their fist back while coating it with cursed energy and exclaims: "失せろ!" (pronouced: Usero, and means "Get lost") before lunging forward a large...
		-- Follow-up: If quickly pressed again during the initial stun prior to the full wind-up of their arm, the user will imbue their blow with cursed...
		[ 3 ] = K.Melee{ "Cleave Rush", cooldown = 5, damage = 150, type = "melee", block = "none", tip = "USE TWICE", again = K.Melee{ "Cleave Rush", damage = 35, type = "melee", block = "none" } },
		-- The user pulls out a vajra-like cursed tool, Kamutoke, wielding it on their right hand and pointing it upwards, calling forth several torrents of lightning to strike...
		[ 4 ] = K.Melee{ "Kamutoke", cooldown = 7, damage = 15, type = "melee", block = "none", bypassRagdoll = true },
	},
	-- The user crosses their arms and makes a hand sign while chanting, with each of the first three incantations granting a different, superior variation of Strong Dismantle.
	-- TODO special variant "Dismantle Net": On the fourth incantation, the player will say "終わりだ" (pronounced: Owarida, means "It's over.") as they point their left hand forward to...
	special = K.Buff{ "Incantation", cooldown = 2, tip = "SPECIAL" },

	-- Base-only: the awakening is a single move
	-- Upon using their Awakening, the user crosses their fingers as a pop-up cutscene plays while a speech bubble covers everyone's screens reading: DOMAIN EXPANSION.
	awakenMove = K.Domain{ "Incomplete Shrine", duration = 20, sureHit = "damage", dps = 14, color = "white" },
} )
