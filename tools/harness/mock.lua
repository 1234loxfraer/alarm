-- Minimal Garry's Mod API mock for running the JJS gamemode headless (Lua 5.3).
-- Geometry is real (vectors/angles); world traces never hit; rendering is a no-op sink.

local REALM = os.getenv( "REALM" ) or "server"
SERVER = REALM == "server"
CLIENT = not SERVER

local unpack = table.unpack
_G.unpack = unpack

------------------------------------------------------------------------------------------
-- Sink: any unknown field/call returns itself (rendering libs, vgui...)
------------------------------------------------------------------------------------------
local Sink
local sinkMT = {}
sinkMT.__index = function( t, k ) return Sink end
sinkMT.__call = function() return Sink end
sinkMT.__newindex = function() end
sinkMT.__add = function() return 0 end
sinkMT.__sub = function() return 0 end
sinkMT.__mul = function() return 0 end
sinkMT.__div = function() return 0 end
sinkMT.__unm = function() return 0 end
sinkMT.__lt = function() return false end
sinkMT.__le = function() return false end
sinkMT.__concat = function() return "" end
sinkMT.__len = function() return 0 end
Sink = setmetatable( {}, sinkMT )

------------------------------------------------------------------------------------------
-- Math helpers
------------------------------------------------------------------------------------------
function math.Clamp( v, a, b ) return math.min( math.max( v, a ), b ) end
function math.Round( v, d ) local m = 10 ^ ( d or 0 ) return math.floor( v * m + 0.5 ) / m end
function math.Rand( a, b ) return a + ( b - a ) * math.random() end
function math.Approach( c, t, inc ) if c < t then return math.min( c + inc, t ) end return math.max( c - inc, t ) end
function math.NormalizeAngle( a ) a = ( a + 180 ) % 360 - 180 return a end
function math.ApproachAngle( c, t, inc ) local d = math.NormalizeAngle( t - c ) return c + math.Clamp( d, -inc, inc ) end
function math.AngleDifference( a, b ) return math.NormalizeAngle( a - b ) end
math.huge = math.huge
math.pow = function( a, b ) return a ^ b end
function Lerp( t, a, b ) return a + ( b - a ) * t end

------------------------------------------------------------------------------------------
-- Vector / Angle
------------------------------------------------------------------------------------------
local VEC = {}
VEC.__index = VEC
local ANG = {}
ANG.__index = ANG

function Vector( x, y, z )
	if type( x ) == "table" then return setmetatable( { x = x.x, y = x.y, z = x.z }, VEC ) end
	return setmetatable( { x = x or 0, y = y or 0, z = z or 0 }, VEC )
end
local function isvec( v ) return getmetatable( v ) == VEC end
VEC.__add = function( a, b ) return Vector( a.x + b.x, a.y + b.y, a.z + b.z ) end
VEC.__sub = function( a, b ) return Vector( a.x - b.x, a.y - b.y, a.z - b.z ) end
VEC.__mul = function( a, b )
	if type( a ) == "number" then a, b = b, a end
	if type( b ) == "number" then return Vector( a.x * b, a.y * b, a.z * b ) end
	return Vector( a.x * b.x, a.y * b.y, a.z * b.z )
