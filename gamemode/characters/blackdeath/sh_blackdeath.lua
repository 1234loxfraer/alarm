-- Black Death (Kurourushi, base-only). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.

local K = JJS.Kit

K.Character( "blackdeath", {
	name = "Black Death",
	category = "baseonly",
	hp = 100,
	scale = 1.25,
	model = K.Model( "blackdeath", "models/player/zombie_soldier.mdl" ),
	color = Color( 110, 80, 60 ),

	-- Festering Life Sword M1 set (1 + 2 + 2 + 3)
	m1 = { Damage = { 1, 2, 2, 3 } },

	passives = {
		{ "Demon of the Modern Era", "1.25x size, extra arms; sword M1s (1 + 2 + 2 + 3), unarmed (3 + 3 + 4 + 4)." },
		{ "Iron-Rich", "Downslamming a corpse eats it: resets all cooldowns and toughens the next clones. (TODO)" },
		{ "Festering Life Sword", "Slashes apply Injury stacks (3 damage each over time) that hatch for 14. (TODO)" },
	},

	abilities = {
		-- Three careful slashes (1 each) applying Injury through block; each swing can parry melee attacks.
		-- TODO special variant "Fierce Strikes": fists, two punches and an unblockable uppercut (13).
		[ 1 ] = K.Melee{ "Festering Strikes", cooldown = 20, startup = 0.3, damage = 3, hits = 3, interval = 0.3, reach = 9, type = "melee",
			blockDamage = 1, ragdoll = { h = 30, v = 12, time = 0.6 }, tip = "SPECIAL" },
		-- Detaches the sword arm and launches it on a bridge of cockroaches (1, 2 Injury).
		-- Follow-up "Reattach": pulls the arm back along with whoever was impaled.
		[ 2 ] = K.Projectile{ "Detach", cooldown = 13, startup = 0.35, damage = 1, range = 50, speed = 170, radius = 2.5, type = "bullet",
			bypassRagdoll = true, stun = 1, color = "brown", tip = "USE AGAIN",
			again = K.Target{ "Reattach", window = 8, teleport = false, range = 55, startup = 0.2, damage = 0, type = "special", block = "none",
				bypassRagdoll = true, ragdoll = { h = -60, v = 12, time = 0.5 } } },
		-- The extra arms grab a neck (stalling the Injury drain) and a slash tosses the target away (2).
		-- TODO variant: before the sword is reattached, a heavy punch instead (12).
		[ 3 ] = K.Grab{ "Chokehold", cooldown = 16, startup = 0.25, damage = 2, hits = 2, interval = 0.6, reach = 7, type = "melee", bypassRagdoll = true,
			whiffEndlag = 0, ragdoll = { h = 50, v = 15 } },
		-- A horde of roaches rushes 35 studs forward tearing everything, ragdolling targets away (6, +2 per 1.5 Injury).
		-- Air variant: rides the wave ~40 studs. TODO special variant: a twirling uncounterable swarm (9).
		[ 4 ] = K.Beam{ "Roach Swarm", cooldown = 17, startup = 0.45, damage = 6, range = 35, radius = 6, pierce = true, maxPitch = 0.1, type = "bullet",
			block = "none", bypassRagdoll = true, ragdoll = { h = 45, v = 20 }, color = "brown",
			air = { kind = "mobility", travel = 40, time = 0.6, dir = "forward" } },
	},
	-- Summons two earthen insects carrying a blinding substance; pressed again at an enemy within 100 studs, they hover around them.
	special = K.Target{ "Earthen Insect Trance", cooldown = 15, teleport = false, range = 100, startup = 0.4, damage = 0, type = "explosion",
		block = "none", bypassRagdoll = true, slow = { 0.7, 6 }, stun = 0.3, color = "brown" },

	-- Splits into two using all their cursed energy (total i-frames); the offspring fights alongside (heals 25, both).
	-- TODO: the clone. Awakening variant "Bugnado" (special in the windup): two swirling roach tornadoes (81.5).
	awakenMove = K.Zone{ "Bugnado", startup = 1.25, radius = 18, offset = 10, duration = 4, tick = 0.4, damage = 8, type = "swarm", block = "none",
		bypassRagdoll = true, iframes = 1.25, stun = 0.4, heal = 25, color = "brown",
		onUse = function( ply ) JJS.Heal( ply, 25 ) end },
} )
