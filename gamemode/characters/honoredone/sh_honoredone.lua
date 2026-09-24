-- Honored One (Satoru Gojo). Moves are JJS.Kit placeholders built from the JJS fandom wiki and
-- the dogslamloop frame data wiki; comments describe what the real move does.

local K = JJS.Kit
local S = JJS.STUD

-- 0.2 Domain: the rush after the instant Infinite Void (3 phases: 7 x 5, 6 x 20, 65)
local RUSH = K.Build( "honoredone", "rush02", K.Rush{ "0.2 Domain: Rush", startup = 0.3, travel = 60, time = 0.5, hits = 14, interval = 0.18,
	hitDamage = { 5, 5, 5, 5, 5, 5, 5, 20, 20, 20, 20, 20, 20, 65 }, type = "melee", block = "none", bypassRagdoll = true, trueRag = true,
	iframesOnHit = 3, ragdoll = { h = 90, v = 30 }, color = "blue",
	onFinish = function( ply )
		-- burnt out: back to the base moves, on cooldown (Limitless excluded)
		if ply:GetJAwakened() then JJS.ExitAwakening( ply ) end
		for slot = 1, 4 do JJS.SetCooldown( ply, slot, 15 ) end
	end } )

-- Unlimited Purple: Lapse Blue MAX's lingering orb (after a kill) shot by Reversal Red MAX
local function PurpleNuke( ply, pos )
	ply.jjs_blueOrb = nil
	timer.Simple( 3, function()
		if not IsValid( ply ) then return end
		for _, v in ipairs( K.SphereTargets( pos, 45 * S, ply, true ) ) do
			local d = math.Clamp( v:GetPos():Distance( pos ) / ( 45 * S ), 0, 1 )
			JJS.Hit( v, { attacker = ply, damage = Lerp( d, 100, 50 ), type = JJS.DMG.EXPLOSION, block = "none", bypassRagdoll = true,
				ragdoll = { time = 1.5, trueRag = true, vel = JJS.Util.Flat( v:GetPos() - pos ) * 90 * S + Vector( 0, 0, 40 * S ) } } )
		end
		K.Effect( "jjs_kit_burst", pos, Vector( 0, 0, 1 ), ply, 45 * S, K.Params( K.AoE{ "Unlimited Purple", color = "purple" } ) )
		JJS.Destruction.GroundImpact( pos, 3000 )
	end )
	-- the whole awakening bar goes into it
	if ply:GetJAwakened() then JJS.ExitAwakening( ply ) end
end
local function RedMeetsBlue( ply, pos )
	local o = ply.jjs_blueOrb
	if o and CurTime() < o.t and pos:DistToSqr( o.pos ) < ( 8 * S ) ^ 2 then
		PurpleNuke( ply, o.pos )
		return true
	end
end

-- Teleports in front of the aimed target. Costs 6% awakening.
local LIMITLESS = K.Target{ "Limitless", cooldown = 15, range = 60, noHit = true, startup = 0.1, endlag = 0.15, awakenCost = 0.06,
	color = "blue", tip = "SPECIAL",
	-- "Air Kick": on an airborne target, appears over them and kicks them down (8, unblockable, true ragdoll)
	airTarget = { noHit = false, damage = 8, type = "melee", block = "none", bypassRagdoll = true, trueRag = true, startup = 0.15,
		ragdoll = { h = 10, v = -45 } },
}

