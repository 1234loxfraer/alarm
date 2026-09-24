-- Actions: timed, predicted player activities (M1s, moves, recoveries).
--
-- JJS.RegisterAction( name, def ):
--   dur          number or function(ply, var) -> seconds the action locks the player
--   moveMult     speed multiplier while active (number or function(ply, t)); default 0.35
--   noJump       block jumping
--   dashCancel   side dash may cancel the action while t < this (number or function(ply, var))
--   uninterruptible  getting hit doesn't stop it
--   armor        table of JJS.DMG types that don't stun/interrupt ( { all = true } for total armor )
--   counter      function(victim, attacker, hit) -> result string if the hit was countered/evaded
--   onHurt       function(ply, hit) -> true to keep the action running when hit
--   events       { { time or function(ply,var), function(ply, t, var) }, ... } run once, in order
--   start / think(ply, t, mv, var) / move(ply, mv, t, var) -> true to own movement / finish(ply, var, interrupted)
--   gesture      sequence name or function(ply, var) -> name, played as an upper-body gesture
--   seq          sequence name or function(ply, var) -> name, played full-body (cycle follows time)

JJS.Actions = JJS.Actions or {}
JJS.ActionById = JJS.ActionById or {}

function JJS.RegisterAction( name, def )
	local old = JJS.Actions[ name ]
	def.name = name
	def.id = old and old.id or ( #JJS.ActionById + 1 )
	if def.events then
		table.sort( def.events, function( a, b )
			local ta, tb = a[ 1 ], b[ 1 ]
			return ( isnumber( ta ) and ta or 0 ) < ( isnumber( tb ) and tb or 0 )
		end )
	end
	JJS.Actions[ name ] = def
	JJS.ActionById[ def.id ] = def
	return def
end

function JJS.GetAction( ply )
	local id = ply:GetJActId()
	return id ~= 0 and JJS.ActionById[ id ] or nil
end

function JJS.ActionTime( ply )
	return CurTime() - ply:GetJActStart()
end

local function Resolve( v, ply, var )
	if isfunction( v ) then return v( ply, var ) end
	return v
end
JJS.Resolve = Resolve

function JJS.StartAction( ply, name, var, target, dur )
	local def = JJS.Actions[ name ]
	if not def then
		ErrorNoHalt( "JJS: unknown action " .. tostring( name ) .. "\n" )
		return
	end
	if JJS.GetAction( ply ) then JJS.StopAction( ply, true ) end

	local now = CurTime()
	var = var or 0
	dur = dur or Resolve( def.dur, ply, var ) or 0.5

	ply:SetJActId( def.id )
	ply:SetJActStart( now )
	ply:SetJActEnd( now + dur )
	ply:SetJActVar( var )
	ply:SetJActTarget( target or NULL )
	ply.jjs_evStart = now
	ply.jjs_evIdx = 1

	if def.start then def.start( ply, var, target ) end
	return def
end

function JJS.StopAction( ply, interrupted )
	local def = JJS.GetAction( ply )
	if not def then return end
	local var = ply:GetJActVar()
	ply:SetJActId( 0 )
	if def.finish then def.finish( ply, var, interrupted ) end
end

-- Returns true if the action was stopped
function JJS.InterruptAction( ply, hit )
	local def = JJS.GetAction( ply )
	if not def then return false end
	if def.uninterruptible then return false end
	if hit and def.armor and ( def.armor.all or def.armor[ hit.type ] ) then return false end
	JJS.StopAction( ply, true )
	return true
end

function JJS.ExtendAction( ply, seconds )
	ply:SetJActEnd( ply:GetJActEnd() + seconds )
end

function JJS.GetMoveMult( ply )
	local def = JJS.GetAction( ply )
	if not def then return 1 end
	local m = def.moveMult
	if isfunction( m ) then m = m( ply, JJS.ActionTime( ply ) ) end
	return m or 0.35
end

-- Runs events/think; called from FinishMove (predicted) for the acting player
function JJS.TickAction( ply, mv )
	local def = JJS.GetAction( ply )
	if not def then return end

	local now = CurTime()
	local start = ply:GetJActStart()
	local t = now - start
	local var = ply:GetJActVar()

	if ply.jjs_evStart ~= start then
		ply.jjs_evStart = start
		ply.jjs_evIdx = 1
	end

	local evs = def.events
	if evs then
		while ply.jjs_evIdx <= #evs do
			local ev = evs[ ply.jjs_evIdx ]
			if t < Resolve( ev[ 1 ], ply, var ) then break end
			ply.jjs_evIdx = ply.jjs_evIdx + 1
			ev[ 2 ]( ply, t, var )
			if JJS.GetAction( ply ) ~= def or ply:GetJActStart() ~= start then return end
		end
	end

	if def.think then
		def.think( ply, t, mv, var )
		if JJS.GetAction( ply ) ~= def or ply:GetJActStart() ~= start then return end
	end

	if now >= ply:GetJActEnd() then
		JJS.StopAction( ply, false )
	end
end
