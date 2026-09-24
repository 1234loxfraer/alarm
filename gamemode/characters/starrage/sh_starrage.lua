-- Star Rage (Yuki Tsukumo, base-only). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.
-- Mass (Res1, 0..1) is built by holding the special and spent by the special variants (TODO).

local K = JJS.Kit

K.Character( "starrage", {
	name = "Star Rage",
	category = "baseonly",
	hp = 100,
	model = K.Model( "starrage", "models/player/mossman.mdl" ),
	color = Color( 255, 200, 90 ),

	-- per-hit M1 frames { startup, recovery, block endlag } (dogslamloop)
	m1 = {
		Frames = { { 14, 5, 11 }, { 14, 5, 11 }, { 14, 5, 11 } },
	},

	passives = {
		{ "Garuda", "Cosmetic: a serpentine shikigami orbiting the user." },
	},

	abilities = {
		-- Kicks Garuda forward as a ball (slight auto-aim) hitting the torso, then it hovers back.
		-- Follow-up: pressed again as it returns, punched forward again, ragdolling toward the user (7, perfect-blockable).
		-- TODO special variant: all stored mass kicks it back at excessive speed, ricocheting (24).
		[ 1 ] = K.Projectile{ "Garuda Rebound", cooldown = 14, startup = 0.3, damage = 5, range = 50, speed = 160, radius = 3, type = "bullet",
			block = "all", bypassRagdoll = true, color = "gold", tip = "USE TWICE",
			again = K.Projectile{ "Garuda Rebound: Punch", window = 1.2, startup = 0.15, damage = 7, range = 50, speed = 180, radius = 3, type = "bullet",
				block = "pre", bypassRagdoll = true, ragdoll = { h = -30, v = 15 }, color = "gold" } },
		-- A sweep then an upward kick propelling the target up and away (7 each).
		-- TODO special variants (30% mass each): a concussive head kick, then a knee kick ejecting them (16 / 24).
		[ 2 ] = K.Melee{ "Rising Rage", cooldown = 15, startup = 0.3, damage = 14, hits = 2, interval = 0.35, type = "melee", ragdoll = { h = 40, v = 45 } },
		-- Charges the fist and lunges into a bone-breaking blow (360 aim while airborne).
		-- TODO special variant (30% mass): ends in a ground smash launching everyone around (12).
		[ 3 ] = K.Melee{ "Mass Breaker", cooldown = 15, startup = 0.5, damage = 15, lunge = 18, type = "melee", block = "none", trueRag = true,
			ragdoll = { h = 70, v = 20 } },
		-- Stabs forward with Garuda's body (7) then a crushing axe kick knocking the target away (7).
		-- TODO special variant (50% mass): Garuda grabs and pulls the enemy in, then whips them twice (21).
		[ 4 ] = K.Melee{ "Garuda Stab", cooldown = 14, startup = 0.35, damage = 14, hits = 2, interval = 0.4, reach = 11, type = "melee", block = "none",
			ragdoll = { h = 50, v = 10 } },
	},
	-- Held: converts cursed energy into virtual mass (up to 21% of the awakening bar).
	special = K.Buff{ "Mass Buildup", cooldown = 16, startup = 0.1, duration = 0.9, moveMult = 0.3, color = "gold",
		onUse = function( ply ) ply:SetJRes1( 1 ) end },

	-- The real one triggers after death: the user latches onto a target and raises their virtual mass beyond the limit,
	-- turning into a black hole (500/s, falling off with distance). Placeholder: a massive pull-in blast.
	awakenMove = K.AoE{ "Unrestricted Density", startup = 2.5, damage = 120, hits = 4, interval = 0.3, radius = 30, type = "domain", block = "none",
		bypassRagdoll = true, trueRag = true, uninterruptible = true, crater = 3000, ragdoll = { h = -40, v = 20 }, color = "black" },
} )
