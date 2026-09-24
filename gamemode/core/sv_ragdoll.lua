-- Ragdoll state: the player is hidden and a physics ragdoll takes over.
-- Regular ragdoll: the timer starts on first contact with a surface.
-- True ragdoll: the timer starts immediately and it can't be evasive-cancelled.

JJS.Ragdoll = JJS.Ragdoll or {}
local R = JJS.Ragdoll
local U = JJS.Util
local cfg = JJS.Config.Ragdoll

local function Pelvis( rag )
	return rag:GetPhysicsObjectNum( 0 )
end

local function SetVelocityAll( rag, vel, add )
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local p = rag:GetPhysicsObjectNum( i )
		if IsValid( p ) then
			if add then p:AddVelocity( vel ) else p:SetVelocity( vel ) end
			p:Wake()
		end
	end
end
R.SetVelocity = SetVelocityAll

local function StartTimer( ply, st )
	st.landed = true
	st.endTime = CurTime() + st.dur
	ply:SetJRagdollEnd( st.endTime )
end

-- Being slammed into a wall/floor fast enough breaks it (like JJS knockback destruction)
local function ImpactCrater( rag, data )
	local vel = data.OurOldVelocity
	local speed = vel:Length()
	if speed < cfg.ImpactSpeed or ( rag.jjs_nextCrater or 0 ) > CurTime() then return end
	rag.jjs_nextCrater = CurTime() + 0.4

	local dir = vel / speed
	local hitPos = data.HitPos
	local scale = math.Clamp( speed / JJS.STUD * cfg.ImpactScalePerStud, 600, 1800 )
	timer.Simple( 0, function()
		local tr = util.TraceLine( {
			start = hitPos - dir * 24,
			endpos = hitPos + dir * 24,
			mask = MASK_SOLID_BRUSHONLY,
		} )
		if tr.Hit and not tr.HitSky then
			JJS.Destruction.Crater( tr.HitPos, tr.HitNormal, scale, dir, tr.SurfaceProps )
		end
	end )
end

local function OnCollide( rag, data )
	local ply = rag.jjs_owner
	if not IsValid( ply ) then return end
	local st = ply.jjs_rag
	if not st or st.ent ~= rag then return end
	local other = data.HitEntity
	if IsValid( other ) and ( other:IsPlayer() or other:IsRagdoll() ) then return end

	if not IsValid( other ) or other:IsWorld() then ImpactCrater( rag, data ) end
	if not st.landed then StartTimer( ply, st ) end
end

-- opt: time (s), trueRag (bool), vel (Vector), dead (bool), spin (false to disable tumble)
function R.Apply( ply, opt, attacker )
	opt = opt or {}
	local now = CurTime()
	local vel = opt.vel or Vector( 0, 0, 0 )

	JJS.StopAction( ply, true )
	ply:SetJBlockStart( 0 )
	ply:SetJDashType( 0 )
	ply:SetJMoveState( JJS.MOVE_NONE )

	local st = ply.jjs_rag
	if st and IsValid( st.ent ) then
		st.dur = opt.time or st.dur
		st.trueRag = opt.trueRag or false
		st.dead = st.dead or opt.dead
		st.start = now
		if st.trueRag then
			StartTimer( ply, st )
		else
			st.landed = false
			st.endTime = nil
			ply:SetJRagdollEnd( 0 )
		end
		ply:SetJTrueRagdoll( st.trueRag )
		SetVelocityAll( st.ent, vel )
		return st.ent
	end

	local rag = ents.Create( "prop_ragdoll" )
	if not IsValid( rag ) then return end
	rag:SetModel( ply:GetModel() )
	rag:SetPos( ply:GetPos() )
	rag:SetAngles( Angle( 0, ply:EyeAngles().y, 0 ) )
	rag:SetSkin( ply:GetSkin() )
	for _, bg in ipairs( ply:GetBodyGroups() ) do
		rag:SetBodygroup( bg.id, ply:GetBodygroup( bg.id ) )
	end
	rag:Spawn()
	rag:Activate()
	rag:SetCollisionGroup( COLLISION_GROUP_WEAPON )
	rag:SetCustomCollisionCheck( true )
	rag.JJSRagdoll = true
	rag.jjs_owner = ply
	rag:SetNWBool( "JJSRagdoll", true )
	rag:SetNWEntity( "JJSOwner", ply )
	rag:AddCallback( "PhysicsCollide", OnCollide )

	-- copy the current pose so the ragdoll starts exactly where the model was
	-- (the server keeps player bones animated; SetupBones only exists clientside)
	local base = ply:GetVelocity() * 0.3
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum( i )
		if not IsValid( phys ) then continue end
		local bone = rag:TranslatePhysBoneToBone( i )
		local m = bone and bone >= 0 and ply:GetBoneMatrix( bone )
		if m then
			phys:SetPos( m:GetTranslation() )
			phys:SetAngles( m:GetAngles() )
		end
		phys:SetVelocity( base + vel )
		phys:Wake()
	end
	if opt.spin ~= false then
		local p = Pelvis( rag )
		if IsValid( p ) then p:AddAngleVelocity( VectorRand() * 180 ) end
	end

	st = {
		ent = rag,
		dur = opt.time or 1,
		trueRag = opt.trueRag or false,
		dead = opt.dead,
		landed = false,
		start = now,
		safePos = ply:GetPos(),
	}
	ply.jjs_rag = st
	if st.trueRag then StartTimer( ply, st ) else ply:SetJRagdollEnd( 0 ) end

	ply:SetJRagdolled( true )
	ply:SetJTrueRagdoll( st.trueRag )
	ply:SetJRagEnt( rag )

	ply:SetMoveType( MOVETYPE_NONE )
	ply:SetNotSolid( true )
	ply:SetNoDraw( true )
	ply:DrawShadow( false )
	ply:SetLocalVelocity( vector_origin )
	return rag
