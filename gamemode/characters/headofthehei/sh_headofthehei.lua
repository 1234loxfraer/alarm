-- Head of the Hei (Naoya Zenin). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.

local K = JJS.Kit

K.Character( "headofthehei", {
	name = "Head of the Hei",
	category = "complete",
	hp = 90,
	model = K.Model( "headofthehei", "models/player/group03/male_02.mdl" ),
	color = Color( 240, 240, 180 ),

	-- Projectionism: 2 damage per M1, the final hit always knocks back with evadable stun
	m1 = { Damage = { 2, 2, 2, 2 } },

	passives = {
		{ "Projectionism", "M1s deal 2 each, no uppercuts/downslams, the front dash becomes a second side dash. (partly TODO)" },
		{ "Frame Freeze", "Moves build Projection on targets (or the user on a miss); a full meter freezes them in a frame. (TODO)" },
	},

	abilities = {
		-- Dashes 15 studs backward with short melee i-frames, then spins back into a heavy kick throwing the target away.
		[ 1 ] = K.Melee{ "Projection Breaker", cooldown = 18, startup = 0.5, damage = 9, reach = 9, type = "melee", bypassRagdoll = true,
			armor = "melee", iframes = 0.3, ragdoll = { h = 60, v = 20 } },
		-- A tanto stab to the abdomen (5) inflicting 3 Bleed stacks (3 each) and Hemorrhage (1.3 per tick).
		-- TODO: Bleed stacks slow the Projection drain; Hemorrhage.
		[ 2 ] = K.Melee{ "Bleedout", cooldown = 20, startup = 0.45, damage = 5, type = "melee", block = "none", bypassRagdoll = true, stun = 1,
			color = "blood" },
		-- Runs 35 studs and punches (6); a hit is followed by a flurry of swift blows (0.5 each, 8 total).
		-- TODO: pressed again extends the run by 15 studs, a third time by 23 more and makes it unblockable; air target lock-on.
		[ 3 ] = K.Grab{ "Decisive Strike", cooldown = 18, startup = 0.2, damage = 14, hits = 6, interval = 0.15, lunge = 35, type = "melee",
			bypassRagdoll = true, stun = 1.2, tip = "USE THRICE" },
		-- Quick-steps to the destination: a back-handed smack (6.5) then a sweep kick propelling the target away (5.5).
		-- TODO variant: on a framed target the smack launches them and they're tossed where the user aims (19.5 + 5).
		[ 4 ] = K.Melee{ "Cursory Impact", cooldown = 16, startup = 0.3, damage = 12, hits = 2, interval = 0.35, lunge = 20, type = "melee",
			block = "none", trueRag = true, ragdoll = { h = 55, v = 15 } },
	},
	-- Aiming at a position within 50 studs, covers the distance in a second leaving an afterimage. Costs 5% awakening.
	-- TODO: a second teleport with a target in sight; punching a framed target (12).
	special = K.Mobility{ "Projection Sorcery", cooldown = 18, travel = 50, time = 0.5, dir = "aim", awakenCost = 0.05 },

	awakening = {
		name = "Vengeance",
		duration = 60,
		heal = 90,
		-- The awakening performs a slowed Bleedout; if struck by melee the opponent turns the tanto on the user, who
		-- reincarnates as a vengeful curse ("No way...").
		-- TODO passive "Vengeance": faster movement, M1s pull further and add 10% Projection; the awakening ends in death.
		abilities = {
			-- Boosts forward, crashing its shell into anyone in the way (5, +1.5 per Acceleration up to 15).
			[ 1 ] = K.Mobility{ "Top Speed", cooldown = 14, startup = 0.2, travel = 45, time = 0.5, damage = 8, type = "melee", block = "none",
				bypassRagdoll = true, ragdoll = { h = 60, v = 20 } },
			-- Freezes the air in front into a line of 15 glass frames that shatter when hit (7 per frame).
			[ 2 ] = K.AoE{ "Flash Freezing", cooldown = 18, startup = 0.5, damage = 14, hits = 2, interval = 0.3, radius = 10, offset = 15,
				type = "explosion", block = "none", bypassRagdoll = true, color = "cyan" },
			-- Tendrils surge from the ground to grab enemies within 25 studs, immobilizing them for about a second.
			[ 3 ] = K.AoE{ "Tendril Grab", cooldown = 10, startup = 0.5, damage = 0, radius = 25, stun = 1.1, slow = { 0, 1.1 }, type = "special",
				block = "none", bypassRagdoll = true, color = "blood" },
			-- Domain Expansion: everyone inside must follow the 24 FPS rule; moving frames and shatters their cells.
			-- Casting it ends the curse form (back to the base moves with the same HP fraction).
			[ 4 ] = K.Domain{ "Time Cell Moon Palace", cooldown = 60, duration = 25, sureHit = "damage", dps = 3, color = "blood",
				onEnd = function( ply ) JJS.ExitAwakening( ply ) end },
		},
		-- Spins rapidly, damaging the area (1 per spin, 7 total) and building speed. Can't kill.
		special = K.AoE{ "Acceleration", cooldown = 9, startup = 0.2, damage = 7, hits = 7, interval = 0.08, radius = 8, type = "explosion",
			block = "all", bypassRagdoll = true, stun = 0.3, color = "white",
			onUse = function( ply )
				ply:SetJBuffMult( math.min( 1.6, ply:GetJBuffEnd() > CurTime() and ply:GetJBuffMult() + 0.08 or 1.08 ) )
				ply:SetJBuffEnd( CurTime() + 20 )
			end },
	},
} )
