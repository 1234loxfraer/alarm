-- Black Death. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "blackdeath", {
	name = "Black Death",
	category = "baseonly",
	hp = 100,
	model = K.Model( "blackdeath", "models/player/zombie_soldier.mdl" ),
	color = Color( 110, 80, 60 ),

	passives = {
		{ "Demon of the Modern Era", "Being a cockroach curse, the user's physiology is clearly unnatural due to their intimidating height, the antennas protruding from their face, and their extra pair of arms." },
		{ "Iron-Rich", "Downslamming a dead body will play a finisher consisting of a gory display of the user, first consuming their head in a single bite, then ripping off both arms to consume them, and lastly grabbing..." },
		{ "Festering Life Sword", "Any player afflicted by injury will gain a meter to their side, with its progress indicating the current injury amount." },
	},

	abilities = {
		-- The user tactically swings their blade forwards thrice, with each slash applying injury through block and canceling ragdoll, and the final hit dealing its damage...
		-- TODO special variant "Fierce Strikes": By pressing the special during the windup, the user tosses their cursed tool upwards and quickly reverts to their fists, punching...
		[ 1 ] = K.Melee{ "Festering Strikes", cooldown = 20, damage = 3, hits = 3, type = "melee", blockDamage = 1.5, ragdoll = { h = 45, v = 18 }, tip = "SPECIAL" },
		-- The user unattaches their upper right arm which holds their cursed tool and launches it forwards, leaving it connected to their body through a bridge of cockroaches.
		-- Follow-up "Reattach": By using this move after a landed Detach, the user will pull on the line of roaches to recall their arm and weapon along with whoever...
		-- TODO variant "Detach/Reattach": While rebounding after a failed Detach or during a Reattach, the Festering Life Sword is still able to harm targets in its way, will...
		[ 2 ] = K.Projectile{ "Detach", cooldown = 13, damage = 1, type = "bullet", bypassRagdoll = true, range = 85, color = "blue", tip = "USE AGAIN", again = K.Buff{ "Reattach", block = "none", bypassRagdoll = true } },
		-- The user's extra pair of arms jolts forwards in an attempt to grab an enemy.
		-- TODO variant: If used before the Festering Life Sword is reattached, then the user will instead wind up a heavy punch that will launch the strangled...
		[ 3 ] = K.Grab{ "Chokehold", cooldown = 16, damage = 2, type = "melee", bypassRagdoll = true },
		-- The user motions for a horde of roaches to move 35 studs forwards and tear everything in front of them, ragdolling any targets away.
		-- Air variant: If the user was airborne, then they will ride the wave of roaches forwards after a slightly extended windup, traveling about 40 studs in...
		-- TODO special variant: By using the special during the windup, the user instead orders the swarm to twirl in the air, becoming fully uncounterable and...
		[ 4 ] = K.Projectile{ "Roach Swarm", cooldown = 17, damage = 6, type = "bullet", block = "none", bypassRagdoll = true, range = 35, ragdoll = { h = 45, v = 18 }, color = "blue", tip = "SPECIAL", air = { range = 40 } },
	},
	-- The user activates a cursed technique that summons two flying earthen insects that possess giant sacs carrying an unknown blinding substance.
	special = K.Target{ "Earthen Insect Trance", cooldown = 15, damage = 4, type = "explosion", block = "none", bypassRagdoll = true, range = 100, ragdoll = { h = 45, v = 18 } },

	-- Base-only: the awakening is a single move
	-- The user stimulates their parthenogenesis process using all their accumulated cursed energy to split into two.
	-- TODO awakening variant "Bugnado": Pressing the special during the Parthenogenesis windup or awakening with the maximum amount of offspring will feint the duplication...
	awakenMove = K.Buff{ "Parthenogenesis", heal = 25 },
	-- TODO domain invasion "Invasion": If Parthenogenesis is activated near a domain border, the user's swarm of roaches will be dedicated towards making a hole in the dome...
} )
