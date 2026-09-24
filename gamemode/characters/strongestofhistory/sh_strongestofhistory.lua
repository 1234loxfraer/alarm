-- Strongest Of History (Heian Sukuna, overpowered). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.
-- Incantation (special) chants up to 4 times; the chant count (mode) upgrades Strong Dismantle.

local K = JJS.Kit

local function ResetChant( ply ) ply:SetJMode( 0 ) end

K.Character( "strongestofhistory", {
	name = "Strongest Of History",
	category = "op",
	hp = 100,
	scale = 1.4,
	model = K.Model( "strongestofhistory", "models/player/charple.mdl" ),
	color = Color( 255, 60, 60 ),

	passives = {
		{ "Pinnacle Of Jujutsu Sorcery", "Cosmetic: an extra pair of arms and 1.4x size." },
	},

	abilities = {
		[ 1 ] = K.ByMode{
			-- No chant: a swinging gesture sending two large slashes toward the target (10 each, unblockable; the second comes
			-- later with no target in sight).
			K.Projectile{ "Strong Dismantle", cooldown = 4, startup = 0.3, damage = 10, count = 2, volley = 0.3, range = 90, speed = 260, radius = 6,
				pierce = true, type = "special", block = "none", bypassRagdoll = true, color = "red" },
			-- 1 chant, "Dismantle": a barrage of six Dismantles (5 each).
			K.Projectile{ "Dismantle Barrage", cooldown = 4, startup = 0.3, damage = 5, count = 6, volley = 0.1, spread = 5, range = 90, speed = 260,
				radius = 5, pierce = true, type = "special", block = "none", bypassRagdoll = true, color = "red", onUse = ResetChant },
			-- 2 chants: levitates arms spread, laughing, releasing more and more slashes within 25 studs (14; blocked: 75% less,
			-- no stun or execution), then suddenly grows and eradicates everything within 27.5 studs (5, unblockable).
			K.AoE{ "Disgraced Sovereign", cooldown = 4, startup = 0.5, hits = 8, interval = 0.2, radius = 27.5, type = "special",
				hitDamage = { 2, 2, 2, 2, 2, 2, 2, 5 }, hitBlock = { "normal", "normal", "normal", "normal", "normal", "normal", "normal", "none" },
				blockDamage = 3.5, bypassRagdoll = true, color = "red", ragdoll = { h = 50, v = 30 },
				onUse = function( ply ) ResetChant( ply ) JJS.Hover( ply, 1.8 ) end },
			-- 3 chants, "Know your place": a vertical World Cutting Slash splitting anyone in its trajectory (150).
			K.Beam{ "World Cutting Slash", cooldown = 4, startup = 0.6, damage = 150, range = 200, radius = 3, pierce = true, type = "special",
				block = "none", bypassRagdoll = true, color = "red", onUse = ResetChant },
			-- 4 chants, "It's over": the left hand points forward and a grid of dismantles travels ~150 studs, disassembling
			-- anyone caught (150; 5% awakening).
			K.Projectile{ "Dismantle Net", cooldown = 4, startup = 0.5, damage = 150, range = 150, speed = 150, radius = 14, pierce = true,
				type = "special", block = "none", bypassRagdoll = true, color = "red", awakenCost = 0.05, onUse = ResetChant },
		},
		-- Conjures fire, claps twice for i-frames, molds the flames into an arrow ("Prepare") and fires it ("Open") at high
		-- speed: a flare, then an explosion incinerating anything near the impact (70) and a shockwave of unstoppable force
		-- hitting harder the farther out (15 to 30; TODO: the distance scaling).
		[ 2 ] = K.Projectile{ "Open FURNACE", cooldown = 12, startup = 1.2, damage = 70, iframes = 1.2, range = 150, speed = 250, radius = 6,
			type = "explosion", block = "none", bypassRagdoll = true, explode = 18, explodeDamage = 22, crater = 2200, ragdoll = { h = 80, v = 40 },
			color = "orange" },
		-- "Get lost!": a cursed-energy fist wound back, then a long lunge; landed, holds them by the face ("Brat!") and releases
		-- black and white cuts across their body, sending them flying dismembered (150; can't hit ragdolls).
		-- USE TWICE during the initial stun, before the arm is fully wound: a Black Flash ("Kill", 35), which keeps the move
		-- off cooldown when it lands.
		[ 3 ] = K.Grab{ "Cleave Rush", cooldown = 5, startup = 0.4, hits = 2, interval = 0.8, hitDamage = { 0, 150 }, lunge = 45, type = "special",
			block = "none", ragdoll = { h = 80, v = 30 }, tip = "USE TWICE",
			again = K.Melee{ "Cleave Rush: Black Flash", window = 0.6, startup = 0.15, damage = 35, type = "melee", block = "none", color = "black",
				ragdoll = { h = 90, v = 25 }, onHit = function( ply ) JJS.SetCooldown( ply, 3, 0 ) end } },
		-- Kamutoke calls torrents of lightning around the user, flinging people away (15 per bolt).
		[ 4 ] = K.AoE{ "Kamutoke", cooldown = 7, startup = 0.6, damage = 45, hits = 3, interval = 0.3, radius = 25, type = "special", block = "none",
			bypassRagdoll = true, crater = 1500, ragdoll = { h = 50, v = 40 }, color = "cyan" },
	},
	-- Crosses the arms with a hand sign and chants: "Scale Of The Dragon...", "Recoil...", "Twin Meteors" (5% awakening
	-- each); each of the first three gives a better Strong Dismantle, the fourth the Dismantle Net.
	special = K.Modes{ "Incantation", cooldown = 2, awakenCost = 0.05, modes = { "", "CHANT 1", "CHANT 2", "CHANT 3", "CHANT 4" }, color = "red" },

	-- Domain awakening: fingers crossed, a "DOMAIN EXPANSION" pop-up on every screen, then an impromptu Malevolent Shrine
	-- without a barrier that reaches the whole map, raining Cleave and Dismantle (3 per slash, 0.5 if blocked) for 20s.
	-- TODO: no barrier (it uses the normal domain for now), limited destruction range.
	awakenMove = K.Domain{ "Incomplete Shrine", duration = 20, radius = 300, sureHit = "damage", dps = 14, blockMult = 0.17, color = "red" },
} )
