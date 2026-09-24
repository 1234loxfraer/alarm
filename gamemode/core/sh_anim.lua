-- Player animation.
-- Locomotion uses the fist hold type until the custom library exists. Actions can play a
-- full-body sequence (def.seq; its cycle is driven by the action time so every client is in
-- sync without extra networking) or an upper-body gesture (def.gesture).
-- With shift-lock off the model turns toward where it moves (Roblox classic camera).

JJS.Anim = JJS.Anim or {}
local A = JJS.Anim

local TRANSLATE = {
	[ ACT_MP_STAND_IDLE ] = ACT_HL2MP_IDLE_FIST,
	[ ACT_MP_WALK ] = ACT_HL2MP_WALK_FIST,
	[ ACT_MP_RUN ] = ACT_HL2MP_RUN_FIST,
	[ ACT_MP_CROUCH_IDLE ] = ACT_HL2MP_IDLE_CROUCH_FIST,
	[ ACT_MP_CROUCHWALK ] = ACT_HL2MP_WALK_CROUCH_FIST,
	[ ACT_MP_JUMP ] = ACT_HL2MP_JUMP_FIST,
	[ ACT_MP_SWIM ] = ACT_HL2MP_SWIM_FIST,
	[ ACT_LAND ] = ACT_LAND,
}

function GM:TranslateActivity( ply, act )
	return TRANSLATE[ act ] or act
end

local function SeqFor( ply, v, var )
	if isfunction( v ) then v = v( ply, var ) end
	if not v then return end
	local seq = ply:LookupSequence( v )
	if seq and seq > 0 then return seq end
end

function GM:CalcMainActivity( ply, vel )
	local pt = ply:GetTable()
	pt.jjs_fullSeq = nil

	local def = JJS.GetAction( ply )
	if def and def.seq then
		local seq = SeqFor( ply, def.seq, ply:GetJActVar() )
		if seq then
			pt.jjs_fullSeq = seq
			pt.jjs_fullSeqRate = def.seqRate or 1
			return ACT_MP_STAND_IDLE, seq
		end
	end

	local ideal, override = self.BaseClass.CalcMainActivity( self, ply, vel )
	if ideal == ACT_MP_RUN or ideal == ACT_MP_WALK then
		ideal = ply:GetJRunning() and ACT_MP_RUN or ACT_MP_WALK
	elseif ideal == ACT_MP_STAND_IDLE and override == -1 and not JJS.IsBlocking( ply ) then
		-- each character can have its own idle; the shared one is the fallback
		local char = JJS.GetChar( ply )
		local seq = char and char.idle and ply:LookupSequence( char.idle )
		if not seq or seq <= 0 then seq = ply:LookupSequence( "jjs_idle" ) end
		if seq and seq > 0 then override = seq end
	end
	return ideal, override
end

function GM:UpdateAnimation( ply, vel, maxSeqGroundSpeed )
	self.BaseClass.UpdateAnimation( self, ply, vel, maxSeqGroundSpeed )

	local pt = ply:GetTable()
	if pt.jjs_fullSeq then
		local dur = math.max( ply:SequenceDuration( pt.jjs_fullSeq ), 0.01 )
		local t = ( CurTime() - ply:GetJActStart() ) * pt.jjs_fullSeqRate
		ply:SetCycle( math.Clamp( t / dur, 0, 1 ) )
		ply:SetPlaybackRate( 0 )
	end

	if CLIENT then A.UpdateGestures( ply, pt ) end
end

function GM:GrabEarAnimation( ply ) end

if SERVER then return end

function A.PlayGesture( ply, name, slot )
	local seq = ply:LookupSequence( name )
	if not seq or seq <= 0 then return end
	ply:AddVCDSequenceToGestureSlot( slot or GESTURE_SLOT_ATTACK_AND_RELOAD, seq, 0, true )
end

function A.UpdateGestures( ply, pt )
	local id, start = ply:GetJActId(), ply:GetJActStart()
	if id ~= 0 and ( pt.jjs_gId ~= id or pt.jjs_gStart ~= start ) then
		pt.jjs_gId, pt.jjs_gStart = id, start
		local def = JJS.ActionById[ id ]
		-- a full-body sequence replaces the placeholder gesture
		if not ( def and def.seq and SeqFor( ply, def.seq, ply:GetJActVar() ) ) then
			local g = def and def.gesture
			if isfunction( g ) then g = g( ply, ply:GetJActVar() ) end
			if g then A.PlayGesture( ply, g ) end
		end
	elseif id == 0 then
		pt.jjs_gId = 0
	end

	local blocking = JJS.IsBlocking( ply )
	if blocking ~= pt.jjs_gBlock then
		pt.jjs_gBlock = blocking
		if blocking then
			local seq = ply:LookupSequence( "fist_block" )
			if seq and seq > 0 then ply:AddVCDSequenceToGestureSlot( GESTURE_SLOT_CUSTOM, seq, 0, false ) end
		else
			ply:AnimResetGestureSlot( GESTURE_SLOT_CUSTOM )
		end
	end
end

-- Shift-lock off: face the movement direction unless busy (actions snap to the aim)
hook.Add( "PrePlayerDraw", "JJS_RenderYaw", function( ply )
	if ply:GetJShiftLock() then return end
	local pt = ply:GetTable()
	local eyeYaw = ply:EyeAngles().y
	local target = pt.jjs_renderYaw or eyeYaw

	if JJS.IsBusy( ply ) or JJS.IsBlocking( ply ) or JJS.IsDashing( ply ) then
		target = eyeYaw
	else
		local v = ply:GetVelocity()
		if v:Length2DSqr() > 400 then target = v:Angle().y end
	end

	pt.jjs_renderYaw = math.ApproachAngle( pt.jjs_renderYaw or target, target, FrameTime() * 720 )
	ply:SetRenderAngles( Angle( 0, pt.jjs_renderYaw, 0 ) )

	local speed = ply:GetVelocity():Length2D()
	if speed > 20 then
		local rel = math.rad( ply:GetVelocity():Angle().y - pt.jjs_renderYaw )
		ply:SetPoseParameter( "move_x", math.cos( rel ) )
		ply:SetPoseParameter( "move_y", -math.sin( rel ) )
	end
	ply:SetPoseParameter( "aim_yaw", 0 )
	ply:SetPoseParameter( "head_yaw", 0 )
	ply:InvalidateBoneCache()
end )
