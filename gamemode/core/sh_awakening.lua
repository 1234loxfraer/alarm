-- Awakening bar: fills with damage dealt (~286 to full). G awakens:
--   complete characters play a short invulnerable sequence, heal, then use their awakening
--   kit for its duration (awakening.domain expands right away for domain awakenings);
--   base-only characters perform their single awakening move instead (char.awakenMove).
--   awakening.hp sets a different max health while awakened, awakening.scale a different size.
-- Characters can replace the activation with their own (char.Awaken) and react to G while
-- awakened or at any time (char.AwakenPress returning true consumes the press).
-- While awakened the bar shows the time left.

local cfg = JJS.Config.Awakening

function JJS.TryAwaken( ply, mv )
	local char = JJS.GetChar( ply )
	if char.AwakenPress and char.AwakenPress( ply, mv ) then return end
	if ply:GetJAwakened() or ply:GetJAwaken() < 1 then return end
	if not JJS.CanAct( ply ) or JJS.IsBusy( ply ) or JJS.IsDashing( ply ) then return end

	if char.Awaken then
		char.Awaken( ply, mv )
	elseif char.awakenMove then
		ply:SetJAwaken( 0 )
		char.awakenMove.Use( ply, mv, 0 )
		hook.Run( "JJS_AwakenMove", ply )
	elseif char.awakening then
		JJS.StartAction( ply, "awaken_seq" )
	elseif SERVER then
		-- early access characters without a proper awakening: heal and reset cooldowns
		JJS.EnterAwakening( ply, nil, cfg.DefaultHeal )
	end
end

JJS.RegisterAction( "awaken_seq", {
	dur = cfg.SequenceTime,
	moveMult = 0,
	noJump = true,
	uninterruptible = true,
	armor = { all = true },
	gesture = "gesture_becon",
	start = function( ply )
		JJS.IFrames( ply, cfg.SequenceTime )
		if SERVER then JJS.Util.Effect( "jjs_kit_cast", JJS.Util.BodyCenter( ply ), nil, ply, 3, 1 ) end
	end,
	finish = function( ply, var, interrupted )
		if CLIENT or not ply:Alive() then return end
		local aw = JJS.GetChar( ply ).awakening or {}
		JJS.EnterAwakening( ply, nil, aw.heal or cfg.DefaultHeal )
		if aw.domain and aw.domain.spec then
			JJS.Domain.Expand( ply, JJS.Kit.Params( aw.domain.spec ) )
		end
	end,
} )

function JJS.GetAwakeningDuration( ply )
	local char = JJS.GetChar( ply )
	return ( char.awakening and char.awakening.duration ) or cfg.DefaultDuration
end

function JJS.EnterAwakening( ply, duration, heal )
	duration = duration or JJS.GetAwakeningDuration( ply )
	ply:SetJAwakened( true )
	ply:SetJAwaken( 1 )
	ply:SetJAwakenEnd( CurTime() + duration )
	ply:SetJKitSet( 0 )
	ply.jjs_awakenDur = duration
	JJS.ClearCooldowns( ply )
	local aw = JJS.GetChar( ply ).awakening
	if aw and aw.hp and SERVER then
		ply:SetMaxHealth( aw.hp )
		ply:SetJHP( aw.hp )
		ply:SetHealth( aw.hp )
	end
	if heal and SERVER then JJS.Heal( ply, heal ) end
	hook.Run( "JJS_Awakened", ply )
end

function JJS.ExitAwakening( ply )
	ply:SetJAwakened( false )
	ply:SetJAwaken( 0 )
	ply:SetJAwakenEnd( 0 )
	ply:SetJKitSet( 0 )
	JJS.ClearCooldowns( ply )
	local char = JJS.GetChar( ply )
	if SERVER and char.awakening and char.awakening.hp and ply:Alive() then
		ply:SetMaxHealth( char.hp )
		local hp = math.min( ply:GetJHP(), char.hp )
		ply:SetJHP( hp )
		ply:SetHealth( math.ceil( hp ) )
	end
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
