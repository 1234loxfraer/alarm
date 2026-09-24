-- Ten Shadows (Megumi Fushiguro). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does. Awakened, G switches between the base and awakened moves.

local K = JJS.Kit

local BASE = {
	-- Aiming at an enemy within 40 studs, a swarm of rabbits overwhelms them: they can't walk or dash while it lasts.
	-- TODO special variant: from Lurking Shadow, hops out on rabbits knocking foes away (14, melee, unblockable).
	[ 1 ] = K.Target{ "Rabbit Escape", cooldown = 18, teleport = false, range = 40, startup = 0.4, damage = 14, hits = 7, interval = 0.25,
		type = "swarm", block = "all", bypassRagdoll = true, slow = { 0.1, 2.5 }, color = "white", tip = "SPECIAL" },
	-- Nue swoops in from the skies toward the cursor; its ragdoll can't be evaded.
	-- TODO special variant: pressing the special in the windup grabs onto Nue's leg to fly with it.
	[ 2 ] = K.Summon{ "Nue", cooldown = 20, startup = 0.45, damage = 16, speed = 90, range = 90, radius = 5, block = "none",
		bypassRagdoll = true, trueRag = true, ragdoll = { h = 40, v = 30 }, tip = "SPECIAL" },
	-- Aiming at a target within 75 studs, a giant frog's tongue wraps around them and pulls them in.
	-- TODO variant "Well's Unknown Abyss": Nue during Toad's startup (12, lift, slam and launch).
	[ 3 ] = K.Target{ "Toad", cooldown = 15, teleport = false, range = 75, startup = 0.5, damage = 0, type = "swarm",
		bypassRagdoll = true, ragdoll = { h = -60, v = 18, time = 0.6 }, color = "green" },
	-- First use summons an improved Divine Dog; the next three uses command it to maul the closest enemy within 50 studs.
	[ 4 ] = K.Target{ "Divine Dog: Totality", cooldown = 20, charges = 3, chargeDelay = 1, teleport = false, range = 50, cone = 0.5,
		startup = 0.3, damage = 6, type = "bullet", block = "all", bypassRagdoll = true, ragdoll = { h = 45, v = 18 }, color = "shadow" },
}

-- Sinks into the shadow for 1.15s: much faster movement but no abilities; still vulnerable.
-- TODO special variant: stores a held item or throwable in the shadow.
local LURKING = K.Buff{ "Lurking Shadow", cooldown = 10, startup = 0.05, duration = 0.05, endlag = 0, speed = 1.9, speedTime = 1.15, color = "shadow" }

K.Character( "tenshadows", {
	name = "Ten Shadows",
	category = "complete",
	hp = 85,
	model = K.Model( "tenshadows", "models/player/group01/male_08.mdl" ),
	color = Color( 120, 120, 200 ),

	-- per-hit M1 frames { startup, recovery, block endlag } (dogslamloop)
	m1 = {
		Frames = { { 13, 6, 13 }, { 13, 6, 13 }, { 12, 7, 15 } },
	},

	abilities = BASE,
	special = LURKING,

	awakening = {
		name = "Insanity",
		duration = 60,
		heal = 15,
		-- "Picture it in your head! With no boundaries!"
		abilities = {
			-- A massive elephant falls from the sky and crushes the area.
			-- TODO hold: stay still and steer the landing spot (red circle) with the cursor.
			[ 1 ] = K.AoE{ "Max Elephant", cooldown = 25, startup = 1.1, damage = 35, radius = 16, offset = 35, type = "explosion", block = "none",
				bypassRagdoll = true, trueRag = true, crater = 1600, ragdoll = { h = 10, v = -30 }, color = "blue" },
			-- The user rides the Great Serpent Orochi, which grabs whoever is near its jaws (11) and poisons them (2/s for 9s).
			[ 2 ] = K.Grab{ "Great Serpent", cooldown = 25, startup = 0.5, damage = 29, hits = 5, interval = 0.4, lunge = 25, type = "melee",
				block = "none", bypassRagdoll = true, trueRag = true, ragdoll = { h = 30, v = 40 } },
			-- Two shadow clones run forward with the user; a target reached is battered (13) then bat-swung away (5).
			-- TODO domain invasion "Chimera Shadow Garden": used against a domain border, invades it (drains 4 HP/s).
			[ 3 ] = K.Grab{ "Shadow Swarm", cooldown = 15, startup = 0.35, damage = 18, hits = 5, interval = 0.2, lunge = 30, type = "melee",
				block = "none", bypassRagdoll = true, ragdoll = { h = 60, v = 20 } },
			-- Aiming at an opponent within 60 studs, a 3 second summoning ritual turns the user into Mahoraga (40% awakening).
			[ 4 ] = K.Target{ "Mahoraga", cooldown = 120, teleport = false, noHit = true, range = 60, startup = 3, endlag = 0, moveMult = 0,
				awakenCost = 0.4, color = "white",
				onEnd = function( ply ) JJS.Transform( ply, "mahoraga", "tenshadows" ) end },
		},
		special = LURKING,
		-- Switch: G swaps back to the base moves (and again to the awakened ones)
		alt = { name = "Base Shikigami", abilities = BASE, special = LURKING },
	},

	AwakenPress = function( ply )
		if not ply:GetJAwakened() then return end
		ply:SetJKitSet( ply:GetJKitSet() == 1 and 0 or 1 )
		return true
	end,
} )
