local U = JJS.Util
local cfg = JJS.Config

function JJS.AddEvasive( ply, frac )
	if frac <= 0 then return end
	ply:SetJEvasive( math.min( 1, ply:GetJEvasive() + frac ) )
end

function JJS.AddAwakening( ply, dmg )
	if ply:GetJAwakened() then return end
	ply:SetJAwaken( math.min( 1, ply:GetJAwaken() + dmg / cfg.Awakening.FullDamage ) )
end

-- Anti-team: two different attackers inside the window grant a burst
local function TrackAttacker( victim, attacker, now )
	local list = victim.jjs_hitters or {}
	victim.jjs_hitters = list
	list[ attacker ] = now

	local n = 0
	for a, t in pairs( list ) do
		if not IsValid( a ) or now - t > cfg.Burst.Window then
			list[ a ] = nil
		else
			n = n + 1
		end
	end
	if n >= 2 then victim:SetJBurstEnd( now + cfg.Burst.Window ) end
end

function JJS.Heal( ply, amount )
	local hp = math.min( ply:GetMaxHealth(), ply:GetJHP() + amount )
	ply:SetJHP( hp )
	ply:SetHealth( math.ceil( hp ) )
end

function JJS.ApplyDamage( victim, attacker, dmg, hit )
	if dmg <= 0 or not victim:Alive() then return end
	local now = CurTime()
	hit = hit or {}

	dmg = hook.Run( "JJS_ScaleDamage", victim, attacker, dmg, hit ) or dmg
	if dmg <= 0 then return end

	local hp = victim:GetJHP() - dmg
	victim:SetJLastHurt( now )

	local ec = cfg.Evasive
	JJS.AddEvasive( victim, dmg / ( hp <= ec.LowHealth and ec.TakenLow or ec.TakenHigh ) )

	if IsValid( attacker ) and attacker:IsPlayer() and attacker ~= victim then
		JJS.AddEvasive( attacker, dmg / ( attacker:GetJHP() <= ec.LowHealth and ec.DealtLow or ec.DealtHigh ) )
		JJS.AddAwakening( attacker, dmg )
		TrackAttacker( victim, attacker, now )
	end

	if hp <= 0 then
		if hook.Run( "JJS_PreventDeath", victim, attacker, dmg, hit ) then return end
		JJS.Kill( victim, attacker, hit )
		return
	end

	victim:SetJHP( hp )
	victim:SetHealth( math.ceil( hp ) )
end

function JJS.Kill( victim, attacker, hit )
	if not victim:Alive() then return end
	victim.jjs_killHit = hit
	victim:SetJHP( 0 )

	local src = IsValid( attacker ) and attacker or game.GetWorld()
	local info = DamageInfo()
	info:SetDamage( math.max( victim:Health(), 1 ) + 1000 )
	info:SetDamageType( DMG_GENERIC )
	info:SetAttacker( src )
	info:SetInflictor( src )

	victim.jjs_allowDamage = true
	victim:TakeDamageInfo( info )
	victim.jjs_allowDamage = nil

	if victim:Alive() then victim:Kill() end
end

local function HitPos( victim, from )
	local c = U.BodyCenter( victim ) + Vector( 0, 0, 10 )
	local d = U.Flat( from - c )
	return c + d * 14, d
end

-- Returns "hit", "killed", "blocked", "dodged", "ignored" or a counter result
function JJS.Hit( victim, hit )
	if not IsValid( victim ) or not victim:IsPlayer() or not victim:Alive() then return end
	local attacker = hit.attacker
	local now = CurTime()
	hit.type = hit.type or JJS.DMG.MELEE

	if victim:GetJRagdolled() and not hit.bypassRagdoll then return "ignored" end
	if JJS.HasIFrames( victim ) and not hit.ignoreIFrames then return "dodged" end

	local act = JJS.GetAction( victim )
	if act and act.counter and IsValid( attacker ) and attacker ~= victim then
		local r = act.counter( victim, attacker, hit )
		if r then return r end
	end

	local from = hit.from or ( IsValid( attacker ) and attacker:GetPos() ) or victim:GetPos()
	local fxPos, fxDir = HitPos( victim, from )

	if hit.block ~= "none" and JJS.IsBlocking( victim ) and not victim:GetJRagdolled() then
		local facing = hit.block == "all" or U.IsFacing( victim, from )
		local early = hit.block ~= "pre" or victim:GetJBlockStart() <= ( hit.startTime or now )
		if facing and early then
			if hit.blockDamage and hit.blockDamage > 0 then
				JJS.ApplyDamage( victim, attacker, hit.blockDamage, hit )
			end
			if hit.onBlocked then hit.onBlocked( victim, hit ) end
			U.Effect( "jjs_block", fxPos, fxDir, victim, hit.fxScale or 1 )
			hook.Run( "JJS_Blocked", victim, hit )
			return "blocked"
		end
	end

	local armored = act and ( ( act.armor and ( act.armor.all or act.armor[ hit.type ] ) ) or ( act.onHurt and act.onHurt( victim, hit ) ) )

	JJS.ApplyDamage( victim, attacker, hit.damage or 0, hit )

	if hit.fx ~= false then
		U.Effect( "jjs_hit", fxPos, fxDir, victim, hit.fxScale or 1, hit.fx == "heavy" and 1 or 0 )
	end

	if not victim:Alive() then
		if hit.onHit then hit.onHit( victim, hit ) end
		hook.Run( "JJS_Hit", victim, hit, "killed" )
		return "killed"
	end

	if not armored then
		local meleeImmune = hit.type == JJS.DMG.MELEE and victim:GetJMeleeImmuneEnd() > now

		if hit.ragdoll then
			JJS.InterruptAction( victim, hit )
			JJS.Ragdoll.Apply( victim, hit.ragdoll, attacker )
		elseif hit.stun and hit.stun > 0 and not meleeImmune and not victim:GetJRagdolled() then
			JJS.Stun( victim, hit.stun )
			JJS.InterruptAction( victim, hit )
			victim:SetJDashType( 0 )
			victim:SetJMoveState( JJS.MOVE_NONE )
			if hit.knock then victim:SetLocalVelocity( hit.knock ) end
		end
	end

	if hit.onHit then hit.onHit( victim, hit ) end
	hook.Run( "JJS_Hit", victim, hit, "hit" )
	return "hit"
end
