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
			-- No chant: two large slashes toward the target (10 each).
			K.Projectile{ "Strong Dismantle", cooldown = 4, startup = 0.3, damage = 10, count = 2, volley = 0.3, range = 90, speed = 260, radius = 6,
				pierce = true, type = "special", block = "none", bypassRagdoll = true, color = "red" },
			-- 1 chant, "Dismantle": a barrage of six Dismantles (5 each).
			K.Projectile{ "Dismantle Barrage", cooldown = 4, startup = 0.3, damage = 5, count = 6, volley = 0.1, spread = 5, range = 90, speed = 260,
				radius = 5, pierce = true, type = "special", block = "none", bypassRagdoll = true, color = "red", onUse = ResetChant },
			-- 2 chants: levitates releasing more and more slashes within 25 studs (14), then eradicates everything within 27.5 (5).
			K.AoE{ "Disgraced Sovereign", cooldown = 4, startup = 0.5, damage = 19, hits = 8, interval = 0.2, radius = 27.5, type = "special",
				blockDamage = 8.5, bypassRagdoll = true, color = "red", ragdoll = { h = 50, v = 30 }, onUse = ResetChant },
			-- 3 chants, "Know your place": a vertical World Cutting Slash splitting anyone in its trajectory (150).
			K.Beam{ "World Cutting Slash", cooldown = 4, startup = 0.6, damage = 150, range = 200, radius = 3, pierce = true, type = "special",
				block = "none", bypassRagdoll = true, color = "red", onUse = ResetChant },
			-- 4 chants, "It's over": a grid of dismantles travelling ~150 studs, killing anyone caught (150).
			K.Projectile{ "Dismantle Net", cooldown = 4, startup = 0.5, damage = 150, range = 150, speed = 150, radius = 14, pierce = true,
				type = "special", block = "none", bypassRagdoll = true, color = "red", onUse = ResetChant },
		},
		-- Claps twice for i-frames, molds flames into an arrow ("Prepare") and fires it ("Open") at high speed (70, 15-30 shockwave).
		[ 2 ] = K.Projectile{ "Open FURNACE", cooldown = 12, startup = 1.2, damage = 70, iframes = 1.2, range = 150, speed = 250, radius = 6,
			type = "explosion", block = "none", bypassRagdoll = true, explode = 18, crater = 2200, ragdoll = { h = 80, v = 40 }, color = "orange" },
		-- "Get lost!": lunges a large distance; landed, holds them by the face ("Brat!") and cleaves (150).
		-- Follow-up: pressed again during the stun, a Black Flash (35, stays off cooldown if it lands).
		[ 3 ] = K.Grab{ "Cleave Rush", cooldown = 5, startup = 0.4, damage = 150, hits = 2, interval = 0.8, lunge = 45, type = "special", block = "none",
			ragdoll = { h = 80, v = 30 }, tip = "USE TWICE",
			again = K.Melee{ "Cleave Rush: Black Flash", window = 0.6, startup = 0.15, damage = 35, type = "melee", block = "none", color = "black",
				ragdoll = { h = 90, v = 25 } } },
		-- Kamutoke calls torrents of lightning around the user, flinging people away (15 per bolt).
		[ 4 ] = K.AoE{ "Kamutoke", cooldown = 7, startup = 0.6, damage = 45, hits = 3, interval = 0.3, radius = 25, type = "special", block = "none",
			bypassRagdoll = true, crater = 1500, ragdoll = { h = 50, v = 40 }, color = "cyan" },
	},
	-- Crosses the arms and chants ("Scale Of The Dragon.", "Recoil."...). Costs 5% awakening.
	special = K.Modes{ "Incantation", cooldown = 2, modes = { "", "CHANT 1", "CHANT 2", "CHANT 3", "CHANT 4" }, color = "red" },

	-- Domain awakening: an unenclosed Malevolent Shrine whose slashes reach far (3 per slash, 0.5 if blocked) for 20s.
	awakenMove = K.Domain{ "Incomplete Shrine", duration = 20, radius = 90, sureHit = "damage", dps = 14, color = "red" },
} )
