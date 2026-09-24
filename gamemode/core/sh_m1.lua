-- Basic attacks (M1). The string length, damage and timings come from the character's m1 table.
-- Final hit variants: 0 = neutral, 1 = uppercut (rising / holding jump), 2 = downslam (falling).
-- m1.Frames = { { startup, recovery, blockEndlag }, ... } gives per-hit timings in 60 fps frames
-- (dogslamloop frame data); hits without an entry use Startup / Duration. Active frames are 1.

local S = JJS.STUD
local U = JJS.Util

JJS.M1 = JJS.M1 or {}
local M = JJS.M1

M.NEUTRAL, M.UP, M.DOWN = 0, 1, 2

-- var = index + variant * 16 (+ 64 when the character picked its alternate version at start)
-- The M1 settings in use: the awakening's own (awakening.m1) while awakened
function M.Cfg( ply )
	local char = JJS.GetChar( ply )
	if ply:GetJAwakened() and char.awakening and char.awakening.m1cfg then return char.awakening.m1cfg end
	return char.m1
end

function M.Unpack( var )
	return var % 16, math.floor( var / 16 ) % 4, var >= 64
end

function M.Variant( ply, mv )
	if M.Cfg( ply ).NoLaunch then return M.NEUTRAL end
	local vz = mv:GetVelocity().z
	local ground = ply:IsOnGround()
	if not ground and vz < -3 * S then return M.DOWN end
	if ( not ground and vz > 3 * S ) or mv:KeyDown( IN_JUMP ) then return M.UP end
	return M.NEUTRAL
end

function M.TryStart( ply, mv )
	if not mv:KeyDown( JJS.IN.M1 ) then return end
	local now = CurTime()
	if now < ply:GetJM1CD() then return end
	-- Side Dash M1: M1s can come out during a side/back dash (not a front dash)
	local dash = ply:GetJDashType()
	if not JJS.CanAct( ply ) or JJS.IsBlocking( ply ) or dash == JJS.Dash.FRONT or JJS.IsBusy( ply ) then return end
	if ply:GetJMoveState() == JJS.MOVE_WALLRUN then return end

	local cfg = M.Cfg( ply )
	local idx = ply:GetJM1Index()
	if now - ply:GetJM1LastEnd() > cfg.ChainWindow then idx = 0 end
	idx = idx + 1
	if idx > cfg.Count then idx = 1 end

	local variant = idx >= cfg.Count and M.Variant( ply, mv ) or M.NEUTRAL
	-- decided once at start so the animation can't switch mid-swing
	local alt = cfg.Alt and cfg.Alt( ply, idx, variant ) and 64 or 0
	ply:SetJM1Index( idx )
	JJS.StartAction( ply, "m1", idx + variant * 16 + alt )
end

function M.FindTargets( ply, cfg, variant )
	local yaw = ply:EyeAngles().y
	local center = U.BodyCenter( ply ) + U.YawForward( yaw ) * cfg.HitCenter
	return U.PlayersInBox( center, yaw, cfg.HitSize, { ignore = ply, ragdolled = variant == M.DOWN } )
end

-- Timings of hit `idx`: startup, action length, extra lock when blocked (seconds)
function M.Timing( cfg, idx )
	local fr = cfg.Frames and cfg.Frames[ idx ]
	local final = idx >= cfg.Count
	if fr then
		local startup = fr[ 1 ] / 60
		local dur = final and math.max( cfg.FinalDuration, startup + 0.1 ) or ( fr[ 1 ] + 1 + fr[ 2 ] ) / 60
		return startup, dur, ( fr[ 3 ] - fr[ 2 ] ) / 60
	end
	local dur = final and cfg.FinalDuration or cfg.Duration
	return cfg.Startup, dur, nil
end

