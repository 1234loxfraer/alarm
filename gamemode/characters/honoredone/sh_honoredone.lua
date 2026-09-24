-- Honored One (Satoru Gojo). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.

local K = JJS.Kit

K.Character( "honoredone", {
	name = "Honored One",
	category = "complete",
	hp = 100,
	model = K.Model( "honoredone", "models/player/group01/male_09.mdl" ),
	color = Color( 110, 190, 255 ),

	passives = {
		{ "Infinity", "Cosmetic: the user poses and hovers instead of guarding when blocking." },
	},

	abilities = {
		-- Aiming at an opponent within 35 studs, a vacuum pulls them in (5), then a kick sends them away (7.5).
		[ 1 ] = K.Target{ "Lapse Blue", cooldown = 13, range = 35, damage = 12.5, hits = 2, interval = 0.35, type = "melee",
			block = "all", bypassRagdoll = true, armor = "melee", ragdoll = { h = 40, v = 16 } },
		-- A red orb that travels forward 40 studs and bursts on the first target (half damage when blocked).
		-- TODO special variants: with Limitless in the windup the user phases behind the target; air target / interruption versions.
		[ 2 ] = K.Projectile{ "Reversal Red", cooldown = 20, startup = 0.5, damage = 12.5, blockDamage = 6.25, range = 40, speed = 110,
			radius = 3, type = "bullet", bypassRagdoll = true, explode = 8, color = "red", ragdoll = { h = 45, v = 20 }, tip = "SPECIAL" },
		-- Spinning kick that locks a nearby enemy in place, then a barrage, heavy blows and a final hit (unblockable grab).
		-- TODO special variant "Face Grater": Limitless right after landing drags the opponent along the floor (10.2).
		[ 3 ] = K.Grab{ "Rapid Punches", cooldown = 15, damage = 17.25, hits = 6, interval = 0.22, type = "melee", block = "none",
			armor = "bullet", ragdoll = { h = 45, v = 18 }, tip = "SPECIAL" },
		-- Upward kick (6) that anchors the enemy in the air, then an unblockable second kick (4) bounces them.
		[ 4 ] = K.Melee{ "Twofold Kick", cooldown = 18, damage = 10, hits = 2, interval = 0.4, type = "melee", blockDamage = 5,
			bypassRagdoll = true, armor = "melee", ragdoll = { h = 10, v = 55 } },
	},
	-- Targeting an enemy, the user instantly appears before them. Costs 6% awakening.
	-- TODO special variant: on an airborne enemy, an air kick knocks them down (8).
	special = K.Target{ "Limitless", cooldown = 15, range = 60, noHit = true, startup = 0.1, endlag = 0.15, awakenCost = 0.06, tip = "SPECIAL" },

	awakening = {
		name = "Six Eyes",
		duration = 60,
		heal = 25,
		-- The user removes the blindfold to reveal the Six Eyes.
		-- TODO awakening variant "0.2 Domain": special during the sequence expands Infinite Void for 0.2s then a 3 phase rush (220).
		abilities = {
			-- A controllable blue vortex that pulls in and harms everything near it for 20 ticks.
			-- TODO variant "Unlimited Purple": shooting Max Blue's finisher with Max Red (50-100).
			[ 1 ] = K.AoE{ "Lapse Blue MAX", cooldown = 17, startup = 0.6, damage = 44, hits = 8, interval = 0.25, radius = 14, offset = 12, up = 4,
				type = "explosion", block = "none", bypassRagdoll = true, ragdoll = { h = -15, v = 20 }, color = "blue" },
			-- A repelling orb charged for a little over a second and fired forward; damage falls off with range.
			-- TODO special variant: with Limitless first, the red rebounds back to the user.
			[ 2 ] = K.Projectile{ "Reversal Red MAX", cooldown = 10, startup = 1.1, damage = 30, speed = 150, range = 90, radius = 5,
				type = "explosion", block = "none", bypassRagdoll = true, explode = 12, color = "red", ragdoll = { h = 60, v = 25 }, tip = "SPECIAL" },
			-- An imaginary purple mass rushes forward and atomizes anything in its path.
			[ 3 ] = K.Projectile{ "Hollow Purple", cooldown = 40, startup = 1.6, damage = 70, speed = 90, range = 160, radius = 10, pierce = true,
				type = "explosion", block = "none", bypassRagdoll = true, uninterruptible = true, explode = 14, color = "purple",
				ragdoll = { h = 50, v = 30 }, crater = 1800 },
			-- Domain Expansion: everyone inside is flooded with information and can't act for 14s.
			[ 4 ] = K.Domain{ "Infinite Void", cooldown = 120, duration = 14, sureHit = "stun", color = "blue" },
		},
		special = K.Target{ "Limitless", cooldown = 15, range = 60, noHit = true, startup = 0.1, endlag = 0.15, tip = "SPECIAL" },
	},
} )
