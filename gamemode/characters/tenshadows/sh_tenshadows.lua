-- Ten Shadows (Megumi Fushiguro). Moves are JJS.Kit placeholders built from the JJS fandom wiki and
-- the dogslamloop frame data wiki; comments describe what the real move does.
-- Awakened, G switches between the base and awakened moves.

local K = JJS.Kit
local S = JJS.STUD

-- In Lurking Shadow: the speed buff it gives (1.9x)
local function InShadow( ply ) return ply:GetJBuffEnd() > CurTime() and ply:GetJBuffMult() > 1.8 end

-- Nue flies faster at a ragdolled enemy under the cursor
local function AimRagdoll( ply )
	local t = K.AimTarget( ply, 90 * S )
	return IsValid( t ) and t:GetJRagdolled()
end

-- Rabbit Escape swarming a grounded target (Nue can't be summoned meanwhile)
local function Swarming( ply )
	for _, z in ipairs( K.Zones ) do
		if z.owner == ply and z.p.name == "Rabbit Escape" and IsValid( z.ent ) and z.ent:IsOnGround() and CurTime() < z.stop then return true end
	end
	return false
end

-- Where the cursor points on the ground (Max Elephant's red circle), up to 70 studs away
local function AimGround( ply )
	local eye = ply:EyePos()
	local tr = util.TraceLine( { start = eye, endpos = eye + ply:GetAimVector() * 70 * S, mask = MASK_SOLID_BRUSHONLY } )
	local down = util.TraceLine( { start = tr.HitPos + Vector( 0, 0, 8 ), endpos = tr.HitPos - Vector( 0, 0, 1200 ), mask = MASK_SOLID_BRUSHONLY } )
	return down.Hit and down.HitPos or tr.HitPos
end

local BASE = {
	-- Aiming at an enemy within 40 studs, rabbits swarm them from the shadows (0.5 each, 14 total): they can't walk or dash
	-- while it lasts (about 2s of forced blocking). The user is free meanwhile; getting hit stops the rabbits.
	-- Lurking Shadow variant "Rabbit Entrance": hops out of the shadow on rabbits, knocking nearby foes away (14, melee, unblockable).
	[ 1 ] = K.Zone{ "Rabbit Escape", cooldown = 18, target = true, range = 40, startup = 0.4, endlag = 0.2, radius = 5, duration = 3.5, tick = 0.125,
		damage = 0.5, stun = 0.2, slow = { 0.1, 0.3 }, stopOnHit = true, type = "swarm", block = "all", bypassRagdoll = true, color = "white",
		tip = "SPECIAL",
		cond = { test = InShadow, kind = "aoe", target = false, damage = 14, radius = 10, startup = 0.2, type = "melee", block = "none",
			ragdoll = { h = 45, v = 35 } } },
	-- Nue swoops from the skies toward the cursor (16): true ragdoll (not while awakened), unblockable; faster at a ragdolled
	-- enemy. Can't be summoned while Rabbit Escape swarms a grounded target. One of the best evasive baits: it can only be
	-- evaded before it hits.
	-- Special during the windup "Nue Flight": grabs onto Nue's leg and flies alongside it, blockable from all sides by
	-- airborne targets (22s; Lurking Shadow: 10s, needn't be ready).
	[ 2 ] = K.Summon{ "Nue", cooldown = 20, startup = 0.45, damage = 16, speed = 90, range = 90, radius = 5, type = "explosion", block = "none",
		bypassRagdoll = true, trueRag = true, ragdoll = { h = 40, v = 30 }, tip = "SPECIAL",
		CanUse = function( ply ) return not Swarming( ply ) end,
		cond = { test = AimRagdoll, speed = 150 },
		special = { kind = "mobility", travel = 45, time = 0.8, dir = "aim", free = true, cooldown = 22, specialCooldown = 10, damage = 16,
			type = "explosion", block = "all" } },
	-- Aiming at a target within 75 studs, a giant frog's tongue wraps around them and pulls them in (no damage).
	-- Combo "The Well's Unknown Abyss" (Nue during the startup): tiny winged toads grab the target, lift and slam them,
	-- then launch them (12); doesn't need or use Nue's cooldown.
	[ 3 ] = K.Target{ "Toad", cooldown = 15, teleport = false, range = 75, startup = 0.5, damage = 0, type = "swarm", bypassRagdoll = true,
		ragdoll = { h = -60, v = 18, time = 0.6 }, color = "green",
		combo = { [ 2 ] = { free = true, damage = 12, hits = 3, interval = 0.35, ragdoll = { h = 10, v = 55 } } } },
	-- First use summons an improved Divine Dog; the next three uses command it to swipe the closest enemy within 50 studs
	-- (6 each, ragdolling away). Uncancelable once used (except by ragdolling the user); blocks the view.
	[ 4 ] = K.Target{ "Divine Dog: Totality", cooldown = 20, charges = 3, chargeDelay = 1, teleport = false, range = 50, cone = 0.5,
		startup = 0.3, damage = 6, type = "bullet", block = "all", bypassRagdoll = true, uninterruptible = true, ragdoll = { h = 45, v = 18 },
		color = "shadow" },
}

-- Sinks into the shadow (~1.15s, dogslamloop: ~2s): much faster movement, no abilities except Rabbit Escape and Divine Dog;
-- M1 or the special leaves early. Still vulnerable.
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
			-- A massive elephant falls from the sky and crushes the area (35, true ragdoll).
			-- Held: the user stays still and steers the landing spot (a red circle) with the cursor.
			[ 1 ] = K.AoE{ "Max Elephant", cooldown = 25, startup = 1.1, damage = 35, radius = 16, offset = 25, type = "explosion", block = "none",
				bypassRagdoll = true, trueRag = true, crater = 1600, ragdoll = { h = 10, v = -30 }, color = "blue", holdMoveMult = 0,
				hold = { time = 0.3, startup = 0.8, moveMult = 0, center = AimGround } },
			-- The user rides the Great Serpent Orochi toward where they aim; whoever is near its jaws is grabbed (11) and poisoned
			-- (2/s for 9s) until dispelled.
			[ 2 ] = K.Rush{ "Great Serpent", cooldown = 25, startup = 0.5, travel = 40, time = 1, hits = 5, interval = 0.4, hitDamage = { 11, 4.5, 4.5, 4.5, 4.5 },
				type = "melee", block = "none", bypassRagdoll = true, trueRag = true, ragdoll = { h = 30, v = 40 } },
			-- Two shadow clones run forward with the user; a target reached is battered (13) then bat-swung away (5).
			-- Domain invasion "Chimera Shadow Garden": against a domain border, the user lays out their own domain and opens a
			-- hole in it: anyone can enter or leave and its sure-hit stops. The user stays in place, drained 4 HP/s, until it's
			-- closed by Shadow Swarm again, a hit, or no health to spare (then 30s cooldown).
			[ 3 ] = K.Rush{ "Shadow Swarm", cooldown = 15, startup = 0.35, travel = 35, time = 0.6, hits = 6, interval = 0.2,
				hitDamage = { 2.6, 2.6, 2.6, 2.6, 2.6, 5 }, type = "melee", block = "none", bypassRagdoll = true, ragdoll = { h = 60, v = 20 } },
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

------------------------------------------------------------------------------------------
-- Chimera Shadow Garden
------------------------------------------------------------------------------------------

local D = JJS.Domain

JJS.RegisterAction( "tenshadows.garden", {
	dur = 600,
	moveMult = 0,
	noJump = true,
	gesture = "gesture_becon",
	start = function( ply )
		if SERVER then JJS.Util.Effect( "jjs_kit_cast", JJS.Util.BodyCenter( ply ), nil, ply, 2.5, K.COLOR_ID.shadow ) end
	end,
	think = function( ply )
		if CLIENT then return end
		local d = ply.jjs_garden
		if not IsValid( d ) or d:GetInvader() ~= ply then JJS.StopAction( ply, true ) return end
		-- the strain of the portal: 4 HP/s, closing when there's no health left to spare
		local dmg = 4 * FrameTime()
		if ply:GetJHP() <= dmg + 1 then JJS.StopAction( ply, true ) return end
		JJS.ApplyDamage( ply, nil, dmg, { type = JJS.DMG.SPECIAL } )
	end,
	finish = function( ply )
		if SERVER and IsValid( ply.jjs_garden ) then D.EndInvasion( ply.jjs_garden ) end
		ply.jjs_garden = nil
		JJS.SetCooldown( ply, 3, 30 )
	end,
} )

local swarm = JJS.Characters.tenshadows.awakening.abilities[ 3 ]
local swarmCanUse, swarmUse = swarm.CanUse, swarm.Use
swarm.CanUse = function( ply, slot, mv )
	-- pressed again: closes the hole
	local act = JJS.GetAction( ply )
	if act and act.name == "tenshadows.garden" then return true end
	return swarmCanUse( ply, slot, mv )
end
swarm.Use = function( ply, mv, slot )
	local act = JJS.GetAction( ply )
	if act and act.name == "tenshadows.garden" then JJS.StopAction( ply, true ) return end
	local d = D.BorderNear( ply, 10 * S )
	if IsValid( d ) then
		if SERVER then
			ply.jjs_garden = d
			D.Invade( d, ply )
		end
		JJS.StartAction( ply, "tenshadows.garden", slot )
		return
	end
	swarmUse( ply, mv, slot )
end

if SERVER then
	-- Nue's ragdoll isn't true while awakened
	hook.Add( "JJS_PreHit", "JJS_NueAwakened", function( victim, hit )
		local a = hit.attacker
		if hit.kit and hit.kit.name == "Nue" and hit.ragdoll and IsValid( a ) and a:GetJChar() == "tenshadows" and a:GetJAwakened() then
			hit.ragdoll.trueRag = false
		end
	end )
end
