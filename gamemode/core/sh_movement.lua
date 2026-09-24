-- Movement: walk/run (double tap W), HP-scaled speed, block/stun slowdowns, wall run + wall
-- jumps (count depends on HP), landing roll, parkour vault/climb, and the predicted
-- SetupMove / Move / FinishMove hooks that drive every other system.

local S = JJS.STUD
local U = JJS.Util
local cfg = JJS.Config

JJS.Move = JJS.Move or {}
local M = JJS.Move

local function TraceWorld( start, endpos )
	return util.TraceLine( {
		start = start,
		endpos = endpos,
		filter = player.GetAll(),
		mask = MASK_PLAYERSOLID,
		collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT,
	} )
end

-- Hull slide with plane clipping (up to 4 bumps)
local function TryMove( ply, origin, vel, dt, mins, maxs )
	local planes = {}
	local left = dt
	for _ = 1, 4 do
		if left <= 0 or vel:LengthSqr() < 0.01 then break end
		local tr = U.MoveTrace( origin, origin + vel * left, mins, maxs, ply )
		if tr.AllSolid then return origin, Vector( 0, 0, 0 ) end
		if tr.Fraction > 0 then origin = tr.HitPos end
		if tr.Fraction >= 1 then break end
		left = left * ( 1 - tr.Fraction )
		planes[ #planes + 1 ] = tr.HitNormal
		for _, p in ipairs( planes ) do
			local d = vel:Dot( p )
			if d < 0 then vel = vel - p * d end
		end
	end
	return origin, vel
end

-- Scripted movement with collision, step-up and floor snapping. Used by dashes, rolls, wall runs.
function M.Slide( ply, mv, vel, dt, stepUp )
	local mins, maxs = ply:GetHull()
	local origin = mv:GetOrigin()
	local o1, v1 = TryMove( ply, origin, vel, dt, mins, maxs )

	if stepUp then
		local step = ply:GetStepSize()
		local up = U.MoveTrace( origin, origin + Vector( 0, 0, step ), mins, maxs, ply )
		local o2, v2 = TryMove( ply, up.HitPos, Vector( vel.x, vel.y, 0 ), dt, mins, maxs )
		local down = U.MoveTrace( o2, o2 - Vector( 0, 0, step ), mins, maxs, ply )
		if not down.StartSolid and down.Hit and down.HitNormal.z >= 0.7
			and ( down.HitPos - origin ):Length2DSqr() > ( o1 - origin ):Length2DSqr() + 1 then
			o1, v1 = down.HitPos, v2
		end
	end

	if vel.z <= 0 then
		local snap = U.MoveTrace( o1, o1 - Vector( 0, 0, ply:GetStepSize() ), mins, maxs, ply )
		if snap.Hit and not snap.StartSolid and snap.HitNormal.z >= 0.7 then o1 = snap.HitPos end
	end

	mv:SetOrigin( o1 )
	mv:SetVelocity( v1 )
end

function M.IsGrounded( ply, mv )
	local mins, maxs = ply:GetHull()
	local o = mv:GetOrigin()
	local tr = U.MoveTrace( o, o - Vector( 0, 0, 2 ), mins, maxs, ply )
	return tr.Hit and tr.HitNormal.z >= 0.7
end

function M.WallJumpTier( ply )
	local f = JJS.GetHealthFrac( ply )
	for _, t in ipairs( cfg.WallJump.Tiers ) do
		if f > t[ 1 ] then return t[ 2 ] end
	end
	return 1
end

function M.GetSpeed( ply, mv )
	local busy = JJS.IsBusy( ply )
	local running = mv:KeyDown( JJS.IN.RUN ) and mv:GetForwardSpeed() > 0 and JJS.CanAct( ply )
		and not JJS.IsBlocking( ply ) and not busy
	if ply:GetJRunning() ~= running then ply:SetJRunning( running ) end

	if JJS.IsStunned( ply ) then return 0 end

	local speed = running and cfg.RunSpeed or cfg.WalkSpeed
	speed = speed * Lerp( JJS.GetHealthFrac( ply ), cfg.HealthSpeedMin, 1 )
	if JJS.IsBlocking( ply ) then speed = speed * cfg.BlockSpeedMult end
	if busy then speed = speed * JJS.GetMoveMult( ply ) end
	if JJS.InEndlag( ply ) then speed = speed * cfg.EndlagSpeedMult end

	if ply:GetJBuffEnd() > CurTime() then speed = speed * ply:GetJBuffMult() end

	local char = JJS.GetChar( ply )
	if char and char.SpeedMult then speed = speed * char.SpeedMult( ply ) end
	return speed
end

function M.CanJump( ply )
	if not JJS.CanAct( ply ) or JJS.IsBlocking( ply ) or JJS.IsDashing( ply ) then return false end
	local def = JJS.GetAction( ply )
	return not ( def and def.noJump )
end

------------------------------------------------------------------------------------------
-- Wall run / wall jump
------------------------------------------------------------------------------------------

local function FindWall( ply, mv, side )
	local yaw = mv:GetMoveAngles().y
	local fwd, right = U.YawForward( yaw ), U.YawRight( yaw ) * side
	local origin = mv:GetOrigin() + Vector( 0, 0, 40 )
	local reach = 16 + cfg.WallJump.Reach
	local diag = ( right + fwd ):GetNormalized()
	for _, d in ipairs( { right, diag, fwd } ) do
		local tr = TraceWorld( origin, origin + d * reach )
		if tr.Hit and not tr.HitSky and math.abs( tr.HitNormal.z ) < 0.3 then return tr.HitNormal end
	end
end

function M.CheckWallRun( ply, mv )
	if ply:IsOnGround() or not mv:KeyDown( IN_JUMP ) then return end
	if ply:GetJMoveState() ~= JJS.MOVE_NONE or ply:GetJWallJumps() <= 0 then return end
	if not JJS.CanAct( ply ) or JJS.IsBusy( ply ) or JJS.IsDashing( ply ) or JJS.IsBlocking( ply ) then return end
	if CurTime() - ply:GetJMoveStart() < cfg.WallJump.Cooldown then return end

	local f, s = U.InputDir( mv )
	if f <= 0 or s == 0 then return end

	local n = FindWall( ply, mv, s )
	if not n then return end
	ply:SetJMoveState( JJS.MOVE_WALLRUN )
	ply:SetJMoveStart( CurTime() )
	ply:SetJMoveA( n )
end

local function WallRunMove( ply, mv, t )
	local wc = cfg.WallJump
	local n = ply:GetJMoveA()
	local fwd = U.YawForward( mv:GetMoveAngles().y )
	local tan = fwd - n * fwd:Dot( n )
	tan.z = 0
	if tan:LengthSqr() < 0.01 then tan = Vector( -n.y, n.x, 0 ) end
	tan:Normalize()

	local origin = mv:GetOrigin() + Vector( 0, 0, 40 )
	local touching = TraceWorld( origin, origin - n * ( 16 + wc.Reach + 8 ) ).Hit

	if t >= wc.RunTime or not touching or not mv:KeyDown( IN_JUMP ) then
		mv:SetVelocity( n * wc.KickOut + tan * wc.KickAlong + Vector( 0, 0, wc.KickUp ) )
		ply:SetJMoveState( JJS.MOVE_NONE )
		ply:SetJMoveStart( CurTime() )
		ply:SetJWallJumps( math.max( 0, ply:GetJWallJumps() - 1 ) )
		hook.Run( "JJS_WallJump", ply, n )
		if IsFirstTimePredicted() then
			local ed = EffectData()
			ed:SetOrigin( mv:GetOrigin() + Vector( 0, 0, 30 ) - n * 16 )
			ed:SetNormal( n )
			ed:SetEntity( ply )
			util.Effect( "jjs_walljump", ed )
		end
		return false
	end

	M.Slide( ply, mv, tan * wc.RunSpeed + Vector( 0, 0, wc.RunLift ) - n * 30, FrameTime(), false )
	return true
end

------------------------------------------------------------------------------------------
-- Landing roll
------------------------------------------------------------------------------------------

local function OnLand( ply, mv, fall, sincePress )
	local jumpHeight = cfg.JumpPower ^ 2 / ( 2 * cfg.Gravity )
	if fall < jumpHeight * 1.05 or sincePress > cfg.Roll.Window then return end
	if not JJS.CanAct( ply ) or JJS.IsBusy( ply ) or JJS.IsDashing( ply ) then return end

	local vel = mv:GetVelocity()
	local h = Vector( vel.x, vel.y, 0 )
	local dir = h:LengthSqr() > 400 and h:GetNormalized() or U.YawForward( mv:GetMoveAngles().y )
	local dist = math.min( cfg.Roll.Max, cfg.Roll.Base + fall / S * cfg.Roll.PerStud )

	ply:SetJMoveState( JJS.MOVE_ROLL )
	ply:SetJMoveStart( CurTime() )
	ply:SetJMoveA( dir )
	ply:SetJMoveB( Vector( dist, h:Length(), 0 ) )
	hook.Run( "JJS_Roll", ply, fall, dist )
end

local function RollMove( ply, mv, t )
	local rc = cfg.Roll
	local u = t / rc.Time
	local dir, b = ply:GetJMoveA(), ply:GetJMoveB()
	local dist, keep = b.x, b.y

	if u >= 1 then
		ply:SetJMoveState( JJS.MOVE_NONE )
		ply:SetJMoveStart( CurTime() )
		local v = dir * math.max( keep, cfg.WalkSpeed * 0.8 )
		v.z = mv:GetVelocity().z
		mv:SetVelocity( v )
		return false
	end

	local speed = math.max( keep, dist / rc.Time * ( 1.5 - u ) )
	local vz = M.IsGrounded( ply, mv ) and 0 or ( mv:GetVelocity().z - cfg.Gravity * FrameTime() )
	M.Slide( ply, mv, dir * speed + Vector( 0, 0, vz ), FrameTime(), true )
	return true
end

------------------------------------------------------------------------------------------
-- Parkour: vault low obstacles, climb ledges, slide under raised ones while running
------------------------------------------------------------------------------------------

-- Obstacle that blocks a standing player but leaves a gap a crouching one fits through
local function CheckSlide( ply, mv, fwd )
	local sc = cfg.Slide
	local pos = mv:GetOrigin()
	local mins, maxs = ply:GetHull()
	local dmins, dmaxs = ply:GetHullDuck()
	if dmaxs.z < sc.GapMin then return end
	local ahead = pos + fwd * sc.ProbeDistance
	local stand = U.MoveTrace( pos, ahead, mins, maxs, ply )
	if not stand.Hit or stand.StartSolid or stand.HitNormal.z > 0.5 then return end
	local duck = U.MoveTrace( pos, ahead, dmins, dmaxs, ply )
	if duck.Hit then return end
	ply:SetJMoveState( JJS.MOVE_SLIDE )
	ply:SetJMoveStart( CurTime() )
	ply:SetJMoveA( fwd )
	hook.Run( "JJS_Parkour", ply, "slide", 0 )
end

function M.CheckParkour( ply, mv )
	if not ply:GetJRunning() or not ply:IsOnGround() or ply:GetJMoveState() ~= JJS.MOVE_NONE then return end
	if JJS.IsBusy( ply ) or JJS.IsDashing( ply ) or not JJS.CanAct( ply ) or mv:GetForwardSpeed() <= 0 then return end

	local pc = cfg.Parkour
	local pos = mv:GetOrigin()
	local fwd = U.YawForward( mv:GetMoveAngles().y )
	local step = ply:GetStepSize()

	local knee = pos + Vector( 0, 0, step + 4 )
	local tr = U.MoveTrace( knee, knee + fwd * pc.ProbeDistance, Vector( -12, -12, 0 ), Vector( 12, 12, 4 ), ply )
	if not tr.Hit then
		CheckSlide( ply, mv, fwd )
		return
	end
	if tr.StartSolid or tr.HitNormal.z > 0.5 then return end

	local probe = tr.HitPos + fwd * 14
	local down = TraceWorld( probe + Vector( 0, 0, pc.ClimbMaxHeight - step ), Vector( probe.x, probe.y, pos.z ) )
	if not down.Hit or down.StartSolid then return end

	local top = down.HitPos
	local h = top.z - pos.z
	if h <= step + 2 then return end

	local mins, maxs = ply:GetHull()
	if h <= pc.VaultMaxHeight then
		-- stairs keep rising behind the "obstacle": walk them instead of vaulting
		local beyond = top + fwd * 24
		local further = TraceWorld( beyond + Vector( 0, 0, 60 ), beyond - Vector( 0, 0, 8 ) )
		if further.Hit and further.HitPos.z > top.z + 4 then return end
		if not U.HullFits( ply, top + Vector( 0, 0, 4 ) ) then return end
		local over = top + fwd * 44
		local land = U.MoveTrace( over + Vector( 0, 0, 8 ), over - Vector( 0, 0, h + 48 ), mins, maxs, ply )
		local dest
		if land.Hit and not land.StartSolid and land.HitNormal.z >= 0.7 then
			dest = land.HitPos
		else
			dest = top + Vector( 0, 0, 2 )
		end
		ply:SetJMoveState( JJS.MOVE_VAULT )
		ply:SetJMoveStart( CurTime() )
		ply:SetJMoveA( pos )
		ply:SetJMoveB( dest )
		ply:SetJMoveC( Vector( ( pos.x + dest.x ) / 2, ( pos.y + dest.y ) / 2, top.z + 18 ) )
		hook.Run( "JJS_Parkour", ply, "vault", h )
	elseif h <= pc.ClimbMaxHeight then
		local dest = top + fwd * 20 + Vector( 0, 0, 2 )
		if not U.HullFits( ply, dest ) or not U.HullFits( ply, Vector( pos.x, pos.y, top.z + 2 ) ) then return end
		ply:SetJMoveState( JJS.MOVE_CLIMB )
		ply:SetJMoveStart( CurTime() )
		ply:SetJMoveA( pos )
		ply:SetJMoveB( dest )
		ply:SetJMoveC( Vector( pos.x, pos.y, top.z + 2 ) )
		hook.Run( "JJS_Parkour", ply, "climb", h )
	end
end

local function ParkourMove( ply, mv, t, state )
	local pc = cfg.Parkour
	local T = state == JJS.MOVE_VAULT and pc.VaultTime or pc.ClimbTime
	local u = math.min( t / T, 1 )
	local A, B, C = ply:GetJMoveA(), ply:GetJMoveB(), ply:GetJMoveC()
	local p

	if state == JJS.MOVE_VAULT then
		local e = U.Ease.InOutSine( u )
		p = A * ( 1 - e ) ^ 2 + C * ( 2 * ( 1 - e ) * e ) + B * e ^ 2
	else
		if u < 0.62 then
			p = LerpVector( U.Ease.OutQuad( u / 0.62 ), A, C )
		else
			p = LerpVector( U.Ease.InOutSine( ( u - 0.62 ) / 0.38 ), C, B )
		end
	end

	local fwd = U.Flat( B - A )
	if u >= 1 then
		mv:SetOrigin( B )
		mv:SetVelocity( fwd * ( state == JJS.MOVE_VAULT and cfg.RunSpeed or cfg.WalkSpeed ) )
		ply:SetJMoveState( JJS.MOVE_NONE )
		ply:SetJMoveStart( CurTime() )
		return false
	end

	mv:SetVelocity( ( p - mv:GetOrigin() ) / math.max( FrameTime(), 0.001 ) )
	mv:SetOrigin( p )
	return true
end

-- The engine keeps moving (and crouching) the player; we only keep the momentum up
local function SlideMove( ply, mv, t )
	local u = t / cfg.Slide.Time
	local dir = ply:GetJMoveA()
	local vz = mv:GetVelocity().z
	if u >= 1 then
		ply:SetJMoveState( JJS.MOVE_NONE )
		ply:SetJMoveStart( CurTime() )
		return false
	end
	local v = dir * cfg.RunSpeed * ( 1.25 - 0.35 * u )
	v.z = vz
	mv:SetVelocity( v )
	return false
end

function M.StateMove( ply, mv )
	local state = ply:GetJMoveState()
	if state == JJS.MOVE_NONE then return false end
	local t = CurTime() - ply:GetJMoveStart()
	if state == JJS.MOVE_WALLRUN then return WallRunMove( ply, mv, t ) end
	if state == JJS.MOVE_ROLL then return RollMove( ply, mv, t ) end
	if state == JJS.MOVE_SLIDE then return SlideMove( ply, mv, t ) end
	return ParkourMove( ply, mv, t, state )
end

------------------------------------------------------------------------------------------
-- Hooks
------------------------------------------------------------------------------------------

local function StripKey( mv, key )
	mv:SetButtons( bit.band( mv:GetButtons(), bit.bnot( key ) ) )
end

function GM:SetupMove( ply, mv, cmd )
	if not ply:Alive() then return end
	local now = CurTime()
	local pt = ply:GetTable()
	JJS.ApplyScale( ply )

	if SERVER then
		local sl = ply:IsBot() or ply:GetInfoNum( "jjs_shiftlock", 1 ) ~= 0
		if ply:GetJShiftLock() ~= sl then ply:SetJShiftLock( sl ) end
	end

	local dashPressed = mv:KeyPressed( JJS.IN.DASH )

	if ply:GetJRagdolled() then
		if SERVER then
			local f, s = U.InputDir( mv )
			local yaw = mv:GetMoveAngles().y
			local dir = U.YawForward( yaw ) * f + U.YawRight( yaw ) * s
			if dir:LengthSqr() > 0 then dir:Normalize() end
			JJS.Ragdoll.SetInput( ply, dir )
		end
		if dashPressed then JJS.Dash.TryStart( ply, mv ) end
		if ply:GetJRagdolled() then
			mv:SetForwardSpeed( 0 )
			mv:SetSideSpeed( 0 )
			mv:SetUpSpeed( 0 )
			StripKey( mv, IN_JUMP )
			return
		end
	end

	if mv:KeyPressed( IN_JUMP ) and not ply:IsOnGround() then pt.jjs_jumpPress = now end

	-- block is held
	local canBlock = JJS.CanAct( ply ) and not JJS.IsBusy( ply ) and not JJS.IsDashing( ply ) and ply:GetJMoveState() == JJS.MOVE_NONE
	if mv:KeyDown( JJS.IN.BLOCK ) and canBlock then
		if not JJS.IsBlocking( ply ) then ply:SetJBlockStart( now ) end
	elseif JJS.IsBlocking( ply ) then
		ply:SetJBlockStart( 0 )
	end

	if dashPressed then JJS.Dash.TryStart( ply, mv ) end
	-- a dash forced on the player (Clairvoyance's Prediction): local direction set by the server
	if pt.jjs_forceDash then
		JJS.Dash.Begin( ply, mv, JJS.Dash.SIDE, pt.jjs_forceDash, true )
		pt.jjs_forceDash = nil
	end

	for slot = 1, 4 do
		if mv:KeyPressed( JJS.AbilityKeys[ slot ] ) then JJS.TryAbility( ply, mv, slot ) end
	end
	if mv:KeyPressed( JJS.IN.SPECIAL ) then JJS.TryAbility( ply, mv, 5 ) end
	if mv:KeyPressed( JJS.IN.AWAKEN ) then JJS.TryAwaken( ply, mv ) end

	JJS.M1.TryStart( ply, mv )
	M.CheckParkour( ply, mv )
	M.CheckWallRun( ply, mv )

	local speed = M.GetSpeed( ply, mv )
	mv:SetMaxSpeed( speed )
	mv:SetMaxClientSpeed( speed )

	if JJS.IsStunned( ply ) or JJS.InEndlag( ply ) then
		mv:SetForwardSpeed( 0 )
		mv:SetSideSpeed( 0 )
	end
	if not M.CanJump( ply ) then StripKey( mv, IN_JUMP ) end
	if ply:GetJMoveState() == JJS.MOVE_SLIDE then
		mv:SetButtons( bit.bor( mv:GetButtons(), IN_DUCK ) )
		StripKey( mv, IN_JUMP )
	end
end

function GM:Move( ply, mv )
	if not ply:Alive() then return end
	if ply:GetJRagdolled() then return true end
	if JJS.Dash.Move( ply, mv ) then return true end
	if M.StateMove( ply, mv ) then return true end

	local def = JJS.GetAction( ply )
	if def and def.move and def.move( ply, mv, JJS.ActionTime( ply ), ply:GetJActVar() ) then return true end

	-- free flight: along the camera with the movement keys, jump rises, crouch sinks
	if JJS.IsFlying( ply ) then
		local ang = mv:GetMoveAngles()
		local f, s = U.InputDir( mv )
		local dir = ang:Forward() * f + ang:Right() * s
		if mv:KeyDown( IN_JUMP ) then dir.z = dir.z + 1 end
		if mv:KeyDown( IN_DUCK ) then dir.z = dir.z - 1 end
		local vel = dir:LengthSqr() > 0 and dir:GetNormalized() * 30 * JJS.STUD or mv:GetVelocity() * 0.85
		M.Slide( ply, mv, vel, FrameTime(), false )
		return true
	end

	-- gliding (Blazing Star): carried along at speed, steering slightly toward the camera; a stun ends it
	if JJS.IsGliding( ply ) then
		if JJS.IsStunned( ply ) then
			JJS.Glide( ply, nil, 0 )
		else
			local gv = ply:GetNW2Vector( "JJSGlideVel", vector_origin )
			local speed = gv:Length()
			local dir = U.Flat( gv )
			local want = U.YawForward( mv:GetMoveAngles().y )
			dir = ( dir * 0.9 + want * 0.1 ):GetNormalized()
			local vz = M.IsGrounded( ply, mv ) and 0 or ( mv:GetVelocity().z - cfg.Gravity * FrameTime() )
			M.Slide( ply, mv, dir * speed + Vector( 0, 0, vz ), FrameTime(), true )
			return true
		end
	end

	-- hovering (air combos): suspended in the air, drifting slowly with the movement keys
	if JJS.IsHovering( ply ) then
		local yaw = mv:GetMoveAngles().y
		local f, s = U.InputDir( mv )
		local drift = ( U.YawForward( yaw ) * f + U.YawRight( yaw ) * s ) * 4 * JJS.STUD
		local vel = mv:GetVelocity() * 0.8 + drift * 0.2
		vel.z = 0
		M.Slide( ply, mv, vel, FrameTime(), false )
		return true
	end
end

function GM:FinishMove( ply, mv )
	if not ply:Alive() then return end
	JJS.TickAction( ply, mv )
	JJS.Domain.Barrier( ply, mv )

	local pt = ply:GetTable()
	if SERVER and pt.jjs_pendingPos then
		mv:SetOrigin( pt.jjs_pendingPos )
		pt.jjs_pendingPos = nil
	end
	if SERVER and pt.jjs_pendingVel then
		mv:SetVelocity( mv:GetVelocity() + pt.jjs_pendingVel )
		pt.jjs_pendingVel = nil
	end

	local onGround = ply:IsOnGround()
	local z = mv:GetOrigin().z
	if not onGround then
		if pt.jjs_wasGround ~= false then pt.jjs_airTop = z end
		pt.jjs_airTop = math.max( pt.jjs_airTop or z, z )
	else
		if pt.jjs_wasGround == false and ply:GetJMoveState() == JJS.MOVE_NONE then
			OnLand( ply, mv, ( pt.jjs_airTop or z ) - z, CurTime() - ( pt.jjs_jumpPress or -10 ) )
		end
		local jumps = M.WallJumpTier( ply )
		if ply:GetJWallJumps() ~= jumps and ply:GetJMoveState() ~= JJS.MOVE_WALLRUN then ply:SetJWallJumps( jumps ) end
	end
	pt.jjs_wasGround = onGround
end

-- Server-side teleport that also holds when made from inside the player's own movement (action events), where
-- a plain SetPos would be overwritten by the movement result
function JJS.Teleport( ply, pos )
	ply:SetPos( pos )
	ply.jjs_pendingPos = pos
end

-- Server-side velocity impulse applied inside the player's next movement (keeps prediction sane)
function JJS.Impulse( ply, vel )
	ply.jjs_pendingVel = ( ply.jjs_pendingVel or Vector( 0, 0, 0 ) ) + vel
end
