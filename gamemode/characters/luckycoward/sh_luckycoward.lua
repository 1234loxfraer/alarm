-- Lucky Coward. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "luckycoward", {
	name = "Lucky Coward",
	category = "baseonly",
	hp = 65,
	model = K.Model( "luckycoward", "models/player/group02/male_02.mdl" ),
	color = Color( 250, 230, 110 ),

	passives = {
		{ "Shoot!", "Since the user isn't experienced enough to fight using their fists, they hold a cursed tool resembling a katana blade connected to a humanoid hand." },
		{ "Miracles", "Above the user's Awakening Bar lie six triangles, each able to fill up by storing a \"miracle\" that the user can later utilize in many ways: *Upon a supposed death, the user's cursed technique will..." },
		{ "Miracle", "While unarmed, pressing the block button will prepare the user to evade any incoming melee or bullet attack, hinted by a circle effect around them." },
		{ "Taunt", "The user's basic attack is also removed while unarmed." },
	},

	abilities = {
		-- The user swings their cursed tool forwards, slashing in front of them and ragdolling anyone hit backwards.
		-- TODO ragdoll variant "Stinger": If a nearby enemy was grounded to the floor, then the user will drive their cursed tool downwards instead of swinging, greatly extending...
		-- Follow-up "Million Stab": After a successful Stinger, the user has a short window to use the move again and add 3 maniacal thrusts on the defenseless target.
		-- TODO special variant "Ankle Cutter": The user commands their sword to attack, which makes the sword blitz forwards while rotating itself to make sure that its blade slices...
		[ 1 ] = K.Melee{ "Ambush", cooldown = 15, damage = 12, type = "melee", block = "pre", ragdoll = { h = 45, v = 18 }, tip = "RAGDOLL", again = K.Melee{ "Million Stab", damage = 6, hits = 2, type = "melee", block = "none", bypassRagdoll = true, trueRag = true, ragdoll = true } },
		-- The user quickly stabs forwards with their weapon, momentarily stunning the enemy.
		-- TODO special variant "High Time": The helping hand rises in the air with a spin, consequently making its blade slice upwards and pull targets alongside it in the air...
		[ 2 ] = K.Melee{ "Backstab", cooldown = 12, damage = 8, type = "melee", block = "none", tip = "SPECIAL" },
		-- The user extends their foot outwards, kick the target and causing them to fall face-first on the floor.
		[ 3 ] = K.Melee{ "Trip", cooldown = 14, damage = 7, type = "melee", bypassRagdoll = true, ragdoll = { h = 45, v = 18 } },
		-- The user throws their cursed tool forwards to pierce through any enemies 60 studs away, consequently unarming themselves.
		-- TODO special variant "Dirty Play": Frantically waving around, the user calls for their weapon, which will come back flying through the air while slicing through targets in...
		[ 4 ] = K.Projectile{ "Cheap Shot", cooldown = 15, damage = 7, type = "bullet", bypassRagdoll = true, range = 60, color = "blue", tip = "SPECIAL" },
	},
	-- If the special is used while aiming at a target within 150 studs, the Hand Sword will latch off of the user and constantly follow the enemy in an attempt to position...
	special = K.Target{ "Helping Hand", block = "none", bypassRagdoll = true, uninterruptible = true, range = 150 },

	-- Base-only: the awakening is a single move
	-- This Awakening can only be used if unarmed, but even while in stun.
	awakenMove = K.Projectile{ "Jawbreaker", damage = 25, heal = 25, type = "explosion", block = "none", uninterruptible = true, explode = 10, color = "orange" },
} )
