-- Dashes (Q).
-- Forward / still: slide ~25 studs winding up a jab, punch the first target met (ragdolls it
-- in the first half of the travel), 6s cooldown. Direction follows the camera while dashing.
-- Side / back: quickstep ~17.5 studs, 2s cooldown, steerable by turning, can cancel the
-- startup of an M1/move. While ragdolled with a full evasive bar it becomes the ragdoll cancel;
-- with an anti-team burst available it triggers the burst.

local S = JJS.STUD
local U = JJS.Util

JJS.Dash = JJS.Dash or {}
local D = JJS.Dash
local cfg = JJS.Config.Dash

D.FRONT, D.SIDE = 1, 2

local function DashEffect( ply, pos, dir, typ )
	if not IsFirstTimePredicted() then return end
	local ed = EffectData()
	ed:SetOrigin( pos )
	ed:SetNormal( dir )
	ed:SetEntity( ply )
	ed:SetFlags( typ )
	util.Effect( "jjs_dash", ed )
end

function D.Begin( ply, mv, typ, localDir, noCooldown )
	local now = CurTime()
	ply:SetJDashType( typ )
	ply:SetJDashStart( now )
	ply:SetJDashDir( localDir )
	ply:SetJDashOrigin( mv:GetOrigin() )
	ply:SetJBlockStart( 0 )
	ply:SetJMoveState( JJS.MOVE_NONE )
	if not noCooldown then
		if typ == D.SIDE then
			ply:SetJDashSideCD( now + cfg.SideCooldown )
		else
			ply:SetJDashFrontCD( now + cfg.FrontCooldown )
		end
	end
	local yaw = mv:GetMoveAngles().y
	DashEffect( ply, mv:GetOrigin(), U.YawForward( yaw ) * localDir.x + U.YawRight( yaw ) * localDir.y, typ )
	hook.Run( "JJS_DashStart", ply, typ )
end

-- Someone under the crosshair, close enough, facing away from us
function D.AntiRunTarget( ply )
	local eye, aim = ply:EyePos(), ply:GetAimVector()
	for _, t in ipairs( player.GetAll() ) do
		if t == ply or not t:Alive() or t:GetJRagdolled() then continue end
		local to = U.BodyCenter( t ) - eye
		local dist = to:Length()
		if dist < 1 or dist > cfg.AntiRunRange then continue end
		to:Div( dist )
		if aim:Dot( to ) < 0.96 then continue end
		local away = U.Flat( t:GetPos() - ply:GetPos() )
		if U.YawForward( t:EyeAngles().y ):Dot( away ) > 0.3 then return t end
	end
end

-- Server: resolve an anti-team burst
function D.Burst( ply )
	local bc = JJS.Config.Burst
	ply:SetJBurstEnd( 0 )
	ply.jjs_hitters = {}
	JJS.Heal( ply, bc.Heal )
	if ply.jjs_burstWeak then
		-- third party interruption: heal only
		ply.jjs_burstWeak = nil
		U.Effect( "jjs_burst", ply:GetPos() + Vector( 0, 0, 40 ), nil, ply, 0.6 )
		hook.Run( "JJS_Burst", ply, true )
		return
	end
	ply:SetJEvasive( 1 )
	ply:SetJStunEnd( 0 )
	ply:SetJEndlagEnd( 0 )
	JJS.IFrames( ply, bc.IFrames )
	JJS.StopAction( ply, true )
	if ply:GetJRagdolled() then JJS.Ragdoll.Stop( ply, "burst" ) end
	U.Effect( "jjs_burst", ply:GetPos() + Vector( 0, 0, 40 ), nil, ply )
	hook.Run( "JJS_Burst", ply )
end

