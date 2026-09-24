-- Ability kit: moves described as data and turned into working placeholder actions.
-- Character files list their moves with the constructors below (values in studs / seconds,
-- as on the wiki) and register with JJS.Kit.Character( id, def ).
--
--   K.Melee{ "Name", cooldown = 15, damage = 10, hits = 2, ragdoll = true, ... }
--
-- Common fields:
--   [1] name, tip, cooldown, startup, endlag, moveMult, noJump
--   damage (total), hits, interval, type ("melee", "bullet", "explosion", "swarm", "domain", "special")
--   block ("normal", "all" = 360, "pre" = perfect block only, "none"), blockDamage, blockedEndlag
--   stun, ragdoll (true or { time, h, v } in studs/s; h < 0 pulls toward the user), trueRag (no evasive)
--   bypassRagdoll, armor ("melee", "bullet", "total"), uninterruptible, iframes (during the move)
--   heal, selfDamage, color (JJS.Kit.PALETTE key), crater (destruction scale on impact)
--   onHit(ply, victim, p) when the final hit lands
--   awakenCost (fraction of the awakening bar spent), noCooldown, charges (uses per cooldown)
--   slow = { mult, time } applied to targets hit, onEnd(ply, p) when the move finishes uninterrupted
--   air = { overrides } (used while airborne), hold = { time, overrides } (HOLD variant),
--   again = spec with a `window` (USE AGAIN / USE TWICE follow-up), onUse(ply, p) when the move starts
--
-- Kinds and their own fields:
--   Melee      reach, width, height, lunge (studs travelled during the startup)
--   Grab       like Melee; a caught target is held in front for the remaining hits
--   Beam       range, radius, pierce, duration (channelled), tick, clash (beam clash strength)
--   Projectile speed, range, radius, count, spread, explode (radius), gravity
--   Summon     a slow projectile (shikigami, swarms)
--   AoE        radius, offset (studs in front of the user), up (studs)
--   Counter    window, counters = { melee = "counter", bullet = "evade", ... }, riposte (damage), teleport,
--              onCounter(ply, attacker, hit, mode)
--   Target     range (studs to the aimed target), then hits it like Melee after appearing next to it
--              (noHit = true: only teleports; teleport = false: hits the target from where the user stands)
--   Mobility   travel, time, dir ("forward", "back", "up", "aim"), hit (hit at the end)
--   Buff       duration, speed, speedTime, evasive, awaken
--   Zone       lingering area: radius, duration, tick, damage (per tick), follow (stays on the user), offset
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

local STUDS = { reach = true, width = true, height = true, range = true, radius = true, lunge = true,
	travel = true, speed = true, offset = true, explode = true, up = true, gravity = true }

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
		p.armorTypes = p.armor == "total" and { all = true } or { [ DMG_BY_NAME[ p.armor ] or 0 ] = true }
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
	idx = idx or p.hits
	local last = idx >= p.hits
	local hit = {
		attacker = ply,
		damage = p.perHit or p.damage / p.hits,
		type = p.dmgType,
		block = p.block,
		blockDamage = p.blockDamage and p.blockDamage / p.hits,
		bypassRagdoll = p.bypassRagdoll,
		ignoreIFrames = p.ignoreIFrames,
		startTime = ply:GetJActStart(),
		from = from,
		fx = last and "heavy" or "light",
		stun = last and ( p.stun or 0.75 ) or math.max( p.interval + 0.4, 0.75 ),
		kit = p,
	}
	if last and p.ragdoll then
		local away = U.Flat( victim:GetPos() - ( from or ply:GetPos() ) )
		if away:LengthSqr() < 0.01 then away = K.Fwd( ply ) end
		hit.ragdoll = { time = p.ragdoll.time, vel = away * p.ragdoll.h + Vector( 0, 0, p.ragdoll.v ), trueRag = p.trueRag }
	end
	if last and p.onHit then
		hit.onHit = function( v ) p.onHit( ply, v, p ) end
	end
	return hit
end

-- Applies a hit and handles blocked endlag; returns the JJS.Hit result
function K.Apply( ply, p, victim, idx, from )
	local r = JJS.Hit( victim, K.MakeHit( ply, p, victim, idx, from ) )
	if r == "blocked" and not ply.jjs_kitBlocked and JJS.IsBusy( ply ) then
		ply.jjs_kitBlocked = true
		JJS.ExtendAction( ply, p.blockedEndlag or 0.3 )
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
	local center = U.BodyCenter( ply ) + U.YawForward( yaw ) * ( p.reach / 2 + 8 )
	U.LagComp( ply, true )
	local list = U.PlayersInBox( center, yaw, Vector( p.reach, p.width, p.height ), { ignore = ply, ragdolled = p.bypassRagdoll } )
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
		local base = t:GetPos()
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
		end }
	end
	return evs
