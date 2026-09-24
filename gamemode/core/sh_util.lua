local S = JJS.STUD

JJS.Util = JJS.Util or {}
local U = JJS.Util

function U.Studs( n )
	return n * S
end

-- Horizontal unit forward/right vectors of a yaw
function U.YawForward( yaw )
	local r = math.rad( yaw )
	return Vector( math.cos( r ), math.sin( r ), 0 )
end

function U.YawRight( yaw )
	local r = math.rad( yaw )
	return Vector( math.sin( r ), -math.cos( r ), 0 )
end

function U.Flat( v )
	local f = Vector( v.x, v.y, 0 )
	f:Normalize()
	return f
end

-- Sign of the movement input: returns forward (-1/0/1), side (-1/0/1; +1 = right)
function U.InputDir( mv )
	local f, s = mv:GetForwardSpeed(), mv:GetSideSpeed()
	return ( f > 0 and 1 ) or ( f < 0 and -1 ) or 0, ( s > 0 and 1 ) or ( s < 0 and -1 ) or 0
end

U.Ease = {
	Linear = function( t ) return t end,
	InQuad = function( t ) return t * t end,
	OutQuad = function( t ) return 1 - ( 1 - t ) * ( 1 - t ) end,
	InOutQuad = function( t ) return t < 0.5 and 2 * t * t or 1 - ( -2 * t + 2 ) ^ 2 / 2 end,
	OutCubic = function( t ) return 1 - ( 1 - t ) ^ 3 end,
	InOutSine = function( t ) return -( math.cos( math.pi * t ) - 1 ) / 2 end,
	OutBack = function( t )
		local c1 = 1.70158
		local c3 = c1 + 1
		return 1 + c3 * ( t - 1 ) ^ 3 + c1 * ( t - 1 ) ^ 2
	end,
}

-- Centre of a player's body used for hit tests (follows the ragdoll while ragdolled)
function U.BodyCenter( ply )
	return ply:GetPos() + Vector( 0, 0, 36 )
end

-- Players whose hull overlaps an oriented box.
-- opts.ignore = entity or set, opts.ragdolled = include ragdolled players, opts.dead = include dead
function U.PlayersInBox( center, yaw, size, opts )
	opts = opts or {}
	local fwd, right = U.YawForward( yaw ), U.YawRight( yaw )
	local hx, hy, hz = size.x / 2 + 16, size.y / 2 + 16, size.z / 2 + 36
	local out = {}

	for _, ply in ipairs( player.GetAll() ) do
		if opts.ignore == ply or ( istable( opts.ignore ) and opts.ignore[ ply ] ) then continue end
		if not ply:Alive() and not opts.dead then continue end
		if ply:GetJRagdolled() and not opts.ragdolled then continue end

		local d = U.BodyCenter( ply ) - center
		if math.abs( d:Dot( fwd ) ) <= hx and math.abs( d:Dot( right ) ) <= hy and math.abs( d.z ) <= hz then
			out[ #out + 1 ] = ply
		end
	end

	table.sort( out, function( a, b ) return a:GetPos():DistToSqr( center ) < b:GetPos():DistToSqr( center ) end )
	return out
end

-- Players along a ray (capsule of given radius), sorted by distance. Walls stop the ray.
function U.PlayersOnRay( start, dir, length, radius, opts )
	opts = opts or {}
	local tr = util.TraceLine( {
		start = start,
		endpos = start + dir * length,
		mask = MASK_SOLID_BRUSHONLY,
	} )
	local maxLen = length * tr.Fraction
	local out = {}

	for _, ply in ipairs( player.GetAll() ) do
		if opts.ignore == ply or ( istable( opts.ignore ) and opts.ignore[ ply ] ) then continue end
		if not ply:Alive() then continue end
		if ply:GetJRagdolled() and not opts.ragdolled then continue end

		local c = U.BodyCenter( ply )
		local along = ( c - start ):Dot( dir )
		if along < -16 or along > maxLen + 16 then continue end

		local closest = start + dir * math.Clamp( along, 0, maxLen )
		local off = c - closest
		if math.abs( off.z ) <= radius + 36 and off:Length2D() <= radius + 16 then
			out[ #out + 1 ] = { ply = ply, dist = along }
		end
	end

	table.sort( out, function( a, b ) return a.dist < b.dist end )
	return out, tr.HitPos, tr
end

-- Is `pos` in front of the player's facing (a <180 degree cone, like JJS block)?
function U.IsFacing( ply, pos, cosLimit )
	local fwd = U.YawForward( ply:EyeAngles().y )
	local d = U.Flat( pos - ply:GetPos() )
	return fwd:Dot( d ) > ( cosLimit or 0 )
end

-- Lag compensation for hit tests. Bots are skipped: their usercmds carry no tick count,
-- so the engine would rewind everyone by the maximum (~1s).
function U.LagComp( ply, on )
	if SERVER and not ply:IsBot() then ply:LagCompensation( on ) end
end

-- Trace used by scripted movement: world + props, never players or ragdolls
function U.MoveTrace( start, endpos, mins, maxs, ply )
	return util.TraceHull( {
		start = start,
		endpos = endpos,
		mins = mins,
		maxs = maxs,
		filter = player.GetAll(),
		mask = MASK_PLAYERSOLID,
		collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT,
	} )
end

function U.HullFits( ply, pos )
	local mins, maxs = ply:GetHull()
	local tr = U.MoveTrace( pos, pos, mins, maxs, ply )
	return not tr.StartSolid and not tr.Hit
end

-- Server helper: send a Lua effect to every client (including the attacker)
function U.Effect( name, pos, normal, ent, scale, flags, magnitude, start )
	local ed = EffectData()
	ed:SetOrigin( pos )
	if normal then ed:SetNormal( normal ) end
	if IsValid( ent ) then ed:SetEntity( ent ) end
	if scale then ed:SetScale( scale ) end
	if flags then ed:SetFlags( flags ) end
	if magnitude then ed:SetMagnitude( magnitude ) end
	if start then ed:SetStart( start ) end
	util.Effect( name, ed, true, true )
end

-- Character size (Mahoraga is twice as big): model scale, hulls and view height. Called from
-- spawn and SetupMove so both realms agree for prediction.
function JJS.ApplyScale( ply )
	local char = JJS.GetChar( ply )
	local sc = char and char.scale or 1
	if char and ply:GetJAwakened() and char.awakening and char.awakening.scale then sc = char.awakening.scale end
	if ply.jjs_scale == sc and ply:GetModelScale() == sc then return end
	ply.jjs_scale = sc
	if SERVER then ply:SetModelScale( sc, 0 ) end
	ply:SetHull( Vector( -16, -16, 0 ) * sc, Vector( 16, 16, 72 ) * sc )
	ply:SetHullDuck( Vector( -16, -16, 0 ) * sc, Vector( 16, 16, 36 ) * sc )
	ply:SetViewOffset( Vector( 0, 0, 64 ) * sc )
	ply:SetViewOffsetDucked( Vector( 0, 0, 28 ) * sc )
	ply:SetStepSize( 18 * sc )
end