end

function R.MarkDead( ply )
	local st = ply.jjs_rag
	if st then st.dead = true end
end

-- World-space influence direction from the player's input (set in SetupMove)
function R.SetInput( ply, dir )
	local st = ply.jjs_rag
	if st then st.input = dir end
end

local OFFSETS = {}
for i = 0, 7 do
	local a = math.rad( i * 45 )
	OFFSETS[ #OFFSETS + 1 ] = Vector( math.cos( a ) * 24, math.sin( a ) * 24, 0 )
end
OFFSETS[ #OFFSETS + 1 ] = Vector( 0, 0, 36 )

function R.FindStandPos( ply, pelvis, fallback )
	local mins, maxs = ply:GetHull()
	local function Try( p )
		local tr = U.MoveTrace( p + Vector( 0, 0, 8 ), p - Vector( 0, 0, 36 ), mins, maxs, ply )
		if not tr.StartSolid then return tr.HitPos end
	end
	local pos = Try( pelvis )
	if pos then return pos end
	for _, off in ipairs( OFFSETS ) do
		pos = Try( pelvis + off )
		if pos then return pos end
	end
	return fallback or pelvis
end

function R.Stop( ply, reason )
	local st = ply.jjs_rag
	if not st then return end
	ply.jjs_rag = nil

	local rag = st.ent
	local pos = ply:GetPos() + Vector( 0, 0, 36 )
	if IsValid( rag ) then
		local p = Pelvis( rag )
		if IsValid( p ) then pos = p:GetPos() end
		rag:Remove()
	end

	ply:SetJRagdolled( false )
	ply:SetJTrueRagdoll( false )
	ply:SetJRagEnt( NULL )
	ply:SetJRagdollEnd( 0 )

	if not ply:Alive() then return end

	ply:SetMoveType( MOVETYPE_WALK )
	ply:SetNotSolid( false )
	ply:SetNoDraw( false )
	ply:DrawShadow( true )
	ply:SetPos( R.FindStandPos( ply, pos, st.safePos ) )
	ply:SetLocalVelocity( vector_origin )

	if reason == "wake" then
		ply:SetJMeleeImmuneEnd( CurTime() + cfg.WakeMeleeImmunity )
	end
	hook.Run( "JJS_RagdollEnd", ply, reason )
end

-- Removes any ragdoll without restoring the player (spawn / disconnect)
function R.Remove( ply )
	local st = ply.jjs_rag
	if st and IsValid( st.ent ) then st.ent:Remove() end
	ply.jjs_rag = nil
end

function R.Tick( ply, now, dt )
	local st = ply.jjs_rag
	if not st then return end

	local rag = st.ent
	local pelvis = IsValid( rag ) and Pelvis( rag ) or nil
	if not IsValid( pelvis ) then
		if st.dead then return end
		R.Stop( ply, "lost" )
		return
	end

	local pos = pelvis:GetPos()
	if ply:Alive() then
		-- keep the hidden player on the ragdoll: hit tests, PVS and the camera use it
		ply:SetPos( pos - Vector( 0, 0, 12 ) )
	end

	if st.dead then return end

	-- fallback when the collide callback missed a soft landing
	if not st.landed and now - st.start > 0.2 and pelvis:GetVelocity():LengthSqr() < 3600 then
		StartTimer( ply, st )
	end

	-- ragdoll influence: accelerate toward the held direction while in motion
	if st.input and st.input:LengthSqr() > 0 and pelvis:GetVelocity():LengthSqr() > ( 2 * JJS.STUD ) ^ 2 then
		SetVelocityAll( rag, st.input * cfg.InfluenceAccel * dt, true )
	end

	if ( st.endTime and now >= st.endTime ) or now - st.start > cfg.MaxTime then
		R.Stop( ply, "wake" )
	end
end