end

local function Base( p )
	return {
		kitParams = p,
		dur = Duration( p ),
		moveMult = p.moveMult or 0.35,
		noJump = p.noJump,
		uninterruptible = p.uninterruptible,
		armor = p.armorTypes,
		dashCancel = p.dashCancel or p.startup,
		gesture = p.gesture or "range_fists_r",
		start = function( ply )
			ply.jjs_kitBlocked = nil
			if p.iframes then JJS.IFrames( ply, p.iframes ) end
			if p.awakenCost and not ply:GetJAwakened() then ply:SetJAwaken( math.max( 0, ply:GetJAwaken() - p.awakenCost ) ) end
			if SERVER and p.selfDamage then JJS.ApplyDamage( ply, nil, p.selfDamage, { type = JJS.DMG.SPECIAL } ) end
			if SERVER and p.onUse then p.onUse( ply, p ) end
		end,
		finish = function( ply, var, interrupted )
			if SERVER and p.onEnd and not interrupted then p.onEnd( ply, p ) end
		end,
	}
end

-- Moves forward during the startup, stopping once someone is within reach
local function Lunge( p )
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

IMPL.melee = function( p )
	local def = Base( p )
	def.move = Lunge( p )
	def.events = HitEvents( p, function( ply, i )
		for _, v in ipairs( K.BoxTargets( ply, p ) ) do
			K.Apply( ply, p, v, i )
		end
		if i == p.hits and p.crater then JJS.Destruction.GroundImpact( ply:GetPos() + K.Fwd( ply ) * p.reach / 2 + Vector( 0, 0, 20 ), p.crater ) end
	end )
	return def
end

IMPL.grab = function( p )
	local def = Base( p )
	def.move = Lunge( p )
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
		local pos = ply:GetPos() + K.Fwd( ply ) * 40
		if U.HullFits( v, pos ) then v:SetPos( pos ) end
		v:SetLocalVelocity( vector_origin )
		JJS.Stun( v, 0.3 )
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
	for n, h in ipairs( hits ) do
		if not p.pierce then stop = start + dir * h.dist end
		K.Apply( ply, p, h.ply, tick, start )
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
			local dir = K.AimDir( ply, 0.6 )
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
		if v:GetPos():DistToSqr( ply:GetPos() ) > reach ^ 2 then return end
		K.Apply( ply, p, v, i )
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
		else dir = U.YawForward( yaw ) end
		local speed = p.travel / p.time
		if p.dir == "up" or p.dir == "aim" then
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
		K.Zones[ #K.Zones + 1 ] = { owner = ply, p = p, pos = center, stop = CurTime() + p.duration, nextTick = CurTime() }
	end } }
	return def
end

