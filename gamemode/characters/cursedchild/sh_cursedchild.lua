-- Cursed Child. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "cursedchild", {
	name = "Cursed Child",
	category = "other",
	hp = 100,
	model = K.Model( "cursedchild", "models/player/p2_chell.mdl" ),
	color = Color( 200, 60, 90 ),

	passives = {
		{ "Real Knife", "The user yields the Real Knife and any attack landed by the user will be followed by a floating indicator that will reveal the exact damage of each hit dealt to the target." },
		{ "Real Knife", "The user's melee basic attacks are slower and deal much less damage than normal, with the first 3 M1s each dealing 2 damage, and the final one dealing 4 damage." },
		{ "Soul Flip", "The user's front dashes and back dashes travel much longer distances than normal." },
	},

	abilities = {
		-- The user winds up a large slash with their knife followed up with two quick stabs, three kicks, then two more stabs before a final kick that ragdolls their target away.
		-- Air variant "Feral Takedown": The user hops up and grabs a nearby opponent, before slamming them downwards into the floor, stabbing them in the torso, then jumping...
		[ 1 ] = K.Melee{ "Onslaught", cooldown = 17, damage = 17.2, type = "melee", ragdoll = { h = 45, v = 18 }, air = { damage = 1.5, hits = 2, block = "none", bypassRagdoll = true } },
		-- The user runs forward before sliding.
		[ 2 ] = K.Melee{ "Lethal Wound", cooldown = 18, damage = 12, type = "melee", block = "none", bypassRagdoll = true },
		-- The user spins backwards with a kick before performing a forward slash.
		[ 3 ] = K.Melee{ "Bloody Mary", cooldown = 21, damage = 21, hits = 2, type = "melee", block = "none", bypassRagdoll = true },
		-- The user readies their knife and thrusts forward.
		[ 4 ] = K.Melee{ "Fight", cooldown = 21, damage = 2, hits = 2, type = "melee" },
	},
	-- While facing a nearby opponent, the user will choose the option to "Act", then "Check".
	special = K.Buff{ "Check", cooldown = 25, block = "none", bypassRagdoll = true },

	awakening = {
		name = "SINCE WHEN WERE YOU THE ONE IN CONTROL?",
		abilities = {
			-- The user crouches and performs three sidesteps in a zig-zag pattern until they lunge forward with the real knife to stab the enemy, then proceeding with two slashes,...
			[ 1 ] = K.Melee{ "Cursed Remedy", cooldown = 16, damage = 7, type = "melee", block = "none", bypassRagdoll = true, uninterruptible = true, lunge = 15 },
			-- The user puts their arms behind their back as they get highlighted in a red outline.
			[ 2 ] = K.Melee{ "Reset", cooldown = 45, damage = 50, type = "melee", block = "none", bypassRagdoll = true, uninterruptible = true, lunge = 15 },
			-- The user tosses their knife up then catches it with a kick, before lunging forward to stab anyone in front of them, then swinging their weapon upwards and ending the...
			-- TODO variant: Should the enemy endure for long enough, then they will block the user's attack and disarm them, tossing themselves to the ground to...
			[ 3 ] = K.Melee{ "Atonement", damage = 100, type = "melee", block = "none", uninterruptible = true },
			-- The user kneels before preparing a long forward run, as Chara's soul manifests to join them during their rush before the user swings forwards.
			-- TODO variant: If the user successfully wins the QTE, then the camera will pan to them as they prepare a long swing of their knife that they are able...
			[ 4 ] = K.Melee{ "Seven Souls", cooldown = 44, damage = 2.5, hits = 2, type = "melee", block = "none", bypassRagdoll = true },
		},
		-- Same as base.
		special = K.Buff{ "Check", cooldown = 25, block = "none", bypassRagdoll = true },
	},
} )
