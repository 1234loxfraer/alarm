-- Ability kit: moves described as data and turned into working placeholder actions.
-- Character files list their moves with the constructors below (values in studs / seconds,
-- as on the wiki) and register with JJS.Kit.Character( id, def ).
--
--   K.Melee{ "Name", cooldown = 15, damage = 10, hits = 2, ragdoll = true, ... }
--
-- Common fields:
--   [1] name, tip, cooldown, startup, endlag, moveMult, noJump
--   damage (total), hits, interval, type ("melee", "bullet", "explosion", "swarm", "domain", "special")
--   block ("normal", "all" = 360, "pre" = perfect block only, "none"), blockDamage
--   endlag (after the last hit when it lands), whiffEndlag (when nothing was hit), blockEndlag (when blocked)
--   Frame data from dogslamloop.com is in 60 fps frames: seconds = frames / 60 (K.F(frames))
--   stun, ragdoll (true or { time, h, v } in studs/s; h < 0 pulls toward the user), trueRag (no evasive)
--   bypassRagdoll, armor ("melee", "bullet", "total" or a list), uninterruptible, iframes (during the move)
--   heal, selfDamage, color (JJS.Kit.PALETTE key), crater (destruction scale on impact)
--   onHit(ply, victim, p) when the final hit lands
--   awakenCost (fraction of the awakening bar spent), noCooldown, charges (uses per cooldown)
--   slow = { mult, time } applied to targets hit, onEnd(ply, p) when the move finishes uninterrupted,
--   onFinish(ply, p, interrupted) whenever it ends; noKill (the hits leave the target at 1 HP at worst), noKillHits
--   = { [hit] = true }; behind (the hitbox is behind the user)
--   backstep (studs travelled backward during the startup)
--   hitDamage = { per hit }, hitBlock = { per hit block rule }, hitBypass = { per hit: hits ragdolls }
--   A variant's own `cooldown` replaces the move's cooldown when that variant is used.
--   interrupt = { damage (bonus), stun, ragdoll, onInterrupt(ply, victim, p) } when the hit interrupts the target's
--              action (HIT tip); lowHp = { hp, damage, stun }: final hit bonus against targets at or under `hp`;
--   vsAir = { damage, ragdoll }: bonus against airborne targets
--   guardBreak = { damage, stun, onBreak(ply, victim, p) } when the target is blocking: the block is broken instead
--   onContact(ply, victim, p, result) whenever a hit connects (landed or blocked)
--   parry = { window, counters = { melee = true, ... } }: hits taken this early in the move are parried
--   feints = true: usable during another move (cancelling it), feintCooldown when it does
--   m1Cancel = true: an M1 ends the move early
--   detached = true: performed by a companion; the user only casts for `cast` seconds and the hits follow on their own
--              (onDone(ply, target, p) once they all played out)
--   comboWindow: combos can be pressed until this time into the move (default: the startup), from comboFrom;
--   a combo's need(ply) must pass, onCombo(ply) when it triggers; combos can hold their own special/combo
--   feintRefund = { except = slot } (with feints): the cancelled move stays off cooldown; zones: falloff
--   meleeIFrames (seconds from the start: melee hits pass through), knock (studs/s push on each hit),
--   knockBlock (the push also goes through block), hitKnock = { per hit push }, chase (studs/s run at the target
--   between hits)
--   Variants (tables of overrides, each becomes its own action):
--     air (user airborne), airTarget (target airborne), ragdolled (target ragdolled), back (walking
--     backward: DIRECTION), highAir (airborne well above jump height), cond (cond.test(ply) is true),
--     special (special pressed during the startup: SPECIAL; `free` = ignores the special's cooldown,
--     `specialCooldown` = cooldown put on the special), combo = { [slot] = overrides } (another move's key
--     pressed during the startup: both moves go on cooldown unless `free`), miss (spec started when
--     nothing was hit),
--   air = { overrides } (used while airborne), hold = { time, overrides } (HOLD variant) or a list of such stages
--   (holdMoveMult: speed while holding),
--   again = spec with a `window` (USE AGAIN / USE TWICE follow-up), onUse(ply, p) when the move starts
--
-- Kinds and their own fields:
--   Melee      reach, width, height, lunge (studs travelled during the startup)
--   Grab       like Melee; a caught target is held in front for the remaining hits; carry (studs/s flight with them
--              along the aim), onCrash(ply, target, p) against walls (crashes = max count)
--   Rush       startup in place, then travel (studs over time seconds) with the hitbox active; the first
--              target met is caught and takes the remaining hits (held in front); iframesOnHit (seconds)
--   Beam       range, radius, pierce, duration (channelled), tick, clash (beam clash strength)
--   Projectile homing (steers at the target passed to K.SpawnProjectile), speed, range, radius, count, spread,
--              explode (radius), explodeDamage, directOnly (no blast after a
--              direct hit), gravity, guided (follows the owner's aim), ghost (passes through players),
--              onExplode(ply, pos, hitSomeone, ent), onFly(ply, pos, ent) -> true to explode there, ragdollFrom
--              (ragdolled players closer than this to the user are passed through)
--   Summon     a slow projectile (shikigami, swarms)
--   AoE        radius, offset (studs in front of the user), up (studs)
--   Counter    window, counters = { melee = "counter", bullet = "evade", ... }, riposte (damage), teleport,
--              onCounter(ply, attacker, hit, mode); miss = spec used when the window passed with nothing countered
--   Target     range (studs to the aimed target), then hits it like Melee after appearing next to it
--              (pickTarget(ply, p) -> target: chosen another way; origin(ply) -> position the hits come from)
--              (noHit = true: only teleports; teleport = false: hits the target from where the user stands;
--              pullIn = true: the first hit drags the target in front of the user)
--   specialAfter = spec with a `window`: pressing the special right after the move (Face Grater...); `anyway` =
--              even when nothing landed, `free` = ignores the special's cooldown
--   Mobility   travel, time, dir ("forward", "back", "up", "aim", "target" = hop toward the last player hit), arc (hop),
--              steer (forward/back keys lengthen/shorten it, jump raises the arc)
--   Buff       duration, speed, speedTime, evasive, awaken
--   Zone       lingering area: radius, duration, tick, damage (per tick), follow (stays on the user), offset,
--              target = true (placed on the aimed target within range and follows them), acting (only hits
--              players performing an action, interrupting it), once (each target once), onPlace(ply, pos, p),
--              zoneHits = { damage per successive hit on the same target }; a zone entry's `paused` holds it
--   AoE / Zone center(ply) -> position (or nil to cancel): placed there instead of in front of the user
--   Beam       far = { dist, ragdoll, onHit } for targets hit beyond `dist` studs, falloff (damage at max range)
--   stunRag = { h, v, time }: targets already stunned are ragdolled instead
--   Domain     duration, sureHit ("damage", "stun", "drain"), dps, radius
--   Toggle     switches to the alternate moveset (def.alt)
--   Feint      cancels the startup of the move being performed and refunds its cooldown
--   Modes      modes = { "Normal", "Blade", ... } cycled by each use
--   ByMode     { spec for mode 0, spec for mode 1, ... }
--   Stub       placeholder that only plays a short action

local S = JJS.STUD
local U = JJS.Util

JJS.Kit = JJS.Kit or {}
local K = JJS.Kit

-- Frames (60 fps) to seconds
function K.F( frames ) return frames / 60 end

K.PALETTE = {
	white = Color( 255, 255, 255 ),
	blue = Color( 80, 150, 255 ),
	red = Color( 255, 60, 60 ),
	purple = Color( 170, 80, 255 ),
	black = Color( 30, 20, 30 ),
	gold = Color( 255, 205, 70 ),
	green = Color( 90, 230, 110 ),
	orange = Color( 255, 140, 40 ),
	pink = Color( 255, 110, 190 ),
	cyan = Color( 110, 230, 255 ),
	blood = Color( 180, 10, 30 ),
	shadow = Color( 40, 40, 70 ),
	brown = Color( 150, 105, 60 ),
}
K.COLOR_ID, K.COLOR_BY_ID = {}, {}
for _, name in ipairs( { "white", "blue", "red", "purple", "black", "gold", "green", "orange", "pink", "cyan", "blood", "shadow", "brown" } ) do
	local id = #K.COLOR_BY_ID + 1
	K.COLOR_ID[ name ] = id
	K.COLOR_BY_ID[ id ] = K.PALETTE[ name ]
end

local DMG_BY_NAME = {
	melee = JJS.DMG.MELEE, bullet = JJS.DMG.BULLET, explosion = JJS.DMG.EXPLOSION,
	swarm = JJS.DMG.SWARM, domain = JJS.DMG.DOMAIN, special = JJS.DMG.SPECIAL,
}

local DEFAULTS = {
	melee = { startup = 0.3, endlag = 0.35, reach = 7, width = 7, height = 7, type = "melee", color = "white" },
	grab = { startup = 0.3, endlag = 0.35, reach = 5, width = 6, height = 7, type = "melee", hits = 3, interval = 0.25, color = "white" },
	rush = { startup = 0.3, endlag = 0.35, travel = 25, time = 0.5, reach = 5, width = 6, height = 7, type = "melee", hits = 3, interval = 0.25,
		color = "white" },
	beam = { startup = 0.5, endlag = 0.4, range = 60, radius = 2.5, type = "bullet", tick = 0.2, color = "cyan" },
	projectile = { startup = 0.35, endlag = 0.35, speed = 120, range = 90, radius = 2, type = "bullet", color = "blue" },
	aoe = { startup = 0.45, endlag = 0.4, radius = 14, offset = 0, type = "explosion", color = "orange" },
	counter = { startup = 0, endlag = 0.5, window = 0.6, type = "melee", riposte = 8, color = "white" },
	target = { startup = 0.25, endlag = 0.35, range = 40, reach = 9, width = 8, height = 8, type = "melee", color = "white" },
	mobility = { startup = 0.05, endlag = 0.25, travel = 25, time = 0.4, dir = "forward", type = "melee", color = "white" },
	buff = { startup = 0.2, duration = 0.6, endlag = 0, type = "special", color = "white" },
	zone = { startup = 0.5, endlag = 0.3, radius = 20, duration = 5, tick = 0.5, offset = 0, type = "special", color = "red" },
	domain = { duration = 14, sureHit = "damage", dps = 2, type = "domain", color = "purple" },
	stub = { startup = 0.2, endlag = 0.2, type = "special", color = "white" },
}

local STUDS = { reach = true, width = true, height = true, range = true, radius = true, lunge = true, backstep = true,
	travel = true, speed = true, offset = true, explode = true, up = true, gravity = true, ragdollFrom = true }

------------------------------------------------------------------------------------------
-- Constructors (they only tag the table; K.Character builds it)
------------------------------------------------------------------------------------------

local function Kind( kind, extra )
	return function( t )
		t.kind = kind
		if extra then for k, v in pairs( extra ) do if t[ k ] == nil then t[ k ] = v end end end
		return t
	end
end

K.Melee = Kind( "melee" )
K.Grab = Kind( "grab" )
K.Rush = Kind( "rush" )
K.Beam = Kind( "beam" )
K.Projectile = Kind( "projectile" )
K.Summon = Kind( "projectile", { speed = 45, radius = 4, type = "swarm", color = "shadow" } )
K.AoE = Kind( "aoe" )
K.Counter = Kind( "counter" )
K.Target = Kind( "target" )
K.Mobility = Kind( "mobility" )
K.Buff = Kind( "buff" )
K.Zone = Kind( "zone" )
K.Domain = Kind( "domain" )
K.Stub = Kind( "stub" )
K.Toggle = Kind( "toggle" )
K.Feint = Kind( "feint" )
K.Modes = Kind( "modes" )
K.ByMode = Kind( "bymode" )

------------------------------------------------------------------------------------------
-- Parameters
------------------------------------------------------------------------------------------

-- Merges defaults, converts studs to units and resolves names to enums
local function Params( spec, over )
	local kind = over and over.kind or spec.kind
	local p = table.Copy( DEFAULTS[ kind ] or DEFAULTS.stub )
	for k, v in pairs( spec ) do p[ k ] = v end
	for k, v in pairs( over or {} ) do p[ k ] = v end
	p.name = p.name or p[ 1 ] or "?"
	p.startup = p.startup or 0.3
	p.endlag = p.endlag or 0.3

	for k in pairs( STUDS ) do
		if isnumber( p[ k ] ) then p[ k ] = p[ k ] * S end
	end
	p.dmgType = DMG_BY_NAME[ p.type ] or JJS.DMG.SPECIAL
	p.hits = math.max( 1, p.hits or 1 )
	p.interval = p.interval or 0.12
	p.damage = p.damage or 0
	p.block = p.block or "normal"
	p.colorId = K.COLOR_ID[ p.color ] or 1

	if p.ragdoll == true then p.ragdoll = {} end
	if istable( p.ragdoll ) then
		p.ragdoll = {
			time = p.ragdoll.time or 1,
			h = ( p.ragdoll.h or 30 ) * S,
			v = ( p.ragdoll.v or 18 ) * S,
		}
	end
	if p.armor then
		-- "total", one damage type name, or a list of them
		if p.armor == "total" then
			p.armorTypes = { all = true }
		else
			p.armorTypes = {}
			for _, a in ipairs( istable( p.armor ) and p.armor or { p.armor } ) do p.armorTypes[ DMG_BY_NAME[ a ] or 0 ] = true end
		end
	end
	return p
end
K.Params = Params

-- Time of the i-th hit and the whole action length
local function HitTime( p, i ) return p.startup + ( i - 1 ) * p.interval end
local function Duration( p ) return HitTime( p, p.hits ) + ( p.duration or 0 ) + p.endlag end

------------------------------------------------------------------------------------------
-- Hit helpers (server)
------------------------------------------------------------------------------------------

function K.Fwd( ply ) return U.YawForward( ply:EyeAngles().y ) end

-- Builds the hit table for hit number `idx` of a move
function K.MakeHit( ply, p, victim, idx, from )
	-- origin(ply): the hits come from somewhere else than the user (Rika)
	if not from and p.origin then from = p.origin( ply ) end
	idx = idx or p.hits
	local last = idx >= p.hits
	local hit = {
		attacker = ply,
		damage = p.hitDamage and ( p.hitDamage[ idx ] or 0 ) or ( p.perHit or p.damage / p.hits ),
		type = p.dmgType,
		block = p.hitBlock and p.hitBlock[ idx ] or p.block,
		blockDamage = p.blockDamage and p.blockDamage / p.hits,
		bypassRagdoll = p.hitBypass and p.hitBypass[ idx ] or ( not p.hitBypass and p.bypassRagdoll ),
		ignoreIFrames = p.ignoreIFrames,
		startTime = ply:GetJActStart(),
		from = from,
		fx = last and "heavy" or "light",
		stun = last and ( p.stun or 0.75 ) or math.max( p.interval + 0.4, 0.75 ),
		kit = p,
		noKill = p.noKill or ( p.noKillHits and p.noKillHits[ idx ] ) or nil,
	}
	if last and p.ragdoll then
		local away = U.Flat( victim:GetPos() - ( from or ply:GetPos() ) )
		if away:LengthSqr() < 0.01 then away = K.Fwd( ply ) end
		hit.ragdoll = { time = p.ragdoll.time, vel = away * p.ragdoll.h + Vector( 0, 0, p.ragdoll.v ), trueRag = p.trueRag }
	end
	local kn = p.hitKnock and p.hitKnock[ idx ] or p.knock
	if kn and kn > 0 and not hit.ragdoll then
		local away = U.Flat( victim:GetPos() - ( from or ply:GetPos() ) )
		if away:LengthSqr() < 0.01 then away = K.Fwd( ply ) end
		hit.knock = away * kn * S + Vector( 0, 0, 40 )
	end
	if last and p.onHit then
		hit.onHit = function( v ) p.onHit( ply, v, p ) end
	end
	return hit
end

-- Applies a hit and handles blocked endlag; returns the JJS.Hit result
function K.Apply( ply, p, victim, idx, from, scale )
	if not from and p.origin then from = p.origin( ply ) end
	local hit = K.MakeHit( ply, p, victim, idx, from )
	if scale then hit.damage = hit.damage * scale end
	-- stunRag = { h, v }: a target that is already stunned is ragdolled instead (Granite Blast)
	if p.stunRag and JJS.IsStunned( victim ) and not victim:GetJRagdolled() then
		local away = U.Flat( victim:GetPos() - ( from or ply:GetPos() ) )
		hit.ragdoll = { time = p.stunRag.time or 0.8, vel = away * ( p.stunRag.h or 30 ) * S + Vector( 0, 0, ( p.stunRag.v or 15 ) * S ) }
	end
	-- interrupting the target's action (a move or a dash, not a block) upgrades the hit
	local it = p.interrupt
	-- hit.interrupting: the target was in the middle of a move or a dash; hit.guarding: they were blocking
	hit.guarding = JJS.IsBlocking( victim )
	hit.interrupting = ( JJS.IsBusy( victim ) or JJS.IsDashing( victim ) ) and not hit.guarding
	if it and hit.interrupting then
		hit.damage = hit.damage + ( it.damage or 0 )
		if it.stun then hit.stun = it.stun hit.ragdoll = nil end
		if it.ragdoll then
			local away = U.Flat( victim:GetPos() - ply:GetPos() )
			hit.ragdoll = { time = it.ragdoll.time or 1, vel = away * ( it.ragdoll.h or 30 ) * S + Vector( 0, 0, ( it.ragdoll.v or 18 ) * S ), trueRag = it.trueRag }
		end
		hit.interrupted = true
	end
	-- vsAir = { damage, ragdoll = { h, v } }: against an airborne (not ragdolled) target
	local va = p.vsAir
	if va and not victim:IsOnGround() and not victim:GetJRagdolled() then
		hit.damage = hit.damage + ( va.damage or 0 )
		if va.ragdoll then
			local away = U.Flat( victim:GetPos() - ply:GetPos() )
			hit.ragdoll = { time = va.ragdoll.time or 1, vel = away * ( va.ragdoll.h or 10 ) * S + Vector( 0, 0, ( va.ragdoll.v or 0 ) * S ), trueRag = va.trueRag }
		end
	end
	-- lowHp = { hp, damage, stun }: bonus on the final hit against a target at or under `hp`
	local lo = p.lowHp
	if lo and ( idx or p.hits ) >= p.hits and victim:GetJHP() <= lo.hp then
		hit.damage = hit.damage + ( lo.damage or 0 )
		if lo.stun and not hit.ragdoll then hit.stun = lo.stun end
	end
	-- block breaks: a blocking target is crushed instead
	local gb = p.guardBreak
	if gb and JJS.IsBlocking( victim ) then
		hit.damage = gb.damage or hit.damage
		hit.block = "none"
		hit.ragdoll = nil
		hit.stun = gb.stun or 2
		victim:SetJBlockStart( 0 )
		hit.guardBroken = true
	end
	local r = JJS.Hit( victim, hit )
	if r == "blocked" and hit.knock and p.knockBlock then victim:SetLocalVelocity( hit.knock ) end
	if r == "hit" or r == "killed" or r == "blocked" then
		ply:SetNW2Entity( "JJSLastHit", victim )
		if p.onContact then p.onContact( ply, victim, p, r ) end
		if hit.guardBroken and gb.onBreak and r ~= "blocked" then gb.onBreak( ply, victim, p ) end
		if hit.interrupted and it.onInterrupt and r ~= "blocked" then it.onInterrupt( ply, victim, p ) end
	end
	local own = JJS.IsBusy( ply ) and JJS.GetAction( ply ).kitParams == p
	if r == "blocked" and not ply.jjs_kitBlocked and own then
		ply.jjs_kitBlocked = true
		JJS.ExtendAction( ply, p.blockEndlag and math.max( p.blockEndlag - p.endlag, 0 ) or 0.3 )
	elseif r == "hit" or r == "killed" then
		ply.jjs_kitLanded = true
	end
	if ( r == "hit" or r == "killed" ) and p.heal then JJS.Heal( ply, p.heal / p.hits ) end
	if r == "hit" and p.slow then
		victim:SetJBuffMult( p.slow[ 1 ] )
		victim:SetJBuffEnd( CurTime() + ( p.slow[ 2 ] or 2 ) )
	end
	return r
end

function K.BoxTargets( ply, p )
	local yaw = ply:EyeAngles().y
	-- behind: the hitbox is behind the user (Reverse Kick)
	if p.behind then yaw = yaw + 180 end
	local center = U.BodyCenter( ply ) + U.YawForward( yaw ) * ( p.reach / 2 + 8 )
	U.LagComp( ply, true )
	local list = U.PlayersInBox( center, yaw, Vector( p.reach, p.width, p.height ), { ignore = ply, ragdolled = p.bypassRagdoll or p.hitBypass ~= nil } )
	U.LagComp( ply, false )
	return list
end

function K.SphereTargets( center, radius, ignore, ragdolled )
	local out = {}
	for _, v in ipairs( player.GetAll() ) do
		if v == ignore or not v:Alive() then continue end
		if v:GetJRagdolled() and not ragdolled then continue end
		if U.BodyCenter( v ):DistToSqr( center ) <= ( radius + 20 ) ^ 2 then out[ #out + 1 ] = v end
	end
	return out
end

-- Living player closest to the crosshair (checked against their feet, centre and head)
function K.AimTarget( ply, range, cone )
	local eye, aim = ply:EyePos(), ply:GetAimVector()
	local best, bestDot = nil, cone or 0.93
	for _, t in ipairs( player.GetAll() ) do
		if t == ply or not t:Alive() then continue end
		local rag = t:GetJRagdolled() and t:GetJRagEnt() or nil
		local base = IsValid( rag ) and rag:GetPos() - Vector( 0, 0, 20 ) or t:GetPos()
		if base:Distance( eye ) > range + 40 then continue end
		for _, z in ipairs( { 12, 36, 64 } ) do
			local to = base + Vector( 0, 0, z ) - eye
			local dist = to:Length()
			if dist > 1 then
				local dot = aim:Dot( to / dist )
				if dot > bestDot then best, bestDot = t, dot end
			end
		end
	end
	return best
end

-- The target of a Target move: pickTarget(ply, p) (Rika's own targeting) or the one under the cursor
function K.PickTarget( ply, p )
	if p.pickTarget then return p.pickTarget( ply, p ) end
	return K.AimTarget( ply, p.range, p.cone )
end

-- Aim direction for rays/projectiles (pitch limited so ground shots stay useful)
function K.AimDir( ply, maxPitch )
	local d = ply:GetAimVector()
	if maxPitch then d.z = math.Clamp( d.z, -maxPitch, maxPitch ) end
	d:Normalize()
	return d
end

function K.Muzzle( ply )
	return U.BodyCenter( ply ) + Vector( 0, 0, 16 ) + K.Fwd( ply ) * 14
end

function K.Effect( name, pos, dir, ent, scale, p, magnitude )
	if CLIENT then return end
	U.Effect( name, pos, dir, ent, scale, p and p.colorId or 1, magnitude )
end

-- Scripted movement that keeps gravity (lunges, dashes)
function K.Drive( ply, mv, vel )
	local vz = JJS.Move.IsGrounded( ply, mv ) and 0 or ( mv:GetVelocity().z - JJS.Config.Gravity * FrameTime() )
	if vel.z ~= 0 then vz = vel.z end
	JJS.Move.Slide( ply, mv, Vector( vel.x, vel.y, vz ), FrameTime(), true )
end

------------------------------------------------------------------------------------------
-- Kind implementations: each returns an action definition for JJS.RegisterAction
------------------------------------------------------------------------------------------

local IMPL = {}

local function HitEvents( p, fn )
	local evs = {}
	for i = 1, p.hits do
		evs[ #evs + 1 ] = { HitTime( p, i ), function( ply, t, var )
			if CLIENT then return end
			fn( ply, i, var )
			-- a whiffed move has its own (usually longer) recovery
			if i == p.hits and not ply.jjs_kitLanded and not ply.jjs_kitBlocked and JJS.IsBusy( ply ) and JJS.GetAction( ply ).kitParams == p then
				if p.missAb then
					p.missAb.Use( ply, nil, 0 )
				elseif p.whiffEndlag then
					JJS.ExtendAction( ply, math.max( p.whiffEndlag - p.endlag, 0 ) )
				end
			end
		end }
	end
	return evs
end

-- Parry: a hit of a listed type during the first `window` seconds is evaded and the attacker pushed back
local function Parry( p )
	local pr = p.parry or ( p.meleeIFrames and { window = p.meleeIFrames, dodge = true } )
	if not pr then return end
	return function( victim, attacker, hit )
		if JJS.ActionTime( victim ) > pr.window then return end
		local ok = false
		for name in pairs( pr.counters or { melee = true } ) do
			if DMG_BY_NAME[ name ] == hit.type then ok = true end
		end
		if not ok then return end
		-- dodge: typed i-frames (melee i-frames), nothing happens to the attacker
		if pr.dodge then return "dodged" end
		JJS.IFrames( victim, pr.iframes or 0.5 )
		if IsValid( attacker ) and attacker:IsPlayer() and attacker ~= victim and hit.type == JJS.DMG.MELEE then
			JJS.Stun( attacker, pr.stun or 0.6 )
			attacker:SetLocalVelocity( U.Flat( attacker:GetPos() - victim:GetPos() ) * 300 )
		end
		K.Effect( "jjs_kit_cast", U.BodyCenter( victim ), nil, victim, 1.2, p )
		if pr.onParry then pr.onParry( victim, attacker, hit ) end
		return "parried"
	end
end

local function Base( p )
	return {
		counter = Parry( p ),
		kitParams = p,
		m1Cancel = p.m1Cancel,
		dur = Duration( p ),
		moveMult = p.moveMult or 0.35,
		noJump = p.noJump,
		uninterruptible = p.uninterruptible,
		armor = p.armorTypes,
		dashCancel = p.dashCancel or p.startup,
		gesture = p.gesture or "range_fists_r",
		start = function( ply )
			ply.jjs_kitBlocked = nil
			ply.jjs_kitLanded = nil
			ply.jjs_crashes = nil
			if p.iframes then JJS.IFrames( ply, p.iframes ) end
			if p.awakenCost and not ply:GetJAwakened() then ply:SetJAwaken( math.max( 0, ply:GetJAwaken() - p.awakenCost ) ) end
			if SERVER and p.selfDamage then JJS.ApplyDamage( ply, nil, p.selfDamage, { type = JJS.DMG.SPECIAL } ) end
			if SERVER and p.onUse then p.onUse( ply, p ) end
		end,
		finish = function( ply, var, interrupted )
			if SERVER and p.onEnd and not interrupted then p.onEnd( ply, p ) end
			if SERVER and p.onFinish then p.onFinish( ply, p, interrupted ) end
		end,
	}
end

-- Moves forward during the startup, stopping once someone is within reach
local function Lunge( p )
	if p.backstep then
		return function( ply, mv, t )
			if t >= p.startup * 0.8 then return false end
			K.Drive( ply, mv, -K.Fwd( ply ) * ( p.backstep / math.max( p.startup * 0.8, 0.05 ) ) )
			return true
		end
	end
	if not p.lunge then return end
	return function( ply, mv, t )
		if t >= p.startup then return false end
		local fwd = K.Fwd( ply )
		local center = mv:GetOrigin() + Vector( 0, 0, 36 ) + fwd * ( p.reach * 0.35 )
		local near = U.PlayersInBox( center, ply:EyeAngles().y, Vector( p.reach * 0.5, p.width, p.height ), { ignore = ply } )
		if near[ 1 ] then
			mv:SetVelocity( fwd * 20 )
			return false
		end
		K.Drive( ply, mv, fwd * ( p.lunge / math.max( p.startup, 0.05 ) ) )
		return true
	end
end

-- chase (studs/s): after the first hit lands, runs at the target until the next hit
local function Chase( p, lunge )
	if not p.chase then return lunge end
	return function( ply, mv, t )
		if lunge and lunge( ply, mv, t ) then return true end
		if t < p.startup or t >= p.startup + ( p.hits - 1 ) * p.interval then return false end
		local v = ply:GetNW2Entity( "JJSLastHit" )
		if not IsValid( v ) or not v:Alive() then return false end
		local to = v:GetPos() - mv:GetOrigin()
		to.z = 0
		if to:Length() < p.reach * 0.6 then
			mv:SetVelocity( vector_origin )
			return true
		end
		K.Drive( ply, mv, to:GetNormalized() * p.chase * S )
		return true
	end
end

IMPL.melee = function( p )
	local def = Base( p )
	def.move = Chase( p, Lunge( p ) )
	def.events = HitEvents( p, function( ply, i )
		for _, v in ipairs( K.BoxTargets( ply, p ) ) do
			K.Apply( ply, p, v, i )
		end
		if i == p.hits and p.crater then JJS.Destruction.GroundImpact( ply:GetPos() + K.Fwd( ply ) * p.reach / 2 + Vector( 0, 0, 20 ), p.crater ) end
	end )
	return def
end

-- carry = studs/s: after the grab lands, the user flies along their aim with the target until the last hit;
-- hitting a wall calls onCrash(ply, target, p) (at most crashes = n times)
local function Carry( p, lunge )
	if not p.carry then return lunge end
	return function( ply, mv, t )
		if lunge and lunge( ply, mv, t ) then return true end
		local v = ply:GetJActTarget()
		if t < p.startup or t >= p.startup + ( p.hits - 1 ) * p.interval or not IsValid( v ) then return false end
		JJS.Move.Slide( ply, mv, ply:GetAimVector() * p.carry * S, FrameTime(), false )
		return true
	end
end

IMPL.grab = function( p )
	local def = Base( p )
	def.move = Carry( p, Lunge( p ) )
	def.events = HitEvents( p, function( ply, i )
		if i == 1 then
			local v = K.BoxTargets( ply, p )[ 1 ]
			local r = v and K.Apply( ply, p, v, 1 )
			if r == "hit" then
				ply:SetJActTarget( v )
			else
				-- whiff or blocked: the rest of the grab is skipped
				JJS.StopAction( ply, true )
				JJS.Endlag( ply, p.whiffEndlag or 0.45 )
			end
			return
		end
		local v = ply:GetJActTarget()
		if IsValid( v ) and v:Alive() then K.Apply( ply, p, v, i ) end
	end )
	-- hold the caught target in front
	def.think = function( ply, t )
		if CLIENT or t < p.startup then return end
		local v = ply:GetJActTarget()
		if not IsValid( v ) or not v:Alive() or v:GetJRagdolled() then return end
		-- carried into a wall
		if p.carry and p.onCrash and ( ply.jjs_crashes or 0 ) < ( p.crashes or 3 ) and ( ply.jjs_crashT or 0 ) < CurTime() then
			local c = U.BodyCenter( ply )
			local tr = util.TraceLine( { start = c, endpos = c + ply:GetAimVector() * 5 * S, mask = MASK_SOLID_BRUSHONLY } )
			if tr.Hit then
				ply.jjs_crashes = ( ply.jjs_crashes or 0 ) + 1
				ply.jjs_crashT = CurTime() + 0.4
				p.onCrash( ply, v, p )
			end
		end
		local pos = ply:GetPos() + K.Fwd( ply ) * 40
		if U.HullFits( v, pos ) then v:SetPos( pos ) end
		v:SetLocalVelocity( vector_origin )
		JJS.Stun( v, 0.3 )
	end
	return def
end

-- Rush: startup, then travel with an active hitbox; contact starts the hit sequence
IMPL.rush = function( p )
	local def = Base( p )
	local base = def.start
	local travelEnd = p.startup + p.time
	def.dur = travelEnd + ( p.whiffEndlag or p.endlag )
	def.moveMult = p.moveMult or 0.1
	def.noJump = true
	def.start = function( ply )
		base( ply )
		ply.jjs_rush = { contact = nil, idx = 0 }
	end
	def.move = function( ply, mv, t )
		local st = ply.jjs_rush
		if t < p.startup or t >= travelEnd or ( st and st.contact ) then return false end
		K.Drive( ply, mv, K.Fwd( ply ) * ( p.travel / p.time ) )
		return true
	end
	def.think = function( ply, t )
		local st = ply.jjs_rush
		if not st then return end
		if not st.contact then
			if t < p.startup or t >= travelEnd then return end
			local v = K.BoxTargets( ply, p )[ 1 ]
			if not v then return end
			st.contact = t
			if CLIENT then return end
			local r = K.Apply( ply, p, v, 1 )
			st.idx = 1
			if r == "hit" then
				ply:SetJActTarget( v )
				if p.iframesOnHit then JJS.IFrames( ply, p.iframesOnHit ) end
				ply:SetJActEnd( CurTime() + ( p.hits - 1 ) * p.interval + p.endlag )
			else
				-- blocked (or countered): the rush ends here
				st.idx = p.hits
				ply:SetJActEnd( CurTime() + ( r == "blocked" and ( p.blockEndlag or 0.5 ) or p.endlag ) )
			end
			return
		end
		if CLIENT or st.idx >= p.hits then return end
		local v = ply:GetJActTarget()
		if not IsValid( v ) or not v:Alive() then return end
		-- hold the caught target in front
		if not v:GetJRagdolled() then
			local pos = ply:GetPos() + K.Fwd( ply ) * 40
			if U.HullFits( v, pos ) then v:SetPos( pos ) end
			v:SetLocalVelocity( vector_origin )
			JJS.Stun( v, 0.3 )
		end
		if t >= st.contact + st.idx * p.interval then
			st.idx = st.idx + 1
			K.Apply( ply, p, v, st.idx )
		end
	end
	def.finish = function( ply, var, interrupted )
		ply.jjs_rush = nil
		if SERVER and p.onEnd and not interrupted then p.onEnd( ply, p ) end
		if SERVER and p.onFinish then p.onFinish( ply, p, interrupted ) end
	end
	return def
end

local function FireRay( ply, p, tick )
	local dir = K.AimDir( ply, p.maxPitch or 0.5 )
	local start = K.Muzzle( ply )
	U.LagComp( ply, true )
	local hits, endPos = U.PlayersOnRay( start, dir, p.range, p.radius, { ignore = ply, ragdolled = p.bypassRagdoll } )
	U.LagComp( ply, false )

	local stop = endPos
	-- far = { dist, ragdoll = { h, v }, onHit }: targets hit beyond `dist` studs react differently (Root Swarm)
	if p.far and not p.farP then
		p.farP = table.Copy( p )
		p.farP.far = nil
		local r = p.far.ragdoll or {}
		p.farP.ragdoll = { time = r.time or 1, h = ( r.h or -30 ) * S, v = ( r.v or 20 ) * S }
		p.farP.onHit = p.far.onHit or p.onHit
	end
	for n, h in ipairs( hits ) do
		if not p.pierce then stop = start + dir * h.dist end
		-- falloff: damage drops linearly to `falloff` at max range
		local scale = p.falloff and Lerp( h.dist / p.range, 1, p.falloff / math.max( p.damage / p.hits, 0.01 ) ) or nil
		K.Apply( ply, ( p.farP and h.dist > p.far.dist * S ) and p.farP or p, h.ply, tick, start, scale )
		if not p.pierce then break end
		if n >= 8 then break end
	end
	K.Effect( "jjs_kit_beam", start, dir, ply, ( stop - start ):Length(), p, p.duration and 2 or 1 )
	if p.crater then JJS.Destruction.SurfaceImpact( start, dir, p.range, p.crater ) end
end
K.FireRay = FireRay

IMPL.beam = function( p )
	local def = Base( p )
	def.moveMult = p.moveMult or 0.15
	if p.duration then
		-- channelled: damage is spread over ticks
		local ticks = math.max( 1, math.floor( p.duration / p.tick ) )
		p.hits = ticks
		p.interval = p.tick
		def.dur = Duration( p ) - p.duration
	end
	def.events = HitEvents( p, function( ply, i )
		if i == 1 and p.clash and JJS.Clash.TryStart( ply, p ) then return end
		FireRay( ply, p, i )
	end )
	return def
end

IMPL.projectile = function( p )
	local def = Base( p )
	local count = p.count or 1
	def.events = {}
	for n = 1, count do
		def.events[ #def.events + 1 ] = { p.startup + ( n - 1 ) * ( p.volley or 0.12 ), function( ply )
			if CLIENT then return end
			local dir = K.AimDir( ply, p.maxPitch or 0.6 )
			if p.spread and count > 1 then
				local ang = dir:Angle()
				ang:RotateAroundAxis( ang:Up(), ( n - ( count + 1 ) / 2 ) * p.spread )
				dir = ang:Forward()
			end
			K.SpawnProjectile( ply, p, K.Muzzle( ply ), dir )
		end }
	end
	def.dur = p.startup + ( count - 1 ) * ( p.volley or 0.12 ) + p.endlag
	return def
end

IMPL.aoe = function( p )
	local def = Base( p )
	def.events = HitEvents( p, function( ply, i )
		local center = U.BodyCenter( ply ) + K.Fwd( ply ) * p.offset + Vector( 0, 0, p.up or 0 )
		-- center(ply) -> position: the area is placed elsewhere (a mark on the ground...)
		if p.center then
			center = p.center( ply )
			if not center then return end
			center = center + Vector( 0, 0, 36 )
		end
		for _, v in ipairs( K.SphereTargets( center, p.radius, ply, p.bypassRagdoll ) ) do
			K.Apply( ply, p, v, i, center )
		end
		if i == 1 then K.Effect( "jjs_kit_burst", center, Vector( 0, 0, 1 ), ply, p.radius, p ) end
		if i == p.hits and p.crater then JJS.Destruction.GroundImpact( center, p.crater ) end
	end )
	return def
end

IMPL.target = function( p )
	local def = Base( p )
	if p.noHit then
		def.dur = p.startup + p.endlag
		return def
	end
	def.events = HitEvents( p, function( ply, i )
		local v = ply:GetJActTarget()
		if not IsValid( v ) or not v:Alive() then return end
		local reach = p.teleport == false and p.range + 60 or p.reach + 40
		if v:GetPos():DistToSqr( p.origin and p.origin( ply ) or ply:GetPos() ) > reach ^ 2 then return end
		-- pullIn: the first hit drags the target in front of the user (before it lands, so a ragdoll starts there)
		local from
		if i == 1 and p.pullIn and not v:GetJRagdolled() and not JJS.HasIFrames( v ) then
			local pos = ply:GetPos() + K.Fwd( ply ) * 44
			if U.HullFits( v, pos ) then
				from = v:GetPos()
				v:SetPos( pos )
				v:SetLocalVelocity( vector_origin )
			end
		end
		local r = K.Apply( ply, p, v, i )
		-- a dodged or countered pull puts them back
		if from and r ~= "hit" and r ~= "blocked" and r ~= "killed" then v:SetPos( from ) end
		if i == 1 and p.teleport == false then K.Effect( "jjs_kit_burst", U.BodyCenter( v ), nil, v, 40, p ) end
	end )
	return def
end

IMPL.mobility = function( p )
	local def = Base( p )
	local base = def.start
	def.dur = p.startup + p.time + p.endlag
	def.moveMult = p.moveMult or 0.2
	def.move = function( ply, mv, t )
		if t < p.startup or t >= p.startup + p.time then return false end
		local yaw = mv:GetMoveAngles().y
		local dir
		if p.dir == "back" then dir = -U.YawForward( yaw )
		elseif p.dir == "up" then dir = Vector( 0, 0, 1 )
		elseif p.dir == "aim" then dir = ply:GetAimVector()
		elseif p.dir == "target" then
			-- a hop toward the last player hit (JJSLastHit), rising by `arc`
			local v = ply:GetNW2Entity( "JJSLastHit" )
			dir = IsValid( v ) and v:Alive() and U.Flat( v:GetPos() - mv:GetOrigin() ) or U.YawForward( yaw )
		else dir = U.YawForward( yaw ) end
		-- arc: rises then falls along the way (a hop)
		local arc = p.arc or ( p.dir == "target" and 0.3 )
		if arc then
			if p.steer and mv:KeyDown( IN_JUMP ) then arc = arc * 1.8 end
			dir = ( dir + Vector( 0, 0, arc * ( 1 - 2 * ( t - p.startup ) / p.time ) ) ):GetNormalized()
		end
		local speed = p.travel / p.time
		-- steer: holding forward carries further, holding back hops short
		if p.steer then
			local f = mv:GetForwardSpeed()
			speed = speed * ( f > 0 and 1.3 or f < 0 and 0.5 or 1 )
		end
		if p.dir == "up" or p.dir == "aim" or arc then
			JJS.Move.Slide( ply, mv, dir * speed, FrameTime(), false )
		else
			K.Drive( ply, mv, dir * speed )
		end
		return true
	end
	if p.damage > 0 then
		-- crashes into everyone along the way (each target once)
		p.reach = p.reach or 8 * S
		p.width = p.width or 8 * S
		p.height = p.height or 8 * S
		def.start = function( ply )
			base( ply )
			ply.jjs_mobHit = {}
		end
		def.think = function( ply, t )
			if CLIENT or t < p.startup or t > p.startup + p.time + 0.05 then return end
			for _, v in ipairs( K.BoxTargets( ply, p ) ) do
				if not ply.jjs_mobHit[ v ] then
					ply.jjs_mobHit[ v ] = true
					K.Apply( ply, p, v )
				end
			end
		end
	end
	return def
end

IMPL.buff = function( p )
	local def = Base( p )
	def.dur = p.startup + p.duration + p.endlag
	def.moveMult = p.moveMult or 0.5
	def.events = { { p.startup, function( ply )
		if p.speed then
			ply:SetJBuffMult( p.speed )
			ply:SetJBuffEnd( CurTime() + ( p.speedTime or 5 ) )
		end
		if CLIENT then return end
		if p.heal then JJS.Heal( ply, p.heal ) end
		if p.evasive then JJS.AddEvasive( ply, p.evasive ) end
		if p.awaken then ply:SetJAwaken( math.Clamp( ply:GetJAwaken() + p.awaken, 0, 1 ) ) end
		K.Effect( "jjs_kit_cast", U.BodyCenter( ply ), nil, ply, 1, p )
	end } }
	return def
end

-- Lingering areas are ticked by the server; the user is free once the move ends
K.Zones = K.Zones or {}

IMPL.zone = function( p )
	local def = Base( p )
	def.events = { { p.startup, function( ply )
		if CLIENT then return end
		local center = ply:GetPos() + K.Fwd( ply ) * p.offset
		if p.center then center = p.center( ply ) end
		if not center then return end
		local ent
		if p.target then
			ent = ply:GetJActTarget()
			if not IsValid( ent ) then return end
			center = ent:GetPos()
		end
		K.Zones[ #K.Zones + 1 ] = { owner = ply, p = p, pos = center, ent = ent, stop = CurTime() + p.duration, nextTick = CurTime(), done = {} }
		if p.onPlace then p.onPlace( ply, center, p ) end
	end } }
	return def
end

if SERVER then
	-- noKill moves leave their target at 1 HP
	hook.Add( "JJS_PreventDeath", "JJS_KitNoKill", function( victim, attacker, dmg, hit )
		if hit and hit.noKill then
			victim:SetJHP( 1 )
			victim:SetHealth( 1 )
			return true
		end
	end )

	hook.Add( "Tick", "JJS_KitZones", function()
		local now = CurTime()
		for i = #K.Zones, 1, -1 do
			local z = K.Zones[ i ]
			local ply = z.owner
			-- paused (Blood Rain toggled off): the time left is kept
			if z.paused and IsValid( ply ) and ply:Alive() and not ply:GetJRagdolled() then
				z.stop = z.stop + FrameTime()
				continue
			end
			local stopped = z.p.stopOnHit and ( ply:GetJLastHurt() > z.stop - z.p.duration )
			if not IsValid( ply ) or not ply:Alive() or now >= z.stop or stopped or ( z.p.stopOnRagdoll ~= false and ply:GetJRagdolled() )
				or ( z.p.target and not IsValid( z.ent ) ) then
				table.remove( K.Zones, i )
			elseif now >= z.nextTick then
				z.nextTick = now + z.p.tick
				local center = z.p.follow and ply:GetPos() or z.pos
				if IsValid( z.ent ) then center = z.ent:GetPos() end
				for _, v in ipairs( K.SphereTargets( center + Vector( 0, 0, 36 ), z.p.radius, ply, z.p.bypassRagdoll ) ) do
					-- acting: only players in the middle of a move (not blocking or side dashing); once: each target once
					local acting = not z.p.acting or ( JJS.IsBusy( v ) or v:GetJDashType() == JJS.Dash.FRONT ) and not JJS.IsBlocking( v )
					-- zoneHits = { damage of the 1st hit on a target, the 2nd, ... } (no more after the last)
					local n = z.done[ v ] or 0
					if acting and not ( z.p.once and n > 0 ) and not ( z.p.zoneHits and n >= #z.p.zoneHits ) then
						z.done[ v ] = n + 1
						if z.p.acting and JJS.GetAction( v ) then JJS.StopAction( v, true ) end
						local hit = K.MakeHit( ply, z.p, v, 1, center )
						if z.p.zoneHits then hit.damage = z.p.zoneHits[ n + 1 ] end
						-- falloff: weaker the farther from the centre
						if z.p.falloff then hit.damage = hit.damage * math.max( 0.05, 1 - v:GetPos():Distance( center ) / z.p.radius ) end
						JJS.Hit( v, hit )
					end
				end
				K.Effect( "jjs_kit_burst", center + Vector( 0, 0, 4 ), Vector( 0, 0, 1 ), ply, z.p.radius, z.p )
			end
		end
	end )
end

IMPL.stub = function( p )
	local def = Base( p )
	def.events = { { p.startup, function( ply )
		if CLIENT then return end
		K.Effect( "jjs_kit_cast", U.BodyCenter( ply ), nil, ply, 1, p )
	end } }
	return def
end

IMPL.counter = function( p )
	local def = Base( p )
	def.dur = p.window + p.endlag
	def.moveMult = p.moveMult or 0.1
	def.gesture = p.gesture or "fist_block"
	local counters = p.counters or { melee = "counter" }
	def.counter = function( victim, attacker, hit )
		if JJS.ActionTime( victim ) > p.window then return end
		local mode
		for name, m in pairs( counters ) do
			if DMG_BY_NAME[ name ] == hit.type then mode = m end
		end
		if not mode then return end
		JJS.IFrames( victim, p.counterIFrames or 0.6 )
		K.Effect( "jjs_kit_cast", U.BodyCenter( victim ), nil, victim, 1.5, p )
		if p.heal then JJS.Heal( victim, p.heal ) end
		if p.onCounter then p.onCounter( victim, attacker, hit, mode ) end
		if mode == "counter" and IsValid( attacker ) and attacker:IsPlayer() then
			JJS.StartAction( victim, p.riposteAction, 0, attacker )
			return "countered"
		end
		return "evaded"
	end
	-- nothing countered: the miss spec (Brothers: Yuji lunges anyway)
	def.events = { { p.window, function( ply )
		if CLIENT or not p.missAb then return end
		local act = JJS.GetAction( ply )
		if act and act.kitParams == p then
			JJS.StopAction( ply, true )
			p.missAb.Use( ply, nil, 0 )
		end
	end } }
	return def
end

-- The strike that follows a successful counter
local function Riposte( p )
	local rp = table.Copy( p )
	rp.hits, rp.startup, rp.endlag = 1, 0.12, 0.35
	rp.damage = p.riposte
	rp.dmgType = JJS.DMG.MELEE
	rp.ragdoll = rp.ragdoll or { time = 1, h = 30 * S, v = 18 * S }
	rp.trueRag = true -- counters disable ragdoll cancel
	rp.block = "none"
	local def = Base( rp )
	def.start = function( ply )
		JJS.IFrames( ply, 0.4 )
		local v = ply:GetJActTarget()
		if p.teleport and IsValid( v ) then
			local behind = v:GetPos() - U.YawForward( v:EyeAngles().y ) * 40
			if U.HullFits( ply, behind ) then JJS.Teleport( ply, behind ) end
		end
	end
	def.events = { { rp.startup, function( ply )
		if CLIENT then return end
		local v = ply:GetJActTarget()
		if IsValid( v ) and v:GetPos():DistToSqr( ply:GetPos() ) < ( p.riposteRange or 16 * S ) ^ 2 then
			JJS.Hit( v, K.MakeHit( ply, rp, v, 1 ) )
		end
	end } }
	return def
end

IMPL.domain = function( p )
	local def = Base( p )
	def.dur = JJS.Config.Domain.CastTime + 0.2
	def.moveMult = 0
	def.noJump = true
	def.gesture = "gesture_item_place"
	def.events = { { JJS.Config.Domain.CastTime, function( ply )
		if SERVER then JJS.Domain.Expand( ply, p ) end
	end } }
	return def
end

------------------------------------------------------------------------------------------
-- Building abilities
------------------------------------------------------------------------------------------

-- detached: the move is performed by a companion (Rika...): the user only makes a short motion (`cast` seconds)
-- and is free again while the hits play out on their own timeline (server Tick below)
K.Detached = K.Detached or {}
local function Detach( p, def )
	local evs = def.events or {}
	local start = def.start
	return {
		kitParams = p,
		detachedEvents = evs,
		dur = p.cast or 0.15,
		moveMult = 0.8,
		gesture = "gesture_item_throw",
		counter = def.counter,
		start = function( ply )
			if start then start( ply ) end
			if CLIENT then return end
			K.Detached[ #K.Detached + 1 ] = { owner = ply, target = ply:GetJActTarget(), t0 = CurTime(), evs = evs, i = 1, p = p }
		end,
	}
end

-- Plays a detached move's hits without any action from the user (effects triggered in the middle of other moves)
function K.Trigger( ply, ab, target )
	if CLIENT or not ab or not ab.move then return end
	local def = JJS.Actions[ ab.move.action ]
	if not def or not def.detachedEvents then return end
	local p = ab.move.p
	if p.onUse then p.onUse( ply, p ) end
	K.Detached[ #K.Detached + 1 ] = { owner = ply, target = target, t0 = CurTime(), evs = def.detachedEvents, i = 1, p = p }
end

if SERVER then
	hook.Add( "Tick", "JJS_KitDetached", function()
		local now = CurTime()
		for n = #K.Detached, 1, -1 do
			local d = K.Detached[ n ]
			local ply = d.owner
			if not IsValid( ply ) or not ply:Alive() then
				table.remove( K.Detached, n )
			else
				while d.evs[ d.i ] and now - d.t0 >= JJS.Resolve( d.evs[ d.i ][ 1 ], ply, 0 ) do
					-- the events read the action target: lend them the one this move started with
					local old = ply:GetJActTarget()
					ply:SetJActTarget( d.target or NULL )
					d.evs[ d.i ][ 2 ]( ply, now - d.t0, 0 )
					ply:SetJActTarget( old )
					d.i = d.i + 1
				end
				if not d.evs[ d.i ] then
					table.remove( K.Detached, n )
					if d.p.onDone then d.p.onDone( ply, d.target, d.p ) end
				end
			end
		end
	end )
end

local function Register( name, p )
	local impl = IMPL[ p.kind ] or IMPL.stub
	local def = impl( p )
	if p.detached then def = Detach( p, def ) end
	JJS.RegisterAction( name, def )
	if p.kind == "counter" then
		p.riposteAction = name .. ".riposte"
		JJS.RegisterAction( p.riposteAction, Riposte( p ) )
	end
	return name
end

local function DefaultCanUse( ply )
	return JJS.CanAct( ply ) and not JJS.IsBlocking( ply ) and not JJS.IsBusy( ply ) and not JJS.IsDashing( ply )
end

local function KeyFor( slot )
	if slot == 5 then return JJS.IN.SPECIAL end
	return JJS.AbilityKeys[ slot ] or 0
end

local Build

-- Starts a built move: cooldown, action, follow-up window. slot 0 = no cooldown (follow-ups)
local function Start( ply, mv, slot, ab, move, skipCooldown )
	if slot >= 1 and slot <= 5 and not skipCooldown and not ab.spec.noCooldown then
		local charges = ab.spec.charges
		if charges then
			-- several uses per cooldown: short delay between them, full cooldown after the last
			ply.jjs_charges = ply.jjs_charges or {}
			local left = ( ply.jjs_charges[ ab ] or charges ) - 1
			if left <= 0 then left = charges end
			ply.jjs_charges[ ab ] = left
			JJS.SetCooldown( ply, slot, left == charges and ab.cooldown or ( ab.spec.chargeDelay or 0.8 ) )
		else
			JJS.SetCooldown( ply, slot, move.p.cooldown or ab.cooldown )
		end
	end
	local target
	if move.p.kind == "target" or move.p.target then
		target = K.PickTarget( ply, move.p )
		if not IsValid( target ) then return end
		if move.p.kind == "target" and move.p.teleport ~= false then
			local dir = U.Flat( target:GetPos() - ( mv and mv:GetOrigin() or ply:GetPos() ) )
			local pos = target:GetPos() - dir * 36
			if U.HullFits( ply, pos ) then
				if mv then
					mv:SetOrigin( pos )
					mv:SetVelocity( vector_origin )
				else
					ply:SetPos( pos )
				end
			end
		end
	end
	local def = JJS.StartAction( ply, move.action, slot, target )
	if ab.specialAfter and def then
		ply.jjs_specialAfter = { t = CurTime() + JJS.Resolve( def.dur, ply, slot ) + ( ab.spec.specialAfter.window or 0.6 ), ab = ab.specialAfter }
	end
	if ab.again then
		ply.jjs_again = ply.jjs_again or {}
		ply.jjs_again[ slot ] = { t = CurTime() + ( ab.spec.again.window or 1.5 ), ab = ab }
	end
end

-- Nearest player in front of the user (ragdolled ones included)
function K.FrontTarget( ply, p )
	local yaw = ply:EyeAngles().y
	local reach = math.max( p.reach or 0, 9 * S )
	local center = U.BodyCenter( ply ) + U.YawForward( yaw ) * ( reach / 2 + 8 )
	return U.PlayersInBox( center, yaw, Vector( reach, math.max( p.width or 0, 9 * S ), 12 * S ), { ignore = ply, ragdolled = true } )[ 1 ]
end

-- Chooses the variant for the current situation: direction, target state, then the user's
function K.PickVariant( ply, mv, p, V, air, move )
	if V.conds then
		for _, c in ipairs( V.conds ) do
			if c.test( ply ) then return c end
		end
	end
	if V.back and mv and mv:GetForwardSpeed() < 0 then return V.back end
	if V.airTarget or V.ragdolled then
		local t = p.kind == "target" and K.PickTarget( ply, p ) or K.FrontTarget( ply, p )
		if IsValid( t ) then
			if V.ragdolled and t:GetJRagdolled() then return V.ragdolled end
			if V.airTarget and not t:IsOnGround() and not t:GetJRagdolled() then return V.airTarget end
		end
	end
	if V.highAir and not ply:IsOnGround() then
		local pos = ply:GetPos()
		local tr = util.TraceLine( { start = pos, endpos = pos - Vector( 0, 0, 7 * S ), mask = MASK_PLAYERSOLID, filter = ply } )
		if not tr.Hit then return V.highAir end
	end
	if air and not ply:IsOnGround() then return air end
	return move
end

-- A key pressed during a move's startup: that move's combo variant (returns true when used)
function K.TryCombo( ply, mv, slot )
	local act = JJS.GetAction( ply )
	local c = act and act.kitCombos and act.kitCombos[ slot ]
	local at = JJS.ActionTime( ply )
	if not c or at >= ( act.kitParams.comboWindow or act.kitParams.startup ) or at < ( act.kitParams.comboFrom or 0 ) then return false end
	if not c.free and JJS.GetCooldown( ply, slot ) > CurTime() then return false end
	if not ply:Alive() or ply:GetJRagdolled() or JJS.IsStunned( ply ) then return false end
	if c.need and not c.need( ply ) then return false end
	c.trigger( ply, mv, slot )
	return true
end

-- Special pressed: a follow-up right after a move, or the current move's SPECIAL variant
function K.TrySpecialVariant( ply, mv )
	-- follow-up right after a move (Face Grater after Rapid Punches...)
	local fa = ply.jjs_specialAfter
	if fa and CurTime() < fa.t and ( ply.jjs_kitLanded or fa.ab.spec.anyway ) and ( fa.ab.spec.free or JJS.GetCooldown( ply, 5 ) <= CurTime() )
		and ( not fa.ab.spec.need or fa.ab.spec.need( ply ) )
		and ply:Alive() and not ply:GetJRagdolled() and not JJS.IsStunned( ply ) then
		ply.jjs_specialAfter = nil
		JJS.StopAction( ply, true )
		JJS.SetCooldown( ply, 5, fa.ab.cooldown )
		fa.ab.Use( ply, mv, 0 )
		return true
	end

	return K.TryCombo( ply, mv, 5 )
end

function Build( id, key, spec )
	if not istable( spec ) or not spec.kind then return spec end
	local name = id .. "." .. key
	local name1 = spec.name or spec[ 1 ]
	local ab = { name = isstring( name1 ) and name1 or "?", tip = spec.tip, cooldown = spec.cooldown or 10, spec = spec }

	if spec.kind == "toggle" then
		ab.cooldown = spec.cooldown or 1
		ab.Use = function( ply, mv, slot )
			JJS.SetCooldown( ply, slot, ab.cooldown )
			ply:SetJKitSet( ply:GetJKitSet() == 1 and 0 or 1 )
			if SERVER then K.Effect( "jjs_kit_cast", U.BodyCenter( ply ), nil, ply, 1, Params( spec ) ) end
		end
		return ab
	end

	if spec.kind == "feint" then
		-- usable in the middle of another move's startup (or an M1): cancels it with no endlag
		ab.cooldown = spec.cooldown or 2
		ab.CanUse = function( ply )
			local act = JJS.GetAction( ply )
			if not act or not ply:Alive() or ply:GetJRagdolled() or JJS.IsStunned( ply ) then return false end
			local startup = act.kitParams and act.kitParams.startup
				or ( act.name == "m1" and ( JJS.M1.Timing( JJS.M1.Cfg( ply ), JJS.M1.Unpack( ply:GetJActVar() ) ) ) )
			return startup and JJS.ActionTime( ply ) < startup or false
		end
		ab.Use = function( ply, mv, slot )
			local act = JJS.GetAction( ply )
			local from = act.kitParams and ply:GetJActVar() or 0
			JJS.SetCooldown( ply, slot, ab.cooldown )
			JJS.StopAction( ply, true )
			if from >= 1 and from <= 4 then JJS.SetCooldown( ply, from, 0 ) end
			if spec.awakenCost and not ply:GetJAwakened() then ply:SetJAwaken( math.max( 0, ply:GetJAwaken() - spec.awakenCost ) ) end
			if SERVER then K.Effect( "jjs_kit_cast", U.BodyCenter( ply ), nil, ply, 0.7, Params( spec ) ) end
		end
		return ab
	end

	if spec.kind == "modes" then
		ab.cooldown = spec.cooldown or 1
		ab.modes = spec.modes
		ab.tip = spec.tip or function( ply ) return string.upper( spec.modes[ ply:GetJMode() + 1 ] or "" ) end
		ab.Use = function( ply, mv, slot )
			JJS.SetCooldown( ply, slot, ab.cooldown )
			if spec.awakenCost and not ply:GetJAwakened() then ply:SetJAwaken( math.max( 0, ply:GetJAwaken() - spec.awakenCost ) ) end
			ply:SetJMode( ( ply:GetJMode() + 1 ) % #spec.modes )
			if SERVER then K.Effect( "jjs_kit_cast", U.BodyCenter( ply ), nil, ply, 1, Params( spec ) ) end
		end
		return ab
	end

	if spec.kind == "bymode" then
		local built, names, seen = {}, {}, {}
		for i, sub in ipairs( spec ) do
			if istable( sub ) then
				built[ i - 1 ] = Build( id, key .. ".m" .. i, sub )
				local n = built[ i - 1 ].name
				if not seen[ n ] then names[ #names + 1 ] = n seen[ n ] = true end
			end
		end
		ab.name = table.concat( names, " / " )
		ab.modes = built
		ab.Pick = function( ply ) return built[ ply:GetJMode() ] or built[ 0 ] end
		return ab
	end

	local p = Params( spec )
	local move = { p = p, action = Register( name, p ) }
	ab.move = move
	local air = spec.air and { p = Params( spec, spec.air ) }
	if air then air.action = Register( name .. ".air", air.p ) end
	-- hold = { time, overrides } or a list of stages { { time, overrides }, ... } (the longest reached is used)
	local stages, hold
	if spec.hold then
		stages = {}
		for i, h in ipairs( spec.hold[ 1 ] and spec.hold or { spec.hold } ) do
			local st = { p = Params( spec, h ), time = h.time or 1 }
			st.action = Register( name .. ".hold" .. ( i > 1 and i or "" ), st.p )
			stages[ i ] = st
		end
		hold = stages[ #stages ]
	end
	if spec.again then
		local sub = spec.again.spec or spec.again
		ab.again = Build( id, key .. ".again", sub )
	end

	-- conditional variants
	local V = {}
	-- cond = { test, overrides } or a list of them (the first whose test passes is used)
	if spec.cond then
		V.conds = {}
		for i, c in ipairs( spec.cond[ 1 ] and spec.cond or { spec.cond } ) do
			local v = { p = Params( spec, c ), test = c.test }
			v.action = Register( name .. ".cond" .. ( i > 1 and i or "" ), v.p )
			V.conds[ i ] = v
		end
		V.cond = V.conds[ 1 ]
	end
	for _, vk in ipairs( { "airTarget", "ragdolled", "back", "highAir" } ) do
		if spec[ vk ] then
			V[ vk ] = { p = Params( spec, spec[ vk ] ) }
			V[ vk ].action = Register( name .. "." .. vk, V[ vk ].p )
		end
	end
	-- combos: another key pressed during the startup (the special is combo slot 5). A combo's own `special` /
	-- `combo` chain further (Rising Rage: special, then special again)
	local function MakeCombos( base, prefix )
		local combos = {}
		if base.special then combos[ 5 ] = base.special end
		for slot, over in pairs( base.combo or {} ) do combos[ slot ] = over end
		local C = {}
		for slot, over in pairs( combos ) do
			-- nested combos inherit the parent combo's fields but not its own combos
			local merged = over
			if base ~= spec then
				merged = table.Copy( base )
				merged.special, merged.combo = nil, nil
				for k, v in pairs( over ) do merged[ k ] = v end
			end
			C[ slot ] = { p = Params( spec, merged ), over = over, merged = merged }
			C[ slot ].action = Register( prefix .. ".combo" .. slot, C[ slot ].p )
		end
		return C
	end
	local C = MakeCombos( spec, name )
	V.special = C[ 5 ]
	if spec.specialAfter then ab.specialAfter = Build( id, key .. ".after", spec.specialAfter ) end
	if spec.miss then
		local missAb = Build( id, key .. ".miss", spec.miss )
		for _, m in ipairs( { move, air, hold, V.airTarget, V.ragdolled, V.back, V.highAir } ) do
			if m then m.p.missAb = missAb end
		end
		for _, m in ipairs( V.conds or {} ) do m.p.missAb = missAb end
		-- combos of the same kind keep it (Brutal Impact's Black Flash still has the wind gust)
		for _, c in pairs( C ) do
			if c.p.kind == p.kind then c.p.missAb = missAb end
		end
	end
	ab.variants = V

	-- another key (or the special) pressed during the startup switches to that combo variant
	local function ComboList( C, depth )
		local list = {}
		for slot, c in pairs( C ) do
			local over = c.over
			-- deeper combos (the special pressed again during the combo)
			if depth < 3 and ( over.special or over.combo ) then
				local sub = MakeCombos( c.merged, c.action )
				if next( sub ) then JJS.Actions[ c.action ].kitCombos = ComboList( sub, depth + 1 ) end
			end
			list[ slot ] = {
				free = over.free,
				need = over.need,
				trigger = function( ply, mv, pressed )
					local slot0 = ply:GetJActVar()
					JJS.StopAction( ply, true )
					if pressed == 5 then
						if over.specialCooldown then JJS.SetCooldown( ply, 5, over.specialCooldown ) end
					elseif not over.free then
						local other = JJS.GetAbility( ply, pressed )
						JJS.SetCooldown( ply, pressed, over.comboCooldown or ( other and other.cooldown ) or 10 )
					end
					-- the combo's own cooldown replaces the move's (Judgement's Reach leap: half cooldown)
					if over.cooldown and slot0 >= 1 and slot0 <= 5 then JJS.SetCooldown( ply, slot0, over.cooldown ) end
					if SERVER and over.onCombo then over.onCombo( ply ) end
					Start( ply, mv, slot0, ab, c, true )
				end,
			}
		end
		return list
	end
	if next( C ) then
		local list = ComboList( C, 1 )
		for _, m in ipairs( { move, air, hold, V.airTarget, V.ragdolled, V.back, V.highAir } ) do
			if m then JJS.Actions[ m.action ].kitCombos = list end
		end
		for _, m in ipairs( V.conds or {} ) do JJS.Actions[ m.action ].kitCombos = list end
	end

	if stages then
		local need = hold.time
		JJS.RegisterAction( name .. ".charge", {
			dur = need + 1.5,
			moveMult = p.holdMoveMult or 0.4,
			gesture = "gesture_bow",
			counter = Parry( p ), -- a parry window starts with the charge
			think = function( ply, t, mv, slot )
				local held = mv and mv:KeyDown( KeyFor( slot ) )
				if held and t < need + 1 then return end
				local pick = K.PickVariant( ply, mv, p, V, air, move )
				-- a stage can require something (need(ply): an orb...)
				for _, st in ipairs( stages ) do
					if t >= st.time and ( not st.p.need or st.p.need( ply ) ) then pick = st end
				end
				Start( ply, mv, slot, ab, pick, true )
			end,
		} )
	end

	ab.CanUse = function( ply, slot, mv )
		if not DefaultCanUse( ply ) then return false end
		if ( p.kind == "target" or p.target ) and not IsValid( K.PickTarget( ply, p ) ) then return false end
		if p.kind == "domain" and not JJS.Domain.CanCast( ply ) then return false end
		if spec.CanUse and not spec.CanUse( ply, slot ) then return false end
		return true
	end
	if ( p.kind == "target" or p.target ) and not ab.tip then ab.tip = "TARGET" end

	ab.Use = function( ply, mv, slot )
		-- a conditional variant takes over the hold (Offloaded Ultra Cannon...)
		local condHit = false
		for _, c in ipairs( V.conds or {} ) do
			if c.test( ply ) then condHit = true break end
		end
		-- airborne, the air variant is used right away (it can't be held)
		if spec.hold and not condHit and not ( ( air or V.highAir ) and not ply:IsOnGround() ) then
			JJS.SetCooldown( ply, slot, ab.cooldown )
			JJS.StartAction( ply, name .. ".charge", slot )
			return
		end
		Start( ply, mv, slot, ab, K.PickVariant( ply, mv, p, V, air, move ) )
	end

	if spec.feints then
		-- usable during another move: that move is cancelled first
		local canUse, use = ab.CanUse, ab.Use
		ab.CanUse = function( ply, slot, mv )
			local act = JJS.GetAction( ply )
			if act and act.kitParams and act.kitParams ~= p and ply:Alive() and not ply:GetJRagdolled() and not JJS.IsStunned( ply ) then
				return true
			end
			return canUse( ply, slot, mv )
		end
		ab.Use = function( ply, mv, slot )
			local act = JJS.GetAction( ply )
			local feinted = act and act.kitParams and act.kitParams ~= p
			local from = feinted and ply:GetJActVar()
			if feinted then JJS.StopAction( ply, true ) end
			use( ply, mv, slot )
			if feinted and spec.feintCooldown then JJS.SetCooldown( ply, slot, spec.feintCooldown ) end
			-- feintRefund = { except = slot }: the feinted move stays off cooldown
			local fr = spec.feintRefund
			if feinted and fr and from >= 1 and from <= 4 and from ~= fr.except then JJS.SetCooldown( ply, from, 0 ) end
		end
	end

	if ab.again then
		local base = ab.tip
		ab.tip = function( ply, slot )
			local a = ply.jjs_again and ply.jjs_again[ slot ]
			if a and CurTime() < a.t then return a.ab == ab and ( spec.again.tip or "USE AGAIN" ) or "USE AGAIN" end
			return isfunction( base ) and base( ply, slot ) or base
		end
		ab.Again = function( ply, mv, slot )
			local a = ply.jjs_again and ply.jjs_again[ slot ]
			if not a or CurTime() > a.t then return false end
			-- a follow-up of the follow-up (third press...)
			if a.ab ~= ab then return a.ab.Again ~= nil and a.ab.Again( ply, mv, slot ) end
			local act = JJS.GetAction( ply )
			local own = act and ( act.name == name or act.name == name .. ".air" )
			if not own and not DefaultCanUse( ply ) and not ( ab.again.spec.feints and act and act.kitParams ) then return false end
			if not ply:Alive() or ply:GetJRagdolled() or JJS.IsStunned( ply ) then return false end
			ply.jjs_again[ slot ] = nil
			ab.again.Use( ply, mv, 0 )
			local sub = ab.again
			if sub.Again then
				local sa = sub.spec.again
				ply.jjs_again[ slot ] = { t = CurTime() + ( ( sa.spec or sa ).window or 1.5 ), ab = sub }
			end
			return true
		end
	end
	return ab
end
K.Build = Build

-- Builds every ability of a moveset table in place
local function BuildSet( id, prefix, set )
	if not set then return end
	if set.abilities then
		for slot, spec in pairs( set.abilities ) do
			set.abilities[ slot ] = Build( id, prefix .. slot, spec )
		end
	end
	if set.special then set.special = Build( id, prefix .. "s", set.special ) end
	if set.alt then BuildSet( id, prefix .. "alt", set.alt ) end
end

function K.Character( id, def )
	BuildSet( id, "b", def )
	if def.awakening then
		BuildSet( id, "a", def.awakening )
		if def.awakening.domain then def.awakening.domain = Build( id, "adomain", def.awakening.domain ) end
	end
	if def.awakenMove then
		def.awakenMove.noCooldown = true
		def.awakenMove = Build( id, "awk", def.awakenMove )
	end
	return JJS.RegisterCharacter( id, def )
end

-- Default model fallback: models/jjs/<id>.mdl when present, otherwise a stock one
function K.Model( id, fallback )
	local mdl = "models/jjs/" .. id .. ".mdl"
	if file.Exists( mdl, "GAME" ) then return mdl end
	return fallback or "models/player/group01/male_07.mdl"
end