if SERVER then
	hook.Add( "Tick", "JJS_KitZones", function()
		local now = CurTime()
		for i = #K.Zones, 1, -1 do
			local z = K.Zones[ i ]
			local ply = z.owner
			if not IsValid( ply ) or not ply:Alive() or now >= z.stop or ( z.p.stopOnRagdoll ~= false and ply:GetJRagdolled() ) then
				table.remove( K.Zones, i )
			elseif now >= z.nextTick then
				z.nextTick = now + z.p.tick
				local center = z.p.follow and ply:GetPos() or z.pos
				for _, v in ipairs( K.SphereTargets( center + Vector( 0, 0, 36 ), z.p.radius, ply, z.p.bypassRagdoll ) ) do
					JJS.Hit( v, K.MakeHit( ply, z.p, v, 1, center ) )
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
			if U.HullFits( ply, behind ) then ply:SetPos( behind ) end
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

local function Register( name, p )
	local impl = IMPL[ p.kind ] or IMPL.stub
	local def = impl( p )
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
			JJS.SetCooldown( ply, slot, ab.cooldown )
		end
	end
	local target
	if move.p.kind == "target" then
		target = K.AimTarget( ply, move.p.range, move.p.cone )
		if not IsValid( target ) then return end
		if move.p.teleport ~= false then
			local dir = U.Flat( target:GetPos() - mv:GetOrigin() )
			local pos = target:GetPos() - dir * 36
			if U.HullFits( ply, pos ) then
				mv:SetOrigin( pos )
				mv:SetVelocity( vector_origin )
			end
		end
	end
	JJS.StartAction( ply, move.action, slot, target )
	if ab.again then
		ply.jjs_again = ply.jjs_again or {}
		ply.jjs_again[ slot ] = { t = CurTime() + ( ab.spec.again.window or 1.5 ), ab = ab }
	end
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
			local startup = act.kitParams and act.kitParams.startup or ( act.name == "m1" and JJS.GetChar( ply ).m1.Startup )
			return startup and JJS.ActionTime( ply ) < startup or false
		end
		ab.Use = function( ply, mv, slot )
			local act = JJS.GetAction( ply )
			local from = act.kitParams and ply:GetJActVar() or 0
			JJS.SetCooldown( ply, slot, ab.cooldown )
			JJS.StopAction( ply, true )
			if from >= 1 and from <= 4 then ply[ "SetJCD" .. from ]( ply, 0 ) end
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
			ply:SetJMode( ( ply:GetJMode() + 1 ) % #spec.modes )
			if SERVER then K.Effect( "jjs_kit_cast", U.BodyCenter( ply ), nil, ply, 1, Params( spec ) ) end
		end
		return ab
	end

	if spec.kind == "bymode" then
		local built, names = {}, {}
		for i, sub in ipairs( spec ) do
			if istable( sub ) then
				built[ i - 1 ] = Build( id, key .. ".m" .. i, sub )
				names[ #names + 1 ] = built[ i - 1 ].name
			end
		end
		ab.name = table.concat( names, " / " )
		ab.Pick = function( ply ) return built[ ply:GetJMode() ] or built[ 0 ] end
		return ab
	end

	local p = Params( spec )
	local move = { p = p, action = Register( name, p ) }
	local air = spec.air and { p = Params( spec, spec.air ) }
	if air then air.action = Register( name .. ".air", air.p ) end
	local hold = spec.hold and { p = Params( spec, spec.hold ) }
	if hold then hold.action = Register( name .. ".hold", hold.p ) end
	if spec.again then
		local sub = spec.again.spec or spec.again
		ab.again = Build( id, key .. ".again", sub )
	end

	if spec.hold then
		local need = spec.hold.time or 1
		JJS.RegisterAction( name .. ".charge", {
			dur = need + 1.5,
			moveMult = 0.4,
			gesture = "gesture_bow",
			think = function( ply, t, mv, slot )
				local held = mv and mv:KeyDown( KeyFor( slot ) )
				if held and t < need + 1 then return end
				Start( ply, mv, slot, ab, t >= need and hold or move, true )
			end,
		} )
	end

	ab.CanUse = function( ply, slot, mv )
		if not DefaultCanUse( ply ) then return false end
		if p.kind == "target" and not IsValid( K.AimTarget( ply, p.range, p.cone ) ) then return false end
		if p.kind == "domain" and not JJS.Domain.CanCast( ply ) then return false end
		if spec.CanUse and not spec.CanUse( ply, slot ) then return false end
		return true
	end
	if p.kind == "target" and not ab.tip then ab.tip = "TARGET" end

	ab.Use = function( ply, mv, slot )
		if spec.hold then
			JJS.SetCooldown( ply, slot, ab.cooldown )
			JJS.StartAction( ply, name .. ".charge", slot )
			return
		end
		local m = ( air and not ply:IsOnGround() ) and air or move
		Start( ply, mv, slot, ab, m )
	end

	if ab.again then
		local base = ab.tip
		ab.tip = function( ply, slot )
			local a = ply.jjs_again and ply.jjs_again[ slot ]
			if a and a.ab == ab and CurTime() < a.t then return spec.again.tip or "USE AGAIN" end
			return isfunction( base ) and base( ply, slot ) or base
		end
		ab.Again = function( ply, mv, slot )
			local a = ply.jjs_again and ply.jjs_again[ slot ]
			if not a or a.ab ~= ab or CurTime() > a.t then return false end
			local act = JJS.GetAction( ply )
			local own = act and ( act.name == name or act.name == name .. ".air" )
			if not own and not DefaultCanUse( ply ) then return false end
			if not ply:Alive() or ply:GetJRagdolled() or JJS.IsStunned( ply ) then return false end
			ply.jjs_again[ slot ] = nil
			ab.again.Use( ply, mv, 0 )
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