end
VEC.__div = function( a, b ) return Vector( a.x / b, a.y / b, a.z / b ) end
VEC.__unm = function( a ) return Vector( -a.x, -a.y, -a.z ) end
VEC.__eq = function( a, b ) return a.x == b.x and a.y == b.y and a.z == b.z end
VEC.__tostring = function( a ) return string.format( "%.2f %.2f %.2f", a.x, a.y, a.z ) end
function VEC:Length() return math.sqrt( self.x ^ 2 + self.y ^ 2 + self.z ^ 2 ) end
function VEC:LengthSqr() return self.x ^ 2 + self.y ^ 2 + self.z ^ 2 end
function VEC:Length2D() return math.sqrt( self.x ^ 2 + self.y ^ 2 ) end
function VEC:Length2DSqr() return self.x ^ 2 + self.y ^ 2 end
function VEC:Dot( b ) return self.x * b.x + self.y * b.y + self.z * b.z end
function VEC:Cross( b ) return Vector( self.y * b.z - self.z * b.y, self.z * b.x - self.x * b.z, self.x * b.y - self.y * b.x ) end
function VEC:Distance( b ) return ( self - b ):Length() end
function VEC:DistToSqr( b ) return ( self - b ):LengthSqr() end
function VEC:Normalize() local l = self:Length() if l > 0 then self.x, self.y, self.z = self.x / l, self.y / l, self.z / l end end
function VEC:GetNormalized() local v = Vector( self ) v:Normalize() return v end
function VEC:GetNormal() return self:GetNormalized() end
function VEC:Mul( n ) self.x, self.y, self.z = self.x * n, self.y * n, self.z * n end
function VEC:Div( n ) self.x, self.y, self.z = self.x / n, self.y / n, self.z / n end
function VEC:Add( b ) self.x, self.y, self.z = self.x + b.x, self.y + b.y, self.z + b.z end
function VEC:Sub( b ) self.x, self.y, self.z = self.x - b.x, self.y - b.y, self.z - b.z end
function VEC:Set( b ) self.x, self.y, self.z = b.x, b.y, b.z end
function VEC:Zero() self.x, self.y, self.z = 0, 0, 0 end
function VEC:IsZero() return self.x == 0 and self.y == 0 and self.z == 0 end
function VEC:Angle()
	local yaw = math.deg( math.atan( self.y, self.x ) )
	local pitch = -math.deg( math.atan( self.z, math.sqrt( self.x ^ 2 + self.y ^ 2 ) ) )
	return Angle( pitch, yaw, 0 )
end
function VEC:ToScreen() return { x = 0, y = 0, visible = true } end
function VEC:Rotate( a ) local v = a:Forward() * self.x - a:Right() * self.y + a:Up() * self.z self:Set( v ) end

function Angle( p, y, r )
	if type( p ) == "table" then return setmetatable( { p = p.p, y = p.y, r = p.r }, ANG ) end
	return setmetatable( { p = p or 0, y = y or 0, r = r or 0 }, ANG )
end
ANG.__index = function( t, k )
	if k == "pitch" then return rawget( t, "p" ) elseif k == "yaw" then return rawget( t, "y" ) elseif k == "roll" then return rawget( t, "r" ) end
	return ANG[ k ]
end
ANG.__add = function( a, b ) return Angle( a.p + b.p, a.y + b.y, a.r + b.r ) end
ANG.__sub = function( a, b ) return Angle( a.p - b.p, a.y - b.y, a.r - b.r ) end
function ANG:Forward()
	local p, y = math.rad( self.p ), math.rad( self.y )
	return Vector( math.cos( p ) * math.cos( y ), math.cos( p ) * math.sin( y ), -math.sin( p ) )
end
function ANG:Right()
	local y = math.rad( self.y )
	return Vector( math.sin( y ), -math.cos( y ), 0 )
end
function ANG:Up() return self:Right():Cross( self:Forward() ) end
function ANG:RotateAroundAxis( axis, deg ) if axis.z > 0.5 then self.y = self.y + deg end end
function ANG:Normalize() self.y = math.NormalizeAngle( self.y ) end
vector_origin = Vector( 0, 0, 0 )
angle_zero = Angle( 0, 0, 0 )
function VectorRand() return Vector( math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1 ) end
function OrderVectors( a, b )
	for _, k in ipairs( { "x", "y", "z" } ) do if a[ k ] > b[ k ] then a[ k ], b[ k ] = b[ k ], a[ k ] end end
end
function LerpVector( t, a, b ) return a + ( b - a ) * t end

local COL = {}
COL.__index = COL
function Color( r, g, b, a ) return setmetatable( { r = r or 255, g = g or 255, b = b or 255, a = a or 255 }, COL ) end
function ColorAlpha( c, a ) return Color( c.r, c.g, c.b, a ) end
color_white = Color( 255, 255, 255 )
color_black = Color( 0, 0, 0 )
IsColor = function( c ) return getmetatable( c ) == COL end

