-- Automated test scenarios for development. Inactive unless data/jjs_autotest.txt exists
-- (its content picks the scenario). The client plays a scripted input timeline, the server
-- places dummies/props and logs events as "[JJSTEST]" lines, screenshots go to
-- data/jjs_test/*.jpg. Run with tools/run_test.ps1 -Scenario <name>.

if not file.Exists( "jjs_autotest.txt", "DATA" ) then return end

local NAME = string.Trim( file.Read( "jjs_autotest.txt", "DATA" ) or "" )
if NAME == "" then NAME = "core" end

local S = JJS.STUD
local U = JJS.Util

local function Log( msg )
	print( string.format( "[JJSTEST] %7.2f %s", CurTime(), msg ) )
end

local function Nick( p )
	return IsValid( p ) and p:Nick() or tostring( p )
end

------------------------------------------------------------------------------------------
-- Scenarios. Server: setup(ctx) + events { t, fn(ctx) }. Client: input { start, dur, keys },
-- shots { t, name }, free (time ranges where the camera isn't aimed at the nearest bot).
------------------------------------------------------------------------------------------

local SC = {}

local function Ahead( ctx, studs, side )
	return ctx.home + U.YawForward( ctx.yaw ) * studs * S + U.YawRight( ctx.yaw ) * ( side or 0 ) * S
end

local function ResetDummy( d )
	if not IsValid( d ) then return end
	if d:GetJRagdolled() then JJS.Ragdoll.Stop( d, "test" ) end
	d:SetJStunEnd( 0 )
	d:SetPos( d.jjs_dummy.pos )
	d:SetLocalVelocity( vector_origin )
end

local function Teleport( ply, pos, yaw )
	ply:SetPos( pos )
	ply:SetLocalVelocity( vector_origin )
	if yaw then ply:SetEyeAngles( Angle( 0, yaw, 0 ) ) end
end

SC.core = {
	finish = 23,
	setup = function( ctx )
		ctx.dummy = JJS.SpawnDummy( JJS.DUMMY.normal, Ahead( ctx, 6 ), Angle( 0, ctx.yaw + 180, 0 ) )
	end,
	events = {
		{ 3.4, function( ctx ) ResetDummy( ctx.dummy ) end },
		{ 6.9, function( ctx ) ResetDummy( ctx.dummy ) end },
		{ 9.5, function( ctx ) ResetDummy( ctx.dummy ) JJS.SetDummyKind( ctx.dummy, JJS.DUMMY.block ) Log( "dummy -> block" ) end },
		{ 12.0, function( ctx )
			ResetDummy( ctx.dummy )
			JJS.SetDummyKind( ctx.dummy, JJS.DUMMY.evasive )
			ctx.dummy:SetJEvasive( 1 )
			Log( "dummy -> evasive" )
		end },
		{ 15.5, function( ctx ) ResetDummy( ctx.dummy ) JJS.SetDummyKind( ctx.dummy, JJS.DUMMY.normal ) Log( "dummy -> normal" ) end },
	},
	input = {
		{ 1.0, 1.7, { M1 = true } }, -- 3 hit string, final neutral = ray
		{ 4.0, 0.08, { DASH = true, D = true } }, -- side dash right
		{ 4.0, 0.3, { D = true } },
		{ 5.4, 0.08, { DASH = true } }, -- front dash into the dummy
		{ 7.3, 1.2, { M1 = true } }, -- string with an uppercut finisher
		{ 7.9, 0.25, { JUMP = true } },
		{ 10.5, 0.9, { M1 = true } }, -- into the blocking dummy
		{ 12.8, 1.5, { M1 = true } }, -- ragdoll the evasive dummy
		{ 16.0, 0.08, { W = true } }, -- double tap W to run
		{ 16.16, 2.0, { W = true, RUN = true } },
		{ 18.6, 0.1, { JUMP = true } },
	},
	shots = {
		{ 0.5, "00_idle" }, { 1.58, "01_m1_second" }, { 2.03, "02_m1_ray" }, { 2.15, "02b_launch" },
		{ 2.4, "03_ragdoll" }, { 4.12, "04_side_dash" }, { 5.62, "05_front_dash_punch" }, { 8.25, "06_uppercut" },
		{ 10.72, "07_blocked" }, { 14.3, "08_evasive" }, { 17.3, "09_run" }, { 18.85, "10_jump" }, { 20.5, "11_hud" },
	},
	free = { { 16.0, 20.0 } },
}

-- Nearest vertical wall around a point (for the wall run test)
local function FindWall( pos )
	local best
	for i = 0, 15 do
		local d = U.YawForward( i * 22.5 )
		local tr = util.TraceLine( { start = pos + Vector( 0, 0, 40 ), endpos = pos + Vector( 0, 0, 40 ) + d * 900, mask = MASK_SOLID_BRUSHONLY } )
		if tr.Hit and not tr.HitSky and math.abs( tr.HitNormal.z ) < 0.1 and ( not best or tr.Fraction < best.Fraction ) then
			local top = util.TraceLine( { start = tr.HitPos + tr.HitNormal * 4 + Vector( 0, 0, 120 ), endpos = tr.HitPos + tr.HitNormal * 4 + Vector( 0, 0, 40 ), mask = MASK_SOLID_BRUSHONLY } )
			if not top.Hit then best = tr end -- tall enough to run along
		end
	end
	return best
end

local function SpawnBlock( pos, yaw, model )
	local e = ents.Create( "prop_physics" )
	e:SetModel( model )
	e:SetPos( pos )
	e:SetAngles( Angle( 0, yaw, 0 ) )
	e:Spawn()
	local phys = e:GetPhysicsObject()
	if IsValid( phys ) then phys:EnableMotion( false ) end
	local mins = e:OBBMins()
	e:SetPos( pos - Vector( 0, 0, mins.z ) )
	return e
end

SC.extra = {
	finish = 26,
	setup = function( ctx )
		ctx.dummy = JJS.SpawnDummy( JJS.DUMMY.lowhp, Ahead( ctx, 6 ), Angle( 0, ctx.yaw + 180, 0 ) )
	end,
	events = {
		-- 1: low HP dummy dies to one M1 and respawns after jjs_respawn_time
		{ 6.5, function( ctx )
			JJS.SetDummyKind( ctx.dummy, JJS.DUMMY.normal )
			ctx.dummy:SetJHP( 100 )
			ctx.dummy:SetHealth( 100 )
			ResetDummy( ctx.dummy )
			-- 2: downslam: drop from above with the string at its last hit
			local host = ctx.host
			host:SetJM1Index( JJS.GetChar( host ).m1.Count - 1 )
			host:SetJM1LastEnd( CurTime() + 1 )
			host:SetJM1CD( 0 )
			Teleport( host, Ahead( ctx, 4.5 ) + Vector( 0, 0, 120 ), ctx.yaw )
			Log( "downslam setup" )
		end },
		-- 3: two attacking dummies beat the host -> burst
		{ 8.5, function( ctx )
			Teleport( ctx.host, ctx.home, ctx.yaw )
			-- in front of and behind the host, 10 studs apart so their 8 stud M1 boxes don't reach each other
			ctx.a1 = JJS.SpawnDummy( JJS.DUMMY.attack, Ahead( ctx, 5 ), Angle( 0, ctx.yaw + 180, 0 ) )
			ctx.a2 = JJS.SpawnDummy( JJS.DUMMY.attack, Ahead( ctx, -5 ), Angle( 0, ctx.yaw, 0 ) )
			Log( "attackers spawned" )
		end },
		{ 12.0, function( ctx )
			for _, k in ipairs( { "a1", "a2" } ) do if IsValid( ctx[ k ] ) then ctx[ k ]:Kick( "test" ) end end
			ctx.host:SetJStunEnd( 0 )
			JJS.Heal( ctx.host, 100 )
			-- 4: wall run along the nearest wall (wall on the right)
			local wall = FindWall( ctx.home )
			if wall then
				local n = wall.HitNormal
				local yaw = math.deg( math.atan2( -n.x, n.y ) )
				Teleport( ctx.host, wall.HitPos - Vector( 0, 0, 40 ) + n * 44, yaw )
				Log( "wall at " .. tostring( wall.HitPos ) .. " normal " .. tostring( n ) )
			else
				Log( "no wall found" )
			end
		end },
		-- 5: fall from high up and press jump just before landing -> roll
		{ 15.0, function( ctx )
			ctx.host:SetJWallJumps( 3 )
			Teleport( ctx.host, ctx.home + Vector( 0, 0, 300 ), ctx.yaw )
			Log( "roll setup" )
		end },
		-- 6: parkour: a low crate to vault, then a taller block to climb
		{ 17.0, function( ctx )
			Teleport( ctx.host, ctx.home, ctx.yaw )
			ctx.low = SpawnBlock( Ahead( ctx, 9 ), ctx.yaw, "models/hunter/blocks/cube075x075x075.mdl" )
			ctx.high = SpawnBlock( Ahead( ctx, 22 ), ctx.yaw, "models/hunter/blocks/cube1x1x1.mdl" )
			Log( "parkour setup low=" .. tostring( ctx.low:OBBMaxs().z - ctx.low:OBBMins().z ) .. " high=" .. tostring( ctx.high:OBBMaxs().z - ctx.high:OBBMins().z ) )
		end },
	},
	input = {
		{ 1.0, 0.1, { M1 = true } },
		{ 6.62, 0.1, { M1 = true } },
		{ 10.6, 0.08, { DASH = true, A = true } },
		{ 10.6, 0.3, { A = true } },
		{ 13.0, 0.8, { W = true, D = true, JUMP = true } },
		{ 15.0, 0.9, { W = true } },
		{ 15.40, 0.08, { JUMP = true } },
		{ 17.3, 0.08, { W = true } },
		{ 17.46, 4.0, { W = true, RUN = true } },
	},
	shots = {
		{ 1.3, "e00_kill" }, { 5.5, "e01_respawn" }, { 6.95, "e02_downslam" }, { 10.2, "e03_burst_ready" },
		{ 10.7, "e04_burst" }, { 13.25, "e05_wallrun" }, { 13.6, "e06_walljump" }, { 15.55, "e07_roll" },
		{ 17.95, "e08_vault" }, { 18.6, "e09_climb" }, { 19.4, "e10_after" },
	},
	free = { { 12.0, 26 } },
}

-- Compares local bone rotations of Ryu and a stock ValveBiped model playing the same sequence
SC.bones = {
	finish = 4,
	setup = function() end,
	events = {},
	input = {},
	shots = {},
	client = function()
		local BONES = { "ValveBiped.Bip01_Pelvis", "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm",
			"ValveBiped.Bip01_R_Hand", "ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Finger1", "ValveBiped.Bip01_Head1" }
		local function Local( ent, name )
			local b = ent:LookupBone( name )
			local m = b and ent:GetBoneMatrix( b )
			if not m then return "nil" end
			local p = ent:GetBoneParent( b )
			local pm = p and p >= 0 and ent:GetBoneMatrix( p )
			if pm then
				local inv = Matrix( pm )
				inv:Invert()
				m = inv * m
			end
			local a, t = m:GetAngles(), m:GetTranslation()
			return string.format( "ang=(%7.2f %7.2f %7.2f) pos=(%6.2f %6.2f %6.2f)", a.p, a.y, a.r, t.x, t.y, t.z )
		end
		for _, seqName in ipairs( { "reference", "idle_all_01", "run_all_01" } ) do
			for _, mdl in ipairs( { "models/reiko/jujutsu/characters/ryu.mdl", "models/player/group01/male_07.mdl" } ) do
				local e = ClientsideModel( mdl )
				e:SetPos( Vector( 0, 0, 0 ) )
				e:SetAngles( Angle( 0, 0, 0 ) )
				local seq = e:LookupSequence( seqName )
				e:ResetSequence( seq )
				e:SetCycle( 0.25 )
				e:SetupBones()
				Log( string.format( "== %s seq=%s(%d) %s", seqName, tostring( seq ), seq, mdl ) )
				for _, bn in ipairs( BONES ) do Log( string.format( "   %-30s %s", bn, Local( e, bn ) ) ) end
				e:Remove()
			end
		end
	end,
}

-- Animation pipeline check: the patched Ryu plays a library sequence (and still has m_anm's)
local ANIM_MODELS = {}
SC.anim = {
	finish = 4,
	setup = function() end,
	events = {},
	input = {},
	shots = { { 1.2, "a00_models" } },
	free = { { 0, 10 } },
	client = function()
		local me = LocalPlayer()
		local yaw = me:EyeAngles().y
		local function Spawn( mdl, seqName, side )
			local e = ClientsideModel( mdl )
			e:SetPos( me:GetPos() + U.YawForward( yaw ) * 130 + U.YawRight( yaw ) * side )
			e:SetAngles( Angle( 0, yaw + 180, 0 ) )
			local seq = e:LookupSequence( seqName )
			e:ResetSequence( seq )
			e:SetCycle( 0 )
			e:SetPlaybackRate( 0 )
			e:SetupBones()
			ANIM_MODELS[ #ANIM_MODELS + 1 ] = e
			Log( string.format( "model %s seq %s -> %d (numseq %d)", mdl, seqName, seq, e:GetSequenceCount() ) )
			return e
		end
		local e = Spawn( "models/jjs/ryu.mdl", "jjs_test_pose", -45 )
		Spawn( "models/jjs/ryu.mdl", "idle_all_01", 45 )
		for _, bn in ipairs( { "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_Head1", "ValveBiped.Bip01_L_Thigh" } ) do
			local b = e:LookupBone( bn )
			local m, pm = e:GetBoneMatrix( b ), e:GetBoneMatrix( e:GetBoneParent( b ) )
			local inv = Matrix( pm )
			inv:Invert()
			local a = ( inv * m ):GetAngles()
			Log( string.format( "GOT %s p=%.2f y=%.2f r=%.2f", bn, a.p, a.y, a.r ) )
		end
		me:SetEyeAngles( Angle( 10, yaw, 0 ) )
	end,
}

local SCEN = SC[ NAME ] or SC.core

------------------------------------------------------------------------------------------
-- Server
------------------------------------------------------------------------------------------

if SERVER then
	util.AddNetworkString( "jjs_autotest" )

	hook.Add( "JJS_Hit", "JJS_AutoTest", function( victim, hit, res )
		Log( string.format( "HIT %s -> %s dmg=%.1f res=%s m1=%s var=%s ragdoll=%s hp=%.1f",
			Nick( hit.attacker ), Nick( victim ), hit.damage or 0, res, tostring( hit.m1Index ), tostring( hit.m1Variant ),
			hit.ragdoll and "yes" or "no", victim:GetJHP() ) )
	end )
	hook.Add( "JJS_Blocked", "JJS_AutoTest", function( victim, hit ) Log( "BLOCKED " .. Nick( hit.attacker ) .. " -> " .. Nick( victim ) ) end )
	hook.Add( "JJS_RagdollEnd", "JJS_AutoTest", function( ply, reason ) Log( "RAGDOLL_END " .. Nick( ply ) .. " reason=" .. reason ) end )
	hook.Add( "JJS_DashStart", "JJS_AutoTest", function( ply, typ ) Log( "DASH " .. Nick( ply ) .. " type=" .. typ ) end )
	hook.Add( "JJS_M1", "JJS_AutoTest", function( ply, idx, variant, landed, blocked )
		Log( string.format( "M1 %s idx=%d var=%d landed=%s blocked=%s", Nick( ply ), idx, variant, Nick( landed ), tostring( blocked ) ) )
	end )
	hook.Add( "JJS_PlayerDied", "JJS_AutoTest", function( ply, attacker ) Log( "DIED " .. Nick( ply ) .. " by " .. Nick( attacker ) ) end )
	hook.Add( "JJS_PlayerSpawned", "JJS_AutoTest", function( ply ) Log( "SPAWNED " .. Nick( ply ) ) end )
	hook.Add( "JJS_Burst", "JJS_AutoTest", function( ply ) Log( "BURST " .. Nick( ply ) .. " hp=" .. math.Round( ply:GetJHP(), 1 ) ) end )
	hook.Add( "JJS_WallJump", "JJS_AutoTest", function( ply ) Log( "WALLJUMP " .. Nick( ply ) .. " left=" .. ply:GetJWallJumps() ) end )
	hook.Add( "JJS_Roll", "JJS_AutoTest", function( ply, fall, dist ) Log( string.format( "ROLL %s fall=%.0f dist=%.0f", Nick( ply ), fall, dist ) ) end )
	hook.Add( "JJS_Parkour", "JJS_AutoTest", function( ply, kind, h ) Log( string.format( "PARKOUR %s %s h=%.0f", Nick( ply ), kind, h ) ) end )

	local ctx, fired, burstSeen = nil, {}, false

	hook.Add( "Think", "JJS_AutoTest", function()
		local host = player.GetHumans()[ 1 ]
		if not ctx then
			if not IsValid( host ) or not host:Alive() or CurTime() < 6 then return end
			-- face an open direction
			local yaw = host:EyeAngles().y
			for _ = 1, 4 do
				local tr = util.TraceHull( {
					start = host:GetPos() + Vector( 0, 0, 36 ),
					endpos = host:GetPos() + Vector( 0, 0, 36 ) + U.YawForward( yaw ) * 500,
					mins = Vector( -16, -16, -16 ), maxs = Vector( 16, 16, 16 ),
					filter = host,
				} )
				if tr.Fraction > 0.95 then break end
				yaw = yaw + 90
			end
			host:SetEyeAngles( Angle( 0, yaw, 0 ) )
			ctx = { host = host, home = host:GetPos(), yaw = yaw, start = CurTime() }
			SCEN.setup( ctx )
			Log( "START scenario=" .. NAME .. " map=" .. game.GetMap() .. " maxplayers=" .. game.MaxPlayers() )
			net.Start( "jjs_autotest" )
			net.Send( host )
			return
		end

		local t = CurTime() - ctx.start
		for i, ev in ipairs( SCEN.events ) do
			if not fired[ i ] and t >= ev[ 1 ] then
				fired[ i ] = true
				ev[ 2 ]( ctx )
			end
		end
		if not burstSeen and IsValid( host ) and host:GetJBurstEnd() > CurTime() then
			burstSeen = true
			Log( "BURST READY " .. Nick( host ) )
		end
		if t >= SCEN.finish and not fired.done then
			fired.done = true
			Log( "DONE" )
		end
	end )
	return
end

------------------------------------------------------------------------------------------
-- Client: scripted input + screenshots
------------------------------------------------------------------------------------------

local t0
net.Receive( "jjs_autotest", function()
	t0 = CurTime()
	Log( "client timeline start" )
	if SCEN.client then SCEN.client() end
end )

function JJS.AutoTestInput( cmd )
	if not t0 then return end
	local t = CurTime() - t0
	if t > SCEN.finish then return end

	local keys = {}
	for _, s in ipairs( SCEN.input ) do
		if t >= s[ 1 ] and t < s[ 1 ] + s[ 2 ] then
			for k in pairs( s[ 3 ] ) do keys[ k ] = true end
		end
	end

	cmd:ClearMovement()
	cmd:ClearButtons()
	if keys.M1 then cmd:AddKey( JJS.IN.M1 ) end
	if keys.BLOCK then cmd:AddKey( JJS.IN.BLOCK ) end
	if keys.DASH then cmd:AddKey( JJS.IN.DASH ) end
	if keys.JUMP then cmd:AddKey( IN_JUMP ) end
	if keys.RUN then cmd:AddKey( IN_SPEED ) end
	if keys.W then cmd:AddKey( IN_FORWARD ) cmd:SetForwardMove( 10000 ) end
	if keys.S then cmd:AddKey( IN_BACK ) cmd:SetForwardMove( -10000 ) end
	if keys.D then cmd:AddKey( IN_MOVERIGHT ) cmd:SetSideMove( 10000 ) end
	if keys.A then cmd:AddKey( IN_MOVELEFT ) cmd:SetSideMove( -10000 ) end

	for _, r in ipairs( SCEN.free or {} ) do
		if t >= r[ 1 ] and t < r[ 2 ] then return true end
	end

	local me = LocalPlayer()
	local best, bd
	for _, p in ipairs( player.GetBots() ) do
		if p:Alive() then
			local d = p:GetPos():DistToSqr( me:GetPos() )
			if not bd or d < bd then best, bd = p, d end
		end
	end
	if IsValid( best ) then
		local target = best:GetJRagdolled() and IsValid( best:GetJRagEnt() ) and best:GetJRagEnt():WorldSpaceCenter()
			or best:GetPos() + Vector( 0, 0, 40 )
		local ang = ( target - me:EyePos() ):Angle()
		ang.p = math.Clamp( ang.p, -30, 30 ) + 8
		cmd:SetViewAngles( ang )
	end
	return true
end

local shotsDone, pending = {}, nil
hook.Add( "Think", "JJS_AutoTestShots", function()
	if not t0 then return end
	local t = CurTime() - t0
	for i, s in ipairs( SCEN.shots ) do
		if not shotsDone[ i ] and t >= s[ 1 ] then
			shotsDone[ i ] = true
			pending = s[ 2 ]
			break
		end
	end
end )

hook.Add( "PostRender", "JJS_AutoTestShots", function()
	if not pending then return end
	local data = render.Capture( { format = "jpeg", x = 0, y = 0, w = ScrW(), h = ScrH(), quality = 80 } )
	file.CreateDir( "jjs_test" )
	if data then file.Write( "jjs_test/" .. pending .. ".jpg", data ) end
	Log( "shot " .. pending )
	pending = nil
end )
