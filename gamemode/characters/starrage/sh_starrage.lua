-- Star Rage (Yuki Tsukumo, base-only). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki; comments describe what the real move does.
--
-- Mass (Res1, 0..1): holding the special converts cursed energy (up to 21% of the awakening bar) into virtual mass.
-- Pressing the special during a move's windup with enough mass triggers its stronger variant (an indicator shows
-- it; Rising Rage takes two presses). Only Garuda Stab's mass variant gives awakening.

local K = JJS.Kit

local function Mass( ply ) return ply:GetJRes1() end
local function Need( x ) return function( ply ) return Mass( ply ) >= x - 0.001 end end
local function Spend( x ) return function( ply ) ply:SetJRes1( math.max( 0, Mass( ply ) - x ) ) end end

-- Holding the special: mass builds up (full in ~1.6s, 21% awakening for a full bar)
JJS.RegisterAction( "starrage.mass", {
	dur = 3,
	moveMult = 0.3,
	gesture = "gesture_bow",
	think = function( ply, t, mv )
		local held = mv and mv:KeyDown( JJS.IN.SPECIAL )
		if not held or Mass( ply ) >= 1 or ply:GetJAwaken() <= 0 then
			JJS.StopAction( ply, true )
			return
		end
		local gain = math.min( FrameTime() / 1.6, 1 - Mass( ply ) )
		ply:SetJRes1( Mass( ply ) + gain )
		if not ply:GetJAwakened() then ply:SetJAwaken( math.max( 0, ply:GetJAwaken() - gain * 0.21 ) ) end
	end,
} )

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
		{ "Garuda", "Cosmetic: a serpentine shikigami orbiting the user (used in Garuda Rebound and Garuda Stab)." },
		{ "Mass", "Hold the special for mass; the special during a move's windup spends it on a stronger variant." },
	},

	abilities = {
		-- Kicks Garuda forward curled into a ball (slight auto-aim) at the torso (5), then it hovers back (holding the move
		-- ~0.5s makes it come back slower). USE TWICE right as it returns: punched forward again (7, perfect blockable;
		-- 20s), ragdolling toward the user; a perfect block sends it back, and the user can parry it again (12.5 to them).
		-- If the user was mid-move, the punch feints it and keeps it off cooldown (except Garuda Stab).
		-- Special while it comes back (100% mass): a kick sending it back at excessive speed (24, no evasive, no
		-- awakening), ricocheting off walls and defeated targets.
		[ 1 ] = K.Projectile{ "Garuda Rebound", cooldown = 14, startup = 0.3, damage = 5, range = 50, speed = 160, radius = 3, type = "bullet",
			block = "normal", bypassRagdoll = true, color = "gold", tip = "USE TWICE",
			again = K.Projectile{ "Garuda Rebound: Punch", window = 1.4, startup = 0.15, damage = 7, range = 50, speed = 180, radius = 3,
				type = "bullet", block = "pre", bypassRagdoll = true, ragdoll = { h = -30, v = 15 }, color = "gold", feints = true,
				feintRefund = { except = 4 }, onUse = function( ply ) JJS.SetCooldown( ply, 1, 20 ) end },
			specialAfter = K.Projectile{ "Garuda Rebound: Mass Kick", window = 1.2, anyway = true, free = true, need = Need( 1 ), cooldown = 16,
				startup = 0.2, damage = 24, range = 90, speed = 320, radius = 4, pierce = true, type = "explosion", block = "pre", bypassRagdoll = true,
				trueRag = true, ragdoll = { h = 60, v = 20 }, color = "gold", onUse = Spend( 1 ) } },
		-- Legs amplified with cursed energy: a sweep (7, can't hit ragdolls) and an upward kick propelling the target up and
		-- away (7). Special before the 2nd kick (30%): a 3rd kick to the head knocks them right with a concussion (7 + 4 + 5,
		-- red highlight, blurred vision, ringing). Special again before the 3rd (60% total): it knocks them back instead,
		-- then an unblockable, uncounterable knee kick ejects them (7 + 4 + 8 + 5, can't kill).
		[ 2 ] = K.Melee{ "Rising Rage", cooldown = 15, startup = 0.3, hits = 2, interval = 0.35, hitDamage = { 7, 7 }, hitBypass = { false, true },
			type = "melee", ragdoll = { h = 40, v = 45 }, comboWindow = 0.64, tip = "SPECIAL",
			special = { free = true, need = Need( 0.3 ), onUse = Spend( 0.3 ), startup = 0.12, hits = 2, interval = 0.35, hitDamage = { 4, 5 },
				hitBypass = false, ragdoll = { h = 45, v = 10 }, comboWindow = 0.45,
				onHit = function( ply, v ) JJS.StaggerArm( v, 4 ) end,
				special = { free = true, need = Need( 0.3 ), onUse = Spend( 0.3 ), startup = 0.1, hits = 2, interval = 0.4, hitDamage = { 8, 5 },
					hitBlock = { "normal", "none" }, type = "explosion", noKillHits = { [ 2 ] = true }, trueRag = true, onHit = false,
					ragdoll = { h = 90, v = 25 } } } },
		-- Charges the fist and lunges into a bone-breaking blow (15, unblockable, no evasive, can't hit ragdolls); airborne,
		-- the lunge aims 360 degrees. Special in the windup (30%): it ends in an uncounterable ground smash launching
		-- everyone around by angle (12, hits ragdolls).
		[ 3 ] = K.Melee{ "Mass Breaker", cooldown = 15, startup = 0.5, damage = 15, lunge = 18, type = "melee", block = "none", trueRag = true,
			ragdoll = { h = 70, v = 20 }, tip = "SPECIAL",
			special = { kind = "aoe", free = true, need = Need( 0.3 ), onUse = Spend( 0.3 ), startup = 0.45, damage = 12, radius = 12, offset = 6,
				type = "explosion", bypassRagdoll = true, trueRag = false, crater = 1300, ragdoll = { h = 45, v = 35 } } },
		-- Stabs forward with Garuda's body (7) then a crushing axe kick knocking the target away (7; unblockable, can't hit
		-- ragdolls). Special in the windup (50%, 20s): Garuda is thrown to grab and pull the enemy in, then whipped twice,
		-- bouncing and grounding them (7 + 6 + 8).
		[ 4 ] = K.Melee{ "Garuda Stab", cooldown = 14, startup = 0.35, hits = 2, interval = 0.4, hitDamage = { 7, 7 }, reach = 11, type = "melee",
			block = "none", ragdoll = { h = 50, v = 10 }, tip = "SPECIAL",
			special = { kind = "target", teleport = false, pullIn = true, range = 30, free = true, need = Need( 0.5 ), onUse = Spend( 0.5 ),
				cooldown = 20, startup = 0.35, hits = 3, interval = 0.35, hitDamage = { 7, 6, 8 }, bypassRagdoll = true, ragdoll = { h = 5, v = -30 } } },
	},
	-- Held: converts cursed energy into virtual mass (a bar at the right; up to 21% of the awakening bar). 16s.
	special = {
		name = "Mass Buildup",
		cooldown = 16,
		tip = function( ply ) return string.format( "%d%%", math.floor( Mass( ply ) * 100 + 0.5 ) ) end,
		Use = function( ply, mv, slot )
			JJS.SetCooldown( ply, slot, 16 )
			JJS.StartAction( ply, "starrage.mass", slot )
		end,
	},

	-- Unrestricted Density: after death, G tosses the user onto a target to latch on; holding the special then raises the
	-- virtual mass beyond the limit, turning their body into a black hole pulling everything in (500/s, weaker with
	-- distance; the pulled can't use moves or M1s). Not possible if their body was severed, wasted if the victim leaves.
	-- Here: killed with a full bar, the user gets 4s; G latches onto the aimed target and the black hole forms.
	awakenMove = K.Zone{ "Unrestricted Density", startup = 1.2, radius = 30, target = true, range = 60, duration = 3, tick = 0.1, damage = 50,
		falloff = true, type = "domain", block = "none", bypassRagdoll = true, uninterruptible = true, color = "black", ragdoll = { time = 0.3, h = -35, v = 5 },
		onEnd = function( ply ) timer.Simple( 0.2, function() if IsValid( ply ) and ply:Alive() then JJS.Kill( ply, nil, { type = JJS.DMG.SPECIAL } ) end end ) end },

	-- only in the last stand after death
	Awaken = function( ply, mv )
		if not ply.jjs_lastStand then return end
		local ab = JJS.GetChar( ply ).awakenMove
		if not ab.CanUse( ply, 0, mv ) then return end
		ply.jjs_lastStand = nil
		ply:SetJAwaken( 0 )
		ab.Use( ply, mv, 0 )
	end,

	-- the mass bar
	HUDPaint = function( ply, now, S2 )
		if not ply:Alive() then return end
		local m = Mass( ply )
		local sp = ( ply:GetPos() + Vector( 0, 0, 44 ) ):ToScreen()
		if not sp.visible then return end
		local w, h = S2( 8 ), S2( 90 )
		local x, y = sp.x + S2( 70 ), sp.y - h / 2
		surface.SetDrawColor( 20, 20, 22, 200 )
		surface.DrawRect( x, y, w, h )
		surface.SetDrawColor( 255, 200, 90, 230 )
		surface.DrawRect( x, y + h * ( 1 - m ), w, h * m )
		surface.SetDrawColor( 255, 255, 255, 90 )
		for _, mark in ipairs( { 0.3, 0.5, 0.6 } ) do surface.DrawRect( x - S2( 2 ), y + h * ( 1 - mark ), w + S2( 4 ), 1 ) end
	end,
} )

if SERVER then
	-- Unrestricted Density: death with a full awakening bar leaves 4s to latch onto someone
	hook.Add( "JJS_PreventDeath", "JJS_UnrestrictedDensity", function( victim )
		if victim:GetJChar() ~= "starrage" or victim:GetJAwaken() < 1 or victim.jjs_lastStand then return end
		victim.jjs_lastStand = CurTime() + 4
		victim:SetJHP( 1 )
		victim:SetHealth( 1 )
		JJS.IFrames( victim, 4 )
		return true
	end )
	hook.Add( "Tick", "JJS_UnrestrictedDensity", function()
		for _, ply in ipairs( player.GetAll() ) do
			local t = ply.jjs_lastStand
			if t and CurTime() > t and ply:Alive() and not JJS.IsBusy( ply ) and ply:GetJAwaken() >= 1 then
				ply.jjs_lastStand = nil
				JJS.Kill( ply, nil, { type = JJS.DMG.SPECIAL } )
			end
		end
	end )
end

hook.Add( "JJS_PlayerSpawned", "JJS_StarRage", function( ply )
	ply:SetJRes1( 0 )
	ply.jjs_lastStand = nil
end )