function isnumber( v ) return type( v ) == "number" end
function isstring( v ) return type( v ) == "string" end
function istable( v ) return type( v ) == "table" end
function isfunction( v ) return type( v ) == "function" end
function isbool( v ) return type( v ) == "boolean" end
function isvector( v ) return isvec( v ) end
function isangle( v ) return getmetatable( v ) == ANG end
function tobool( v ) return v and v ~= 0 and v ~= "0" and v ~= "false" end

------------------------------------------------------------------------------------------
-- string / table helpers
------------------------------------------------------------------------------------------
function string.GetFileFromFilename( p ) return p:match( "([^/]*)$" ) end
function string.Trim( s ) return ( s:gsub( "^%s+", "" ):gsub( "%s+$", "" ) ) end
function string.Split( s, sep ) local t = {} for p in ( s .. sep ):gmatch( "(.-)" .. sep:gsub( "%p", "%%%0" ) ) do t[ #t + 1 ] = p end return t end
string.Explode = function( sep, s ) return string.Split( s, sep ) end
function string.StartWith( s, p ) return s:sub( 1, #p ) == p end
string.StartsWith = string.StartWith
function string.EndsWith( s, p ) return p == "" or s:sub( -#p ) == p end
string.upper = string.upper
function table.Copy( t, seen )
	if type( t ) ~= "table" then return t end
	seen = seen or {}
	if seen[ t ] then return seen[ t ] end
	local c = {}
	seen[ t ] = c
	for k, v in pairs( t ) do
		if type( v ) == "table" and getmetatable( v ) == nil then c[ k ] = table.Copy( v, seen )
		elseif isvec( v ) then c[ k ] = Vector( v )
		elseif getmetatable( v ) == ANG then c[ k ] = Angle( v )
		else c[ k ] = v end
	end
	return setmetatable( c, getmetatable( t ) )
end
function table.Count( t ) local n = 0 for _ in pairs( t ) do n = n + 1 end return n end
function table.HasValue( t, v ) for _, x in pairs( t ) do if x == v then return true end end return false end
function table.Random( t ) local k = {} for _, v in pairs( t ) do k[ #k + 1 ] = v end return k[ math.random( #k ) ] end
function table.GetKeys( t ) local k = {} for x in pairs( t ) do k[ #k + 1 ] = x end return k end
function table.Merge( a, b ) for k, v in pairs( b ) do a[ k ] = v end return a end
function table.Add( a, b ) for _, v in ipairs( b ) do a[ #a + 1 ] = v end return a end
function table.IsEmpty( t ) return next( t ) == nil end
function PrintTable( t ) for k, v in pairs( t ) do print( k, v ) end end
function ErrorNoHalt( ... ) io.stderr:write( "ErrorNoHalt: ", table.concat( { ... }, " " ), "\n" ) MOCK_ERRORS = ( MOCK_ERRORS or 0 ) + 1 end
function MsgN( ... ) end
function Msg( ... ) end

bit = {
	band = function( a, b ) return a & b end,
	bor = function( ... ) local r = 0 for _, v in ipairs( { ... } ) do r = r | v end return r end,
	bnot = function( a ) return ~a end,
	bxor = function( a, b ) return a ~ b end,
	lshift = function( a, n ) return a << n end,
	rshift = function( a, n ) return a >> n end,
}

------------------------------------------------------------------------------------------
-- Time
------------------------------------------------------------------------------------------
MOCK = { time = 10, tick = 1 / 66, tickCount = 0 }
function CurTime() return MOCK.time end
function RealTime() return MOCK.time end
function SysTime() return MOCK.time end
function FrameTime() return MOCK.tick end
function IsFirstTimePredicted() return true end
engine = { TickInterval = function() return MOCK.tick end, TickCount = function() return MOCK.tickCount end, ActiveGamemode = function() return "jjs" end }

------------------------------------------------------------------------------------------
-- Hooks, timers, commands, convars
------------------------------------------------------------------------------------------
hook = { hooks = {} }
function hook.Add( ev, name, fn ) hook.hooks[ ev ] = hook.hooks[ ev ] or {} hook.hooks[ ev ][ name ] = fn end
function hook.Remove( ev, name ) if hook.hooks[ ev ] then hook.hooks[ ev ][ name ] = nil end end
function hook.GetTable() return hook.hooks end
function hook.Call( ev, gm, ... )
	for _, fn in pairs( hook.hooks[ ev ] or {} ) do
		local a, b, c, d = fn( ... )
		if a ~= nil then return a, b, c, d end
	end
	if gm and gm[ ev ] then return gm[ ev ]( gm, ... ) end
end
function hook.Run( ev, ... ) return hook.Call( ev, GAMEMODE, ... ) end

timer = { list = {} }
function timer.Simple( d, fn ) timer.list[ #timer.list + 1 ] = { t = MOCK.time + d, fn = fn } end
function timer.Create( name, d, reps, fn ) end
function timer.Remove() end
function timer.Exists() return false end
function MOCK.RunTimers()
	local due = {}
	for i = #timer.list, 1, -1 do
		if timer.list[ i ].t <= MOCK.time then due[ #due + 1 ] = table.remove( timer.list, i ) end
	end
	for _, t in ipairs( due ) do t.fn() end
end

concommand = { cmds = {} }
function concommand.Add( n, fn ) concommand.cmds[ n ] = fn end
local CVARS = {}
local CV = {}
CV.__index = CV
function CV:GetFloat() return tonumber( self.v ) or 0 end
function CV:GetInt() return math.floor( tonumber( self.v ) or 0 ) end
function CV:GetBool() return ( tonumber( self.v ) or 0 ) ~= 0 end
function CV:GetString() return tostring( self.v ) end
function CreateConVar( n, v ) CVARS[ n ] = CVARS[ n ] or setmetatable( { v = v }, CV ) return CVARS[ n ] end
CreateClientConVar = CreateConVar
function GetConVar( n ) return CVARS[ n ] or CreateConVar( n, "0" ) end
function RunConsoleCommand( n, ... ) if CVARS[ n ] then CVARS[ n ].v = ( ... ) end end
FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED = 1, 2, 4

------------------------------------------------------------------------------------------
-- Entities and players
------------------------------------------------------------------------------------------
local ENTITY = {}
ENTITY.__index = ENTITY
local PLAYER = setmetatable( {}, { __index = ENTITY } )
PLAYER.__index = PLAYER
MOCK.ENTITY, MOCK.PLAYER = ENTITY, PLAYER
local META = { Entity = ENTITY, Player = PLAYER }
function FindMetaTable( n ) return META[ n ] end

local entities = {}
local nextIndex = 1
NULL = setmetatable( { __null = true }, { __index = function() return function() return nil end end } )
-- like GMod's: only objects with an IsValid method that says so
function IsValid( e )
	if not e or e == NULL then return false end
	if type( e ) == "table" and e.IsValid then return e:IsValid() end
	return false
end

local function NewEntity( class, mt )
	local e = setmetatable( {
		class = class, pos = Vector(), ang = Angle(), vel = Vector(), dt = {}, nw = {}, valid = true,
		index = nextIndex, model = "", scale = 1, callbacks = {},
	}, mt or ENTITY )
	nextIndex = nextIndex + 1
	entities[ #entities + 1 ] = e
	return e
end
MOCK.NewEntity = NewEntity

function ENTITY:IsValid() return self.valid end
function ENTITY:EntIndex() return self.index end
function ENTITY:GetClass() return self.class end
function ENTITY:IsPlayer() return false end
function ENTITY:IsBot() return false end
function ENTITY:IsWorld() return false end
function ENTITY:IsRagdoll() return self.class == "prop_ragdoll" end
function ENTITY:GetPos() return Vector( self.pos ) end
function ENTITY:SetPos( p ) self.pos = Vector( p ) end
function ENTITY:GetAngles() return Angle( self.ang ) end
function ENTITY:SetAngles( a ) self.ang = Angle( a ) end
function ENTITY:GetVelocity() return Vector( self.vel ) end
function ENTITY:SetVelocity( v ) self.vel = self.vel + v end
function ENTITY:SetLocalVelocity( v ) self.vel = Vector( v ) end
function ENTITY:WorldSpaceCenter() return self.pos + Vector( 0, 0, 36 ) end
function ENTITY:OBBMins() return Vector( -16, -16, 0 ) end
function ENTITY:OBBMaxs() return Vector( 16, 16, 72 ) end
function ENTITY:Remove() self.valid = false end
function ENTITY:Spawn() if self.Initialize then self:Initialize() end end
function ENTITY:Activate() end
function ENTITY:SetModel( m ) self.model = m end
function ENTITY:GetModel() return self.model end
function ENTITY:SetModelScale( s ) self.scale = s end
function ENTITY:GetModelScale() return self.scale end
function ENTITY:SetOwner( o ) self.owner = o end
function ENTITY:GetOwner() return self.owner or NULL end
function ENTITY:SetNoDraw() end
function ENTITY:DrawShadow() end
function ENTITY:SetMoveType( m ) self.movetype = m end
function ENTITY:GetMoveType() return self.movetype end
function ENTITY:SetSolid() end
function ENTITY:SetNotSolid() end
function ENTITY:SetCollisionGroup() end
function ENTITY:SetCustomCollisionCheck() end
function ENTITY:AddCallback( n, fn ) self.callbacks[ n ] = fn end
function ENTITY:SetSkin() end
function ENTITY:GetSkin() return 0 end
function ENTITY:GetBodyGroups() return {} end
function ENTITY:SetBodygroup() end
function ENTITY:GetBodygroup() return 0 end
function ENTITY:NextThink() end
function ENTITY:SetRenderBoundsWS() end
function ENTITY:SetRenderBounds() end
function ENTITY:SetRenderAngles() end
function ENTITY:SetPoseParameter() end
function ENTITY:InvalidateBoneCache() end
function ENTITY:LookupBone() return nil end
function ENTITY:LookupSequence() return -1 end
function ENTITY:SequenceDuration() return 1 end
function ENTITY:SetCycle() end
function ENTITY:SetPlaybackRate() end
function ENTITY:GetBoneMatrix() return nil end
function ENTITY:TranslatePhysBoneToBone() return 0 end
function ENTITY:GetPhysicsObjectCount() return 1 end
function ENTITY:EyePos() return self.pos + Vector( 0, 0, 64 * ( self.scale or 1 ) ) end
function ENTITY:KeyDown( k ) return ( ( self.oldButtons or 0 ) & k ) ~= 0 end
for _, kind in ipairs( { "Float", "Int", "Bool", "Vector", "Angle", "Entity", "String" } ) do
	local def = ( { Float = 0, Int = 0, Bool = false, String = "" } )[ kind ]
	ENTITY[ "SetNW2" .. kind ] = function( self, k, v ) self.nw[ k ] = v end
	ENTITY[ "GetNW2" .. kind ] = function( self, k, d )
		local v = self.nw[ k ]
		if v == nil then
			if d ~= nil then return d end
			if kind == "Entity" then return NULL end
			if kind == "Vector" then return Vector() end
			return def
		end
		return v
	end
	ENTITY[ "SetNW" .. kind ] = ENTITY[ "SetNW2" .. kind ]
	ENTITY[ "GetNW" .. kind ] = ENTITY[ "GetNW2" .. kind ]
	ENTITY[ "SetDT" .. kind ] = function( self, slot, v ) self.dt[ kind .. slot ] = v end
	ENTITY[ "GetDT" .. kind ] = function( self, slot )
		local v = self.dt[ kind .. slot ]
		if v == nil then
			if kind == "Entity" then return NULL end
			if kind == "Vector" then return Vector() end
			return def
		end
		return v
	end
end
function ENTITY:NetworkVar( kind, slot, name )
	self[ "Get" .. name ] = function( s ) return s[ "GetDT" .. kind ]( s, slot ) end
	self[ "Set" .. name ] = function( s, v ) s[ "SetDT" .. kind ]( s, slot, v ) end
end

local PHYS = {}
PHYS.__index = PHYS
function PHYS:IsValid() return true end
function PHYS:GetPos() return Vector( self.ent.pos ) end
function PHYS:SetPos( p ) self.ent.pos = Vector( p ) end
function PHYS:SetAngles() end
function PHYS:GetVelocity() return Vector( self.ent.vel ) end
function PHYS:SetVelocity( v ) self.ent.vel = Vector( v ) end
function PHYS:AddVelocity( v ) self.ent.vel = self.ent.vel + v end
function PHYS:AddAngleVelocity() end
function PHYS:Wake() end
function PHYS:EnableMotion() end
function ENTITY:GetPhysicsObjectNum() self.phys = self.phys or setmetatable( { ent = self }, PHYS ) return self.phys end
ENTITY.GetPhysicsObject = ENTITY.GetPhysicsObjectNum

-- Players
local players = {}
function PLAYER:IsPlayer() return true end
function PLAYER:IsBot() return self.bot end
function PLAYER:Nick() return self.name end
function PLAYER:Name() return self.name end
function PLAYER:Alive() return self.alive end
function PLAYER:IsOnGround() return self.onGround ~= false end
function PLAYER:EyeAngles() return Angle( self.eye ) end
function PLAYER:SetEyeAngles( a ) self.eye = Angle( a ) end
function PLAYER:GetAimVector() return self.eye:Forward() end
function PLAYER:GetHull() return self.hullMin or Vector( -16, -16, 0 ), self.hullMax or Vector( 16, 16, 72 ) end
function PLAYER:GetHullDuck() return Vector( -16, -16, 0 ), Vector( 16, 16, 36 ) end
function PLAYER:SetHull( a, b ) self.hullMin, self.hullMax = a, b end
function PLAYER:SetHullDuck() end
function PLAYER:SetViewOffset() end
function PLAYER:SetViewOffsetDucked() end
function PLAYER:GetStepSize() return 18 end
function PLAYER:SetStepSize() end
function PLAYER:LagCompensation() end
function PLAYER:Health() return self.hp end
function PLAYER:SetHealth( h ) self.hp = h end
function PLAYER:GetMaxHealth() return self.maxhp or 100 end
function PLAYER:SetMaxHealth( h ) self.maxhp = h end
function PLAYER:Team() return 0 end
function PLAYER:SetTeam() end
function PLAYER:UnSpectate() end
function PLAYER:SetupHands() end
function PLAYER:StripWeapons() end
function PLAYER:SetWalkSpeed() end
function PLAYER:SetSlowWalkSpeed() end
function PLAYER:SetRunSpeed() end
function PLAYER:SetJumpPower() end
function PLAYER:SetCrouchedWalkSpeed() end
function PLAYER:SetDuckSpeed() end
function PLAYER:SetUnDuckSpeed() end
function PLAYER:SetAvoidPlayers() end
function PLAYER:AllowFlashlight() end
function PLAYER:SetCanZoom() end
function PLAYER:AddDeaths() end
function PLAYER:AddFrags() end
function PLAYER:ChatPrint( s ) MOCK.chat = s end
function PLAYER:IsAdmin() return true end
function PLAYER:IsListenServerHost() return true end
function PLAYER:GetInfoNum( k, d ) return d end
function PLAYER:IsTyping() return false end
function PLAYER:GetViewEntity() return self end
function PLAYER:InVehicle() return false end
function PLAYER:GetTable() return self end
function PLAYER:Kick() self.valid = false for i, p in ipairs( players ) do if p == self then table.remove( players, i ) end end end
function PLAYER:TakeDamageInfo( info )
	if GAMEMODE.EntityTakeDamage and GAMEMODE:EntityTakeDamage( self, info ) then return end
	self.hp = self.hp - info.dmg
	if self.hp <= 0 then self:Kill() end
end
function PLAYER:Kill()
	if not self.alive then return end
	self.alive = false
	GAMEMODE:DoPlayerDeath( self, NULL, nil )
end
function PLAYER:Spawn()
	self.alive = true
	GAMEMODE:PlayerSpawn( self )
end
function PLAYER:AnimResetGestureSlot() end
function PLAYER:AddVCDSequenceToGestureSlot() end
function PLAYER:GetBonePosition() return self.pos end

player = {}
function player.GetAll() local t = {} for _, p in ipairs( players ) do if p.valid then t[ #t + 1 ] = p end end return t end
function player.GetHumans() local t = {} for _, p in ipairs( player.GetAll() ) do if not p.bot then t[ #t + 1 ] = p end end return t end
function player.GetBots() local t = {} for _, p in ipairs( player.GetAll() ) do if p.bot then t[ #t + 1 ] = p end end return t end
function player.GetCount() return #player.GetAll() end
function player.CreateNextBot( name ) return MOCK.NewPlayer( name, true ) end
function MOCK.NewPlayer( name, bot )
	local p = NewEntity( "player", PLAYER )
	p.name, p.bot, p.alive, p.hp, p.eye = name, bot, false, 100, Angle()
	players[ #players + 1 ] = p
	return p
end

game = { MaxPlayers = function() return 32 end, GetMap = function() return "gm_mock" end, GetWorld = function() return MOCK.world end }
MOCK.world = NewEntity( "worldspawn" )
MOCK.world.IsWorld = function() return true end
function Entity( i ) return i == 0 and MOCK.world or NULL end

ents = {}
local SENTS = {}
function ents.Create( class )
	local base = SENTS[ class ]
	local mt
	if base then
		local cls = setmetatable( {}, { __index = function( t, k ) local v = base[ k ] if v ~= nil then return v end return ENTITY[ k ] end } )
		cls.__index = cls
		mt = cls
	end
	local e = NewEntity( class, mt )
	if base and base.SetupDataTables then e:SetupDataTables() end
	return e
end
function ents.FindByClass( class )
	local t = {}
	for _, e in ipairs( entities ) do if e.valid and e.class == class then t[ #t + 1 ] = e end end
	return t
end
function ents.GetAll() local t = {} for _, e in ipairs( entities ) do if e.valid then t[ #t + 1 ] = e end end return t end
function MOCK.ThinkEntities()
	for _, e in ipairs( entities ) do
		if e.valid and e.class ~= "player" and e.Think then e:Think() end
	end
end
scripted_ents = { Register = function( t, name ) SENTS[ name ] = t end, Get = function( n ) return SENTS[ n ] end }
effects = { Register = function() end }

------------------------------------------------------------------------------------------
-- util
------------------------------------------------------------------------------------------
local function Miss( t )
	return { Hit = false, HitWorld = false, Fraction = 1, HitPos = Vector( t.endpos ), StartPos = Vector( t.start ), HitNormal = Vector( 0, 0, 1 ), Entity = NULL, StartSolid = false, AllSolid = false, HitSky = false, SurfaceProps = 0 }
end
util = {
	TraceLine = function( t )
		-- a flat floor at z = 0
		if t.endpos.z < 0 and t.start.z >= 0 then
			local f = t.start.z / ( t.start.z - t.endpos.z )
			local r = Miss( t )
			r.Hit, r.HitWorld, r.Fraction = true, true, f
			r.HitPos = t.start + ( t.endpos - t.start ) * f
			return r
		end
		return Miss( t )
	end,
	TraceHull = function( t )
		if t.endpos.z < 0 and t.start.z >= 0 then
			local f = t.start.z / ( t.start.z - t.endpos.z )
			local r = Miss( t )
			r.Hit, r.HitWorld, r.Fraction = true, true, f
			r.HitPos = t.start + ( t.endpos - t.start ) * f
			return r
		end
		return Miss( t )
	end,
	Effect = function( name ) MOCK.effects = ( MOCK.effects or 0 ) + 1 end,
	AddNetworkString = function() end,
	PrecacheModel = function() end,
	IsValidModel = function() return false end,
	ScreenShake = function() end,
	Decal = function() end,
}
function EffectData()
	local d = {}
	return setmetatable( d, { __index = function( t, k )
		if k:sub( 1, 3 ) == "Set" then return function( s, v ) rawset( s, k:sub( 4 ), v ) end end
		if k:sub( 1, 3 ) == "Get" then return function( s ) return rawget( s, k:sub( 4 ) ) end end
	end } )
end
function DamageInfo()
	local d = { dmg = 0 }
	function d:SetDamage( v ) self.dmg = v end
	function d:GetDamage() return self.dmg end
	function d:SetDamageType( v ) self.dtype = v end
	function d:IsDamageType( v ) return self.dtype == v end
	function d:SetAttacker( a ) self.att = a end
	function d:GetAttacker() return self.att end
	function d:SetInflictor() end
	return d
end

physenv = { SetGravity = function() end, GetPerformanceSettings = function() return {} end, SetPerformanceSettings = function() end }
file = {
	Exists = function( p, where )
		if where == "LUA" or where == "GAME" then return MOCK.FileExists( p ) end
		return false
	end,
	Find = function( p, where ) return MOCK.FileFind( p ) end,
	Read = function() return nil end,
	Write = function() end,
	CreateDir = function() end,
}
net = setmetatable( {}, { __index = function() return function() end end } )
team = setmetatable( {}, { __index = function() return function() return 0 end end } )
list = setmetatable( {}, { __index = function() return function() return {} end end } )
game.AddParticles = function() end
IN_ATTACK, IN_JUMP, IN_DUCK, IN_FORWARD, IN_BACK, IN_USE, IN_CANCEL, IN_LEFT, IN_RIGHT, IN_MOVELEFT, IN_MOVERIGHT, IN_ATTACK2, IN_RUN, IN_RELOAD, IN_ALT1, IN_ALT2, IN_SCORE, IN_SPEED, IN_WALK, IN_ZOOM, IN_WEAPON1, IN_WEAPON2, IN_BULLRUSH, IN_GRENADE1, IN_GRENADE2 =
	1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288, 1048576, 2097152, 4194304, 8388608, 16777216
MASK_SOLID_BRUSHONLY, MASK_PLAYERSOLID, MASK_SHOT, MASK_SOLID = 1, 2, 3, 4
COLLISION_GROUP_PLAYER_MOVEMENT, COLLISION_GROUP_WEAPON, COLLISION_GROUP_DEBRIS = 1, 2, 3
MOVETYPE_NONE, MOVETYPE_WALK, MOVETYPE_NOCLIP = 0, 2, 8
SOLID_NONE, SOLID_VPHYSICS = 0, 6
DMG_GENERIC, DMG_DROWN, DMG_BURN = 0, 16384, 8
TEAM_UNASSIGNED = 1001
RENDERGROUP_TRANSLUCENT, RENDERGROUP_OPAQUE = 1, 2
ACT_MP_STAND_IDLE, ACT_MP_WALK, ACT_MP_RUN, ACT_MP_CROUCH_IDLE, ACT_MP_CROUCHWALK, ACT_MP_JUMP, ACT_MP_SWIM, ACT_LAND = 1, 2, 3, 4, 5, 6, 7, 8
ACT_HL2MP_IDLE_FIST, ACT_HL2MP_WALK_FIST, ACT_HL2MP_RUN_FIST, ACT_HL2MP_IDLE_CROUCH_FIST, ACT_HL2MP_WALK_CROUCH_FIST, ACT_HL2MP_JUMP_FIST, ACT_HL2MP_SWIM_FIST = 11, 12, 13, 14, 15, 16, 17
GESTURE_SLOT_ATTACK_AND_RELOAD, GESTURE_SLOT_CUSTOM = 1, 6
TEXT_ALIGN_CENTER, TEXT_ALIGN_LEFT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, TEXT_ALIGN_BOTTOM = 1, 0, 2, 3, 4
KEY_F, KEY_Q, KEY_R, KEY_G, KEY_1, KEY_2, KEY_3, KEY_4, KEY_LSHIFT, KEY_I, KEY_O, MOUSE_LEFT = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 107
FILL, LEFT, RIGHT, TOP, BOTTOM = 1, 2, 3, 4, 5

-- client-only libraries are sinks
for _, n in ipairs( { "surface", "draw", "render", "cam", "vgui", "gui", "halo", "language", "sound" } ) do _G[ n ] = Sink end
input = { GetKeyName = function() return "k" end, IsButtonDown = function() return false end, IsKeyDown = function() return false end }
Material = function() return Sink end
ParticleEmitter = function() return Sink end
ClientsideModel = function() return Sink end
ScrW = function() return 1920 end
ScrH = function() return 1080 end
EyePos = function() return Vector() end
EyeAngles = function() return Angle() end
Matrix = function() return Sink end
LocalPlayer = function() return MOCK.localPlayer or NULL end
AddCSLuaFile = function() end
