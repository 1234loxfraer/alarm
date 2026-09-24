-- Head of the Hei (Naoya Zenin). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki; comments describe what the real move does.
--
-- Frame Freeze (Projection Sorcery, the 24 FPS rule): some moves add Projection to the enemies they hit, or to the
-- user when they fail (miss 50%, blocked 45%). A meter under the player drains 2%/s (1.3%/s with a Bleed stack);
-- the user's own meter doesn't drain but landing moves lowers it by 20% and framing someone empties it. At 100%
-- the player freezes in a glass frame for 3s; a hit from a Head of the Hei breaks it for 3x damage.
-- Bleed (Bleedout): 3 stacks; each of the victim's moves going on cooldown removes one for 3 damage. Hit again by
-- Bleedout while bleeding: the stacks refresh and Hemorrhage drains their health (1.3 per tick, can't kill) until
-- the stacks are gone or 39 ticks passed (Blood Manipulator loses awakening instead, up to 50%).

local K = JJS.Kit

local function Proj( v ) return v:GetNW2Float( "JJSProj", 0 ) end
local function Framed( v ) return v:GetNW2Float( "JJSFramed", 0 ) > CurTime() end
local function IsHei( v ) return IsValid( v ) and v:IsPlayer() and v:GetJChar() == "headofthehei" end

local function SetProj( v, x ) v:SetNW2Float( "JJSProj", math.Clamp( x, 0, 1 ) ) end

-- Freezes a player in a glass frame for 3s
local function Frame( v, by )
	SetProj( v, 0 )
	v:SetNW2Float( "JJSFramed", CurTime() + 3 )
	if JJS.GetAction( v ) then JJS.StopAction( v, true ) end
	JJS.Stun( v, 3 )
	v:SetLocalVelocity( vector_origin )
	if IsValid( by ) and by ~= v then SetProj( by, 0 ) end
	JJS.Util.Effect( "jjs_kit_burst", JJS.Util.BodyCenter( v ), Vector( 0, 0, 1 ), v, 40, K.COLOR_ID.white )
end

-- Adds Projection; reaching 100% frames the player (unless the move can't frame)
local function AddProj( v, amount, by, cantFrame )
	if amount <= 0 or not v:Alive() then return end
	local x = Proj( v ) + amount
	if x >= 1 and not cantFrame then Frame( v, by ) else SetProj( v, math.min( x, 0.99 ) ) end
end

-- Projection a move puts on an enemy it landed on: { none = at 0%, any = with some meter, framed = on a framed target }
local function ProjOnHit( t )
	return function( ply, v, p, r )
		if r == "blocked" or not v:IsPlayer() then return end
		-- once per move
		local key = ply:GetJActStart()
		if v.jjs_projKey == key then return end
		v.jjs_projKey = key
		local amt
		if v.jjs_wasFramed then amt = t.framed
		elseif Proj( v ) <= 0 then amt = t.none
		else amt = t.any end
		SetProj( ply, Proj( ply ) - 0.2 )
		AddProj( v, amt or 0, ply, t.cantFrame )
	end
end

-- The user's own meter fills when the move fails: missed 50%, blocked 45%
local function SelfProj( ply, p, interrupted )
	if ply.jjs_kitLanded then return end
	AddProj( ply, ply.jjs_kitBlocked and 0.45 or 0.5, nil )
end

-- Bleedout: 3 Bleed stacks, Hemorrhage when they were already bleeding
local function Bleed( ply, v )
	if not v:IsPlayer() then return end
	if v:GetNW2Int( "JJSBleed", 0 ) > 0 then v.jjs_hemo = { left = 39, next = CurTime() + 0.25, by = ply } end
	v:SetNW2Int( "JJSBleed", 3 )
end

-- Cursory Impact's framed variant, Projection Sorcery's punch: aimed at a framed enemy
local function AimFramed( range )
	return function( ply )
		local t = K.AimTarget( ply, range * JJS.STUD, 0.8 )
		return IsValid( t ) and Framed( t )
	end
end

-- Vengeance's awakening: a slowed Bleedout; stabbed by a melee attack during it, the user revives as a curse
local VENGEANCE = K.Build( "headofthehei", "vengeance", K.Counter{ "Vengeance", window = 1.2, endlag = 0.3, counters = { melee = "evade" },
	color = "blood",
	onCounter = function( ply )
		timer.Simple( 0, function()
			if not IsValid( ply ) or not ply:Alive() then return end
			JJS.StopAction( ply, true )
			JJS.EnterAwakening( ply, nil, 90 )
			-- the transformation knocks everyone around away (10)
			for _, v in ipairs( K.SphereTargets( JJS.Util.BodyCenter( ply ), 18 * JJS.STUD, ply, true ) ) do
				JJS.Hit( v, { attacker = ply, damage = 10, type = JJS.DMG.SPECIAL, block = "none", bypassRagdoll = true,
					ragdoll = { time = 1, vel = JJS.Util.Flat( v:GetPos() - ply:GetPos() ) * 55 * JJS.STUD + Vector( 0, 0, 250 ) } } )
			end
		end )
	end,
	-- nobody took the bait: half the awakening bar comes back
	onEnd = function( ply ) ply:SetJAwaken( 0.5 ) end } )

-- Top Speed for each Acceleration count (JMode 0-7)
local function TopSpeed()
	local list = {}
	for m = 0, 7 do
		list[ m + 1 ] = K.Mobility{ "Top Speed", cooldown = 14, startup = 0.2, travel = 45 + 3 * m, time = 0.5,
			damage = m == 7 and 15 or 5 + 1.5 * m, type = m >= 4 and "bullet" or "melee", block = "none", bypassRagdoll = true,
			ragdoll = { h = 60, v = 20 }, tip = m > 0 and ( m .. "/7" ) or nil }
	end
	return K.ByMode( list )
end

K.Character( "headofthehei", {
	name = "Head of the Hei",
	category = "complete",
	hp = 90,
	model = K.Model( "headofthehei", "models/player/group03/male_02.mdl" ),
	color = Color( 240, 240, 180 ),

	-- Projectionism: 2 per M1 (8 per string), no uppercuts or downslams; the last M1 always knocks back with evadable
	-- stun and reaches grounded ragdolls (cancelling ragdoll-interruptible moves). Per-hit frames from dogslamloop.
	-- TODO: the front dash becomes a second side dash (dash any direction, 0.45s between the two).
	m1 = { Frames = { { 12, 7, 15 }, { 11, 9, 19 }, { 11, 9, 19 } }, Damage = { 2, 2, 2, 2 }, NoLaunch = true, FinalStun = 1.1 },

	passives = {
		{ "Projectionism", "2 per M1, no uppercut/downslam, the last M1 knocks back with stun; front dash = 2nd side dash (TODO)." },
		{ "Frame Freeze", "Moves build Projection on targets (or the user on a miss); at 100% they freeze in a frame for 3s." },
	},

	abilities = {
		-- Dashes 15 studs backward with melee i-frames (29f), then spins back into a heavy kick throwing the target away
		-- (9, 27 on a framed target). Resets the user's M1 string. Projection: 80% at 0%, 35% otherwise, 50% if framed.
		[ 1 ] = K.Melee{ "Projection Breaker", cooldown = 18, startup = K.F( 38 ), endlag = K.F( 12 ), damage = 9, reach = 10, backstep = 15,
			type = "melee", meleeIFrames = K.F( 29 ), ragdoll = { h = 60, v = 20 },
			onContact = ProjOnHit{ none = 0.8, any = 0.35, framed = 0.5 }, onFinish = function( ply, p, i )
				SelfProj( ply, p, i )
				ply:SetJM1Index( 0 )
			end },
		-- Spins a tanto and stabs the abdomen (5, 15 framed; breaks blocks): 3 Bleed stacks, Hemorrhage if already bleeding.
		-- Not a true extender. Finisher: a target at 14 HP or less gets blitzed and stabbed in the neck.
		[ 2 ] = K.Melee{ "Bleedout", cooldown = 20, startup = 0.45, damage = 5, type = "melee", block = "normal", bypassRagdoll = true,
			ragdoll = { time = 0.6, h = 20, v = 10 }, color = "blood", guardBreak = { damage = 5, stun = 1.5, onBreak = Bleed },
			lowHp = { hp = 14, damage = 100 }, onHit = Bleed },
		-- Runs 35 studs and punches (6); landed, a flurry of swift blows (1 + 8, stunned in place) and the user's M1 string
		-- goes to the 2nd M1. USE TWICE: the jab is delayed and the run extends by 15 studs; THRICE: 23 more and the punch
		-- becomes unblockable. Airborne target within 70 studs: locks on and travels to land a sure hit (no self
		-- Projection on a miss). Projection: 30% on a target with some meter, 15% if framed.
		[ 3 ] = K.Rush{ "Decisive Strike", cooldown = 18, startup = 0.2, travel = 35, time = 0.55, hits = 18, interval = 0.08,
			hitDamage = { 6, 1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5 }, type = "melee",
			bypassRagdoll = true, stun = 1.2, tip = "USE THRICE",
			onContact = ProjOnHit{ none = 0, any = 0.3, framed = 0.15 }, onFinish = SelfProj,
			onHit = function( ply ) ply:SetJM1Index( 1 ) ply:SetJM1LastEnd( CurTime() ) end,
			again = K.Rush{ "Decisive Strike: Extended", window = 0.45, startup = 0.1, travel = 50, time = 0.7, hits = 18, interval = 0.08,
				hitDamage = { 6, 1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5 }, type = "melee",
				bypassRagdoll = true, stun = 1.2, onContact = ProjOnHit{ none = 0, any = 0.3, framed = 0.15 }, onFinish = SelfProj,
				onHit = function( ply ) ply:SetJM1Index( 1 ) ply:SetJM1LastEnd( CurTime() ) end,
				again = K.Rush{ "Decisive Strike: Unblockable", window = 0.6, startup = 0.1, travel = 73, time = 0.9, hits = 18,
					interval = 0.08, hitDamage = { 6, 1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5 },
					hitBlock = { "none" }, type = "melee", bypassRagdoll = true, stun = 1.2,
					onContact = ProjOnHit{ none = 0, any = 0.3, framed = 0.15 }, onFinish = SelfProj,
					onHit = function( ply ) ply:SetJM1Index( 1 ) ply:SetJM1LastEnd( CurTime() ) end } },
			airTarget = { kind = "target", range = 70, startup = 0.35, onFinish = false } },
		-- Quick-steps to the destination and reappears with a back-handed smack (7) then a sweep kick propelling the target
		-- away (6; breaks blocks, no ragdoll). 75% Projection but it can't frame.
		-- A framed target (anyone's frame): the smack launches them up, the user flash-steps mid-air, catches them and
		-- tosses them where they aim (19.5 + 5).
		[ 4 ] = K.Melee{ "Cursory Impact", cooldown = 16, startup = 0.3, hits = 2, interval = 0.35, hitDamage = { 7, 6 }, lunge = 20,
			type = "melee", stun = 1, hitKnock = { 0, 45 }, guardBreak = { damage = 7, stun = 1.5 },
			onContact = ProjOnHit{ none = 0.75, any = 0.75, framed = 0, cantFrame = true }, onFinish = SelfProj,
			cond = { test = AimFramed( 25 ), hitDamage = { 6.5, 5 }, hitKnock = false, onContact = false, onFinish = false,
				ragdoll = { h = 60, v = 35 } } },
	},
	-- Aiming at a spot within 50 studs, covers the distance in a second, leaving an afterimage (5% awakening).
	-- Pressed again with a target in sight, a second projection before the cooldown; an interrupted projection keeps
	-- it off cooldown (TODO). A framed target in sight: a quick punch through the glass launching them and resetting
	-- the user's M1s (4, 12 through the frame; 35% Projection).
	special = K.Mobility{ "Projection Sorcery", cooldown = 18, startup = 0.1, travel = 50, time = 0.5, dir = "aim", awakenCost = 0.05,
		tip = "USE AGAIN",
		again = K.Target{ "Projection Sorcery: Again", window = 1.5, range = 50, noHit = true, startup = 0.1, endlag = 0.1 },
		cond = { test = AimFramed( 50 ), kind = "target", range = 50, startup = 0.25, damage = 4, type = "melee", block = "none",
			bypassRagdoll = true, ragdoll = { h = 60, v = 25 }, onContact = ProjOnHit{ none = 0.35, any = 0.35, framed = 0.35 },
			onHit = function( ply ) ply:SetJM1Index( 0 ) end } },

	-- The awakening performs a slowed Bleedout: struck by melee during it, the opponent catches the thrust and stabs the
	-- user with their own tanto ("No way..." "I lost to this?"), who reincarnates as a vengeful curse (spikes knock
	-- everyone away, 10). Not struck, half the awakening bar comes back.
	Awaken = function( ply )
		ply:SetJAwaken( 0 )
		VENGEANCE.Use( ply, nil, 0 )
	end,

	awakening = {
		name = "Vengeance",
		duration = 60,
		-- The curse form moves faster, hovering; its red tendrils M1s pull it further and add 10% Projection each, with
		-- uppercuts, downslams and normal damage back. It dies when the bar runs out unless it cast its domain.
		m1 = { Damage = { 3, 3, 4, 4 }, NoLaunch = false, FinalStun = false, Pull = 30 * JJS.STUD },
		abilities = {
			-- Takes in air through its inlets and boosts forward, crashing its shell into anyone in the way (5, +1.5 per
			-- Acceleration, 15 at 7; bullet type after 4; faster each time). Through Flash Freezing's frames it flies
			-- longer and hits harder (+0.6 per frame, those frames deal nothing; TODO).
			[ 1 ] = TopSpeed(),
			-- Freezes the air in front into a line of 15 glass frames; a hit frame shatters, hurting nearby enemies and
			-- frames in a chain (7 per frame). Finisher: the victim's body shatters with the glass.
			[ 2 ] = K.Melee{ "Flash Freezing", cooldown = 18, startup = 0.5, hits = 2, interval = 0.2, hitDamage = { 7, 7 }, reach = 30,
				width = 6, type = "explosion", block = "none", bypassRagdoll = true, color = "cyan", ragdoll = { h = 30, v = 20 } },
			-- Tendrils surge from the ground to grab enemies within 25 studs, immobilizing them for about a second.
			[ 3 ] = K.AoE{ "Tendril Grab", cooldown = 10, startup = 0.5, damage = 0, radius = 25, stun = 1.1, slow = { 0, 1.1 }, type = "special",
				block = "none", bypassRagdoll = true, color = "blood" },
			-- Domain Expansion: hops out of the curse form (back to the base moves, same HP fraction) and makes everyone
			-- inside follow the 24 FPS rule at a cellular level: moving freezes and shatters their cells (damage by their
			-- and the user's speed, blocking cuts it). The user's failed moves still fill their meter but can't frame them.
			[ 4 ] = K.Domain{ "Time Cell Moon Palace", cooldown = 60, duration = 25, sureHit = "motion", dps = 4, color = "blood",
				onUse = function( ply ) ply.jjs_usedDomain = true end,
				onEnd = function( ply ) JJS.ExitAwakening( ply ) end },
		},
		-- Spins rapidly, damaging the area (1 per spin, 7) and building momentum for Top Speed (7 uses max) and walk speed
		-- when not blocked. Can't kill.
		special = K.AoE{ "Acceleration", cooldown = 9, startup = 0.2, damage = 7, hits = 7, interval = 0.08, radius = 8, type = "explosion",
			block = "all", bypassRagdoll = true, stun = 0.3, color = "white", noKill = true,
			onUse = function( ply )
				ply:SetJMode( math.min( 7, ply:GetJMode() + 1 ) )
				ply:SetJBuffMult( 1 + 0.06 * ply:GetJMode() )
				ply:SetJBuffEnd( CurTime() + 20 )
			end },
	},

	SpeedMult = function( ply ) return ply:GetJAwakened() and 1.25 or 1 end,
} )

if SERVER then
	-- remember whether the target was framed before the hit breaks the frame; Head of the Hei hits break it for 3x
	hook.Add( "JJS_PreHit", "JJS_FrameFreeze", function( victim, hit )
		victim.jjs_wasFramed = Framed( victim )
		if victim.jjs_wasFramed and IsHei( hit.attacker ) and hit.attacker ~= victim and not hit.throwable then
			victim:SetNW2Float( "JJSFramed", 0 )
			victim:SetJStunEnd( 0 )
			hit.jjs_frameBreak = true
		end
	end )
	JJS.AddDamageMod( "JJS_FrameFreeze", function( victim, attacker, dmg, hit )
		if hit.jjs_frameBreak then return 3 end
	end )

	-- M1s: the final one applies Projection (35% at 0, 30% under 60%, 100% from 60%, 40% on a bleeding target);
	-- in the curse form every M1 adds 10%
	hook.Add( "JJS_M1", "JJS_FrameFreeze", function( ply, idx, variant, landed )
		if not IsHei( ply ) or not IsValid( landed ) then return end
		if ply:GetJAwakened() then AddProj( landed, 0.1, ply ) return end
		if idx < JJS.M1.Cfg( ply ).Count then return end
		local x = Proj( landed )
		local amt
		if landed:GetNW2Int( "JJSBleed", 0 ) > 0 then amt = 0.4
		elseif x <= 0 then amt = 0.35
		elseif x < 0.6 then amt = 0.3
		else amt = 1 end
		AddProj( landed, amt, ply )
	end )

	-- Bleed stacks: each move going on cooldown costs one stack and 3 HP
	hook.Add( "JJS_Cooldown", "JJS_Bleed", function( ply )
		local n = ply:GetNW2Int( "JJSBleed", 0 )
		if n <= 0 then return end
		ply:SetNW2Int( "JJSBleed", n - 1 )
		JJS.ApplyDamage( ply, nil, 3, { type = JJS.DMG.SPECIAL } )
		if n == 1 then ply.jjs_hemo = nil end
	end )

	hook.Add( "Tick", "JJS_FrameFreeze", function()
		local now = CurTime()
		local dt = FrameTime()
		for _, v in ipairs( player.GetAll() ) do
			-- the meter drains, except the Head of the Hei's own
			local x = Proj( v )
			if x > 0 and not IsHei( v ) and not Framed( v ) then
				SetProj( v, x - dt * ( v:GetNW2Int( "JJSBleed", 0 ) > 0 and 0.013 or 0.02 ) )
			end
			-- Hemorrhage (paused while framed)
			local h = v.jjs_hemo
			if h and now >= h.next and not Framed( v ) then
				h.next = now + 0.25
				h.left = h.left - 1
				if v:GetJChar() == "bloodmanipulator" then
					v:SetJAwaken( math.max( 0, v:GetJAwaken() - 0.5 / 39 ) )
				elseif v:GetJHP() > 1.3 then
					JJS.ApplyDamage( v, h.by, 1.3, { type = JJS.DMG.SPECIAL } )
				end
				if h.left <= 0 or v:GetNW2Int( "JJSBleed", 0 ) <= 0 then
					v.jjs_hemo = nil
					v:SetNW2Int( "JJSBleed", 0 )
				end
			end
		end
	end )

	-- the curse form dies when the awakening runs out, unless its domain was cast
	hook.Add( "JJS_AwakeningEnd", "JJS_Vengeance", function( ply )
		if not IsHei( ply ) then return end
		if not ply.jjs_usedDomain and ply:Alive() then
			timer.Simple( 0, function() if IsValid( ply ) then JJS.Kill( ply, nil, { type = JJS.DMG.SPECIAL } ) end end )
		end
		ply.jjs_usedDomain = nil
		ply:SetJMode( 0 )
	end )
end

if CLIENT then
	-- the Projection meter under affected players
	hook.Add( "HUDPaint", "JJS_FrameFreeze", function()
		for _, v in ipairs( player.GetAll() ) do
			local x = Proj( v )
			if v:Alive() and ( x > 0 or Framed( v ) ) then
				local sp = ( v:GetPos() - Vector( 0, 0, 4 ) ):ToScreen()
				if sp.visible then
					surface.SetDrawColor( 0, 0, 0, 180 )
					surface.DrawRect( sp.x - 40, sp.y, 80, 6 )
					surface.SetDrawColor( 240, 240, 180, 230 )
					surface.DrawRect( sp.x - 40, sp.y, 80 * ( Framed( v ) and 1 or x ), 6 )
				end
			end
		end
	end )
end

hook.Add( "JJS_PlayerSpawned", "JJS_FrameFreeze", function( ply )
	ply:SetNW2Float( "JJSProj", 0 )
	ply:SetNW2Float( "JJSFramed", 0 )
	ply:SetNW2Int( "JJSBleed", 0 )
	ply.jjs_hemo = nil
	ply.jjs_usedDomain = nil
end )