function D.TryStart( ply, mv )
	local now = CurTime()
	local f, s = U.InputDir( mv )
	local side = not ( s == 0 and f >= 0 )
	local localDir = side and Vector( f, s, 0 ) or Vector( 1, 0, 0 )
	localDir:Normalize()

	-- escapes are resolved by the server (the ragdoll lives there)
	if side and ply:GetJBurstEnd() > now then
		if SERVER then
			D.Burst( ply )
			mv:SetOrigin( ply:GetPos() )
			mv:SetVelocity( vector_origin )
			D.Begin( ply, mv, D.SIDE, localDir, true )
		end
		return
	end

	if ply:GetJRagdolled() then
		if SERVER and side and ply:GetJEvasive() >= 1 and not ply:GetJTrueRagdoll() then
			JJS.Ragdoll.Stop( ply, "evasive" )
			ply:SetJEvasive( 0 )
			ply:SetJStunEnd( 0 )
			JJS.IFrames( ply, JJS.Config.Ragdoll.EvasiveIFrames )
			mv:SetOrigin( ply:GetPos() )
			mv:SetVelocity( vector_origin )
			U.Effect( "jjs_evasive", ply:GetPos() + Vector( 0, 0, 36 ), nil, ply )
			D.Begin( ply, mv, D.SIDE, localDir, true )
		end
		return
	end

	if not JJS.CanAct( ply ) or JJS.IsBlocking( ply ) or JJS.IsDashing( ply ) then return end
	if ply:GetJMoveState() == JJS.MOVE_WALLRUN then return end

	local act = JJS.GetAction( ply )
	if act then
		local window = act.dashCancel and JJS.Resolve( act.dashCancel, ply, ply:GetJActVar() )
		if not side or not window or JJS.ActionTime( ply ) >= window then return end
		JJS.StopAction( ply, true )
	end

	if side then
		if now < ply:GetJDashSideCD() then return end
		D.Begin( ply, mv, D.SIDE, localDir )
		return
	end

	if now < ply:GetJDashFrontCD() then
		-- anti-run: chasing a target that turned its back gives a forward quickstep
		if now >= ply:GetJDashSideCD() and D.AntiRunTarget( ply ) then
			D.Begin( ply, mv, D.SIDE, Vector( 1, 0, 0 ) )
		end
		return
	end
	D.Begin( ply, mv, D.FRONT, Vector( 1, 0, 0 ) )
end

function D.FindPunchTarget( ply, mv )
	local yaw = mv:GetMoveAngles().y
	local center = mv:GetOrigin() + Vector( 0, 0, 36 ) + U.YawForward( yaw ) * cfg.FrontHitCenter
	U.LagComp( ply, true )
	local list = U.PlayersInBox( center, yaw, cfg.FrontHitSize, { ignore = ply } )
	U.LagComp( ply, false )
	return list[ 1 ]
end

function D.WorldDir( ply, yaw )
	local ld = ply:GetJDashDir()
	local dir = U.YawForward( yaw ) * ld.x + U.YawRight( yaw ) * ld.y
	dir:Normalize()
	return dir
end

-- Called from GM:Move; returns true while the dash owns movement
function D.Move( ply, mv )
	local typ = ply:GetJDashType()
	if typ == 0 then return false end

	local front = typ == D.FRONT
	local T = front and cfg.FrontTime or cfg.SideTime
	local dist = front and cfg.FrontDistance or cfg.SideDistance
	local u = ( CurTime() - ply:GetJDashStart() ) / T
	local dir = D.WorldDir( ply, mv:GetMoveAngles().y )

	if u >= 1 then
		ply:SetJDashType( 0 )
		local v = dir * ( front and JJS.Config.RunSpeed or JJS.Config.WalkSpeed )
		v.z = mv:GetVelocity().z
		mv:SetVelocity( v )
		if front then JJS.StartAction( ply, "dash_whiff" ) end
		return false
	end

	-- average speed = dist / T ; front slides almost evenly, side snaps out and settles
	local k = front and 1.25 * ( 1 - 0.4 * u ) or ( 1.5 - u )
	JJS.Move.Slide( ply, mv, dir * ( dist / T * k ), FrameTime(), true )

	if front then
		local target = D.FindPunchTarget( ply, mv )
		if target then
			local early = ( mv:GetOrigin() - ply:GetJDashOrigin() ):Length2D() < cfg.FrontDistance / 2
			ply:SetJDashType( 0 )
			mv:SetVelocity( dir * JJS.Config.WalkSpeed * 0.4 )
			JJS.StartAction( ply, "dash_punch", early and 1 or 0, target )
		end
	end
	return true
end

JJS.RegisterAction( "dash_punch", {
	dur = cfg.FrontHitLock,
	moveMult = 0.2,
	noJump = true,
	gesture = "range_fists_r",
	events = {
		{ 0.04, function( ply, t, var )
			if CLIENT then return end
			local target = ply:GetJActTarget()
			if not IsValid( target ) then return end
			local fwd = U.YawForward( ply:EyeAngles().y )
			local hit = {
				attacker = ply,
				damage = cfg.FrontDamage,
				type = JJS.DMG.MELEE,
				stun = cfg.FrontStun,
				block = "normal",
				fx = "light",
			}
			if var == 1 then
				local rc = cfg.FrontRagdoll
				hit.ragdoll = { time = rc.time, vel = fwd * rc.h + Vector( 0, 0, rc.v ) }
				hit.fx = "heavy"
			end
			if JJS.Hit( target, hit ) == "blocked" then
				JJS.ExtendAction( ply, cfg.FrontBlockedEndlag )
			end
		end },
	},
} )

JJS.RegisterAction( "dash_whiff", {
	dur = cfg.FrontWhiffEndlag,
	moveMult = 0.1,
	noJump = true,
	gesture = "range_fists_r",
} )