-- Builds the hit table for one target
function M.BuildHit( ply, victim, cfg, idx, variant )
	local final = idx >= cfg.Count
	local fwd = U.YawForward( ply:EyeAngles().y )
	local hit = {
		attacker = ply,
		damage = cfg.Damage[ idx ] or cfg.Damage[ #cfg.Damage ],
		type = JJS.DMG.MELEE,
		stun = cfg.Stun,
		block = "normal",
		fx = final and "heavy" or "light",
		isM1 = true,
		m1Index = idx,
		m1Variant = variant,
	}

	if final then
		local f = cfg.Final[ variant ]
		local vel = fwd * f.h + Vector( 0, 0, f.v )
		if variant == M.DOWN then
			hit.block = "none"
			hit.bypassRagdoll = true
			if victim:IsOnGround() or victim:GetJRagdolled() then vel = fwd * f.h * 0.3 + Vector( 0, 0, -10 * S ) end
		end
		hit.ragdoll = { time = f.ragdoll, vel = vel }
		-- FinalStun: the last hit knocks back with (evadable) stun instead, and reaches grounded ragdolls
		if cfg.FinalStun then
			hit.ragdoll = nil
			hit.stun = cfg.FinalStun
			hit.knock = fwd * f.h * 0.6
			hit.bypassRagdoll = true
		end
		hit.fxScale = 1.4

		-- 20% evasive for downslams on ragdolled targets / launches right at wakeup
		local wasRagdolled = victim:GetJRagdolled()
		local justWoke = victim:GetJMeleeImmuneEnd() > CurTime()
		hit.onHit = function( v )
			if ( variant == M.DOWN and wasRagdolled ) or ( variant ~= M.DOWN and justWoke ) then
				JJS.AddEvasive( v, JJS.Config.Evasive.ComboBonus )
			end
		end
	end
	return hit
end

-- The hit frame (server applies damage)
function M.DoHit( ply, var )
	if CLIENT then return end
	local char = JJS.GetChar( ply )
	local cfg = M.Cfg( ply )
	local idx, variant, alt = M.Unpack( var )
	local final = idx >= cfg.Count

	if final and char.OnM1Final and char.OnM1Final( ply, variant, cfg, alt ) then return end

	U.LagComp( ply, true )
	local targets = M.FindTargets( ply, cfg, variant )
	U.LagComp( ply, false )

	local landed, blocked
	for _, v in ipairs( targets ) do
		local r = JJS.Hit( v, M.BuildHit( ply, v, cfg, idx, variant ) )
		if r == "hit" or r == "killed" then
			landed = landed or v
		elseif r == "blocked" then
			blocked = true
		end
	end

	if landed then
		local dir = U.Flat( landed:GetPos() - ply:GetPos() )
		JJS.Impulse( ply, dir * cfg.Pull )
		-- launches break things when the ragdoll lands (sv_ragdoll); a downslam cracks the floor right away
		if final and variant == M.DOWN then
			JJS.Destruction.GroundImpact( landed:GetPos() + Vector( 0, 0, 20 ), cfg.CraterScale, Vector( 0, 0, -1 ) )
		end
	elseif blocked then
		-- blocked M1s have longer endlag (about double the recovery)
		local _, _, extra = M.Timing( cfg, idx )
		JJS.ExtendAction( ply, extra or math.max( ply:GetJActEnd() - CurTime(), 0.1 ) )
	end
	hook.Run( "JJS_M1", ply, idx, variant, landed, blocked )
end

local function Startup( ply, var )
	local startup = M.Timing( M.Cfg( ply ), M.Unpack( var or ply:GetJActVar() ) )
	return startup
end

JJS.RegisterAction( "m1", {
	dur = function( ply, var )
		local _, dur = M.Timing( M.Cfg( ply ), M.Unpack( var ) )
		return dur
	end,
	moveMult = function( ply ) return M.Cfg( ply ).MoveMult end,
	dashCancel = Startup,
	seq = function( ply, var )
		local m1 = M.Cfg( ply )
		if m1.Seq then return m1.Seq( ply, M.Unpack( var ) ) end
	end,
	gesture = function( ply, var )
		local idx, variant = M.Unpack( var )
		local cfg = M.Cfg( ply )
		if cfg.Gestures then return cfg.Gestures( ply, idx, variant ) end
		return idx % 2 == 1 and "range_fists_r" or "range_fists_l"
	end,
	events = {
		{ Startup, function( ply, t, var ) M.DoHit( ply, var ) end },
	},
	finish = function( ply, var, interrupted )
		local cfg = M.Cfg( ply )
		local idx = M.Unpack( var )
		ply:SetJM1LastEnd( CurTime() )
		if idx >= cfg.Count and not interrupted then
			ply:SetJM1CD( CurTime() + cfg.Downtime )
			ply:SetJM1Index( 0 )
		end
	end,
} )
