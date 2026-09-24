-- Awakening bar: fills with damage dealt (~286 to full). G awakens; characters can replace
-- the activation with their own sequence (char.Awaken). While awakened the bar shows the
-- time left and the character's awakening kit is used.

local cfg = JJS.Config.Awakening

function JJS.TryAwaken( ply, mv )
	if ply:GetJAwakened() or ply:GetJAwaken() < 1 then return end
	if not JJS.CanAct( ply ) or JJS.IsBusy( ply ) or JJS.IsDashing( ply ) then return end

	local char = JJS.GetChar( ply )
	if char.Awaken then
		char.Awaken( ply, mv )
	elseif SERVER then
		JJS.EnterAwakening( ply )
	end
end

function JJS.GetAwakeningDuration( ply )
	local char = JJS.GetChar( ply )
	return ( char.awakening and char.awakening.duration ) or cfg.DefaultDuration
end

function JJS.EnterAwakening( ply, duration, heal )
	duration = duration or JJS.GetAwakeningDuration( ply )
	ply:SetJAwakened( true )
	ply:SetJAwaken( 1 )
	ply:SetJAwakenEnd( CurTime() + duration )
	ply.jjs_awakenDur = duration
	for i = 1, 5 do ply[ "SetJCD" .. i ]( ply, 0 ) end
	if heal and SERVER then JJS.Heal( ply, heal ) end
	hook.Run( "JJS_Awakened", ply )
end

function JJS.ExitAwakening( ply )
	ply:SetJAwakened( false )
	ply:SetJAwaken( 0 )
	ply:SetJAwakenEnd( 0 )
	for i = 1, 5 do ply[ "SetJCD" .. i ]( ply, 0 ) end
	hook.Run( "JJS_AwakeningEnd", ply )
end

-- Adds a fraction of the full awakening duration (e.g. True Cannon's awakened Restyle: +10%)
function JJS.AddAwakeningTime( ply, frac )
	if not ply:GetJAwakened() then return end
	local dur = ply.jjs_awakenDur or JJS.GetAwakeningDuration( ply )
	ply:SetJAwakenEnd( math.min( CurTime() + dur, ply:GetJAwakenEnd() + dur * frac ) )
end

if SERVER then
	function JJS.AwakeningTick( ply, now )
		if not ply:GetJAwakened() then return end
		local left = ply:GetJAwakenEnd() - now
		if left <= 0 then
			JJS.ExitAwakening( ply )
			return
		end
		ply:SetJAwaken( left / ( ply.jjs_awakenDur or JJS.GetAwakeningDuration( ply ) ) )
	end
end
