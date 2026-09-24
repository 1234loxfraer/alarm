-- Input: our actions ride on usercmd button bits the engine doesn't use for movement,
-- so they are predicted and reach the server like normal keys. Keys are read directly
-- (rebindable through convars) instead of relying on the player's GMod binds.

JJS.IN = {
	M1 = IN_ATTACK,
	BLOCK = IN_GRENADE2,
	DASH = IN_GRENADE1,
	SPECIAL = IN_BULLRUSH,
	AWAKEN = IN_CANCEL,
	RUN = IN_SPEED,
}
JJS.AbilityKeys = { IN_ALT1, IN_ALT2, IN_WEAPON1, IN_WEAPON2 }

local ACTION_BITS = bit.bor( IN_ATTACK, IN_ATTACK2, IN_GRENADE1, IN_GRENADE2, IN_BULLRUSH, IN_CANCEL,
	IN_ALT1, IN_ALT2, IN_WEAPON1, IN_WEAPON2, IN_SPEED, IN_DUCK, IN_WALK, IN_ZOOM, IN_RELOAD, IN_RUN )

if SERVER then return end

local function Bind( name, default, help )
	return CreateClientConVar( "jjs_key_" .. name, tostring( default ), true, false, help )
end

JJS.Binds = {
	m1 = Bind( "m1", MOUSE_LEFT, "M1 (basic attack)" ),
	block = Bind( "block", KEY_F, "Block" ),
	dash = Bind( "dash", KEY_Q, "Dash" ),
	a1 = Bind( "a1", KEY_1, "Move 1" ),
	a2 = Bind( "a2", KEY_2, "Move 2" ),
	a3 = Bind( "a3", KEY_3, "Move 3" ),
	a4 = Bind( "a4", KEY_4, "Move 4" ),
	special = Bind( "special", KEY_R, "Special" ),
	awaken = Bind( "awaken", KEY_G, "Awakening" ),
	shiftlock = Bind( "shiftlock", KEY_LSHIFT, "Toggle shift-lock" ),
	zoomin = Bind( "zoomin", KEY_I, "Zoom in" ),
	zoomout = Bind( "zoomout", KEY_O, "Zoom out" ),
}

local cvAutoRun = CreateClientConVar( "jjs_autorun", "0", true, false, "Run without double tapping W" )
local cvShiftLock = CreateClientConVar( "jjs_shiftlock", "1", true, true, "Character faces the camera" )

local function Down( cv )
	local k = cv:GetInt()
	return k > 0 and input.IsButtonDown( k )
end

function JJS.InputBlocked()
	local ply = LocalPlayer()
	return gui.IsGameUIVisible() or gui.IsConsoleVisible() or vgui.GetKeyboardFocus() ~= nil
		or ( IsValid( ply ) and ply:IsTyping() ) or vgui.CursorVisible()
end

local running, lastTap, fwdWas = false, 0, false

hook.Add( "CreateMove", "JJS_Input", function( cmd )
	cmd:SetButtons( bit.band( cmd:GetButtons(), bit.bnot( ACTION_BITS ) ) )

	local fwd = cmd:KeyDown( IN_FORWARD )
	if fwd and not fwdWas then
		if RealTime() - lastTap < JJS.Config.RunTapWindow then running = true end
		lastTap = RealTime()
	end
	fwdWas = fwd
	if not fwd then running = false end
	if fwd and cvAutoRun:GetBool() then running = true end
	if running then cmd:AddKey( IN_SPEED ) end

	if JJS.AutoTestInput and JJS.AutoTestInput( cmd ) then return end
	if JJS.InputBlocked() then return end

	local B = JJS.Binds
	if Down( B.m1 ) then cmd:AddKey( JJS.IN.M1 ) end
	if Down( B.block ) then cmd:AddKey( JJS.IN.BLOCK ) end
	if Down( B.dash ) then cmd:AddKey( JJS.IN.DASH ) end
	if Down( B.special ) then cmd:AddKey( JJS.IN.SPECIAL ) end
	if Down( B.awaken ) then cmd:AddKey( JJS.IN.AWAKEN ) end
	if Down( B.a1 ) then cmd:AddKey( JJS.AbilityKeys[ 1 ] ) end
	if Down( B.a2 ) then cmd:AddKey( JJS.AbilityKeys[ 2 ] ) end
	if Down( B.a3 ) then cmd:AddKey( JJS.AbilityKeys[ 3 ] ) end
	if Down( B.a4 ) then cmd:AddKey( JJS.AbilityKeys[ 4 ] ) end
end )

-- Toggle keys (shift-lock, zoom) are edge triggered on the client
local wasDown = {}
local function Pressed( name )
	local d = Down( JJS.Binds[ name ] )
	local p = d and not wasDown[ name ]
	wasDown[ name ] = d
	return p
end

hook.Add( "Think", "JJS_InputToggles", function()
	if JJS.InputBlocked() then
		wasDown = {}
		return
	end
	if Pressed( "shiftlock" ) then
		RunConsoleCommand( "jjs_shiftlock", cvShiftLock:GetBool() and "0" or "1" )
	end
	if Pressed( "zoomin" ) then JJS.Zoom( -1 ) end
	if Pressed( "zoomout" ) then JJS.Zoom( 1 ) end
end )

-- Swallow default GMod binds that collide with JJS keys
local BLOCKED_BINDS = {
	[ "slot1" ] = true, [ "slot2" ] = true, [ "slot3" ] = true, [ "slot4" ] = true, [ "slot5" ] = true, [ "slot6" ] = true,
	[ "+menu" ] = true, [ "+menu_context" ] = true, [ "impulse 100" ] = true, [ "+reload" ] = true,
	[ "+zoom" ] = true, [ "lastinv" ] = true, [ "+attack2" ] = true,
}

hook.Add( "PlayerBindPress", "JJS_Binds", function( ply, bind, pressed )
	if bind == "invprev" then
		if pressed then JJS.Zoom( -1 ) end
		return true
	elseif bind == "invnext" then
		if pressed then JJS.Zoom( 1 ) end
		return true
	end
	if BLOCKED_BINDS[ bind ] then return true end
end )
