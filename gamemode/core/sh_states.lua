-- Queries and setters for combat states (stun, endlag, i-frames, block...)

function JJS.IsStunned( ply ) return ply:GetJStunEnd() > CurTime() end
function JJS.InEndlag( ply ) return ply:GetJEndlagEnd() > CurTime() end
function JJS.HasIFrames( ply ) return ply:GetJIFrameEnd() > CurTime() end
function JJS.IsRagdolled( ply ) return ply:GetJRagdolled() end
function JJS.IsBlocking( ply ) return ply:GetJBlockStart() > 0 end
function JJS.IsDashing( ply ) return ply:GetJDashType() ~= 0 end
function JJS.IsBusy( ply ) return ply:GetJActId() ~= 0 end
function JJS.InMoveState( ply ) return ply:GetJMoveState() ~= JJS.MOVE_NONE end

-- Stunned or ragdolled: shown red on the dummy indicator
function JJS.IsDisabled( ply )
	return JJS.IsStunned( ply ) or JJS.IsRagdolled( ply )
end

-- Free to start a new action (M1, move, dash, block)
function JJS.CanAct( ply )
	return ply:Alive() and not ply:GetJRagdolled() and not JJS.IsStunned( ply ) and not JJS.InEndlag( ply )
		and ply:GetJMoveState() ~= JJS.MOVE_ROLL and ply:GetJMoveState() ~= JJS.MOVE_VAULT and ply:GetJMoveState() ~= JJS.MOVE_CLIMB
		and ply:GetJMoveState() ~= JJS.MOVE_SLIDE
end

function JJS.Stun( ply, seconds )
	ply:SetJStunEnd( math.max( ply:GetJStunEnd(), CurTime() + seconds ) )
end

function JJS.Endlag( ply, seconds )
	ply:SetJEndlagEnd( math.max( ply:GetJEndlagEnd(), CurTime() + seconds ) )
end

function JJS.IFrames( ply, seconds )
	ply:SetJIFrameEnd( math.max( ply:GetJIFrameEnd(), CurTime() + seconds ) )
end

function JJS.GetHealthFrac( ply )
	return math.Clamp( ply:GetJHP() / math.max( ply:GetMaxHealth(), 1 ), 0, 1 )
end
