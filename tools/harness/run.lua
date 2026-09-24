-- Loads the translated JJS gamemode on the mock and exercises every character's moves.
-- Usage: REALM=server|client lua5.3 run.lua <translated gamemode dir> [character id]

local ROOTDIR = arg[ 1 ]
local ONLY = arg[ 2 ]
package.path = package.path .. ";" .. ( debug.getinfo( 1 ).source:match( "@(.*/)" ) or "./" ) .. "?.lua"
dofile( ( debug.getinfo( 1 ).source:match( "@(.*/)" ) or "./" ) .. "mock.lua" )

local EFFECTS = {}
effects.Register = function( t, name ) EFFECTS[ name ] = t end

local failures = {}
local function Fail( where, err )
	local key = where .. ": " .. tostring( err )
	if not failures[ key ] then
		failures[ key ] = true
		failures[ #failures + 1 ] = key
		io.stderr:write( "FAIL ", key, "\n" )
	end
end

-- file system over the translated tree
local function Exists( path )
	local f = io.open( path, "r" )
	if f then f:close() return true end
	return false
end
local function ListDir( dir, dirsOnly )
	local p = io.popen( "ls -1 '" .. dir .. "' 2>/dev/null" )
	local out = {}
	for line in p:lines() do
		local isDir = os.execute( "test -d '" .. dir .. "/" .. line .. "'" )
		if ( dirsOnly and isDir ) or ( not dirsOnly and not isDir ) then out[ #out + 1 ] = line end
	end
	p:close()
	return out
end
-- paths look like "jjs/gamemode/..."
local function Local( p ) return ROOTDIR .. "/" .. ( p:gsub( "^jjs/gamemode/", "" ):gsub( "^jjs/", "" ) ) end
MOCK.FileExists = function( p ) return Exists( Local( p ) ) end
MOCK.FileFind = function( p )
	local dir, pat = p:match( "^(.*)/([^/]*)$" )
	local d = Local( dir )
	if pat == "*" then return ListDir( d, false ), ListDir( d, true ) end
	local ext = pat:match( "%*(%..+)$" )
	local files = {}
	for _, f in ipairs( ListDir( d, false ) ) do if not ext or f:sub( -#ext ) == ext then files[ #files + 1 ] = f end end
	return files, {}
end

local currentDir = {}
function include( p )
	local path
	if Exists( Local( p ) ) then path = Local( p ) else path = ROOTDIR .. "/" .. p end
	local chunk, err = loadfile( path )
	if not chunk then Fail( "load " .. p, err ) return end
	local ok, e = xpcall( chunk, debug.traceback )
	if not ok then Fail( "run " .. p, e ) end
end

-- base gamemode
local BASE = {}
function BASE:CalcMainActivity( ply, vel ) return ACT_MP_STAND_IDLE, -1 end
function BASE:UpdateAnimation() end
function BASE:CalcView( ply, o, a, f ) return { origin = o, angles = a, fov = f } end
function DeriveGamemode() GM.BaseClass = BASE end
GM = { FolderName = "jjs", BaseClass = BASE }
GAMEMODE = GM

include( SERVER and "init.lua" or "cl_init.lua" )
if not JJS or not JJS.Characters then print( "gamemode failed to load" ) os.exit( 1 ) end
if GM.Initialize then GM:Initialize() end
if GM.InitPostEntity then GM:InitPostEntity() end
hook.Run( "Initialize" )

local chars = {}
for _, id in ipairs( JJS.CharacterOrder ) do chars[ #chars + 1 ] = id end

-- DUMP=1: print every character's moves as tab separated rows and exit
if os.getenv( "DUMP" ) then
	local S = JJS.STUD
	local function row( id, set, slot, ab )
		if not ab then return end
		if ab.spec and ab.spec.kind == "bymode" then
			for i, sub in ipairs( ab.spec ) do
				if istable( sub ) then row( id, set, slot .. "m" .. i, K_BUILT and nil or { name = sub[ 1 ], spec = sub, cooldown = sub.cooldown } ) end
			end
			return
		end
		local sp = ab.spec or {}
		local rg = sp.ragdoll and "yes" or "no"
		print( table.concat( { id, set, tostring( slot ), tostring( ab.name ), sp.kind or "?", tostring( ab.cooldown or "" ), tostring( sp.damage or "" ),
			tostring( sp.block or "normal" ), rg, tostring( sp.bypassRagdoll and "bypass" or "" ), tostring( sp.range or "" ), tostring( sp.window or "" ), tostring( sp.startup or "" ),
			tostring( sp.hits or "" ), sp.again and ( "again:" .. tostring( sp.again[ 1 ] ) ) or "" }, "\t" ) )
	end
	for _, id in ipairs( chars ) do
		local c = JJS.Characters[ id ]
		local function set( name, t )
			if not t then return end
			for slot = 1, 4 do row( id, name, slot, t.abilities and t.abilities[ slot ] ) end
			row( id, name, "R", t.special )
			if t.alt then set( name .. "-alt", t.alt ) end
		end
		set( "base", c )
		set( "awk", c.awakening )
		row( id, "awkmove", "G", c.awakenMove )
	end
	os.exit( 0 )
end
print( string.format( "%s realm: %d characters, %d actions", SERVER and "server" or "client", #chars, #JJS.ActionById ) )

------------------------------------------------------------------------------------------
-- Movement simulation
------------------------------------------------------------------------------------------
local MV = {}
MV.__index = MV
function MV:GetOrigin() return Vector( self.origin ) end
function MV:SetOrigin( v ) self.origin = Vector( v ) end
function MV:GetVelocity() return Vector( self.vel ) end
function MV:SetVelocity( v ) self.vel = Vector( v ) end
function MV:KeyDown( k ) return ( self.buttons & k ) ~= 0 end
function MV:KeyPressed( k ) return ( self.buttons & k ) ~= 0 and ( self.old & k ) == 0 end
function MV:KeyReleased( k ) return ( self.buttons & k ) == 0 and ( self.old & k ) ~= 0 end
function MV:GetButtons() return self.buttons end
function MV:SetButtons( b ) self.buttons = b end
function MV:GetForwardSpeed() return self.fwd end
function MV:SetForwardSpeed( v ) self.fwd = v end
function MV:GetSideSpeed() return self.side end
function MV:SetSideSpeed( v ) self.side = v end
function MV:SetUpSpeed() end
function MV:GetMoveAngles() return Angle( self.ang ) end
function MV:SetMaxSpeed( v ) self.maxspeed = v end
function MV:SetMaxClientSpeed() end
function MV:GetMaxSpeed() return self.maxspeed or 0 end

local CMD = {}
CMD.__index = CMD
function CMD:ClearMovement() self.fwd, self.side = 0, 0 end
function CMD:ClearButtons() self.buttons = 0 end
function CMD:SetViewAngles( a ) self.ang = a end
function CMD:AddKey( k ) self.buttons = self.buttons | k end
function CMD:KeyDown( k ) return ( self.buttons & k ) ~= 0 end
function CMD:SetButtons( b ) self.buttons = b end
function CMD:GetButtons() return self.buttons end
function CMD:SetSideMove( v ) self.side = v end
function CMD:SetForwardMove( v ) self.fwd = v end

local function Tick( input )
	MOCK.tickCount = MOCK.tickCount + 1
	local dt = MOCK.tick
	for _, ply in ipairs( player.GetAll() ) do
		local cmd = setmetatable( { buttons = 0, fwd = 0, side = 0 }, CMD )
		local inp = input and input[ ply ]
		if inp then cmd.buttons, cmd.fwd, cmd.side = inp.buttons or 0, inp.fwd or 0, inp.side or 0 end
		local ok, err = xpcall( function() hook.Call( "StartCommand", GM, ply, cmd ) end, debug.traceback )
		if not ok then Fail( "StartCommand", err ) end

		local mv = setmetatable( { origin = ply:GetPos(), vel = ply:GetVelocity(), buttons = cmd.buttons, old = ply.oldButtons or 0,
			fwd = cmd.fwd, side = cmd.side, ang = ply:EyeAngles() }, MV )
		ok, err = xpcall( function()
			hook.Call( "SetupMove", GM, ply, mv, cmd )
			local owned = hook.Call( "Move", GM, ply, mv )
			if not owned and ply:Alive() and ply:GetMoveType() ~= MOVETYPE_NONE then
				local v = mv:GetVelocity()
				if mv.origin.z > 0 or v.z > 0 then v.z = v.z - JJS.Config.Gravity * dt end
				local o = mv.origin + v * dt
				if o.z <= 0 then o.z = 0 v.z = 0 end
				mv.origin, mv.vel = o, v
			end
			hook.Call( "FinishMove", GM, ply, mv )
		end, debug.traceback )
		if not ok then Fail( "move " .. ply:GetJChar(), err ) end
		if ply:GetMoveType() ~= MOVETYPE_NONE then
			ply.pos, ply.vel = mv.origin, mv.vel
		end
		ply.onGround = ply.pos.z <= 0.5
		ply.oldButtons = mv.buttons
	end
	local ok, err = xpcall( function()
		hook.Run( "Tick" )
		hook.Run( "Think" )
		MOCK.ThinkEntities()
		MOCK.RunTimers()
	end, debug.traceback )
	if not ok then Fail( "tick", err ) end
	MOCK.time = MOCK.time + dt
end

local function Run( seconds, input )
	for _ = 1, math.floor( seconds / MOCK.tick ) do Tick( input ) end
end

------------------------------------------------------------------------------------------
-- Scenarios
------------------------------------------------------------------------------------------
if SERVER then
	local hits = {}
	hook.Add( "JJS_Hit", "harness", function( victim, hit, res )
		local a = hit.attacker
		if IsValid( a ) then hits[ a ] = ( hits[ a ] or 0 ) + 1 end
	end )

	local A = MOCK.NewPlayer( "Attacker", false )
	local B = MOCK.NewPlayer( "Victim", true )
	A:SetJChar( JJS.Config.DefaultCharacter )
	B:SetJChar( JJS.Config.DefaultCharacter )
	A:Spawn()
	B:Spawn()

	local KEYS = { JJS.AbilityKeys[ 1 ], JJS.AbilityKeys[ 2 ], JJS.AbilityKeys[ 3 ], JJS.AbilityKeys[ 4 ], JJS.IN.SPECIAL }

	-- remember which actions A started (to see which variant ran)
	local StartAction = JJS.StartAction
	JJS.StartAction = function( ply, name, ... )
		if ply == A and A.jjs_acts then
			local short = string.match( name, "[^.]+%.[^.]+(.*)$" ) or name
			A.jjs_acts[ #A.jjs_acts + 1 ] = short ~= "" and short or "base"
		end
		return StartAction( ply, name, ... )
	end

	local function Reset()
		for _, p in ipairs( { A, B } ) do
			if not p:Alive() then p:Spawn() end
			if p:GetJRagdolled() then JJS.Ragdoll.Stop( p, "test" ) end
			JJS.StopAction( p, true )
			p:SetJStunEnd( 0 )
			p:SetJEndlagEnd( 0 )
			p:SetJIFrameEnd( 0 )
			p:SetJDashType( 0 )
			p:SetLocalVelocity( Vector() )
			JJS.Heal( p, 1000 )
			JJS.ClearCooldowns( p )
		end
		A:SetPos( Vector( 0, 0, 0 ) )
		A:SetEyeAngles( Angle( 0, 0, 0 ) )
		B:SetPos( Vector( 70, 0, 0 ) )
		B:SetEyeAngles( Angle( 0, 180, 0 ) )
		for _, d in ipairs( ents.FindByClass( "jjs_domain" ) ) do d:Remove() end
		for _, d in ipairs( ents.FindByClass( "jjs_projectile" ) ) do d:Remove() end
		for k in pairs( JJS.Kit.Zones ) do JJS.Kit.Zones[ k ] = nil end
		for k in pairs( JJS.Kit.Detached ) do JJS.Kit.Detached[ k ] = nil end
		A:SetNW2Entity( "JJSDomain", NULL )
		B:SetNW2Entity( "JJSDomain", NULL )
		Run( 0.1 )
	end

	local function Press( key, hold, extra, fwd )
		local n = math.max( 1, math.floor( ( hold or 0.03 ) / MOCK.tick ) )
		for _ = 1, n do Tick( { [ A ] = { buttons = key | ( extra or 0 ), fwd = fwd or 0 } } ) end
	end

	local report = {}
	local function TrySlot( label, slot, opts )
		opts = opts or {}
		Reset()
		if opts.setup then opts.setup() end
		local ab = JJS.GetAbility( A, slot )
		if not ab then return end
		local before = hits[ A ] or 0
		A.jjs_acts = {}
		if opts.air then A:SetPos( Vector( 0, 0, 150 ) ) A.onGround = false end
		if opts.highAir then A:SetPos( Vector( 0, 0, 400 ) ) A.onGround = false end
		if opts.airTarget then B:SetPos( Vector( 70, 0, 120 ) ) B.onGround = false end
		if opts.ragdolled then JJS.Ragdoll.Apply( B, { time = 3 } ) Run( 0.3 ) end
		-- aim at the target like a player would
		A:SetEyeAngles( ( B:GetPos() + Vector( 0, 0, 40 ) - A:EyePos() ):Angle() )
		Press( KEYS[ opts.feint or slot ], opts.hold, nil, opts.back and -400 )
		if opts.again then Run( 0.15 ) Press( KEYS[ slot ] ) end
		if opts.again2 then Run( 0.3 ) Press( KEYS[ slot ] ) end
		if opts.feint then Run( 0.05 ) Press( KEYS[ slot ] ) end
		if opts.special then Run( 0.05 ) Press( JJS.IN.SPECIAL ) end
		if opts.combo then Run( math.max( 0.05, ( ab.spec.comboFrom or 0 ) + 0.05 ) ) Press( KEYS[ opts.combo ] ) end
		if opts.after then Run( opts.after ) Press( JJS.IN.SPECIAL ) end
		Run( opts.time or 3 )
		local n = ( hits[ A ] or 0 ) - before
		report[ #report + 1 ] = string.format( "  %-13s %d %-34s hits=%d %s", label, slot, ab.name, n, table.concat( A.jjs_acts or {}, "," ) )
	end

	for _, id in ipairs( chars ) do
		if ONLY and id ~= ONLY then goto next end
		A:SetJChar( id )
		A:SetJAwaken( 0 )
		A:Spawn()
		report[ #report + 1 ] = id
		for slot = 1, 5 do
			TrySlot( "base", slot )
			local ab = JJS.GetAbility( A, slot )
			if ab and ab.spec and ab.spec.hold then TrySlot( "hold", slot, { hold = ( ab.spec.hold.time or 1 ) + 0.1 } ) end
			if ab and ab.spec and ab.spec.air then TrySlot( "air", slot, { air = true } ) end
			if ab and ab.again then TrySlot( "again", slot, { again = true } ) end
			local V = ab and ab.variants or {}
			if V.back then TrySlot( "back", slot, { back = true } ) end
			if V.airTarget then TrySlot( "airTarget", slot, { airTarget = true } ) end
			if V.ragdolled then TrySlot( "ragdolled", slot, { ragdolled = true } ) end
			if V.special then TrySlot( "special", slot, { special = true } ) end
			if V.highAir then TrySlot( "highAir", slot, { highAir = true } ) end
			if ab and ab.specialAfter then TrySlot( "after", slot, { after = 1.2 } ) end
			-- each conditional variant in turn (the others forced off)
			for i, c in ipairs( V.conds or {} ) do
				local saved = {}
				for j, o in ipairs( V.conds ) do saved[ j ] = o.test o.test = function() return j == i end end
				TrySlot( "cond" .. ( i > 1 and i or "" ), slot, {} )
				for j, o in ipairs( V.conds ) do o.test = saved[ j ] end
			end
			for cs in pairs( ab and ab.spec and ab.spec.combo or {} ) do TrySlot( "combo" .. cs, slot, { combo = cs } ) end
			if ab and ab.again and ab.again.again then TrySlot( "again2", slot, { again = true, again2 = true } ) end
			if ab and ab.spec and ab.spec.feints then TrySlot( "feint", slot, { feint = slot == 1 and 2 or 1 } ) end
		end
		-- alternate set
		local char = JJS.Characters[ id ]
		if char.alt then
			for slot = 1, 5 do TrySlot( "alt", slot, { setup = function() A:SetJKitSet( 1 ) end } ) end
			A:SetJKitSet( 0 )
		end
		-- modes
		for mode = 1, 2 do
			for slot = 1, 5 do
				local ab = JJS.GetAbility( A, slot )
				if ab and ab.spec and ab.spec.kind == "bymode" then
					TrySlot( "mode" .. mode, slot, { setup = function() A:SetJMode( mode ) end } )
				end
			end
		end
		A:SetJMode( 0 )
		-- awakening
		Reset()
		A:SetJAwaken( 1 )
		if id == "truecannon" then A:SetJRes1( 0.85 ) end
		if id == "puppetmaster" then A:SetNW2Float( "JJSReserve", 1 ) end
		local beforeAwk = hits[ A ] or 0
		Press( JJS.IN.AWAKEN )
		Run( 5 )
		report[ #report + 1 ] = string.format( "  awaken: awakened=%s hits=%d", tostring( A:GetJAwakened() ), ( hits[ A ] or 0 ) - beforeAwk )
		-- conditional awakenings (Vengeance...): still exercise the awakened moves
		if not A:GetJAwakened() and char.awakening and char.awakening.abilities then JJS.EnterAwakening( A ) end
		if A:GetJAwakened() then
			for slot = 1, 5 do
				TrySlot( "awk", slot, { setup = function() end } )
				local ab = JJS.GetAbility( A, slot )
				if ab and ab.spec and ab.spec.hold then TrySlot( "awk-hold", slot, { hold = ( ab.spec.hold.time or 1 ) + 0.1 } ) end
				if ab and ab.spec and ab.spec.air then TrySlot( "awk-air", slot, { air = true } ) end
				if ab and ab.again then TrySlot( "awk-again", slot, { again = true } ) end
				local V = ab and ab.variants or {}
				if V.back then TrySlot( "awk-back", slot, { back = true } ) end
				if V.airTarget then TrySlot( "awk-airTarget", slot, { airTarget = true } ) end
				if V.ragdolled then TrySlot( "awk-ragdolled", slot, { ragdolled = true } ) end
				if V.special then TrySlot( "awk-special", slot, { special = true } ) end
				if V.highAir then TrySlot( "awk-highAir", slot, { highAir = true } ) end
				if ab and ab.specialAfter then TrySlot( "awk-after", slot, { after = 1.2 } ) end
				-- each conditional variant in turn (the others forced off)
				for i, c in ipairs( V.conds or {} ) do
					local saved = {}
					for j, o in ipairs( V.conds ) do saved[ j ] = o.test o.test = function() return j == i end end
					TrySlot( "awk-cond" .. ( i > 1 and i or "" ), slot, {} )
					for j, o in ipairs( V.conds ) do o.test = saved[ j ] end
				end
				for cs in pairs( ab and ab.spec and ab.spec.combo or {} ) do TrySlot( "awk-combo" .. cs, slot, { combo = cs } ) end
				if ab and ab.again and ab.again.again then TrySlot( "awk-again2", slot, { again = true, again2 = true } ) end
			end
			if char.awakening and char.awakening.alt then
				for slot = 1, 5 do TrySlot( "awk-alt", slot, { setup = function() A:SetJKitSet( 1 ) end } ) end
			end
			JJS.ExitAwakening( A )
		end
		-- M1 string + dashes
		Reset()
		for _ = 1, 5 do Press( JJS.IN.M1, 0.4 ) end
		Reset()
		Press( JJS.IN.DASH )
		Run( 1 )
		::next::
	end

	-- beam clash and domain clash smoke tests
	local function FindBeam()
		for _, id in ipairs( chars ) do
			local c = JJS.Characters[ id ]
			for _, set in ipairs( { c, c.awakening } ) do
				for slot, ab in pairs( set and set.abilities or {} ) do
					if ab.spec and ab.spec.clash then return id, set == c.awakening, slot end
				end
			end
		end
	end
	local id, awk, slot = FindBeam()
	if id and not ONLY then
		Reset()
		for _, p in ipairs( { A, B } ) do
			p:SetJChar( id ) p:Spawn()
			if awk then JJS.EnterAwakening( p ) end
		end
		Reset()
		for _ = 1, 3 do
			Tick( { [ A ] = { buttons = KEYS[ slot ] }, [ B ] = { buttons = KEYS[ slot ] } } )
		end
		Run( 1.2 )
		report[ #report + 1 ] = "beam clash: foe=" .. tostring( A:GetNW2Entity( "JJSClashFoe" ).name )
		for i = 1, 60 do
			local k = JJS.Config.BeamClash.Keys[ A:GetNW2Int( "JJSClashKey" ) ] or 0
			Tick( { [ A ] = { buttons = ( i % 2 == 0 ) and k or 0 } } )
		end
		Run( 4 )
		report[ #report + 1 ] = "beam clash done, A score " .. A:GetNW2Int( "JJSClashScore" )
	end

	-- domains: sure-hit damage, barrier, domain clash
	if not ONLY then
		A:SetJChar( "vessel" ) A:Spawn()
		B:SetJChar( "honoredone" ) B:Spawn()
		Reset()
		JJS.EnterAwakening( A )
		JJS.EnterAwakening( B )
		Reset()
		local hp0 = B:GetJHP()
		Press( KEYS[ 4 ] )
		Run( 3 )
		local d = ents.FindByClass( "jjs_domain" )[ 1 ]
		report[ #report + 1 ] = string.format( "domain: %s, B caught=%s, B hp %.1f -> %.1f", d and d:GetDomainName() or "none",
			tostring( B:GetNW2Entity( "JJSDomain" ) == d ), hp0, B:GetJHP() )
		-- B walks outward for 3s: the barrier should keep them inside
		Run( 3, { [ B ] = { buttons = IN_FORWARD, fwd = 400 } } )
		for _ = 1, 200 do
			B:SetPos( B:GetPos() + Vector( 20, 0, 0 ) )
			Tick()
		end
		report[ #report + 1 ] = string.format( "barrier: B distance from centre %.0f (radius %.0f)", d and B:GetPos():Distance( d:GetPos() ) or -1, d and d:GetRadius() or -1 )
		-- clash: both cast at once
		Reset()
		JJS.EnterAwakening( A )
		JJS.EnterAwakening( B )
		Reset()
		for _ = 1, 3 do Tick( { [ A ] = { buttons = KEYS[ 4 ] }, [ B ] = { buttons = KEYS[ 4 ] } } ) end
		Run( 2 )
		local ds = ents.FindByClass( "jjs_domain" )
		local clashing = 0
		for _, x in ipairs( ds ) do if x:InClash() then clashing = clashing + 1 end end
		report[ #report + 1 ] = string.format( "domain clash: %d domains, %d clashing", #ds, clashing )
		Run( 16 )
		report[ #report + 1 ] = string.format( "after clash: %d domains left", #ents.FindByClass( "jjs_domain" ) )
		JJS.ExitAwakening( A ) JJS.ExitAwakening( B )
	end

	-- EXTRA=file.lua: an ad-hoc scenario run with the harness helpers in scope
	if os.getenv( "EXTRA" ) then
		local env = setmetatable( { A = A, B = B, Press = Press, Run = Run, Reset = Reset, KEYS = KEYS, report = report, Tick = Tick,
			hits = hits }, { __index = _G } )
		local f = assert( loadfile( os.getenv( "EXTRA" ), "t", env ) )
		local ok, err = xpcall( f, debug.traceback )
		if not ok then Fail( "extra", err ) end
	end

	-- parries: B starts a move with a parry window and A's M1 lands in it
	for _, id in ipairs( chars ) do
		if ONLY and id ~= ONLY then goto nextParry end
		for _, set in ipairs( { JJS.Characters[ id ], JJS.Characters[ id ].alt } ) do
			for slot, ab in pairs( set.abilities or {} ) do
				if ab.spec and ab.spec.parry then
					A:SetJChar( JJS.Config.DefaultCharacter ) A:Spawn()
					B:SetJChar( id ) B:Spawn()
					Reset()
					if set ~= JJS.Characters[ id ] then B:SetJKitSet( 1 ) end
					local hp0 = B:GetJHP()
					-- A's M1 is on its way (12f startup) when B starts the move
					A:SetPos( Vector( 40, 0, 0 ) )
					Tick( { [ A ] = { buttons = JJS.IN.M1 } } )
					Run( 0.1 )
					Tick( { [ B ] = { buttons = KEYS[ slot ] } } )
					Run( 0.3 )
					report[ #report + 1 ] = string.format( "parry %s %s: A stunned=%s, B hp %.1f -> %.1f", id, ab.name,
						tostring( JJS.IsStunned( A ) ), hp0, B:GetJHP() )
					B:SetJKitSet( 0 )
				end
			end
		end
		::nextParry::
	end
	B:SetJChar( JJS.Config.DefaultCharacter ) B:Spawn()

	-- dummies
	Reset()
	for _, kind in ipairs( { "normal", "lowhp", "immortal", "attack", "block", "evasive", "bullet", "counter" } ) do
		concommand.cmds[ "jjs_dummy" ]( A, "jjs_dummy", { kind } )
	end
	Run( 3 )
	concommand.cmds[ "jjs_dummy_clear" ]( A )
	concommand.cmds[ "jjs_char" ]( A, "jjs_char", {} )

	print( table.concat( report, "\n" ) )
else
	-- client: HUD, overhead, effects, entity drawing for every character in both states
	local me = MOCK.NewPlayer( "Me", false )
	MOCK.localPlayer = me
	local other = MOCK.NewPlayer( "Other", true )
	for _, p in ipairs( { me, other } ) do p.alive = true p:SetJHP( 100 ) end
	for _, id in ipairs( chars ) do
		me:SetJChar( id )
		for _, st in ipairs( { false, true } ) do
			me:SetJAwakened( st )
			me:SetJAwaken( st and 0.5 or 1 )
			for set = 0, 1 do
				me:SetJKitSet( set )
				local ok, err = xpcall( function()
					GM:HUDPaint()
					hook.Run( "PostDrawTranslucentRenderables", false, false )
					hook.Run( "Think" )
					GM:CalcView( me, Vector(), Angle(), 70 )
				end, debug.traceback )
				if not ok then Fail( "hud " .. id, err ) end
			end
		end
	end
	for name, E in pairs( EFFECTS ) do
		local ok, err = xpcall( function()
			local e = setmetatable( {}, { __index = function( t, k ) return E[ k ] or MOCK.ENTITY[ k ] end } )
			local d = EffectData()
			d:SetOrigin( Vector( 0, 0, 10 ) ) d:SetNormal( Vector( 1, 0, 0 ) ) d:SetScale( 100 ) d:SetFlags( 1 ) d:SetEntity( me ) d:SetMagnitude( 1 ) d:SetStart( Vector() )
			e:Init( d )
			if e.Think then e:Think() end
			if e.Render then e:Render() end
		end, debug.traceback )
		if not ok then Fail( "effect " .. name, err ) end
	end
	for _, class in ipairs( { "jjs_projectile", "jjs_domain" } ) do
		local ok, err = xpcall( function()
			local e = ents.Create( class )
			e:Spawn()
			if e.SetRadius then e:SetRadius( 100 ) end
			if e.DrawTranslucent then e:DrawTranslucent() end
		end, debug.traceback )
		if not ok then Fail( "ent " .. class, err ) end
	end
	local ok, err = xpcall( function() JJS.OpenCharacterMenu() end, debug.traceback )
	if not ok then Fail( "menu", err ) end
	print( "client checks done" )
end

print( string.format( "%d unique failures", #failures ) )
os.exit( #failures == 0 and 0 or 1 )