K.Character( "honoredone", {
	name = "Honored One",
	category = "complete",
	hp = 100,
	model = K.Model( "honoredone", "models/player/group01/male_09.mdl" ),
	color = Color( 110, 190, 255 ),

	-- per-hit M1 frames { startup, recovery, block endlag } (dogslamloop)
	m1 = {
		Frames = { { 14, 5, 11 }, { 12, 8, 17 }, { 12, 8, 17 } },
	},

	passives = {
		{ "Infinity", "Cosmetic: the user poses and hovers instead of guarding when blocking." },
	},

	abilities = {
		-- Aiming at an enemy within 35 studs: a vacuum pulls them in (5, bullet, blockable), then with melee i-frames
		-- a kick sends them high into the air (7.5, unblockable).
		[ 1 ] = K.Target{ "Lapse Blue", cooldown = 13, teleport = false, pullIn = true, range = 35, startup = 0.35, hitDamage = { 5, 7.5 }, hits = 2,
			interval = 0.35, hitBlock = { "normal", "none" }, type = "bullet", bypassRagdoll = true, armor = "melee", color = "blue",
			ragdoll = { h = 8, v = 60 } },
		-- A slow red orb that explodes on impact or by itself after 40 studs (15 stud AoE; 6.25 on block).
		-- Special during the startup ("Blink", aiming at an enemy): phases behind the target and fires point-blank
		-- (Limitless goes on its 15s cooldown). Interrupting their action this way stuns them first (15).
		-- "Air Blink": on an airborne target, a kick then the red (17.5).
		[ 2 ] = K.Projectile{ "Reversal Red", cooldown = 20, startup = 0.5, damage = 12.5, blockDamage = 6.25, range = 40, speed = 70, radius = 3,
			type = "bullet", bypassRagdoll = true, explode = 7.5, color = "red", ragdoll = { h = 45, v = 20 }, tip = "SPECIAL",
			special = { kind = "target", range = 40, startup = 0.35, endlag = 0.4, damage = 12.5, type = "explosion", specialCooldown = 15,
				interrupt = { damage = 2.5, stun = 1 }, vsAir = { damage = 5, ragdoll = { h = 45, v = 25 } } } },
		-- A spinning kick locks a nearby enemy in place, then a barrage and a final blow (17.25). Unblockable, melee and bullet
		-- i-frames during the barrage, interruptible during the startup, can't hit ragdolls.
		-- Special right after it lands: "Face Grater", appears before them and drags them along the floor (10.2, 360 blockable).
		[ 3 ] = K.Grab{ "Rapid Punches", cooldown = 15, startup = 0.35, damage = 17.25, hits = 6, interval = 0.22, type = "melee", block = "none",
			ragdoll = { h = 60, v = 20 }, tip = "SPECIAL",
			onUse = function( ply ) timer.Simple( 0.4, function() if IsValid( ply ) and JJS.IsBusy( ply ) then JJS.IFrames( ply, 1 ) end end ) end,
			specialAfter = K.Melee{ "Face Grater", window = 0.6, cooldown = 15, startup = 0.2, damage = 10.2, hits = 3, interval = 0.25, lunge = 20,
				type = "melee", block = "all", bypassRagdoll = true, awakenCost = 0.06, ragdoll = { h = 45, v = 10 } } },
		-- An upward kick that freezes the target in the air (6, blockable) then an unblockable second kick launching them (4).
		-- Melee i-frames on hit.
		[ 4 ] = K.Melee{ "Twofold Kick", cooldown = 18, startup = 0.35, hits = 2, interval = 0.45, hitDamage = { 6, 4 }, hitBlock = { "normal", "none" },
			type = "melee", bypassRagdoll = true, armor = "melee", ragdoll = { h = 10, v = 70 } },
	},
	special = LIMITLESS,

	awakening = {
		name = "Six Eyes",
		duration = 60,
		heal = 25,
		-- The user removes the blindfold to reveal the Six Eyes.
		-- "0.2 Domain" (the special during the sequence): Infinite Void right after the blindfold comes off, only for 0.2s
		-- (the i-frames are lost): its sure-hit reaches twice as far but lasts 7s. Then a long rush of relentless strikes in
		-- 3 phases (7 x 5, 6 x 20, 65; total i-frames on the runs). Afterwards the user is burnt out: base moves, on
		-- cooldown (not Limitless).
		abilities = {
			-- A controllable blue vortex that pulls in and harms everything near it for 20 ticks (2.2 per tick).
			-- "Unlimited Purple": after it kills someone the azure orb lingers; hit by Reversal Red MAX, it turns into a purple
			-- nuke exploding 3s later (50-100 by distance from the centre), spending the whole awakening bar.
			[ 1 ] = K.AoE{ "Lapse Blue MAX", cooldown = 17, startup = 0.6, damage = 44, hits = 20, interval = 0.1, radius = 14, offset = 12, up = 4,
				type = "explosion", block = "none", bypassRagdoll = true, stun = 0.3, ragdoll = { h = -15, v = 20 }, color = "blue",
				onContact = function( ply, v, p, r )
					if r == "killed" then ply.jjs_blueOrb = { pos = JJS.Util.BodyCenter( v ), t = CurTime() + 8 } end
				end },
			-- A repelling orb charged for a little over a second, fired forward; damage falls from 30 to 7 with range.
			-- Special variant: with Limitless first, a Black Flash punch sends the red back (10; 15 to the user on a miss).
			[ 2 ] = K.Projectile{ "Reversal Red MAX", cooldown = 10, startup = 1.1, damage = 30, speed = 150, range = 90, radius = 5,
				type = "explosion", block = "none", bypassRagdoll = true, explode = 12, color = "red", ragdoll = { h = 60, v = 25 }, tip = "SPECIAL",
				onFly = RedMeetsBlue,
				special = { kind = "melee", startup = 0.4, damage = 10, type = "melee", color = "black", specialCooldown = 15,
					ragdoll = { h = 80, v = 25 } } },
			-- An imaginary purple mass rushes forward and atomizes anything in its path (70).
			[ 3 ] = K.Projectile{ "Hollow Purple", cooldown = 40, startup = 1.6, damage = 70, speed = 90, range = 160, radius = 10, pierce = true,
				type = "explosion", block = "none", bypassRagdoll = true, uninterruptible = true, explode = 14, color = "purple",
				ragdoll = { h = 50, v = 30 }, crater = 1800 },
			-- Domain Expansion: everyone inside is flooded with information and can't act for 14s (adaptable).
			[ 4 ] = K.Domain{ "Infinite Void", cooldown = 120, duration = 14, sureHit = "stun", color = "blue" },
		},
		special = LIMITLESS,
	},
} )

-- the special during the awakening sequence: the 0.2 Domain
local ho = JJS.Characters.honoredone
ho.special.Again = function( ply, mv )
	local act = JJS.GetAction( ply )
	if not act or act.name ~= "awaken_seq" then return false end
	JJS.StopAction( ply, true )
	if SERVER then
		JJS.EnterAwakening( ply, nil, 25 )
		ply:SetJIFrameEnd( 0 )
		-- the sure-hit over twice the usual reach, for 7s
		local r = ( JJS.Config.Domain.Radius or 60 * S ) * 2
		for _, v in ipairs( K.SphereTargets( JJS.Util.BodyCenter( ply ), r, ply, true ) ) do
			if not hook.Run( "JJS_DomainImmune", v ) then JJS.Stun( v, 7 ) end
		end
		JJS.Util.Effect( "jjs_kit_burst", JJS.Util.BodyCenter( ply ), Vector( 0, 0, 1 ), ply, r, K.COLOR_ID.blue )
	end
	RUSH.Use( ply, mv, 0 )
	return true
end
