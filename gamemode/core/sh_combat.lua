-- Shared combat definitions.
--
-- A hit (passed to JJS.Hit on the server):
--   attacker        player
--   damage          number
--   type            JJS.DMG.* (default MELEE)
--   stun            seconds of stun (ignored by melee-stun immunity after wakeup for MELEE)
--   knock           Vector velocity applied with a stun (optional)
--   ragdoll         { time = s, trueRag = bool, vel = Vector } ragdolls instead of stunning
--   block           "normal" (front 180), "all" (any side), "pre" (only if blocking before startTime), "none"
--   blockDamage     damage still taken through block
--   startTime       for block = "pre"
--   bypassRagdoll   can hit ragdolled targets
--   ignoreIFrames
--   from            position the hit comes from (block direction); default attacker pos
--   fx              "light" | "heavy" | false ; fxScale
--   onHit(victim, hit) / onBlocked(victim, hit)

JJS.DMG_NAMES = {
	[ JJS.DMG.MELEE ] = "Melee",
	[ JJS.DMG.BULLET ] = "Bullet",
	[ JJS.DMG.EXPLOSION ] = "Explosion",
	[ JJS.DMG.SWARM ] = "Swarm",
	[ JJS.DMG.DOMAIN ] = "Domain",
	[ JJS.DMG.SPECIAL ] = "Special",
}

-- Players never collide with ragdolls; with each other only if jjs_player_collide is on
local cvCollide = GetConVar( "jjs_player_collide" )

local function IsJJSRagdoll( ent )
	return ent.JJSRagdoll or ( ent:GetClass() == "prop_ragdoll" and ent:GetNWBool( "JJSRagdoll" ) )
end

function GM:ShouldCollide( a, b )
	local ap, bp = a:IsPlayer(), b:IsPlayer()
	if ap and bp then return cvCollide:GetBool() end
	if ( ap and IsJJSRagdoll( b ) ) or ( bp and IsJJSRagdoll( a ) ) then return false end
	return true
end
